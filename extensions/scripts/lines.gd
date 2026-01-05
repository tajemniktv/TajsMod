# ==============================================================================
# Taj's Mod - Upload Labs
# Lines Extension - Override grid rendering for expanded workspace
# Author: TajemnikTV
# ==============================================================================
extends "res://scripts/lines.gd"

const WorkspaceBounds = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workspace_bounds.gd")

var _last_grid_range: int = 100

## Override _ready to generate grid based on expanded bounds
func _ready() -> void:
	_generate_grid()
	
	# Set up callback for when bounds change (so we can regenerate grid)
	WorkspaceBounds.set_bounds_changed_callback(_on_bounds_changed)


## Generate grid lines based on current workspace bounds
func _generate_grid() -> void:
	# Clear existing grid
	RenderingServer.canvas_item_clear(rid)
	
	var grid_range = WorkspaceBounds.get_grid_range()
	var limit = WorkspaceBounds.get_limit()
	
	_last_grid_range = grid_range
	
	# Generate horizontal lines
	for y: int in range(-grid_range + 1, grid_range):
		var length: int = 2
		if (y - 1) % 10 == 0:
			length = 4
		RenderingServer.canvas_item_add_line(rid, Vector2(-limit, 50 * y), Vector2(limit, 50 * y), Color(1, 1, 1, 0.1), length)
	
	# Generate vertical lines
	for x: int in range(-grid_range + 1, grid_range):
		var length: int = 2
		if (x - 1) % 10 == 0:
			length = 4
		RenderingServer.canvas_item_add_line(rid, Vector2(50 * x, -limit), Vector2(50 * x, limit), Color(1, 1, 1, 0.1), length)


## Callback when workspace bounds change - regenerate grid
func _on_bounds_changed() -> void:
	var new_range = WorkspaceBounds.get_grid_range()
	if new_range != _last_grid_range:
		_generate_grid()
