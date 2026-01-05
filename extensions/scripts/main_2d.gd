# ==============================================================================
# Taj's Mod - Upload Labs
# Main2D Extension - Override screen_size for expanded workspace
# Author: TajemnikTV
# ==============================================================================
extends "res://scripts/main_2d.gd"

const WorkspaceBounds = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workspace_bounds.gd")

## Override set_screen to use expanded camera limit for desktop
func set_screen(screen: int) -> void:
	Globals.cur_screen = screen
	Signals.screen_set.emit(screen)
	
	$Desktop.visible = Globals.cur_screen == 0
	$Research.visible = Globals.cur_screen == 1
	$Ascension.visible = Globals.cur_screen == 2
	$Camera2D.position = screen_position[screen]
	
	# Use expanded limit for desktop screen when enabled
	if screen == 0 and WorkspaceBounds.is_enabled():
		$Camera2D.limit = WorkspaceBounds.get_limit()
	else:
		$Camera2D.limit = screen_size[screen]
	
	$Camera2D.min_zoom = screen_min_zoom[screen]
	$Camera2D.reset_smoothing()
