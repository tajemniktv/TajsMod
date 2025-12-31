# ==============================================================================
# Taj's Mod - Upload Labs
# DisconnectCommand - Undoable command for connection deletion
# Author: TajemnikTV
# ==============================================================================
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_command.gd"

## The output window name
var _output_window_name: String = ""
var _output_path: String = ""

## The input window name
var _input_window_name: String = ""
var _input_path: String = ""


## Setup the command with connection endpoints (Window Names + Relative Paths)
func setup(output_window: String, output_path: String, input_window: String, input_path: String) -> void:
    _output_window_name = output_window
    _output_path = output_path
    _input_window_name = input_window
    _input_path = input_path
    description = "Disconnect Wire"


## Execute (delete connection)
func execute() -> bool:
    var output_id = _get_resource_id(_output_window_name, _output_path)
    var input_id = _get_resource_id(_input_window_name, _input_path)
    
    if output_id.is_empty() or input_id.is_empty():
        return false
        
    Signals.delete_connection.emit(output_id, input_id)
    return true


## Undo (recreate connection)
func undo() -> bool:
    var output_id = _get_resource_id(_output_window_name, _output_path)
    var input_id = _get_resource_id(_input_window_name, _input_path)
    
    if output_id.is_empty() or input_id.is_empty():
        return false
        
    Signals.create_connection.emit(output_id, input_id)
    return true


## Check if command is still valid
## Note: Always return true - validation happens at runtime
func is_valid() -> bool:
    return true


## Helper to get resource ID from window name and relative path
func _get_resource_id(window_name: String, relative_path: String) -> String:
    if not Globals.desktop:
        return ""
        
    var window = Globals.desktop.get_node_or_null("Windows/" + window_name)
    if not window:
        return ""
        
    # Find exact ResourceContainer by path
    var resource_node = window.get_node_or_null(relative_path)
    if resource_node and resource_node is ResourceContainer:
        return resource_node.id
    
    # Fallback: if path is empty/invalid, try finding ANY resource
    if relative_path.is_empty():
        return _find_resource_id_recursive(window)
        
    return ""


## Recursive search for ResourceContainer (fallback)
func _find_resource_id_recursive(node: Node) -> String:
    if node is ResourceContainer:
        return node.id
        
    for child in node.get_children():
        var id = _find_resource_id_recursive(child)
        if not id.is_empty():
            return id
            
    return ""
