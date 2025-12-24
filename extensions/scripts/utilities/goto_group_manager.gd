# ==============================================================================
# Taj's Mod - Upload Labs
# Go To Group Manager - Navigate camera to Node Groups
# Author: TajemnikTV
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:GotoGroup"

# Signals for UI updates
signal groups_changed

# Cache
var _groups_cache: Array = []
var _bounds_cache: Dictionary = {} # group instance_id -> Rect2
var _cache_dirty: bool = true

# Animation
var _nav_tween: Tween = null

# UI references
var panel: Control = null


func _ready() -> void:
	# Connect to tree signals for detecting node changes
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
	# Check if it's a relevant node (window or could be a group)
	if node.is_in_group("selectable") or node.is_in_group("window"):
		_invalidate_cache()


func _on_node_removed(node: Node) -> void:
	# Invalidate on any removal from relevant groups
	_invalidate_cache()


func _invalidate_cache() -> void:
	_cache_dirty = true
	_bounds_cache.clear()


## Get all Node Groups currently on the desktop
func get_all_groups() -> Array:
	if _cache_dirty:
		_refresh_groups_cache()
	return _groups_cache


## Refresh the groups cache
func _refresh_groups_cache() -> void:
	_groups_cache.clear()
	
	for window in get_tree().get_nodes_in_group("selectable"):
		# Check if this is a Node Group by checking the "window" property
		if window.get("window") == "group":
			_groups_cache.append(window)
	
	_cache_dirty = false
	groups_changed.emit()


## Get the bounding rectangle of all nodes within a group
## Returns the combined Rect2 of all enclosed nodes, or the group's own rect if empty
func get_group_bounds(group) -> Rect2:
	if not is_instance_valid(group):
		return Rect2()
	
	var group_id = group.get_instance_id()
	
	# Check cache
	if _bounds_cache.has(group_id):
		return _bounds_cache[group_id]
	
	var group_rect = group.get_rect()
	var bounds: Rect2 = Rect2()
	var has_nodes: bool = false
	
	# Find all nodes enclosed by this group
	for window in get_tree().get_nodes_in_group("selectable"):
		if window == group:
			continue
		# Skip other groups
		if window.get("window") == "group":
			continue
		
		var window_rect = window.get_rect()
		if group_rect.encloses(window_rect):
			if not has_nodes:
				bounds = window_rect
				has_nodes = true
			else:
				bounds = bounds.merge(window_rect)
	
	# If no nodes found, use the group's own rect
	if not has_nodes:
		bounds = group_rect
	
	# Cache the result
	_bounds_cache[group_id] = bounds
	return bounds


## Navigate camera to focus on a specific group
func navigate_to_group(group) -> void:
	if not is_instance_valid(group):
		Signals.notify.emit("exclamation", "Group no longer exists")
		return
	
	var bounds = get_group_bounds(group)
	if bounds.size == Vector2.ZERO or bounds.size.x < 1 or bounds.size.y < 1:
		Signals.notify.emit("exclamation", "Group is empty")
		return
	
	# Cancel any existing navigation animation
	if _nav_tween and _nav_tween.is_valid():
		_nav_tween.kill()
	
	# Add ~15% padding around bounds
	var padding_x = bounds.size.x * 0.15
	var padding_y = bounds.size.y * 0.15
	var padded_bounds = bounds.grow_individual(padding_x, padding_y, padding_x, padding_y)
	
	# Get viewport size
	var viewport = get_viewport()
	if not viewport:
		return
	
	var viewport_size = viewport.get_visible_rect().size
	
	# Calculate required zoom to fit bounds in viewport
	var zoom_x = viewport_size.x / padded_bounds.size.x
	var zoom_y = viewport_size.y / padded_bounds.size.y
	var target_zoom_value = min(zoom_x, zoom_y)
	
	# Clamp zoom to sane values (matching game's camera limits)
	# Game uses min_zoom (varies) and max of 1.2-1.6
	target_zoom_value = clamp(target_zoom_value, 0.1, 1.2)
	var target_zoom = Vector2(target_zoom_value, target_zoom_value)
	
	# Calculate center of bounds
	var center = bounds.position + bounds.size / 2
	
	# Get the camera
	var camera = viewport.get_camera_2d()
	if not camera:
		# Fallback: just emit center_camera signal
		Signals.center_camera.emit(center)
		return
	
	# Clamp position to camera limits if available
	if camera.has_method("clamp_pos"):
		center = camera.clamp_pos(center)
	else:
		# Manual clamp based on typical limit
		var limit = camera.get("limit")
		if limit:
			center = Vector2(
				clampf(center.x, -limit, limit),
				clampf(center.y, -limit, limit)
			)
	
	# Animate the camera movement
	_nav_tween = create_tween()
	_nav_tween.set_ease(Tween.EASE_OUT)
	_nav_tween.set_trans(Tween.TRANS_CUBIC)
	_nav_tween.set_parallel(true)
	
	# Tween position
	_nav_tween.tween_property(camera, "position", center, 0.35)
	
	# Tween zoom
	_nav_tween.tween_property(camera, "zoom", target_zoom, 0.35)
	
	# Also update target_zoom for camera's internal state
	_nav_tween.tween_property(camera, "target_zoom", target_zoom, 0.35)
	
	# Get group name for notification
	var group_name = "Group"
	if group.has_method("get_window_name"):
		group_name = group.get_window_name()
	elif group.get("custom_name") and not group.custom_name.is_empty():
		group_name = group.custom_name
	
	Signals.notify.emit("check", "Navigated to: " + group_name)
	Sound.play("click2")


## Get the color of a group
func get_group_color(group) -> Color:
	if not is_instance_valid(group):
		return Color.WHITE
	
	# Check for custom color (from mod extension)
	var custom_color = group.get("custom_color")
	if custom_color and custom_color != Color.TRANSPARENT:
		return custom_color
	
	# Use the color index
	var color_idx = group.get("color")
	if color_idx == null:
		return Color.WHITE
	
	# Get colors array - try NEW_COLORS first (mod extension), then fallback
	var colors_array = group.get("NEW_COLORS")
	if colors_array == null:
		colors_array = group.get("colors")
	if colors_array == null:
		# Fallback to base game colors
		colors_array = ["1a202c", "1a2b22", "1a292b", "1a1b2b", "211a2b", "2b1a27", "2b1a1a"]
	
	if color_idx >= 0 and color_idx < colors_array.size():
		return Color(colors_array[color_idx])
	
	return Color.WHITE


## Get the icon path for a group
func get_group_icon_path(group) -> String:
	if not is_instance_valid(group):
		return "res://textures/icons/window.png"
	
	if group.has_method("get_icon"):
		return group.get_icon()
	
	var custom_icon = group.get("custom_icon")
	if custom_icon and not custom_icon.is_empty():
		return "res://textures/icons/" + custom_icon + ".png"
	
	return "res://textures/icons/window.png"


## Get the display name for a group
func get_group_name(group) -> String:
	if not is_instance_valid(group):
		return "Unknown Group"
	
	if group.has_method("get_window_name"):
		return group.get_window_name()
	
	var custom_name = group.get("custom_name")
	if custom_name and not custom_name.is_empty():
		return custom_name
	
	return "Group"


## Force refresh of all caches
func force_refresh() -> void:
	_invalidate_cache()
	_refresh_groups_cache()
