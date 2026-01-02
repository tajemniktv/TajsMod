# ==============================================================================
# Taj's Mod - Upload Labs
# Wire Drop Handler - Detects when a wire is dropped on empty canvas
# Author: TajemnikTV
# ==============================================================================
class_name TajsModWireDropHandler
extends RefCounted

const LOG_NAME = "TajsModded:WireDropHandler"

signal wire_dropped_on_canvas(origin_info: Dictionary, drop_position: Vector2)

var _enabled: bool = true
var _config # TajsModConfigManager reference
var _connected: bool = false

# Track connection state - these persist across calls
var _last_connection_output: String = ""
var _last_connection_input: String = ""

func _init() -> void:
	pass


## Log debug message only if debug logging is enabled in config
func _debug_log(message: String) -> void:
	if _config and _config.get_value("debug_mode", false):
		ModLoaderLog.info(message, LOG_NAME)


func setup(config) -> void:
	_config = config
	_enabled = config.get_value("wire_drop_menu_enabled", true)
	_connect_signals()


func _connect_signals() -> void:
	if _connected:
		return
	
	# Connect to connection_droppped signal (note: game uses double 'p' spelling)
	if not Signals.connection_droppped.is_connected(_on_connection_dropped):
		Signals.connection_droppped.connect(_on_connection_dropped)
	
	# Listen for create_connection to know when a connection is being created
	if not Signals.create_connection.is_connected(_on_create_connection):
		Signals.create_connection.connect(_on_create_connection)
	
	_connected = true
	ModLoaderLog.info("Wire drop handler connected to signals", LOG_NAME)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _config:
		_config.set_value("wire_drop_menu_enabled", enabled)


func is_enabled() -> bool:
	return _enabled


func _on_create_connection(output_id: String, input_id: String) -> void:
	# Track the most recent connection being created
	# This fires BEFORE connection_dropped!
	_last_connection_output = output_id
	_last_connection_input = input_id


func _on_connection_dropped(connection_id: String, connection_type: int) -> void:
	_debug_log("connection_dropped signal received: id=%s, type=%d" % [connection_id, connection_type])
	
	if not _enabled:
		_debug_log("WireDrop disabled, skipping")
		return
	
	# Check if feature is enabled in config
	if _config and not _config.get_value("wire_drop_menu_enabled", true):
		_debug_log("WireDrop disabled in config, skipping")
		return
	
	# Get the origin resource container
	var origin_resource: ResourceContainer = Globals.desktop.get_resource(connection_id)
	if not is_instance_valid(origin_resource):
		ModLoaderLog.warning("Origin resource no longer valid, canceling wire drop", LOG_NAME)
		return
	
	# Capture shape and color IMMEDIATELY - they may change after waiting
	var origin_shape: String = origin_resource.get_connection_shape()
	var origin_color: String = origin_resource.get_connector_color()
	var is_output: bool = connection_type == Utils.connections_types.OUTPUT
	
	_debug_log("Origin: shape=%s, color=%s, is_output=%s" % [origin_shape, origin_color, is_output])
	
	# DON'T clear tracking vars here - create_connection already fired BEFORE this!
	# Just check immediately if a connection was made for this origin
	_check_and_emit_async(connection_id, connection_type, origin_shape, origin_color, is_output)


