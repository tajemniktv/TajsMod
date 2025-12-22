# ==============================================================================
# Taj's Mod - Upload Labs
# Node Compatibility Filter - Filters spawnable nodes by pin compatibility
# Author: TajemnikTV
# ==============================================================================
class_name TajsModNodeCompatibilityFilter
extends RefCounted

const LOG_NAME = "TajsModded:NodeCompatibilityFilter"

# Cache of window connector info to avoid loading scenes repeatedly
var _window_connectors_cache: Dictionary = {}
var _cache_built: bool = false


func _init() -> void:
	pass


## Build cache of window connector information
func build_cache() -> void:
	if _cache_built:
		return
	
	_window_connectors_cache.clear()
	
	for window_id in Data.windows:
		var window_data: Dictionary = Data.windows[window_id]
		
		# Skip windows without scenes
		if not window_data.has("scene") or window_data.scene.is_empty():
			continue
		
		# Try to get connector info from the scene
		var connector_info := _get_window_connector_info(window_id, window_data)
		if not connector_info.is_empty():
			_window_connectors_cache[window_id] = connector_info
	
	_cache_built = true
	ModLoaderLog.info("Built node compatibility cache for %d windows" % _window_connectors_cache.size(), LOG_NAME)


## Get connector info for a window by loading its scene
func _get_window_connector_info(window_id: String, window_data: Dictionary) -> Dictionary:
	var scene_path: String = "res://scenes/windows/" + window_data.scene + ".tscn"
	
	if not ResourceLoader.exists(scene_path):
		return {}
	
	# Load scene to inspect ResourceContainers
	var scene: PackedScene = load(scene_path)
	if not scene:
		return {}
	
	var instance: Node = scene.instantiate()
	if not instance:
		return {}
	
	var info := {
		"id": window_id,
		"name": window_data.get("name", window_id),
		"description": window_data.get("description", ""),
		"category": window_data.get("category", ""),
		"sub_category": window_data.get("sub_category", ""),
		"icon": window_data.get("icon", ""),
		"inputs": [],
		"outputs": []
	}
	
	# Find ResourceContainers with input/output connectors
	_collect_connectors(instance, info)
	
	# Clean up
	instance.queue_free()
	
	return info


## Recursively collect connector info from a node tree
func _collect_connectors(node: Node, info: Dictionary) -> void:
	if node is ResourceContainer:
		var rc: ResourceContainer = node
		var shape := ""
		var color := ""
		
		# Get connector properties from the resource container
		if rc.override_connector.is_empty():
			# Need to use default_resource to determine connector type
			if not rc.default_resource.is_empty() and Data.resources.has(rc.default_resource):
				var resource_data: Dictionary = Data.resources[rc.default_resource]
				shape = resource_data.get("connection", "")
				color = resource_data.get("color", "")
		else:
			shape = rc.override_connector
			color = rc.override_color if not rc.override_color.is_empty() else "white"
		
		if not shape.is_empty():
			var connector_data := {
				"shape": shape,
				"color": color,
				"name": node.name
			}
			
			# Check if this container has input/output connectors
			if node.has_node("InputConnector"):
				info.inputs.append(connector_data)
			if node.has_node("OutputConnector"):
				info.outputs.append(connector_data)
	
	# Recurse into children
	for child in node.get_children():
		_collect_connectors(child, info)


## Get list of windows compatible with the given origin pin
## Returns array of window info dictionaries
func get_compatible_nodes(origin_shape: String, origin_color: String, origin_is_output: bool) -> Array[Dictionary]:
	if not _cache_built:
		build_cache()
	
	var compatible: Array[Dictionary] = []
	
	for window_id in _window_connectors_cache:
		var window_info: Dictionary = _window_connectors_cache[window_id]
		
		# If origin is OUTPUT, we need to find windows with compatible INPUTS
		# If origin is INPUT, we need to find windows with compatible OUTPUTS
		var target_pins: Array = window_info.outputs if not origin_is_output else window_info.inputs
		
		for pin in target_pins:
			if _is_compatible(origin_shape, origin_color, pin.shape, pin.color):
				# Add window to compatible list (only once per window)
				var already_added := false
				for existing in compatible:
					if existing.id == window_id:
						already_added = true
						break
				
				if not already_added:
					compatible.append(window_info.duplicate())
				break
	
	# Sort by category then name
	compatible.sort_custom(_sort_by_category_and_name)
	
	return compatible


## Check if two connectors are compatible (same logic as ResourceContainer.can_connect)
func _is_compatible(shape1: String, color1: String, shape2: String, color2: String) -> bool:
	# Shape must match
	if shape1 != shape2:
		return false
	
	# Color must match, or one must be white (wildcard)
	if color1 != "white" and color2 != "white" and color1 != color2:
		return false
	
	return true


## Sort function for windows
func _sort_by_category_and_name(a: Dictionary, b: Dictionary) -> bool:
	if a.category != b.category:
		return a.category < b.category
	if a.sub_category != b.sub_category:
		return a.sub_category < b.sub_category
	return a.name < b.name


## Clear the cache (call if window definitions change)
func clear_cache() -> void:
	_window_connectors_cache.clear()
	_cache_built = false


## Get total number of cached windows
func get_cache_size() -> int:
	return _window_connectors_cache.size()
