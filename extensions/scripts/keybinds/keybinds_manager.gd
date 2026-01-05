# ==============================================================================
# Taj's Mod - Upload Labs
# Keybinds Manager - Centralized keybind registration, dispatch, and persistence
# Author: TajemnikTV
# ==============================================================================
class_name TajsModKeybindsManager
extends Node

const LOG_NAME = "TajsModded:KeybindsManager"

# ============== Signals ==============
signal bind_triggered(bind_id: String)
signal bind_registered(bind_id: String)
signal bind_unregistered(bind_id: String)
signal binding_changed(bind_id: String, new_binding: Dictionary)
signal conflict_detected(bind_id1: String, bind_id2: String)

# ============== Types ==============
enum BindingType {
	KEY,
	MOUSE
}

enum Context {
	GLOBAL, # Always active
	IN_GAME, # Only when playing (not in menus)
	PALETTE_OPEN, # Only when palette is open
	TEXT_FOCUS # Only when text field has focus
}

# ============== Internal State ==============
var _binds: Dictionary = {} # bind_id -> definition
var _overrides: Dictionary = {} # bind_id -> binding (user customizations)
var _callbacks: Dictionary = {} # bind_id -> Array of {target, method}
var _config # TajsModConfigManager reference
var _enabled: bool = true
var _initialized: bool = false

# Context tracking
var _current_context: int = Context.GLOBAL
var _palette_open: bool = false
var _text_focused: bool = false


func _init() -> void:
	name = "KeybindsManager"


func _ready() -> void:
	# Track focus changes for context
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


var _mod_main_ref = null

## Initialize the manager with config reference
func setup(config, mod_main_ref = null) -> void:
	_config = config
	_mod_main_ref = mod_main_ref
	_load_overrides()
	_initialized = true
	_log("KeybindsManager initialized")

func _log(message: String, is_warning: bool = false, is_error: bool = false) -> void:
	if _mod_main_ref and _mod_main_ref.has_method("_debug_log_wrapper"):
		_mod_main_ref._debug_log_wrapper(message)
	
	# Also log to console based on severity
	if is_error:
		ModLoaderLog.error(message, LOG_NAME)
	elif is_warning:
		ModLoaderLog.warning(message, LOG_NAME)
	else:
		ModLoaderLog.info(message, LOG_NAME)


## Set enabled state (global on/off)
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


## Check if enabled
func is_enabled() -> bool:
	return _enabled


# ============== Registration API ==============

## Register an internal keybind (for Taj's Mod)
func register_bind(definition: Dictionary) -> bool:
	return _register_bind_internal(definition, "taj")


## Register an external keybind (for other mods)
## Returns true if registration succeeded
func register_external_bind(mod_id: String, definition: Dictionary) -> bool:
	if mod_id.is_empty():
		_log("External bind registration requires mod_id", false, true)
		return false
	return _register_bind_internal(definition, mod_id)


## Internal registration logic
func _register_bind_internal(definition: Dictionary, mod_id: String) -> bool:
	# Validate required fields
	if not definition.has("id"):
		_log("Keybind definition missing 'id'", false, true)
		return false
	if not definition.has("default_binding"):
		_log("Keybind definition missing 'default_binding' for: %s" % definition.id, false, true)
		return false
	
	var bind_id: String = definition.id
	
	# Check for duplicates
	if _binds.has(bind_id):
		_log("Keybind '%s' already registered, skipping" % bind_id, true)
		return false
	
	# Build full definition with defaults
	var full_def = {
		"id": bind_id,
		"display_name": definition.get("display_name", bind_id),
		"description": definition.get("description", ""),
		"category": definition.get("category", "General"),
		"default_binding": definition.default_binding.duplicate(),
		"allow_rebind": definition.get("allow_rebind", true),
		"context": definition.get("context", Context.GLOBAL),
		"mod_id": mod_id
	}
	
	# Normalize the binding
	full_def.default_binding = _normalize_binding(full_def.default_binding)
	
	_binds[bind_id] = full_def
	_callbacks[bind_id] = []
	
	# Check for conflicts
	_check_conflicts(bind_id)
	
	bind_registered.emit(bind_id)
	
	if _config and _config.get_value("debug_mode", false):
		_log("Registered keybind: %s" % bind_id)
	
	return true


