# =============================================================================
# Taj's Mod - Upload Labs
# Workshop Sync - Forces Steam Workshop downloads for subscribed items
# Author: TajemnikTV
# =============================================================================
extends Node

const LOG_NAME = "TajsModded:WorkshopSync"

# Steam UGC Item State Flags (from Steamworks SDK)
const STATE_NONE := 0
const STATE_SUBSCRIBED := 1
const STATE_LEGACY_ITEM := 2
const STATE_INSTALLED := 4
const STATE_NEEDS_UPDATE := 8
const STATE_DOWNLOADING := 16
const STATE_DOWNLOAD_PENDING := 32

# Settings
var sync_on_startup := true
var high_priority_downloads := true

# State
var _steam_available := false
var _sync_in_progress := false
var _triggered_ids: Dictionary = {} # PublishedFileId -> true (to avoid re-triggering)
var _pending_downloads: Dictionary = {} # PublishedFileId -> true (waiting for completion)
var _total_triggered := 0
var _completed_count := 0

# Callbacks
var _on_restart_required: Callable = Callable() # Called when we need to show restart window
var _debug_log_callback: Callable = Callable()

signal sync_started()
signal sync_completed(updated_count: int)
signal download_progress(file_id: int, bytes_downloaded: int, bytes_total: int)

func _ready() -> void:
	_check_steam_availability()
	if _steam_available:
		_connect_steam_signals()

func _process(_delta: float) -> void:
	# Pump Steam callbacks if Steam is available
	if _steam_available:
		var steam = _get_steam_api()
		if steam and steam.has_method("run_callbacks"):
			steam.run_callbacks()

## Get the Steam API object (from GlobalSteam or Engine singleton)
func _get_steam_api() -> Object:
	# Prefer GlobalSteam's api property
	if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("GlobalSteam"):
		var global_steam = Engine.get_main_loop().root.get_node("GlobalSteam")
		if global_steam.initialized and global_steam.api != null:
			return global_steam.api
	# Fallback to Engine singleton
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null

## Check if Steam is initialized and logged on
func _check_steam_availability() -> void:
	# The game uses GlobalSteam autoload which wraps the Steam singleton
	# Check if GlobalSteam exists and is initialized
	if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("GlobalSteam"):
		var global_steam = Engine.get_main_loop().root.get_node("GlobalSteam")
		if global_steam.initialized and global_steam.api != null:
			_steam_available = true
			_log("Steam is available via GlobalSteam. Workshop Sync enabled.")
			return
	
	# Fallback: try direct Engine singleton
	if Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		# Just check if we can access the API at all
		if steam != null:
			_steam_available = true
			_log("Steam is available via Engine singleton. Workshop Sync enabled.")
			return
	
	_log("Steam not available. Workshop Sync disabled.")
	_steam_available = false

## Connect to GodotSteam UGC signals if they exist
func _connect_steam_signals() -> void:
	var steam = _get_steam_api()
	if steam == null:
		return
	
	# item_downloaded signal: (app_id: int, file_id: int, result: int)
	if steam.has_signal("item_downloaded"):
		if not steam.is_connected("item_downloaded", _on_item_downloaded):
			steam.connect("item_downloaded", _on_item_downloaded)
			_log("Connected to item_downloaded signal.")
	else:
		_log("item_downloaded signal not found. Will poll for completion.")

