# ==============================================================================
# Taj's Mod - Upload Labs
# Node Group Z-Order Fix - Ensures contained groups render on top
# Author: TajemnikTV
# ==============================================================================
#
# HOW NODE GROUPS ARE LOCATED:
# Node Groups are identified by checking `window.get("window") == "group"` on
# nodes in the "selectable" group. This matches how the base game identifies them.
#
# HOW CONTAINMENT/DEPTH IS COMPUTED:
# 1. For each group, we get its global rect via get_global_rect()
# 2. Group A "contains" Group B if A.encloses(B) with a small epsilon margin
# 3. Depth = count of other groups that fully contain this group
# 4. z_index = BASE_Z + depth, so deeply nested groups render on top
#
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:ZOrder"

# Z-index base value (above normal windows which are typically 0)
const BASE_Z_INDEX: int = 10

# Epsilon margin for containment detection (prevents jitter at boundaries)
const CONTAINMENT_EPSILON: float = 4.0

# Debounce timer for updates during rapid changes
const DEBOUNCE_MS: float = 50.0

# State
var _groups: Array = [] # All current Node Groups
var _rect_hashes: Dictionary = {} # group instance_id -> rect hash for change detection
var _update_pending: bool = false
var _debounce_timer: Timer = null
var _initialized: bool = false


func _ready() -> void:
	# Create debounce timer
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = DEBOUNCE_MS / 1000.0
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)
	
	# Connect to tree signals for detecting new/removed groups
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	# Initial scan after a short delay to let the scene settle
	await get_tree().create_timer(0.1).timeout
	_full_scan()
	_initialized = true
	
	ModLoaderLog.info("Node Group Z-Order Fix initialized", LOG_NAME)


func _on_node_added(node: Node) -> void:
	if not _initialized:
		return
	
	# Check if it's a Node Group
	if _is_node_group(node):
		_connect_group(node)
		_request_update()


func _on_node_removed(node: Node) -> void:
	if not _initialized:
		return
	
	# Clean up if it was a tracked group
	var id = node.get_instance_id()
	if _rect_hashes.has(id):
		_rect_hashes.erase(id)
		_groups.erase(node)
		_request_update()


## Check if a node is a Node Group
func _is_node_group(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if not node.is_in_group("selectable"):
		return false
	return node.get("window") == "group"


## Full scan to find all Node Groups and set up connections
func _full_scan() -> void:
	_groups.clear()
	_rect_hashes.clear()
	
	for node in get_tree().get_nodes_in_group("selectable"):
		if _is_node_group(node):
			_connect_group(node)
	
	_compute_and_apply_z_order()


## Connect to a group's signals for change detection
func _connect_group(group: Node) -> void:
	if not is_instance_valid(group):
		return
	
	if group in _groups:
		return # Already tracking
	
	_groups.append(group)
	
	# Connect to item_rect_changed for move/resize detection
	if group.has_signal("item_rect_changed"):
		if not group.item_rect_changed.is_connected(_on_group_rect_changed):
			group.item_rect_changed.connect(_on_group_rect_changed.bind(group))
	
	# Also connect to resized signal as backup
	if group.has_signal("resized"):
		if not group.resized.is_connected(_on_group_rect_changed):
			group.resized.connect(_on_group_rect_changed.bind(group))


## Called when a group's rect changes
func _on_group_rect_changed(group: Node) -> void:
	if not is_instance_valid(group):
		return
	_request_update()


## Request an update with debouncing
func _request_update() -> void:
	if _update_pending:
		return
	
	_update_pending = true
	
	# Restart the debounce timer
	if _debounce_timer.is_stopped():
		_debounce_timer.start()
	else:
		# Timer already running, it will handle the update
		pass


## Called when debounce timer expires
func _on_debounce_timeout() -> void:
	_update_pending = false
	
	# Check if any rects actually changed
	if _check_for_changes():
		_compute_and_apply_z_order()


## Check if any group rects have changed since last update
func _check_for_changes() -> bool:
	var changed := false
	
	for group in _groups:
		if not is_instance_valid(group):
			changed = true
			continue
		
		var id = group.get_instance_id()
		var rect = _get_group_rect(group)
		var hash = _hash_rect(rect)
		
		if not _rect_hashes.has(id) or _rect_hashes[id] != hash:
			_rect_hashes[id] = hash
			changed = true
	
	return changed


## Get the global rect of a group
func _get_group_rect(group: Node) -> Rect2:
	if group.has_method("get_global_rect"):
		return group.get_global_rect()
	elif group is Control:
		return Rect2(group.global_position, group.size)
	return Rect2()


## Simple hash of a rect for change detection
func _hash_rect(rect: Rect2) -> int:
	# Round to avoid floating point noise
	var x = int(rect.position.x)
	var y = int(rect.position.y)
	var w = int(rect.size.x)
	var h = int(rect.size.y)
	return x ^ (y << 8) ^ (w << 16) ^ (h << 24)


## Check if rect A fully contains rect B (with epsilon margin)
func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	# Shrink the outer rect by epsilon to require clear containment
	var shrunk_outer = outer.grow(-CONTAINMENT_EPSILON)
	return shrunk_outer.encloses(inner)


## Compute containment depth for each group
func _compute_depths() -> Dictionary:
	# depths: group instance_id -> depth (int)
	var depths := {}
	var valid_groups := []
	
	# Filter to only valid, visible groups
	for group in _groups:
		if not is_instance_valid(group):
			continue
		if not group.visible:
			continue
		valid_groups.append(group)
		depths[group.get_instance_id()] = 0
	
	# For each group, count how many other groups contain it
	for group in valid_groups:
		var group_id = group.get_instance_id()
		var group_rect = _get_group_rect(group)
		var depth := 0
		
		for other in valid_groups:
			if other == group:
				continue
			var other_rect = _get_group_rect(other)
			
			# Does 'other' contain 'group'?
			if _rect_contains(other_rect, group_rect):
				depth += 1
		
		depths[group_id] = depth
	
	return depths


## Apply z_index based on computed depths
func _compute_and_apply_z_order() -> void:
	var depths = _compute_depths()
	
	for group in _groups:
		if not is_instance_valid(group):
			continue
		
		var id = group.get_instance_id()
		var depth = depths.get(id, 0)
		
		# Set z_index: base + depth so nested groups are on top
		var target_z = BASE_Z_INDEX + depth
		
		if group.z_index != target_z:
			group.z_index = target_z
			group.z_as_relative = true # Relative to parent


## Force a full rescan and update (can be called externally)
func force_update() -> void:
	_full_scan()
