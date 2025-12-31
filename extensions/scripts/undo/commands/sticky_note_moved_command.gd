# ==============================================================================
# Taj's Mod - Upload Labs
# StickyNoteMovedCommand - Undoable command for sticky note movement
# Author: TajemnikTV
# ==============================================================================
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_command.gd"

var _manager = null
var _note_id: String = ""
var _before_pos: Vector2 = Vector2.ZERO
var _after_pos: Vector2 = Vector2.ZERO

## Setup the command
func setup(manager, note_id: String, before: Vector2, after: Vector2) -> void:
    _manager = manager
    _note_id = note_id
    _before_pos = before
    _after_pos = after
    description = "Move Sticky Note"

## Execute (move to after)
func execute() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    var note = _manager._notes.get(_note_id)
    if is_instance_valid(note):
        note.position = _after_pos
        # Notify changes implicitly via note's logic or explicitly if needed?
        # StickyNote doesn't have a 'moved' signal for external sync other than drag/duplicate
        # But setting position is enough for rendering.
        # We might want to save though.
        _manager.save_notes()
        return true
        
    return false

## Undo (move to before)
func undo() -> bool:
    if not is_instance_valid(_manager):
        return false
        
    var note = _manager._notes.get(_note_id)
    if is_instance_valid(note):
        note.position = _before_pos
        _manager.save_notes()
        return true
        
    return false

## Check if command is valid
func is_valid() -> bool:
    if not is_instance_valid(_manager): return false
    # Helper validity: Note must exist?
    # If note was deleted, we can't move it. 
    # But if we undo deletion, we might want to redo movement?
    # Usually if note is gone, invalid.
    return _manager._notes.has(_note_id)