## Unregister a keybind
func unregister_bind(bind_id: String) -> void:
	if not _binds.has(bind_id):
		return
	
	_binds.erase(bind_id)
	_callbacks.erase(bind_id)
	_overrides.erase(bind_id)
	
	bind_unregistered.emit(bind_id)


## Unregister an external keybind
func unregister_external_bind(mod_id: String, bind_id: String) -> void:
	if not _binds.has(bind_id):
		return
	
	# Verify ownership
	if _binds[bind_id].mod_id != mod_id:
		_log("Cannot unregister '%s' - wrong mod_id" % bind_id, true)
		return
	
	unregister_bind(bind_id)


# ============== Callback Connection ==============

## Connect a callback to a keybind
func connect_bind(mod_id: String, bind_id: String, target: Object, method: String) -> void:
	if not _callbacks.has(bind_id):
		_callbacks[bind_id] = []
	
	# Check for duplicate
	for cb in _callbacks[bind_id]:
		if cb.target == target and cb.method == method:
			return
	
	_callbacks[bind_id].append({
		"target": target,
		"method": method,
		"mod_id": mod_id
	})


## Disconnect a callback from a keybind
func disconnect_bind(mod_id: String, bind_id: String, target: Object, method: String) -> void:
	if not _callbacks.has(bind_id):
		return
	
	var to_remove = -1
	for i in range(_callbacks[bind_id].size()):
		var cb = _callbacks[bind_id][i]
		if cb.target == target and cb.method == method:
			to_remove = i
			break
	
	if to_remove >= 0:
		_callbacks[bind_id].remove_at(to_remove)


# ============== Binding Getters/Setters ==============

## Get current effective binding for a keybind
func get_binding(bind_id: String) -> Dictionary:
	if not _binds.has(bind_id):
		return {}
	
	# Return override if exists, otherwise default
	if _overrides.has(bind_id) and _overrides[bind_id] != null:
		return _overrides[bind_id]
	
	return _binds[bind_id].default_binding


## Set a custom binding (user override)
func set_binding(bind_id: String, new_binding: Dictionary) -> bool:
	if not _binds.has(bind_id):
		return false
	
	if not _binds[bind_id].allow_rebind:
		_log("Keybind '%s' does not allow rebinding" % bind_id, true)
		return false
	
	var normalized = _normalize_binding(new_binding)
	_overrides[bind_id] = normalized
	_save_overrides()
	
	# Check for new conflicts
	_check_conflicts(bind_id)
	
	binding_changed.emit(bind_id, normalized)
	return true


## Reset a keybind to its default
func reset_binding(bind_id: String) -> void:
	if _overrides.has(bind_id):
		_overrides.erase(bind_id)
		_save_overrides()
		binding_changed.emit(bind_id, _binds[bind_id].default_binding if _binds.has(bind_id) else {})


## Reset all keybinds to defaults
func reset_all_bindings() -> void:
	_overrides.clear()
	_save_overrides()
	
	for bind_id in _binds:
		binding_changed.emit(bind_id, _binds[bind_id].default_binding)


# ============== Query Methods ==============

## Get all registered binds
func get_all_binds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bind_id in _binds:
		var entry = _binds[bind_id].duplicate()
		entry.current_binding = get_binding(bind_id)
		result.append(entry)
	return result


## Get binds by category
func get_binds_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bind_id in _binds:
		if _binds[bind_id].category == category:
			var entry = _binds[bind_id].duplicate()
			entry.current_binding = get_binding(bind_id)
			result.append(entry)
	return result


## Get all categories
func get_categories() -> Array[String]:
	var categories: Array[String] = []
	for bind_id in _binds:
		var cat = _binds[bind_id].category
		if cat not in categories:
			categories.append(cat)
	categories.sort()
	return categories


## Get bind definition by ID
func get_bind(bind_id: String) -> Dictionary:
	if _binds.has(bind_id):
		var entry = _binds[bind_id].duplicate()
		entry.current_binding = get_binding(bind_id)
		return entry
	return {}


# ============== Conflict Detection ==============

## Get list of all current conflicts
func get_conflicts() -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []
	var binding_map: Dictionary = {} # binding_key -> [bind_ids]
	
	for bind_id in _binds:
		var binding = get_binding(bind_id)
		var context = _binds[bind_id].context
		var key = _binding_to_key(binding, context)
		
		if not binding_map.has(key):
			binding_map[key] = []
		binding_map[key].append(bind_id)
	
	# Find conflicts (more than one bind per key)
	for key in binding_map:
		if binding_map[key].size() > 1:
			var ids = binding_map[key]
			for i in range(ids.size()):
				for j in range(i + 1, ids.size()):
					conflicts.append({
						"bind_id1": ids[i],
						"bind_id2": ids[j],
						"binding_key": key
					})
	
	return conflicts


