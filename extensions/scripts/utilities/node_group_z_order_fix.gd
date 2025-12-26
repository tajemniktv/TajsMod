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
# 3. Only groups with a containment relationship are reordered
# 4. Partially overlapping groups (not fully contained) keep their existing order
#
# APPROACH:
# For each pair of groups where A fully contains B:
#   - If B is currently drawn before A (wrong order), move B after A
# This ensures contained groups are always on top of their containers,
# while leaving non-contained groups in their current order.
#
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:ZOrder"

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
var _enabled: bool = true # Can be toggled via settings


## Enable or disable the z-order fix
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled and _initialized:
		# Re-apply fix when re-enabled
		_fix_containment_order()


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
	
	# Connect to selection changes - the game moves clicked items to front,
	# so we need to re-fix the order after selection changes
	Signals.selection_set.connect(_on_selection_changed)
	
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


## Called when selection changes - the game moves selected items to the front
## We need to re-fix containment order after a short delay
func _on_selection_changed() -> void:
	if not _initialized:
		return
	
	# Use call_deferred to let the game's move_child complete first
	call_deferred("_fix_containment_order")


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
	
	_fix_containment_order()


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


## Called when debounce timer expires
func _on_debounce_timeout() -> void:
	_update_pending = false
	
	# Check if any rects actually changed
	if _check_for_changes():
		_fix_containment_order()


## Check if any group rects have changed since last update
func _check_for_changes() -> bool:
	var changed := false
	
	for group in _groups:
		if not is_instance_valid(group):
			changed = true
			continue
		
		var id = group.get_instance_id()
		var rect = _get_group_rect(group)
		var new_hash = _hash_rect(rect)
		
		if not _rect_hashes.has(id) or _rect_hashes[id] != new_hash:
			_rect_hashes[id] = new_hash
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
	var x = int(rect.position.x)
	var y = int(rect.position.y)
	var w = int(rect.size.x)
	var h = int(rect.size.y)
	return x ^ (y << 8) ^ (w << 16) ^ (h << 24)


## Check if rect A fully contains rect B (with epsilon margin)
func _rect_fully_contains(outer: Rect2, inner: Rect2) -> bool:
	# Shrink the outer rect by epsilon to require clear containment
	var shrunk_outer = outer.grow(-CONTAINMENT_EPSILON)
	return shrunk_outer.encloses(inner)


## Fix sibling order only for groups with containment relationships
## If A fully contains B, then B must be drawn AFTER A (higher child index)
func _fix_containment_order() -> void:
	if not _enabled:
		return
	
	# Get valid groups with same parent
	var groups_by_parent: Dictionary = {} # parent -> [group, ...]
	
	for group in _groups:
		if not is_instance_valid(group):
			continue
		if not group.visible:
			continue
		
		var parent = group.get_parent()
		if not is_instance_valid(parent):
			continue
		
		if not groups_by_parent.has(parent):
			groups_by_parent[parent] = []
		groups_by_parent[parent].append(group)
	
	# For each parent, check containment pairs and fix order
	for parent in groups_by_parent:
		var groups_in_parent = groups_by_parent[parent]
		
		# Keep fixing until no more swaps are needed (bubble sort style)
		var fixed_something := true
		var max_iterations := 100 # Prevent infinite loops
		var iterations := 0
		
		while fixed_something and iterations < max_iterations:
			fixed_something = false
			iterations += 1
			
			# Check all pairs
			for i in range(groups_in_parent.size()):
				for j in range(i + 1, groups_in_parent.size()):
					var group_a = groups_in_parent[i]
					var group_b = groups_in_parent[j]
					
					if not is_instance_valid(group_a) or not is_instance_valid(group_b):
						continue
					
					var rect_a = _get_group_rect(group_a)
					var rect_b = _get_group_rect(group_b)
					
					var idx_a = group_a.get_index()
					var idx_b = group_b.get_index()
					
					# Case 1: A fully contains B
					# B should be drawn after A (idx_b > idx_a)
					if _rect_fully_contains(rect_a, rect_b):
						if idx_b < idx_a:
							# B is before A but should be after - move B after A
							parent.move_child(group_b, idx_a)
							fixed_something = true
					
					# Case 2: B fully contains A
					# A should be drawn after B (idx_a > idx_b)
					elif _rect_fully_contains(rect_b, rect_a):
						if idx_a < idx_b:
							# A is before B but should be after - move A after B
							parent.move_child(group_a, idx_b)
							fixed_something = true
					
					# Case 3: Partial overlap or no overlap - don't touch


## Force a full rescan and update (can be called externally)
func force_update() -> void:
	_full_scan()
