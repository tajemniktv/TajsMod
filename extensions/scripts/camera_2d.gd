# ==============================================================================
# Taj's Mod - Upload Labs
# Camera Extension - Override camera clamp to use expanded workspace bounds
# Author: TajemnikTV
# ==============================================================================
extends "res://scripts/camera_2d.gd"

const WorkspaceBounds = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workspace_bounds.gd")

## Override clamp_pos to use expanded bounds when on desktop screen (screen 0)
func clamp_pos(to: Vector2) -> Vector2:
	# Only expand bounds for desktop screen (screen 0)
	# Screen 1 (Research) and Screen 2 (Ascension) keep their original limits
	if Globals.cur_screen == 0 and WorkspaceBounds.is_enabled():
		var expanded_limit = WorkspaceBounds.get_limit()
		return Vector2(clampf(to.x, -expanded_limit, expanded_limit), clampf(to.y, -expanded_limit, expanded_limit))
	
	# Default behavior: use the exported limit variable
	return Vector2(clampf(to.x, -limit, limit), clampf(to.y, -limit, limit))
