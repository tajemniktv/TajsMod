# ==============================================================================
# Taj's Mod - Upload Labs
# Extended Caps - GPU Cluster Extension
# Extends: res://scenes/windows/window_gpu_cluster.gd
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_gpu_cluster.gd"

const SYSTEM_NAME = "gpu_cluster"
const VANILLA_CAP = 48

func _get_caps_manager():
	var mgr = Globals.get("extended_caps_manager")
	return mgr

func _ready() -> void:
	super ()
	print("[ExtCaps:GPU] _ready called - extension IS loaded!")

func update_all() -> void:
	var caps_mgr = _get_caps_manager()
	var is_ext_enabled = caps_mgr.is_enabled(SYSTEM_NAME) if caps_mgr else false
	
	# If extended caps disabled and level exceeds vanilla cap, reset to vanilla cap
	if not is_ext_enabled and level > VANILLA_CAP:
		print("[ExtCaps:GPU] Feature disabled, resetting level %d -> %d" % [level, VANILLA_CAP])
		level = VANILLA_CAP
	
	# Call vanilla update_all
	super ()
	
	# Override cap check if extended caps enabled
	if is_ext_enabled:
		var effective_cap = caps_mgr.get_cap(SYSTEM_NAME)
		upgrade_maxed = level >= effective_cap
		print("[ExtCaps:GPU] Extended caps active! effective_cap=%d, upgrade_maxed=%s" % [effective_cap, upgrade_maxed])
		
		# Re-apply visibility since super() set it based on vanilla cap
		$"ActionContainer/UpgradeButton".visible = !upgrade_maxed
		$"ActionContainer/ColorRect".visible = count < 9 and !upgrade_maxed
		
		# Re-apply theme variations
		if count < 9 and !upgrade_maxed:
			$"ActionContainer/AddButton".theme_type_variation = "WindowButtonBottom1"
			$"ActionContainer/UpgradeButton".theme_type_variation = "WindowButtonBottom3"
			$PanelContainer.theme_type_variation = "WindowPanelContainerFlatBottom"
		elif count >= 9 and !upgrade_maxed:
			$"ActionContainer/UpgradeButton".theme_type_variation = "WindowButtonBottom2"
			$PanelContainer.theme_type_variation = "WindowPanelContainerFlatBottom"
		elif count < 9 and upgrade_maxed:
			$"ActionContainer/AddButton".theme_type_variation = "WindowButtonBottom2"
			$PanelContainer.theme_type_variation = "WindowPanelContainerFlatBottom"
		else:
			$PanelContainer.theme_type_variation = "WindowPanelContainer"

func get_upgrade_cost(level: int) -> float:
	var base_cost = super (level)
	
	var caps_mgr = _get_caps_manager()
	if caps_mgr and caps_mgr.is_enabled(SYSTEM_NAME):
		return caps_mgr.get_cost(SYSTEM_NAME, base_cost, level)
	
	return base_cost