## Check conflicts for a specific bind and emit signals
func _check_conflicts(bind_id: String) -> void:
	if not _binds.has(bind_id):
		return
	
	var binding = get_binding(bind_id)
	var context = _binds[bind_id].context
	var key = _binding_to_key(binding, context)
	
	for other_id in _binds:
		if other_id == bind_id:
			continue
		
		var other_binding = get_binding(other_id)
		var other_context = _binds[other_id].context
		
		# Check if contexts overlap
		if not _contexts_overlap(context, other_context):
			continue
		
		var other_key = _binding_to_key(other_binding, other_context)
		if key == other_key:
			conflict_detected.emit(bind_id, other_id)
			_log("Keybind conflict: '%s' and '%s' have same binding" % [bind_id, other_id], true)


## Check if two contexts can overlap (and thus conflict)
func _contexts_overlap(ctx1: int, ctx2: int) -> bool:
	# Global overlaps with everything
	if ctx1 == Context.GLOBAL or ctx2 == Context.GLOBAL:
		return true
	# Same context overlaps
	return ctx1 == ctx2


## Convert binding + context to unique string key for comparison
func _binding_to_key(binding: Dictionary, context: int) -> String:
	var parts: Array[String] = []
	
	if binding.get("ctrl", false):
		parts.append("ctrl")
	if binding.get("alt", false):
		parts.append("alt")
	if binding.get("shift", false):
		parts.append("shift")
	if binding.get("meta", false):
		parts.append("meta")
	
	var type = binding.get("type", "key")
	if type == "mouse":
		parts.append("mouse_%d" % binding.get("button", 0))
	else:
		parts.append("key_%d" % binding.get("keycode", 0))
	
	parts.append("ctx_%d" % context)
	
	return "+".join(parts)


# ============== Input Processing ==============

func _input(event: InputEvent) -> void:
	if not _enabled or not _initialized:
		return
	
	# Update context based on current state
	_update_context()
	
	# Check each registered bind
	for bind_id in _binds:
		var binding = get_binding(bind_id)
		var context = _binds[bind_id].context
		
		# Check context match
		if not _context_matches(context):
			continue
		
		# Check if event matches binding
		if _event_matches_binding(event, binding):
			_trigger_bind(bind_id)
			get_viewport().set_input_as_handled()
			return


## Update current context based on game state
func _update_context() -> void:
	# Check text focus
	var focused = get_viewport().gui_get_focus_owner()
	_text_focused = focused != null and (focused is LineEdit or focused is TextEdit)
	
	# Palette state is set externally via set_palette_open()


## Check if current context matches bind context
func _context_matches(bind_context: int) -> bool:
	match bind_context:
		Context.GLOBAL:
			# Global binds should NOT trigger when text is focused
			# unless explicitly designed for text fields
			return not _text_focused
		Context.IN_GAME:
			return not _text_focused and not _palette_open
		Context.PALETTE_OPEN:
			return _palette_open
		Context.TEXT_FOCUS:
			return _text_focused
	return true


## Check if an input event matches a binding
func _event_matches_binding(event: InputEvent, binding: Dictionary) -> bool:
	var binding_type = binding.get("type", "key")
	
	# Check modifiers for key events
	if event is InputEventKey:
		if binding_type != "key":
			return false
		
		if not event.pressed or event.is_echo():
			return false
		
		if event.keycode != binding.get("keycode", 0):
			return false
		
		# Check modifiers
		if event.ctrl_pressed != binding.get("ctrl", false):
			return false
		if event.alt_pressed != binding.get("alt", false):
			return false
		if event.shift_pressed != binding.get("shift", false):
			return false
		if event.meta_pressed != binding.get("meta", false):
			return false
		
		return true
	
	elif event is InputEventMouseButton:
		if binding_type != "mouse":
			return false
		
		if not event.pressed:
			return false
		
		if event.button_index != binding.get("button", 0):
			return false
		
		# Check modifiers for mouse events too
		if event.ctrl_pressed != binding.get("ctrl", false):
			return false
		if event.alt_pressed != binding.get("alt", false):
			return false
		if event.shift_pressed != binding.get("shift", false):
			return false
		if event.meta_pressed != binding.get("meta", false):
			return false
		
		return true
	
	return false