## Start the sync process
func start_sync() -> void:
	if not _steam_available:
		_log("Cannot sync: Steam not available.")
		return
	
	if _sync_in_progress:
		_log("Sync already in progress.")
		return
	
	_sync_in_progress = true
	_total_triggered = 0
	_completed_count = 0
	_pending_downloads.clear()
	
	emit_signal("sync_started")
	_log("Starting Workshop Sync...")
	
	var steam = _get_steam_api()
	if steam == null:
		_log("Failed to get Steam API.")
		_finish_sync()
		return
	
	# Get subscribed items count
	var num_subscribed := _get_num_subscribed_items(steam)
	_log("Found " + str(num_subscribed) + " subscribed items.")
	
	if num_subscribed == 0:
		_finish_sync()
		return
	
	# Get subscribed item IDs
	var subscribed_items := _get_subscribed_items(steam, num_subscribed)
	
	# Check each item's state
	for file_id in subscribed_items:
		if _triggered_ids.has(file_id):
			continue # Already triggered this session
		
		var state := steam.getItemState(file_id) as int
		var needs_download := _should_download(state)
		
		if needs_download:
			_trigger_download(steam, file_id)
	
	if _total_triggered == 0:
		_log("All subscribed items are up to date.")
		_finish_sync()
	else:
		_log("Triggered downloads for " + str(_total_triggered) + " items.")
		Signals.notify.emit("download", "Workshop updates started (" + str(_total_triggered) + " items)")

## Get number of subscribed items (handles API differences)
func _get_num_subscribed_items(steam) -> int:
	# Some GodotSteam versions have include_locally_disabled parameter
	var methods = steam.get_method_list()
	for m in methods:
		if m["name"] == "getNumSubscribedItems":
			var args = m.get("args", [])
			if args.size() > 0:
				# Has include_locally_disabled parameter
				return steam.getNumSubscribedItems(true)
			else:
				return steam.getNumSubscribedItems()
	return 0

## Get subscribed item IDs (handles API differences)
func _get_subscribed_items(steam, count: int) -> Array:
	var methods = steam.get_method_list()
	for m in methods:
		if m["name"] == "getSubscribedItems":
			var args = m.get("args", [])
			if args.size() > 0:
				# Has include_locally_disabled parameter
				return steam.getSubscribedItems(true)
			else:
				return steam.getSubscribedItems()
	return []

## Determine if an item needs to be downloaded
func _should_download(state: int) -> bool:
	# Needs update
	if state & STATE_NEEDS_UPDATE:
		return true
	# Subscribed but not installed
	if (state & STATE_SUBSCRIBED) and not (state & STATE_INSTALLED):
		return true
	return false

## Trigger download for a specific item
func _trigger_download(steam, file_id: int) -> void:
	_log("Triggering download for item: " + str(file_id))
	steam.downloadItem(file_id, high_priority_downloads)
	_triggered_ids[file_id] = true
	_pending_downloads[file_id] = true
	_total_triggered += 1

## Handle item_downloaded signal from GodotSteam
func _on_item_downloaded(app_id: int, file_id: int, result: int) -> void:
	if not _pending_downloads.has(file_id):
		return # Not one we triggered
	
	_pending_downloads.erase(file_id)
	_completed_count += 1
	
	if result == 1: # k_EResultOK
		_log("Item " + str(file_id) + " downloaded successfully.")
	else:
		_log("Item " + str(file_id) + " download failed with result: " + str(result))
	
	emit_signal("download_progress", file_id, 0, 0)
	
	# Check if all downloads are complete
	if _pending_downloads.is_empty():
		_finish_sync()

## Finish the sync process
func _finish_sync() -> void:
	_sync_in_progress = false
	
	emit_signal("sync_completed", _total_triggered)
	
	if _total_triggered > 0:
		_log("Workshop Sync complete. " + str(_total_triggered) + " items were updated.")
		Signals.notify.emit("check", "Workshop updates finished. Restart recommended.")
		
		# Show restart required window
		if _on_restart_required.is_valid():
			_on_restart_required.call()
	else:
		_log("Workshop Sync complete. No updates needed.")

## Set callback for when restart is required
func set_restart_callback(callback: Callable) -> void:
	_on_restart_required = callback

## Set debug log callback
func set_debug_log_callback(callback: Callable) -> void:
	_debug_log_callback = callback

## Check if Steam is available
func is_steam_available() -> bool:
	return _steam_available

## Check if sync is in progress
func is_syncing() -> bool:
	return _sync_in_progress

## Internal logging
func _log(message: String) -> void:
	ModLoaderLog.info(message, LOG_NAME)
	# Debug callback is for UI display only, don't duplicate to log
	# (the callback in mod_main also logs, causing double output)
