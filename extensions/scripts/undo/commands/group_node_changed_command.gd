# ==============================================================================
# Taj's Mod - Upload Labs
# GroupNodeChangedCommand - Undoable command for group node property changes (pattern, color, name)
# Author: TajemnikTV
# ==============================================================================
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_command.gd"

var _window_name: String = ""
var _before_data: Dictionary = {}
var _after_data: Dictionary = {}
var _changed_keys: Array = []

## Setup the command
func setup(window_name: String, before: Dictionary, after: Dictionary) -> void:
    _window_name = window_name
    _before_data = before.duplicate()
    _after_data = after.duplicate()
    description = "Edit Group Node"
    
    # Identify what changed
    _changed_keys = []
    for key in after.keys():
        if not before.has(key) or str(before[key]) != str(after[key]):
            # Use string comparison for robustness against float noise
            _changed_keys.append(key)
    # Check for removed keys
    for key in before.keys():
        if not after.has(key):
             if not key in _changed_keys:
                 _changed_keys.append(key)
                 
    _changed_keys.sort()


## Execute (apply after data)
func execute() -> bool:
    var window = _get_window()
    if is_instance_valid(window):
        if window.has_method("load_data"):
            window.load_data(_after_data)
            return true
    return false

## Undo (apply before data)
func undo() -> bool:
    var window = _get_window()
    if is_instance_valid(window):
        if window.has_method("load_data"):
            window.load_data(_before_data)
            return true
    return false

## Helper to find window
func _get_window() -> Node:
    if not Globals.desktop: return null
    var windows_root = Globals.desktop.get_node_or_null("Windows")
    if not windows_root: return null
    
    # Windows are named by their ID usually.
    if windows_root.has_node(_window_name):
        return windows_root.get_node(_window_name)
        
    # Fallback if name mismatches (shouldn't happen if using internal ID)
    return null

## Merge with subsequent command
func merge_with(other: RefCounted) -> bool:
    if other.get_script() != get_script():
        return false
        
    if other._window_name != _window_name:
        return false
        
    # Ensure we are modifying the same properties (e.g. dragging a slider)
    if _changed_keys != other._changed_keys:
        return false
        
    # Time-based merge limit
    if timestamp - other.timestamp > MERGE_WINDOW_MS:
        return false
        
    _after_data = other._after_data
    timestamp = other.timestamp
    return true

## Check if command is valid
func is_valid() -> bool:
    return _get_window() != null
