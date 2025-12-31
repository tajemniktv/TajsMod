# ==============================================================================
# Taj's Mod - Upload Labs
# StickyNoteDeletedCommand - Undoable command for sticky note deletion
# Author: TajemnikTV
# ==============================================================================
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_command.gd"

var _manager = null
var _note_id: String = ""
var _note_data: Dictionary = {}

## Setup the command
func setup(manager, note_id: String, note_data: Dictionary) -> void:
    _manager = manager
    _note_id = note_id
    _note_data = note_data.duplicate()
    description = "Delete Sticky Note"

## Execute (redo deletion)
func execute() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    _manager.delete_note(_note_id)
    return true

## Undo (restore note)
func undo() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    # Recreate the note using the stored data
    var note = _manager._create_note_from_data(_note_data)
    return is_instance_valid(note)

## Check if command is valid
func is_valid() -> bool:
    return is_instance_valid(_manager)
