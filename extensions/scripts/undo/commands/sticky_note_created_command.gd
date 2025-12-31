# ==============================================================================
# Taj's Mod - Upload Labs
# StickyNoteCreatedCommand - Undoable command for sticky note creation
# Author: TajemnikTV
# ==============================================================================
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_command.gd"

var _manager = null
var _note_id: String = ""
var _note_data: Dictionary = {}

## Setup the command
func setup(manager, note) -> void:
    _manager = manager
    _note_id = note.note_id
    _note_data = note.get_data()
    description = "Create Sticky Note"

## Execute (redo creation)
func execute() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    # Recreate the note using the stored data
    var note = _manager._create_note_from_data(_note_data)
    return is_instance_valid(note)

## Undo (delete note)
func undo() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    _manager.delete_note(_note_id)
    return true

## Check if command is valid
func is_valid() -> bool:
    return is_instance_valid(_manager)
