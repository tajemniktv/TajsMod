# ==============================================================================
# Taj's Mod - Upload Labs
# Group Picker Mode - Jump to Group feature
# Author: TajemnikTV
# ==============================================================================
class_name TajsModGroupPickerMode
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/mode_base.gd"

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

## Emitted when a group is selected
signal group_selected(group)

# State
var _all_groups: Array = []
var _items: Array[Dictionary] = []
var _goto_manager = null


func enter() -> void:
	super.enter()


func exit() -> void:
	super.exit()
	_all_groups.clear()
	_items.clear()
	_goto_manager = null


func get_breadcrumb() -> String:
	return "📍 Jump to Group (%d groups)" % _all_groups.size()


func filter(query: String) -> void:
	if query.is_empty():
		_build_items(_all_groups)
	else:
		var filtered: Array = []
		var query_lower := query.to_lower()
		
		for group in _all_groups:
			if not is_instance_valid(group):
				continue
			
			var group_name := _get_group_name(group)
			if query_lower in group_name.to_lower():
				filtered.append(group)
		
		_build_items(filtered)
	
	items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
	return _items


func execute_selection(item: Dictionary) -> bool:
	var group = item.get("_group_ref", null)
	
	if not is_instance_valid(group):
		Signals.notify.emit("exclamation", "Group no longer exists")
		request_close.emit()
		return true
	
	group_selected.emit(group)
	
	Sound.play("click")
	request_close.emit()
	return true


func handle_back() -> bool:
	# Group picker exits immediately on back
	return false


## Setup the picker with groups
func setup(groups: Array, goto_manager) -> void:
	_all_groups = groups.duplicate()
	_goto_manager = goto_manager
	_build_items(_all_groups)


func _build_items(groups: Array) -> void:
	_items.clear()
	
	for group in groups:
		if not is_instance_valid(group):
			continue
		
		var group_name := _get_group_name(group)
		var icon_path := _get_group_icon(group)
		
		_items.append({
			"id": str(group.get_instance_id()),
			"title": group_name,
			"hint": "",
			"category_path": [],
			"icon_path": icon_path,
			"is_category": false,
			"badge": "SAFE",
			"_group_ref": group
		})


func _get_group_name(group) -> String:
	if _goto_manager and _goto_manager.has_method("get_group_name"):
		return _goto_manager.get_group_name(group)
	elif group.has_method("get_window_name"):
		return group.get_window_name()
	elif group.get("custom_name") and not group.custom_name.is_empty():
		return group.custom_name
	return "Group"


func _get_group_icon(group) -> String:
	if _goto_manager and _goto_manager.has_method("get_group_icon_path"):
		return _goto_manager.get_group_icon_path(group)
	return "res://textures/icons/window.png"
