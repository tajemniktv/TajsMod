# ==============================================================================
# Taj's Mod - Upload Labs
# Note Picker Mode - Jump to Note feature
# Author: TajemnikTV
# ==============================================================================
class_name TajsModNotePickerMode
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/mode_base.gd"

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

## Emitted when a note is selected
signal note_selected(note)

# State
var _all_notes: Array = []
var _items: Array[Dictionary] = []
var _sticky_manager = null


func enter() -> void:
	super.enter()


func exit() -> void:
	super.exit()
	_all_notes.clear()
	_items.clear()
	_sticky_manager = null


func get_breadcrumb() -> String:
	return "📍 Jump to Note (%d notes)" % _all_notes.size()


func filter(query: String) -> void:
	if query.is_empty():
		_build_items(_all_notes)
	else:
		var filtered: Array = []
		var query_lower := query.to_lower()
		
		for note in _all_notes:
			if not is_instance_valid(note):
				continue
			
			var title: String = note.title_text if "title_text" in note else ""
			var body: String = note.body_text if "body_text" in note else ""
			
			if query_lower in title.to_lower() or query_lower in body.to_lower():
				filtered.append(note)
		
		_build_items(filtered)
	
	items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
	return _items


func execute_selection(item: Dictionary) -> bool:
	var note = item.get("_note_ref", null)
	
	if not is_instance_valid(note):
		Signals.notify.emit("exclamation", "Note no longer exists")
		request_close.emit()
		return true
	
	note_selected.emit(note)
	
	Sound.play("click")
	request_close.emit()
	return true


func handle_back() -> bool:
	# Note picker exits immediately on back
	return false


## Setup the picker with notes
func setup(notes: Array, sticky_manager) -> void:
	_all_notes = notes.duplicate()
	_sticky_manager = sticky_manager
	_build_items(_all_notes)


func _build_items(notes: Array) -> void:
	_items.clear()
	
	for note in notes:
		if not is_instance_valid(note):
			continue
		
		var title = note.title_text if "title_text" in note else "Note"
		var body = note.body_text if "body_text" in note else ""
		
		# Truncate body for hint
		var hint = body.replace("\n", " ").substr(0, 50)
		if body.length() > 50:
			hint += "..."
		
		_items.append({
			"id": str(note.get_instance_id()),
			"title": title,
			"hint": hint,
			"category_path": [],
			"icon_path": "res://textures/icons/star.png",
			"is_category": false,
			"badge": "SAFE",
			"_note_ref": note
		})
