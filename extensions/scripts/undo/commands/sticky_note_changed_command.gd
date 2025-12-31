# ==============================================================================
# Taj's Mod - Upload Labs
# StickyNoteChangedCommand - Undoable command for sticky note property changes
# Author: TajemnikTV
# ==============================================================================
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_command.gd"

var _manager = null
var _note_id: String = ""
var _before_data: Dictionary = {}
var _after_data: Dictionary = {}
var _changed_keys: Array = []

## Setup the command
func setup(manager, note_id: String, before: Dictionary, after: Dictionary) -> void:
    _manager = manager
    _note_id = note_id
    _before_data = before.duplicate()
    _after_data = after.duplicate()
    description = "Edit Sticky Note"
    
    # Identify what changed
    _changed_keys = []
    for key in after.keys():
        if not before.has(key) or str(before[key]) != str(after[key]):
            _changed_keys.append(key)
    # Check for removed keys
    for key in before.keys():
        if not after.has(key):
             if not key in _changed_keys:
                 _changed_keys.append(key)
                 
    _changed_keys.sort()

## Execute (apply after data)
func execute() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    var note = _manager._notes.get(_note_id)
    if is_instance_valid(note):
        note.load_from_data(_after_data)
        _manager.save_notes()
        return true
        
    return false

## Undo (apply before data)
func undo() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    var note = _manager._notes.get(_note_id)
    if is_instance_valid(note):
        note.load_from_data(_before_data)
        _manager.save_notes()
        return true
        
    return false

## Merge with subsequent command
func merge_with(other: RefCounted) -> bool:
    # Check if other is same type (we can't easily check class_name if it's script, but we can check script path or duck type)
    if other.get_script() != get_script():
        return false
        
    if other._note_id != _note_id:
        return false
        
    # Check if same properties changed
    if _changed_keys != other._changed_keys:
        return false
        
    # Time-based merge limit
    if timestamp - other.timestamp > MERGE_WINDOW_MS:
        return false
        
    # Merge: Update my after_data to be other's after_data
    _after_data = other._after_data
    timestamp = other.timestamp # Update timestamp to extend window?
    return true

## Check if command is valid
func is_valid() -> bool:
    if not is_instance_valid(_manager): return false
    return _manager._notes.has(_note_id)
