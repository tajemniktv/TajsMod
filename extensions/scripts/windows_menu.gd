# =============================================================================
# Taj's Mod - Upload Labs
# Windows Menu - Handles window creation and selection logic
# Author: TajemnikTV
# =============================================================================
extends "res://scripts/windows_menu.gd"

func _on_add_pressed() -> void:
	var limit = Globals.custom_node_limit
	
	# Override manual check
	var limit_reached = false
	if limit != -1:
		if Globals.max_window_count >= limit:
			limit_reached = true
	else:
		limit_reached = false # Unlimited
		
	if limit_reached:
		Signals.notify.emit("exclamation", "build_limit_reached")
		Sound.play("error")
		return
	elif Utils.can_add_window(cur_window):
		var window: WindowContainer = load("res://scenes/windows/" + Data.windows[cur_window].scene + ".tscn").instantiate()
		window.name = cur_window
		window.global_position = Vector2(Globals.camera_center - window.size / 2).snappedf(50)
		Signals.create_window.emit(window)
		Signals.set_menu.emit(0, 0)


func _on_window_selected(w: String) -> void:
	if Globals.platform == 2 or Globals.platform == 3:
		if w == cur_window:
			set_window("")
		else:
			set_window(w)
	elif !w.is_empty():
		var limit = Globals.custom_node_limit
		
		# Override manual check
		var limit_reached = false
		if limit != -1:
			if Globals.max_window_count >= limit:
				limit_reached = true
		else:
			limit_reached = false # Unlimited
			
		if limit_reached:
			Signals.notify.emit("exclamation", "build_limit_reached")
			Sound.play("error")
			return
		elif Utils.can_add_window(w):
			add_window(w)

			if !Input.is_key_pressed(KEY_SHIFT):
				Signals.set_menu.emit(0, 0)