func _check_and_emit_async(connection_id: String, connection_type: int, origin_shape: String, origin_color: String, is_output: bool) -> void:
	# Check IMMEDIATELY if a connection was created that involves our origin
	# (create_connection fires BEFORE connection_dropped, so data is already set)
	var connection_involves_origin: bool = (_last_connection_output == connection_id or _last_connection_input == connection_id)
	var connection_was_created: bool = not _last_connection_output.is_empty()
	
	_debug_log("Check: was_created=%s, involves_origin=%s (last_out=%s, last_in=%s)" % [
		connection_was_created, connection_involves_origin, _last_connection_output, _last_connection_input])
	
	# Clear the tracking vars NOW (after checking)
	_last_connection_output = ""
	_last_connection_input = ""
	
	if connection_was_created and connection_involves_origin:
		# Connection was made involving origin, don't show picker
		_debug_log("Bailing: connection was created involving this origin")
		return
	
	# Wait a frame to handle any edge cases with signal timing
	await Engine.get_main_loop().process_frame
	
	# Fallback check: If mouse is currently over a connector, don't show picker
	# This handles cases where signal timing is off when connecting quickly
	if _is_mouse_over_connector():
		_debug_log("Bailing: mouse is over a connector")
		return
	
	# If mouse is over any window, don't show picker
	# (SmartConnections or base game will handle the connection)
	if _is_mouse_over_any_window():
		_debug_log("Bailing: mouse is over a window")
		return
	
	# We dropped on empty canvas - emit signal to show node picker
	var drop_position := _get_mouse_world_position()
	
	var origin_info := {
		"resource_id": connection_id,
		"connection_type": connection_type, # 1 = OUTPUT, 2 = INPUT
		"connection_shape": origin_shape,
		"connection_color": origin_color,
		"is_output": is_output
	}
	
	_debug_log("Wire dropped on canvas, showing node picker")
	wire_dropped_on_canvas.emit(origin_info, drop_position)


func _get_mouse_world_position() -> Vector2:
	# Get mouse position in world coordinates
	if is_instance_valid(Globals.desktop):
		return Globals.desktop.get_global_mouse_position()
	return Vector2.ZERO


## Fallback check if mouse is over any connector
func _is_mouse_over_connector() -> bool:
	if not is_instance_valid(Globals.desktop):
		return false
	
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if not windows_container:
		return false
	
	var mouse_pos := Globals.desktop.get_global_mouse_position()
	
	for window in windows_container.get_children():
		if not window is WindowContainer:
			continue
		if not is_instance_valid(window):
			continue
		if _find_connector_at_position(window, mouse_pos):
			return true
	
	return false


## Check if mouse is over any WindowContainer (excluding Node Groups)
func _is_mouse_over_any_window() -> bool:
	if not is_instance_valid(Globals.desktop):
		return false
	
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if not windows_container:
		return false
	
	var mouse_pos := Globals.desktop.get_global_mouse_position()
	
	for window in windows_container.get_children():
		if not window is WindowContainer:
			continue
		if not is_instance_valid(window):
			continue
		
		# Skip Node Groups - they shouldn't block wire drops
		# Groups are named "group1", "group2", etc. and have window_id "group"
		# We also check for NodeGroup class if available
		if _is_node_group(window):
			continue
		
		var rect: Rect2 = window.get_global_rect()
		if rect.has_point(mouse_pos):
			return true
	
	return false


## Check if a window is a Node Group (which shouldn't block wire drops)
func _is_node_group(window: WindowContainer) -> bool:
	# Check by window_id first (most reliable)
	if "window_id" in window and window.window_id == "group":
		return true
	
	# Check by class name
	if window.get_class() == "NodeGroup":
		return true
	
	# Fallback: check if the scene/script indicates it's a group
	var script = window.get_script()
	if script:
		var script_path: String = script.resource_path if script.resource_path else ""
		if "group" in script_path.to_lower():
			return true
	
	# Fallback: check by name pattern (group1, group2, etc.)
	var window_name: String = window.name
	if window_name.begins_with("group") and window_name.substr(5).is_valid_int():
		return true
	
	return false


func _find_connector_at_position(node: Node, mouse_pos: Vector2) -> ConnectorButton:
	if node is ConnectorButton:
		var rect: Rect2 = node.get_global_rect()
		if rect.has_point(mouse_pos):
			return node
	
	for child in node.get_children():
		var result := _find_connector_at_position(child, mouse_pos)
		if result:
			return result
	
	return null
