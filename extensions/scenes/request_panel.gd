extends "res://scenes/request_panel.gd"

var _hide_completed: bool = true

func set_hide_completed(val: bool) -> void:
	_hide_completed = val
	update_all() # Re-evaluate visibility

func is_claimed() -> bool:
	return Globals.requests.get(name, 0) == 2

func update_all() -> void:
	super.update_all()
	
	# Apply Hide Completed filter
	# super sets 'visible = unlocked'
	if visible and _hide_completed and is_claimed():
		visible = false
