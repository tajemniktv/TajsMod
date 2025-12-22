# ==============================================================================
# Taj's Mod - Upload Labs
# Focus Handler - Mutes/reduces audio when game loses focus
# Author: TajemnikTV
# ==============================================================================
class_name TajsModFocusHandler
extends Node

const LOG_NAME = "TajsModded:FocusHandler"

var _config # TajsModConfigManager reference
var _enabled: bool = true
var _background_volume: float = 0.0 # 0-100%
var _was_focused: bool = true
var _stored_master_volume_db: float = 0.0


func _init() -> void:
	pass


func setup(config) -> void:
	_config = config
	_enabled = config.get_value("mute_on_focus_loss", true)
	_background_volume = config.get_value("background_volume", 0.0)
	
	# Store current master volume
	_stored_master_volume_db = AudioServer.get_bus_volume_db(0)
	ModLoaderLog.info("Focus handler initialized (enabled: %s, bg_vol: %s%%)" % [_enabled, _background_volume], LOG_NAME)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _config:
		_config.set_value("mute_on_focus_loss", enabled)
	
	# If disabling while unfocused, restore volume
	if not enabled and not _was_focused:
		_restore_volume()


func is_enabled() -> bool:
	return _enabled


func set_background_volume(volume: float) -> void:
	_background_volume = clampf(volume, 0.0, 100.0)
	if _config:
		_config.set_value("background_volume", _background_volume)
	
	# If currently unfocused, apply new volume immediately
	if not _was_focused and _enabled:
		_apply_background_volume()


func get_background_volume() -> float:
	return _background_volume


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_focus_lost()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_focus_gained()


func _on_focus_lost() -> void:
	if _was_focused:
		_was_focused = false
		if _enabled:
			# Store current master volume before changing
			_stored_master_volume_db = AudioServer.get_bus_volume_db(0)
			_apply_background_volume()
			ModLoaderLog.info("Focus lost - audio reduced to %s%%" % _background_volume, LOG_NAME)


func _on_focus_gained() -> void:
	if not _was_focused:
		_was_focused = true
		if _enabled:
			_restore_volume()
			ModLoaderLog.info("Focus gained - audio restored", LOG_NAME)


func _apply_background_volume() -> void:
	# Convert percentage to linear then to dB
	var linear_volume: float = _background_volume / 100.0
	var db_volume: float = linear_to_db(linear_volume) if linear_volume > 0 else -80.0
	AudioServer.set_bus_volume_db(0, db_volume)


func _restore_volume() -> void:
	AudioServer.set_bus_volume_db(0, _stored_master_volume_db)
