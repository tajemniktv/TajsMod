# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Config - Persistence for palette-specific settings
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteConfig
extends RefCounted

const LOG_NAME = "TajsModded:PaletteConfig"
const CONFIG_PATH = "user://tajs_mod_palette.json"

const DEFAULT_CONFIG := {
	"hotkey": "middle_mouse",
	"favorites": [],
	"recents": [],
	"tools_enabled": false,
	"max_recents": 10
}

var _config: Dictionary = {}


func _init() -> void:
	_config = DEFAULT_CONFIG.duplicate(true)
	load_config()


func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		save_config()
		return
	
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		ModLoaderLog.error("Failed to open palette config", LOG_NAME)
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		if data is Dictionary:
			# Merge with defaults
			for key in DEFAULT_CONFIG:
				if data.has(key):
					_config[key] = data[key]
				else:
					_config[key] = DEFAULT_CONFIG[key]
	file.close()


func save_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_config, "\t"))
		file.close()


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
