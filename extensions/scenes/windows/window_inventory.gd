# ==============================================================================
# Taj's Mod - Upload Labs
# Window Inventory Extension - Adds 6th input slot (Issue #18)
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_inventory.gd"

var _sixth_input: ResourceContainer = null


func _enter_tree() -> void:
	# Add 6th input BEFORE super._enter_tree() so it gets included in containers array
	_add_sixth_input_early()
	super ()


func _add_sixth_input_early() -> void:
	var input_container = get_node_or_null("PanelContainer/MainContainer/Input")
	if not input_container:
		return
	
	# Check if 6th input already exists
	if input_container.get_child_count() >= 6:
		return
	
	# Load the input_container scene
	var input_scene = load("res://scenes/input_container.tscn")
	if not input_scene:
		return
	
	# Get reference to first input to copy its properties
	var first_input: ResourceContainer = input_container.get_child(0) if input_container.get_child_count() > 0 else null
	
	# Create 6th input
	_sixth_input = input_scene.instantiate()
	_sixth_input.name = "5"
	
	# Copy exact same properties from first input instead of hardcoding
	if first_input:
		_sixth_input.placeholder_name = first_input.placeholder_name
		_sixth_input.override_connector = first_input.override_connector
		_sixth_input.override_color = first_input.override_color
		_sixth_input.default_resource = first_input.default_resource
		_sixth_input.default_variation = first_input.default_variation
	else:
		# Fallback
		_sixth_input.placeholder_name = "input_currency"
		_sixth_input.override_connector = "triangle"
		_sixth_input.override_color = "white"
	
	# Set exporting to output (same as other inputs)
	var output_node = get_node_or_null("PanelContainer/MainContainer/Output")
	if output_node:
		_sixth_input.exporting = [output_node]
	
	# Ensure it's in persistent_container group for saving
	if not _sixth_input.is_in_group("persistent_container"):
		_sixth_input.add_to_group("persistent_container")
	
	input_container.add_child(_sixth_input)


func _ready() -> void:
	super ()
	
	# Ensure the 6th input is properly registered
	if _sixth_input:
		# Add to containers array if missing (for save/load)
		if "containers" in self and not containers.has(_sixth_input):
			containers.append(_sixth_input)
		
		# Connect signals
		_sixth_input.connection_in_set.connect(_on_connection_set)
		_sixth_input.resource_set.connect(_on_5_resource_set)
		
		# Enable ticking
		if has_method("should_tick"):
			_sixth_input.set_ticking(should_tick())
		else:
			_sixth_input.set_ticking(true)
		
		# Sync resource/variation with existing inputs
		var first_input = get_node_or_null("PanelContainer/MainContainer/Input/0")
		if first_input and not first_input.resource.is_empty():
			_sixth_input.call_deferred("set_resource", first_input.resource, first_input.variation)
	
	# Update visibility
	update_visible_inputs()


func _on_5_resource_set() -> void:
	var input_5 = get_node_or_null("PanelContainer/MainContainer/Input/5")
	if input_5:
		set_resources(input_5.resource, input_5.variation)
