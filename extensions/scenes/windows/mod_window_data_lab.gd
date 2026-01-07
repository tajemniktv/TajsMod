# ==============================================================================
# Taj's Mod - Upload Labs
# Extended Caps - Data Lab Extension
# Extends: res://scenes/windows/window_data_lab.gd
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_data_lab.gd"

const SYSTEM_NAME = "data_lab"
const VANILLA_CAP = 200

func _get_caps_manager():
	if Globals.get("extended_caps_manager"):
		return Globals.extended_caps_manager
	return null

func update_all() -> void:
	var caps_mgr = _get_caps_manager()
	var is_ext_enabled = caps_mgr.is_enabled(SYSTEM_NAME) if caps_mgr else false
	
	# If extended caps disabled and level exceeds vanilla cap, reset to vanilla cap
	if not is_ext_enabled and level > VANILLA_CAP:
		level = VANILLA_CAP
	
	# Call vanilla update_all first
	super ()
	
	# Override cap check if extended caps enabled
	if is_ext_enabled:
		var effective_cap = caps_mgr.get_cap(SYSTEM_NAME)
		maxed = level >= effective_cap
		
		# Re-apply visibility since super() set it based on vanilla cap
		$UpgradeButton.visible = !maxed
		
		if maxed:
			$PanelContainer.theme_type_variation = "WindowPanelContainer"
		else:
			$PanelContainer.theme_type_variation = "WindowPanelContainerFlatBottom"

func get_cost(level: int) -> float:
	var base_cost = super (level)
	
	var caps_mgr = _get_caps_manager()
	if caps_mgr and caps_mgr.is_enabled(SYSTEM_NAME):
		return caps_mgr.get_cost(SYSTEM_NAME, base_cost, level)
	
	return base_cost
