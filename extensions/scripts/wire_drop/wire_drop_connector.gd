# ==============================================================================
# Taj's Mod - Upload Labs
# Wire Drop Connector - Spawns nodes and auto-connects wires
# Author: TajemnikTV
# ==============================================================================
class_name TajsModWireDropConnector
extends RefCounted

const LOG_NAME = "TajsModded:WireDropConnector"

const NodeCompatibilityFilterScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/wire_drop/node_compatibility_filter.gd")

signal node_spawned(window: WindowContainer, connected: bool)
signal spawn_failed(reason: String)

var _filter # TajsModNodeCompatibilityFilter
var _debug_callback: Callable


func _init() -> void:
    _filter = NodeCompatibilityFilterScript.new()


## Set debug logging callback
func set_debug_callback(callback: Callable) -> void:
    _debug_callback = callback


## Log a debug message
func _log(message: String, force: bool = false) -> void:
    ModLoaderLog.info(message, LOG_NAME)
    if _debug_callback.is_valid():
        _debug_callback.call(message, force)


## Spawn a node and connect it to the origin pin
## Returns true if node was spawned and connected successfully
func spawn_and_connect(window_id: String, position: Vector2, origin_info: Dictionary) -> bool:
    # Validate window exists
    if not Data.windows.has(window_id):
        _log("Window not found: " + window_id, true)
        spawn_failed.emit("Window not found: " + window_id)
        return false
    
    # Check build limits
    if Globals.max_window_count >= Utils.MAX_WINDOW:
        Signals.notify.emit("exclamation", "build_limit_reached")
        Sound.play("error")
        spawn_failed.emit("Build limit reached")
        return false
    
    if not Utils.can_add_window(window_id):
        Signals.notify.emit("exclamation", "Cannot add more of this window type")
        Sound.play("error")
        spawn_failed.emit("Window limit reached for type: " + window_id)
        return false
    
    # Load and instantiate window
    var window_data: Dictionary = Data.windows[window_id]
    var scene_path: String = "res://scenes/windows/" + window_data.scene + ".tscn"
    
    if not ResourceLoader.exists(scene_path):
        _log("Scene not found: " + scene_path, true)
        spawn_failed.emit("Scene not found")
        return false
    
    var scene: PackedScene = load(scene_path)
    if not scene:
        _log("Failed to load scene: " + scene_path, true)
        spawn_failed.emit("Failed to load scene")
        return false
    
    var window: WindowContainer = scene.instantiate()
    if not window:
        _log("Failed to instantiate window", true)
        spawn_failed.emit("Failed to instantiate window")
        return false
    
    # Set window properties
    window.name = window_id
    
    # Position the window with offset so it doesn't spawn under cursor
    # Snap to grid like the game does
    var spawn_pos := Vector2(position.x + 50, position.y - 50).snappedf(50)
    window.global_position = spawn_pos
    
    # Emit signal to add window to scene
    Signals.create_window.emit(window)
    
    # Wait for window to initialize
    await _wait_for_initialization(window)
    
    if not is_instance_valid(window):
        _log("Window was destroyed during initialization", true)
        spawn_failed.emit("Window initialization failed")
        return false
    
    # Now find and create the connection
    var connected := await _auto_connect(window, origin_info)
    
    if connected:
        _log("Node spawned and connected: " + window_id)
        Sound.play("connect")
    else:
        _log("Node spawned but connection failed: " + window_id, true)
        # Node is still useful, just show a warning
        Signals.notify.emit("exclamation", "Node added (connection failed)")
    
    node_spawned.emit(window, connected)
    return true


## Wait for a window to initialize (has ResourceContainers registered)
func _wait_for_initialization(window: WindowContainer) -> void:
    # Wait a couple frames for the window to be added and initialized
    for i in range(3):
        await Engine.get_main_loop().process_frame
        if not is_instance_valid(window):
            return


## Find the best compatible pin on the new window and connect
func _auto_connect(window: WindowContainer, origin_info: Dictionary) -> bool:
    var origin_id: String = origin_info.get("resource_id", "")
    var origin_is_output: bool = origin_info.get("is_output", true)
    var origin_shape: String = origin_info.get("connection_shape", "")
    var origin_color: String = origin_info.get("connection_color", "")
    
    # Find ResourceContainers in the new window
    var resource_containers := _find_resource_containers(window)
    
    if resource_containers.is_empty():
        _log("No resource containers found in window", true)
        return false
    
    # Find compatible pin
    # If origin is OUTPUT, we need to find an INPUT on the new window
    # If origin is INPUT, we need to find an OUTPUT on the new window
    var target_container: ResourceContainer = null
    
    for rc in resource_containers:
        if not is_instance_valid(rc):
            continue
        
        var rc_shape := rc.get_connection_shape()
        var rc_color := rc.get_connector_color()
        
        # Check shape compatibility
        if rc_shape != origin_shape:
            continue
        
        # Check color compatibility (white is wildcard)
        if origin_color != "white" and rc_color != "white" and origin_color != rc_color:
            continue
        
        # Check if this container has the right connector type
        # InputConnector = accepts input (for when origin is output)
        # OutputConnector = provides output (for when origin is input)
        if origin_is_output:
            if rc.has_node("InputConnector"):
                target_container = rc
                break
        else:
            if rc.has_node("OutputConnector"):
                target_container = rc
                break
    
    if target_container == null:
        _log("No compatible pin found on new window", true)
        return false
    
    # Get the origin resource container
    var origin_rc: ResourceContainer = Globals.desktop.get_resource(origin_id)
    if not is_instance_valid(origin_rc):
        _log("Origin resource no longer valid", true)
        return false
    
    # Create the connection
    # Output -> Input order
    var output_id: String
    var input_id: String
    
    if origin_is_output:
        output_id = origin_id
        input_id = target_container.id
    else:
        output_id = target_container.id
        input_id = origin_id
    
    _log("Creating connection: %s -> %s" % [output_id, input_id])
    Signals.create_connection.emit(output_id, input_id)
    
    return true


## Find all ResourceContainers in a window
func _find_resource_containers(node: Node) -> Array[ResourceContainer]:
    var containers: Array[ResourceContainer] = []
    _collect_resource_containers(node, containers)
    return containers


## Recursively collect ResourceContainers
func _collect_resource_containers(node: Node, containers: Array[ResourceContainer]) -> void:
    if node is ResourceContainer:
        containers.append(node as ResourceContainer)
    
    for child in node.get_children():
        _collect_resource_containers(child, containers)


## Get the compatibility filter (for access by palette)
func get_filter():
    return _filter
