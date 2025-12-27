# ==============================================================================
# Taj's Mod - Upload Labs
# Config Manager - Handles persistent configuration
# Author: TajemnikTV
# ==============================================================================
class_name TajsModConfigManager
extends RefCounted

const LOG_NAME = "TajsModded:Config"
const CONFIG_PATH = "user://tajs_mod_config.json"

const DEFAULT_CONFIG := {
	# General tab
	"node_limit": 400,
	"screenshot_quality": 2,
	"screenshot_watermark": true, # Taj's Mod watermark on screenshots
	# Input/Keyboard Features
	"select_all_enabled": true, # Ctrl+A select all nodes
	"command_palette_enabled": true, # Middle mouse button palette
	# Wire Drop Menu
	"wire_drop_menu_enabled": true,
	# Right-click wire clear
	"right_click_clear_enabled": true,
	# UI Features
	"goto_group_enabled": true, # Go To Group panel button
	"buy_max_enabled": true, # Buy Max button in upgrades
	"z_order_fix_enabled": true, # Node group z-order fix
	# Focus mute (Issue #11)
	"mute_on_focus_loss": true,
	"background_volume": 0.0, # 0-100%, 0 = mute
	# Drag dead zone (Issue #13)
	"drag_dead_zone": 5, # pixels
	# 6-input containers (Issue #18)
	"six_input_containers": true,
	# Visuals tab
	"extra_glow": false,
	"glow_intensity": 2.0,
	"glow_strength": 1.3,
	"glow_bloom": 0.2,
	"glow_sensitivity": 0.8,
	"ui_opacity": 100.0,
	# Palette tab
	"palette_tools_enabled": false,
	# Debug tab
	"custom_boot_screen": true,
}

var _config: Dictionary = {}

func _init() -> void:
	_config = DEFAULT_CONFIG.duplicate()
	load_config()

func load_config() -> void:
	if !FileAccess.file_exists(CONFIG_PATH):
		ModLoaderLog.info("No config file found, using defaults.", LOG_NAME)
		save_config() # Create default file
		return
		
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if !file:
		ModLoaderLog.error("Failed to open config file for reading.", LOG_NAME)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result == OK:
		var loaded_data = json.get_data()
		if loaded_data is Dictionary:
			# Start with defaults
			for key in DEFAULT_CONFIG:
				if loaded_data.has(key):
					_config[key] = loaded_data[key]
				else:
					_config[key] = DEFAULT_CONFIG[key]
			
			# Also load any extra keys not in defaults (like wire_colors_hex)
			for key in loaded_data:
				if !DEFAULT_CONFIG.has(key):
					_config[key] = loaded_data[key]
			
			ModLoaderLog.info("Config loaded successfully.", LOG_NAME)
		else:
			ModLoaderLog.error("Config file malformed (not a dictionary).", LOG_NAME)
	else:
		ModLoaderLog.error("JSON Parse Error: " + json.get_error_message(), LOG_NAME)

func save_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(_config, "\t")
		file.store_string(json_string)
		file.close()
		ModLoaderLog.info("Config saved.", LOG_NAME)
	else:
		ModLoaderLog.error("Failed to open config file for writing.", LOG_NAME)

func get_value(key: String, default_override = null):
	if _config.has(key):
		return _config[key]
	elif default_override != null:
		return default_override
	elif DEFAULT_CONFIG.has(key):
		return DEFAULT_CONFIG[key]
	return null

func set_value(key: String, value) -> void:
	_config[key] = value
	save_config()

func get_all() -> Dictionary:
	return _config.duplicate()

func reset_to_defaults() -> void:
	# Delete config file
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(CONFIG_PATH)
	# Reset to defaults
	_config = DEFAULT_CONFIG.duplicate()
	save_config()
	ModLoaderLog.info("Config reset to defaults.", LOG_NAME)
