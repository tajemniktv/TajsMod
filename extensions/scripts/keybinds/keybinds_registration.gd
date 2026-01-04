# ==============================================================================
# Taj's Mod - Upload Labs
# Keybinds Registration - Defines and registers all mod keybinds
# Author: TajemnikTV
# ==============================================================================
class_name TajsModKeybindsRegistration
extends RefCounted

const LOG_NAME = "TajsModded:KeybindsRegistration"

# References
var _manager # TajsModKeybindsManager
var _mod_main # mod_main.gd reference for callbacks


func setup(keybinds_manager, mod_main_ref) -> void:
	_manager = keybinds_manager
	_mod_main = mod_main_ref
	
	if not _manager:
		ModLoaderLog.error("KeybindsManager not provided", LOG_NAME)
		return
	
	_register_all()


func _register_all() -> void:
	# ============== EDITING CATEGORY ==============
	# Undo (Ctrl+Z)
	_manager.register_bind({
		"id": "taj.undo",
		"display_name": "Undo",
		"description": "Undo the last action",
		"category": "Editing",
		"default_binding": {
			"type": "key",
			"keycode": KEY_Z,
			"ctrl": true
		},
		"allow_rebind": true,
		"context": _manager.Context.GLOBAL
	})
	_manager.connect_bind("taj", "taj.undo", self, "_on_undo")
	
	# Redo (Ctrl+Y)
	_manager.register_bind({
		"id": "taj.redo",
		"display_name": "Redo",
		"description": "Redo the last undone action",
		"category": "Editing",
		"default_binding": {
			"type": "key",
			"keycode": KEY_Y,
			"ctrl": true
		},
		"allow_rebind": true,
		"context": _manager.Context.GLOBAL
	})
	_manager.connect_bind("taj", "taj.redo", self, "_on_redo")
	
	# Redo Alt (Ctrl+Shift+Z)
	_manager.register_bind({
		"id": "taj.redo_alt",
		"display_name": "Redo (Alt)",
		"description": "Redo the last undone action (alternate binding)",
		"category": "Editing",
		"default_binding": {
			"type": "key",
			"keycode": KEY_Z,
			"ctrl": true,
			"shift": true
		},
		"allow_rebind": true,
		"context": _manager.Context.GLOBAL
	})
	_manager.connect_bind("taj", "taj.redo_alt", self, "_on_redo")
	
	# Select All (Ctrl+A)
	_manager.register_bind({
		"id": "taj.select_all",
		"display_name": "Select All Nodes",
		"description": "Select all nodes on the desktop",
		"category": "Editing",
		"default_binding": {
			"type": "key",
			"keycode": KEY_A,
			"ctrl": true
		},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.select_all", self, "_on_select_all")
	
	# Delete Selection (Delete)
	_manager.register_bind({
		"id": "taj.delete",
		"display_name": "Delete Selection",
		"description": "Delete selected nodes",
		"category": "Editing",
		"default_binding": {
			"type": "key",
			"keycode": KEY_DELETE
		},
		"allow_rebind": true,
		"context": _manager.Context.GLOBAL
	})
	_manager.connect_bind("taj", "taj.delete", self, "_on_delete")
	
	# ============== PALETTE CATEGORY ==============
	
	# Open Command Palette (Middle Mouse)
	_manager.register_bind({
		"id": "taj.palette.open",
		"display_name": "Open Command Palette",
		"description": "Open the command palette for quick actions",
		"category": "Palette",
		"default_binding": {
			"type": "mouse",
			"button": MOUSE_BUTTON_MIDDLE
		},
		"allow_rebind": true,
		"context": _manager.Context.GLOBAL
	})
	_manager.connect_bind("taj", "taj.palette.open", self, "_on_palette_toggle")
	
	# Palette Back (Mouse Back)
	_manager.register_bind({
		"id": "taj.palette.back",
		"display_name": "Palette History Back",
		"description": "Navigate backwards in palette history",
		"category": "Palette",
		"default_binding": {
			"type": "mouse",
			"button": MOUSE_BUTTON_XBUTTON1
		},
		"allow_rebind": true,
		"context": _manager.Context.PALETTE_OPEN
	})
	_manager.connect_bind("taj", "taj.palette.back", self, "_on_palette_back")
	
	# Palette Forward (Mouse Forward)
	_manager.register_bind({
		"id": "taj.palette.forward",
		"display_name": "Palette History Forward",
		"description": "Navigate forward in palette history",
		"category": "Palette",
		"default_binding": {
			"type": "mouse",
			"button": MOUSE_BUTTON_XBUTTON2
		},
		"allow_rebind": true,
		"context": _manager.Context.PALETTE_OPEN
	})
	_manager.connect_bind("taj", "taj.palette.forward", self, "_on_palette_forward")
	
	# NOTE: Wire Clear (Right Mouse) is NOT registered here because it's context-dependent
	# (only triggers when hovering over a connector). It stays in wire_clear_handler.gd
	
	ModLoaderLog.info("Registered %d keybinds" % _manager.get_all_binds().size(), LOG_NAME)


# ============== CALLBACK HANDLERS ==============

func _on_undo() -> void:
	if _mod_main.config.get_value("undo_redo_enabled", true) and _mod_main.undo_manager:
		_mod_main.undo_manager.undo()


func _on_redo() -> void:
	if _mod_main.config.get_value("undo_redo_enabled", true) and _mod_main.undo_manager:
		_mod_main.undo_manager.redo()


func _on_palette_toggle() -> void:
	if _mod_main.palette_controller and _mod_main.config.get_value("command_palette_enabled", true):
		_mod_main.palette_controller.toggle()


func _on_palette_back() -> void:
	if _mod_main.palette_controller and _mod_main.palette_controller.is_open():
		_mod_main.palette_controller.overlay._go_back()


func _on_palette_forward() -> void:
	if _mod_main.palette_controller and _mod_main.palette_controller.is_open():
		_mod_main.palette_controller.overlay._go_forward()


func _on_select_all() -> void:
	if Globals.select_all_enabled:
		var desktop = Globals.desktop
		if desktop and desktop.has_method("_select_all_nodes"):
			desktop._select_all_nodes()


func _on_delete() -> void:
	var desktop = Globals.desktop
	if desktop:
		if _mod_main.undo_manager:
			_mod_main.undo_manager.begin_action("Delete Selection")
		# Trigger the original delete behavior
		var fake_event = InputEventKey.new()
		fake_event.keycode = KEY_DELETE
		fake_event.pressed = true
		desktop._input(fake_event)
		if _mod_main.undo_manager:
			_mod_main.undo_manager.commit_action()
