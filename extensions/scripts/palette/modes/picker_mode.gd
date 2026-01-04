# ==============================================================================
# Taj's Mod - Upload Labs
# Picker Mode - Node picker for wire-drop feature
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPickerMode
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/mode_base.gd"

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

## Emitted when a node is selected from the picker
signal node_selected(node_id: String, spawn_pos: Vector2, origin_info: Dictionary)

# State
var _origin_info: Dictionary = {}
var _spawn_position: Vector2 = Vector2.ZERO
var _all_nodes: Array[Dictionary] = []
var _items: Array[Dictionary] = []


func enter() -> void:
	super.enter()


func exit() -> void:
	super.exit()
	_origin_info.clear()
	_all_nodes.clear()
	_items.clear()


func get_breadcrumb() -> String:
	var origin_desc := ""
	if _origin_info.get("is_output", true):
		origin_desc = "connecting output → input"
	else:
		origin_desc = "connecting input ← output"
	return "🔌 Add Node (%s)" % origin_desc


func filter(query: String) -> void:
	if query.is_empty():
		_build_items(_all_nodes)
	else:
		var filtered: Array[Dictionary] = []
		var query_lower := query.to_lower()
		
		for node in _all_nodes:
			var name_lower: String = node.get("name", "").to_lower()
			var desc_lower: String = node.get("description", "").to_lower()
			var cat_lower: String = node.get("category", "").to_lower()
			
			if query_lower in name_lower or query_lower in desc_lower or query_lower in cat_lower:
				filtered.append(node)
		
		_build_items(filtered)
	
	items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
	return _items


func execute_selection(item: Dictionary) -> bool:
	var node_id: String = item.get("_node_id", item.get("id", ""))
	
	if node_id.is_empty():
		return false
	
	# Emit signal for controller to handle spawning
	# IMPORTANT: Pass a duplicate because exit() clears _origin_info
	node_selected.emit(node_id, _spawn_position, _origin_info.duplicate())
	
	Sound.play("click")
	request_close.emit()
	return true


func handle_back() -> bool:
	# Picker mode exits immediately on back
	return false


## Setup the picker with compatible nodes
func setup(compatible_nodes: Array[Dictionary], origin_info: Dictionary, spawn_position: Vector2) -> void:
	_origin_info = origin_info.duplicate()
	_spawn_position = spawn_position
	_all_nodes = compatible_nodes.duplicate()
	_build_items(_all_nodes)


func _build_items(nodes: Array[Dictionary]) -> void:
	_items.clear()
	
	for node_data in nodes:
		_items.append({
			"id": node_data.id,
			"title": node_data.get("name", node_data.id),
			"hint": node_data.get("description", ""),
			"category_path": [node_data.get("category", ""), node_data.get("sub_category", "")],
			"icon_path": "res://textures/icons/" + node_data.get("icon", "cog") + ".png",
			"is_category": false,
			"badge": "SAFE",
			"_node_id": node_data.id
		})
