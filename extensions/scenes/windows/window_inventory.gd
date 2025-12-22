# ==============================================================================
# Taj's Mod - Upload Labs
# Window Inventory Extension - Adds 6th input slot (Issue #18)
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_inventory.gd"


func _ready() -> void:
	# Call base init first
	super ()
	
	# Add 6th input after a frame to ensure base is fully initialized
	call_deferred("_add_sixth_input")


func _add_sixth_input() -> void:
	var input_container = $PanelContainer/MainContainer/Input
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
	var new_input: ResourceContainer = input_scene.instantiate()
	new_input.name = "5"
	
	# Copy exact same properties from first input instead of hardcoding
	if first_input:
		new_input.placeholder_name = first_input.placeholder_name
		new_input.override_connector = first_input.override_connector
		new_input.override_color = first_input.override_color
		new_input.default_resource = first_input.default_resource
		new_input.default_variation = first_input.default_variation
	else:
		# Fallback
		new_input.placeholder_name = "input_currency"
		new_input.override_connector = "triangle"
		new_input.override_color = "white"
	
	# Set exporting to output (same as other inputs)
	var output_node = $PanelContainer/MainContainer/Output
	if output_node:
		new_input.exporting = [output_node]
	
	input_container.add_child(new_input)
	
	# Connect signals (like the original)
	new_input.connection_in_set.connect(_on_connection_set)
	new_input.resource_set.connect(_on_5_resource_set)
	
	# Sync resource/variation with existing inputs AFTER adding to tree
	if first_input and not first_input.resource.is_empty():
		new_input.call_deferred("set_resource", first_input.resource, first_input.variation)
	
	# Update visibility
	update_visible_inputs()


func _on_5_resource_set() -> void:
	var input_5 = get_node_or_null("PanelContainer/MainContainer/Input/5")
	if input_5:
		set_resources(input_5.resource, input_5.variation)
