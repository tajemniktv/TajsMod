# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Config - Persistence for palette-specific settings
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteConfig
extends RefCounted

const LOG_NAME = "TajsModded:PaletteConfig"

const DEFAULT_CONFIG := {
	"hotkey": "middle_mouse",
	"favorites": [],
	"recents": [],
	"tools_enabled": false,
	"max_recents": 10
}

var _config: Dictionary = {}
var _mod_config # TajsModConfigManager reference


func _init() -> void:
	_config = DEFAULT_CONFIG.duplicate(true)

func setup(mod_config_ref) -> void:
	_mod_config = mod_config_ref
	load_config()


func load_config() -> void:
	if not _mod_config: return
	
	var palette_data = _mod_config.get_value("palette", {})
	
	# Migration check: if no palette data in main config, try load from old file
	if palette_data.is_empty() and FileAccess.file_exists("user://tajs_mod_palette.json"):
		var file = FileAccess.open("user://tajs_mod_palette.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary:
					palette_data = data
					ModLoaderLog.info("Migrated old palette config to main config", LOG_NAME)
			file.close()
			
			# Ensure we save the migrated data to main config immediately
			if not palette_data.is_empty():
				_mod_config.set_value("palette", palette_data)
				# Optional: Rename old file to .bak to avoid re-migration/confusion
				# DirAccess.rename_absolute("user://tajs_mod_palette.json", "user://tajs_mod_palette.json.bak")
	
	if palette_data is Dictionary and not palette_data.is_empty():
		# Merge with defaults
		for key in DEFAULT_CONFIG:
			if palette_data.has(key):
				_config[key] = palette_data[key]
			else:
				_config[key] = DEFAULT_CONFIG[key]
	else:
		# Save defaults if empty
		save_config()


func save_config() -> void:
	if _mod_config:
		_mod_config.set_value("palette", _config)


## Get a config value
func get_value(key: String, default = null):
	if _config.has(key):
		return _config[key]
	if default != null:
		return default
	return DEFAULT_CONFIG.get(key)


## Set a config value
func set_value(key: String, value) -> void:
	_config[key] = value
	save_config()


# ============== Favorites ==============

func get_favorites() -> Array:
	return _config.get("favorites", []).duplicate()


func is_favorite(command_id: String) -> bool:
	return command_id in _config.get("favorites", [])


func add_favorite(command_id: String) -> void:
	var favorites = _config.get("favorites", [])
	if command_id not in favorites:
		favorites.append(command_id)
		_config["favorites"] = favorites
		save_config()


func remove_favorite(command_id: String) -> void:
	var favorites = _config.get("favorites", [])
	favorites.erase(command_id)
	_config["favorites"] = favorites
	save_config()


func toggle_favorite(command_id: String) -> bool:
	if is_favorite(command_id):
		remove_favorite(command_id)
		return false
	else:
		add_favorite(command_id)
		return true


# ============== Recents ==============

func get_recents() -> Array:
	return _config.get("recents", []).duplicate()


func add_recent(command_id: String) -> void:
	var recents = _config.get("recents", [])
	
	# Remove if already exists (to move to front)
	recents.erase(command_id)
	
	# Add to front
	recents.push_front(command_id)
	
	# Trim to max size
	var max_recents = _config.get("max_recents", 10)
	if recents.size() > max_recents:
		recents.resize(max_recents)
	
	_config["recents"] = recents
	save_config()


func clear_recents() -> void:
	_config["recents"] = []
	save_config()


# ============== Tools ==============

func are_tools_enabled() -> bool:
	return _config.get("tools_enabled", false)


func set_tools_enabled(enabled: bool) -> void:
	_config["tools_enabled"] = enabled
	save_config()
