# ==============================================================================
# Taj's Mod - Upload Labs
# Paint Extension - Override background rendering for expanded workspace
# Author: TajemnikTV
# ==============================================================================
@tool
extends "res://scripts/paint.gd"

const WorkspaceBounds = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workspace_bounds.gd")

## Override _draw to use expanded bounds
func _draw() -> void:
	var limit = WorkspaceBounds.get_limit()
	var size = limit * 2
	draw_rect(Rect2(Vector2(-limit, -limit), Vector2(size, size)), Color.WHITE)