## Trigger a keybind
func _trigger_bind(bind_id: String) -> void:
	if _config and _config.get_value("debug_mode", false):
		_log("Triggering keybind: %s" % bind_id)
	
	# Emit global signal
	bind_triggered.emit(bind_id)
	
	# Call registered callbacks
	if _callbacks.has(bind_id):
		for cb in _callbacks[bind_id]:
			if is_instance_valid(cb.target) and cb.target.has_method(cb.method):
				cb.target.call(cb.method)


# ============== Context Setters (for external state) ==============

## Set palette open state (called by palette controller)
func set_palette_open(is_open: bool) -> void:
	_palette_open = is_open


## Track focus changes
func _on_focus_changed(control: Control) -> void:
	_text_focused = control != null and (control is LineEdit or control is TextEdit)


# ============== Persistence ==============

## Load overrides from config
func _load_overrides() -> void:
	if not _config:
		return
	
	var saved = _config.get_value("keybind_overrides", {})
	if saved is Dictionary:
		_overrides = saved.duplicate()
		_log("Loaded %d keybind overrides" % _overrides.size())


## Save overrides to config  
func _save_overrides() -> void:
	if not _config:
		return
	
	_config.set_value("keybind_overrides", _overrides.duplicate())


# ============== Utility ==============

## Normalize a binding dictionary to canonical form
func _normalize_binding(binding: Dictionary) -> Dictionary:
	var normalized = {
		"type": binding.get("type", "key"),
		"keycode": binding.get("keycode", 0),
		"button": binding.get("button", 0),
		"ctrl": binding.get("ctrl", false),
		"alt": binding.get("alt", false),
		"shift": binding.get("shift", false),
		"meta": binding.get("meta", false)
	}
	return normalized


## Get human-readable string for a binding
func get_binding_display_string(bind_id: String) -> String:
	var binding = get_binding(bind_id)
	return binding_to_display_string(binding)


## Convert binding dictionary to display string
func binding_to_display_string(binding: Dictionary) -> String:
	var parts: Array[String] = []
	
	if binding.get("ctrl", false):
		parts.append("Ctrl")
	if binding.get("alt", false):
		parts.append("Alt")
	if binding.get("shift", false):
		parts.append("Shift")
	if binding.get("meta", false):
		parts.append("Meta")
	
	var binding_type = binding.get("type", "key")
	if binding_type == "mouse":
		var button = binding.get("button", 0)
		match button:
			MOUSE_BUTTON_LEFT:
				parts.append("Left Click")
			MOUSE_BUTTON_RIGHT:
				parts.append("Right Click")
			MOUSE_BUTTON_MIDDLE:
				parts.append("Middle Click")
			MOUSE_BUTTON_XBUTTON1:
				parts.append("Mouse Back")
			MOUSE_BUTTON_XBUTTON2:
				parts.append("Mouse Forward")
			MOUSE_BUTTON_WHEEL_UP:
				parts.append("Scroll Up")
			MOUSE_BUTTON_WHEEL_DOWN:
				parts.append("Scroll Down")
			_:
				parts.append("Mouse %d" % button)
	else:
		var keycode = binding.get("keycode", 0)
		var key_string = OS.get_keycode_string(keycode)
		if key_string.is_empty():
			key_string = "Key %d" % keycode
		parts.append(key_string)
	
	return "+".join(parts) if parts.size() > 0 else "Unbound"


## Create a binding from an input event (for rebind capture)
func binding_from_event(event: InputEvent) -> Dictionary:
	var binding = {
		"type": "key",
		"keycode": 0,
		"button": 0,
		"ctrl": false,
		"alt": false,
		"shift": false,
		"meta": false
	}
	
	if event is InputEventKey:
		binding.type = "key"
		binding.keycode = event.keycode
		binding.ctrl = event.ctrl_pressed
		binding.alt = event.alt_pressed
		binding.shift = event.shift_pressed
		binding.meta = event.meta_pressed
	elif event is InputEventMouseButton:
		binding.type = "mouse"
		binding.button = event.button_index
		binding.ctrl = event.ctrl_pressed
		binding.alt = event.alt_pressed
		binding.shift = event.shift_pressed
		binding.meta = event.meta_pressed
	
	return binding
