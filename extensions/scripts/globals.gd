# =============================================================================
# Taj's Mod - Upload Labs
# Globals - Shared constants and variables
# Author: TajemnikTV
# =============================================================================
extends "res://scripts/globals.gd"

var custom_node_limit: int = 400
var select_all_enabled: bool = true
var custom_upgrade_multiplier: int = 10
var undo_manager = null
var keybinds_manager = null # TajsModKeybindsManager reference
var breach_threat_manager = null # BreachThreatManager reference
var extended_caps_manager = null # ExtendedCapsManager reference

# Note: Node window levels (processor, gpu_cluster, network, data_lab) are stored
# directly on the window instances (in their save() dictionary), not in Globals.upgrades.
# So init_upgrades() doesn't clamp them. The windows themselves will be loaded with
# whatever level was saved, and our extensions handle the cap check in update_all().
# This means Extended Caps for nodes work without patching init_upgrades()!
