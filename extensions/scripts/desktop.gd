# =============================================================================
# Taj's Mod - Upload Labs
# Desktop Script - Handles window creation and pasting logic
# Author: TajemnikTV
# =============================================================================
extends "res://scripts/desktop.gd"

func paste(data: Dictionary) -> void:
    var seed: int = randi() / 10
    var new_windows: Dictionary
    var to_connect: Dictionary[String, Array]
    var required: int
    for window: String in data.windows:
        required += 1

        for resource: String in data.windows[window].container_data:
            var new_name: String = Utils.generate_id_from_seed(data.windows[window].container_data[resource].id.hash() + seed)
            data.windows[window].container_data[resource].id = new_name
            data.windows[window].container_data[resource].erase("count")
            to_connect[new_name] = []
            for output: String in data.windows[window].container_data[resource].outputs_id:
                to_connect[new_name].append(Utils.generate_id_from_seed(output.hash() + seed))
            data.windows[window].container_data[resource].outputs_id.clear()

        var new_name: String = find_window_name(window)
        new_windows[new_name] = data.windows[window].duplicate()
        new_windows[new_name].position -= data.rect.position - Globals.camera_center.snappedf(50) + (data.rect.size / 2)

    # MOD MATCH: Use Globals.custom_node_limit instead of Utils.MAX_WINDOW
    # Check limit only if NOT unlimited (-1)
    if Globals.custom_node_limit != -1:
        if required > Globals.custom_node_limit - Globals.max_window_count:
            Signals.notify.emit("exclamation", "build_limit_reached")
            Sound.play("error")
            return

    data.windows = new_windows
    var windows_added: Array[WindowContainer]
    windows_added = add_windows_from_data(data.windows, true)
    Globals.set_selection(windows_added, [], 1)

    for i: String in data.connectors:
        var new_id: String = Utils.generate_id_from_seed(i.hash() + seed)
        data.connectors[i].pivot_pos -= data.rect.position - Globals.camera_center.snappedf(50) + (data.rect.size / 2)
        $Connectors.connector_data[new_id] = data.connectors[i]

    var connection_remaining: Dictionary[String, Array] = to_connect.duplicate(true)
    for i: String in to_connect:
        var container: ResourceContainer = get_resource(i)
        if !container: continue
        if container.resource.is_empty(): continue
        for output: String in to_connect[i]:
            Signals.create_connection.emit(i, output)
        connection_remaining.erase(i)

    for i: String in connection_remaining:
        for output: String in connection_remaining[i]:
            Signals.create_connection.emit(i, output)

    $Connectors.connector_data.clear()


func _input(event: InputEvent) -> void:
    # Call parent to preserve CTRL+C/CTRL+V functionality
    super._input(event)
    
    # Ctrl+A to select all nodes (only if enabled and no text field is focused)
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_A and event.ctrl_pressed:
            # Skip if a text input field has focus (e.g., palette search)
            var focused = get_viewport().gui_get_focus_owner()
            if focused is LineEdit or focused is TextEdit:
                return # Let the text field handle Ctrl+A
            
            if Globals.select_all_enabled:
                _select_all_nodes()
                get_viewport().set_input_as_handled()


func _select_all_nodes() -> void:
    var windows_container = get_node_or_null("Windows")
    if windows_container:
        var typed_windows: Array[WindowContainer] = []
        for child in windows_container.get_children():
            if child is WindowContainer:
                typed_windows.append(child)
        var typed_connectors: Array[Control] = []
        Globals.set_selection(typed_windows, typed_connectors, 1)
        Signals.notify.emit("check", "Selected %d nodes" % typed_windows.size())
