# ==============================================================================
# Taj's Mod - Upload Labs
# Wire Clear Handler - Right-click on connectors to clear wires
# Author: TajemnikTV
# ==============================================================================
class_name TajsModWireClearHandler
extends Node

const LOG_NAME = "TajsModded:WireClearHandler"

var _enabled: bool = true
var _config # TajsModConfigManager reference


func _init() -> void:
	pass


func setup(config) -> void:
	_config = config
	_enabled = config.get_value("right_click_clear_enabled", true)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _config:
		_config.set_value("right_click_clear_enabled", enabled)


func is_enabled() -> bool:
	return _enabled


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	
	# Right-click on connector to clear wires
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var connector := _get_hovered_connector()
		if connector:
			_clear_connector_wires(connector)
			get_viewport().set_input_as_handled()


## Find a ConnectorButton under the mouse position
func _get_hovered_connector() -> ConnectorButton:
	if not is_instance_valid(Globals.desktop):
		return null
	
	# Windows are in the $Windows child of desktop
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if not windows_container:
		return null
	
	# Use world coordinates to match connector global rects
	var mouse_pos := Globals.desktop.get_global_mouse_position()
	
	for window in windows_container.get_children():
		if not window is WindowContainer:
			continue
		if not is_instance_valid(window):
			continue
		var connector := _find_connector_at_position(window, mouse_pos)
		if connector:
			return connector
	
	return null


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


## Clear all wires from a connector
func _clear_connector_wires(connector: ConnectorButton) -> void:
	var container: ResourceContainer = connector.container
	if not is_instance_valid(container):
		return
	
	var had_connections := false
	
	if connector.type == Utils.connections_types.OUTPUT:
		# Clear all output connections
		if container.outputs_id.size() > 0:
			had_connections = true
			var outputs: Array[String] = container.outputs_id.duplicate()
			for output_id: String in outputs:
				Signals.delete_connection.emit(container.id, output_id)
	
	elif connector.type == Utils.connections_types.INPUT:
		# Clear the input connection
		if not container.input_id.is_empty():
			had_connections = true
			Signals.delete_connection.emit(container.input_id, container.id)
	
	if had_connections:
		Sound.play("close")
