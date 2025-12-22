# ==============================================================================
# Taj's Mod - Upload Labs
# Context Provider - Provides current game/mod state for command visibility
# Author: TajemnikTV
# ==============================================================================
class_name TajsModContextProvider
extends RefCounted

const LOG_NAME = "TajsModded:Context"

# Current state - updated by mod_main
var selected_nodes: Array = []
var selected_node_count: int = 0
var is_in_menu: bool = false
var is_photo_mode: bool = false
var tools_enabled: bool = false
var mod_profile: String = "default"

# References
var _tree: SceneTree
var _config # TajsModConfigManager


func _init() -> void:
	pass


func set_tree(tree: SceneTree) -> void:
	_tree = tree


func set_config(config) -> void:
	_config = config
	_update_from_config()


func _update_from_config() -> void:
	if _config:
		tools_enabled = _config.get_value("palette_tools_enabled", false)


## Refresh context from current game state
func refresh() -> void:
	_update_from_config()
	
	if not _tree:
		return
	
	# Check menu state
	var main = _tree.root.get_node_or_null("Main")
	if main:
		var hud = main.get_node_or_null("HUD")
		if hud:
			# Check if any game menus are open
			is_in_menu = false # Can be expanded based on game's menu system
	
	# Get selected nodes from Globals if available
	if is_instance_valid(Globals):
		if "selected_windows" in Globals:
			selected_nodes = Globals.selected_windows if Globals.selected_windows else []
			selected_node_count = selected_nodes.size()
		else:
			selected_nodes = []
			selected_node_count = 0


## Check if there are selected nodes
func has_selection() -> bool:
	return selected_node_count > 0


## Check if tools/cheats are enabled in palette
func are_tools_enabled() -> bool:
	return tools_enabled


## Enable or disable tools in palette
func set_tools_enabled(enabled: bool) -> void:
	tools_enabled = enabled
	if _config:
		_config.set_value("palette_tools_enabled", enabled)
