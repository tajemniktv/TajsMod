# ==============================================================================
# Taj's Mod - Upload Labs
# Command Registry - Central storage for all palette commands
# Author: TajemnikTV
# ==============================================================================
class_name TajsModCommandRegistry
extends RefCounted

const LOG_NAME = "TajsModded:CommandRegistry"

# Command structure:
# {
#     "id": String,
#     "title": String,
#     "category_path": Array[String],  # e.g. ["Taj's Mod", "Visuals"]
#     "keywords": Array[String],
#     "hint": String,
#     "badge": String,  # "SAFE" | "OPT-IN" | "GAMEPLAY"
#     "icon_path": String,  # optional
#     "is_category": bool,
#     "can_run": Callable,  # func(context) -> bool
#     "run": Callable,  # func(context) -> void
#     "keep_open": bool  # optional, if true palette stays open after execution
# }

var _commands: Dictionary = {} # id -> command dict
var _categories: Dictionary = {} # category path string -> Array of command ids
var _root_items: Array[String] = [] # Top-level category/command ids

signal commands_changed


func _init() -> void:
	# Initialize root categories
	_categories[""] = []


## Register a new command or category
func register(data: Dictionary) -> void:
	var id = data.get("id", "")
	if id.is_empty():
		ModLoaderLog.error("Command must have an id", LOG_NAME)
		return
	
	# Validate required fields
	if not data.has("title"):
		ModLoaderLog.error("Command '%s' must have a title" % id, LOG_NAME)
		return
	
	# Set defaults
	var command = {
		"id": id,
		"title": data.get("title", ""),
		"category_path": data.get("category_path", []),
		"keywords": data.get("keywords", []),
		"hint": data.get("hint", ""),
		"badge": data.get("badge", "SAFE"),
		"icon_path": data.get("icon_path", ""),
		"is_category": data.get("is_category", false),
		"can_run": data.get("can_run", Callable()),
		"run": data.get("run", Callable()),
		"keep_open": data.get("keep_open", false)
	}
	
	_commands[id] = command
	
	# Register in category structure (avoid duplicates when re-registering)
	var path_key = "/".join(command["category_path"])
	if not _categories.has(path_key):
		_categories[path_key] = []
	if id not in _categories[path_key]:
		_categories[path_key].append(id)
	
	# Track root items (avoid duplicates)
	if command["category_path"].is_empty():
		if id not in _root_items:
			_root_items.append(id)
	
	commands_changed.emit()


## Register multiple commands at once
func register_many(commands: Array) -> void:
	for cmd in commands:
		register(cmd)


## Get a command by id
func get_command(id: String) -> Dictionary:
	return _commands.get(id, {})


## Get all commands in a category path
func get_commands_in_category(category_path: Array) -> Array[Dictionary]:
	var path_key = "/".join(category_path)
	var result: Array[Dictionary] = []
	
	if _categories.has(path_key):
		for cmd_id in _categories[path_key]:
			if _commands.has(cmd_id):
				result.append(_commands[cmd_id])
	
	return result


## Get root level items (categories and commands at top level)
func get_root_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd_id in _root_items:
		if _commands.has(cmd_id):
			result.append(_commands[cmd_id])
	return result


## Get all commands (for search)
func get_all_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd in _commands.values():
		result.append(cmd)
	return result


## Get all non-category commands (executable commands only)
func get_all_executable_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cmd in _commands.values():
		if not cmd.get("is_category", false):
			result.append(cmd)
	return result


## Check if a command can run in the current context
func can_run(id: String, context: RefCounted) -> bool:
	var cmd = _commands.get(id, {})
	if cmd.is_empty():
		return false
	
	var can_run_func = cmd.get("can_run", Callable())
	if can_run_func.is_valid():
		return can_run_func.call(context)
	
	return true # Default to runnable if no condition specified


## Execute a command
func run(id: String, context: RefCounted) -> bool:
	var cmd = _commands.get(id, {})
	if cmd.is_empty():
		ModLoaderLog.error("Command not found: " + id, LOG_NAME)
		return false
	
	if cmd.get("is_category", false):
		return false # Categories don't execute
	
	var run_func = cmd.get("run", Callable())
	if run_func.is_valid():
		run_func.call(context)
		return true
	
	ModLoaderLog.warning("Command '%s' has no run function" % id, LOG_NAME)
	return false


## Clear all commands
func clear() -> void:
	_commands.clear()
	_categories.clear()
	_root_items.clear()
	_categories[""] = []
	commands_changed.emit()


## Get command count
func get_count() -> int:
	return _commands.size()
