# ==============================================================================
# Taj's Mod - Upload Labs
# UndoCommand - Base class for all undoable commands
# Author: TajemnikTV
# ==============================================================================
class_name TajsUndoCommand
extends RefCounted

## Human-readable description of this command (for UI/debugging)
var description: String = "Unknown Action"

## Timestamp for creating the command (used for merge grouping)
var timestamp: int = 0
const MERGE_WINDOW_MS: int = 1000 # Max time betweeen commands to allow merging

func _init() -> void:
    timestamp = Time.get_ticks_msec()


## Execute the action (do/redo). Returns true if successful.
func execute() -> bool:
    push_warning("UndoCommand.execute() not implemented")
    return false


## Undo the action. Returns true if successful.
func undo() -> bool:
    push_warning("UndoCommand.undo() not implemented")
    return false


## Get a human-readable description of this command
func get_description() -> String:
    return description


## Check if this command is still valid (referenced nodes exist, etc.)
## Override in subclasses that hold node references.
func is_valid() -> bool:
    return true


## Merge with another command of the same type (for coalescing).
## Returns true if merge was successful, false if commands should stay separate.
## Override in subclasses that support merging.
func merge_with(other) -> bool:
    return false
