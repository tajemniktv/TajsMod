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
	
	# ============== MENUS CATEGORY ==============
	
	# Window Menu Hotkeys (1-8)
	_manager.register_bind({
		"id": "taj.menu.network",
		"display_name": "Open Network Menu",
		"description": "Toggle the Network nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_1},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.network", self, "_on_menu_network")
	
	_manager.register_bind({
		"id": "taj.menu.cpu",
		"display_name": "Open CPU Menu",
		"description": "Toggle the CPU nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_2},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.cpu", self, "_on_menu_cpu")
	
	_manager.register_bind({
		"id": "taj.menu.gpu",
		"display_name": "Open GPU Menu",
		"description": "Toggle the GPU nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_3},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.gpu", self, "_on_menu_gpu")
	
	_manager.register_bind({
		"id": "taj.menu.research",
		"display_name": "Open Research Menu",
		"description": "Toggle the Research nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_4},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.research", self, "_on_menu_research")
	
	_manager.register_bind({
		"id": "taj.menu.factory",
		"display_name": "Open Factory Menu",
		"description": "Toggle the Factory nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_5},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.factory", self, "_on_menu_factory")
	
	_manager.register_bind({
		"id": "taj.menu.hacking",
		"display_name": "Open Hacking Menu",
		"description": "Toggle the Hacking nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_6},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.hacking", self, "_on_menu_hacking")
	
	_manager.register_bind({
		"id": "taj.menu.coding",
		"display_name": "Open Coding Menu",
		"description": "Toggle the Coding nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_7},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.coding", self, "_on_menu_coding")
	
	_manager.register_bind({
		"id": "taj.menu.utility",
		"display_name": "Open Utilities Menu",
		"description": "Toggle the Utilities nodes menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_8},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.utility", self, "_on_menu_utility")
	
	_manager.register_bind({
		"id": "taj.menu.schematics",
		"display_name": "Open Schematics",
		"description": "Toggle the Schematics panel",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_9},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.schematics", self, "_on_menu_schematics")
	
	# Side Menu Hotkeys (Ctrl+1-4)
	_manager.register_bind({
		"id": "taj.menu.upgrades",
		"display_name": "Open Upgrades",
		"description": "Toggle the Upgrades side menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_1, "ctrl": true},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.upgrades", self, "_on_menu_upgrades")
	
	_manager.register_bind({
		"id": "taj.menu.tokens",
		"display_name": "Open Token Shop",
		"description": "Toggle the Token Shop side menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_2, "ctrl": true},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.tokens", self, "_on_menu_tokens")
	
	_manager.register_bind({
		"id": "taj.menu.requests",
		"display_name": "Open Requests",
		"description": "Toggle the Requests side menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_3, "ctrl": true},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.requests", self, "_on_menu_requests")
	
	_manager.register_bind({
		"id": "taj.menu.achievements",
		"display_name": "Open Achievements",
		"description": "Toggle the Achievements side menu",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_4, "ctrl": true},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.menu.achievements", self, "_on_menu_achievements")
	
	# Mod Settings (F1)
	_manager.register_bind({
		"id": "taj.menu.settings",
		"display_name": "Open Taj's Mod Settings",
		"description": "Toggle the Taj's Mod settings panel",
		"category": "Menus",
		"default_binding": {"type": "key", "keycode": KEY_F1},
		"allow_rebind": true,
		"context": _manager.Context.GLOBAL
	})
	_manager.connect_bind("taj", "taj.menu.settings", self, "_on_menu_mod_settings")
	
	# ============== ACTIONS CATEGORY ==============
	
	# Pause/Unpause (Space)
	_manager.register_bind({
		"id": "taj.action.pause",
		"display_name": "Pause/Unpause Selected",
		"description": "Toggle pause state on selected nodes",
		"category": "Actions",
		"default_binding": {"type": "key", "keycode": KEY_SPACE},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.action.pause", self, "_on_action_pause")
	
	# Upgrade Selected (U)
	_manager.register_bind({
		"id": "taj.action.upgrade",
		"display_name": "Upgrade Selected",
		"description": "Upgrade the selected node",
		"category": "Actions",
		"default_binding": {"type": "key", "keycode": KEY_U},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.action.upgrade", self, "_on_action_upgrade")
	
	# Upgrade All Selected (Alt+U)
	_manager.register_bind({
		"id": "taj.action.upgrade_all",
		"display_name": "Upgrade All in Group",
		"description": "Upgrade all nodes in the selected group",
		"category": "Actions",
		"default_binding": {"type": "key", "keycode": KEY_U, "alt": true},
		"allow_rebind": true,
		"context": _manager.Context.IN_GAME
	})
	_manager.connect_bind("taj", "taj.action.upgrade_all", self, "_on_action_upgrade_all")
	
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


# ============== MENU HANDLERS ==============

## Toggle a window menu (node builder at bottom)
func _toggle_window(menu: int) -> void:
	if not _mod_main.get_tree().root.has_node("Signals"):
		return
	var main = _mod_main.get_tree().root.get_node_or_null("Main")
	if not main:
		return
	var hud = main.get_node_or_null("HUD")
	if not hud:
		return
	var wm = hud.get_node_or_null("Main/MainContainer/Overlay/WindowsMenu")
	if wm and wm.get("open") and wm.get("cur_tab") == menu:
		Signals.set_menu.emit(Utils.menu_types.NONE, 0)
	else:
		Signals.set_menu.emit(Utils.menu_types.WINDOWS, menu)


## Toggle a side menu tab
func _toggle_side_menu(tab: int) -> void:
	if not _mod_main.get_tree().root.has_node("Signals"):
		return
	Signals.set_menu.emit(Utils.menu_types.SIDE, tab)


func _on_menu_network() -> void:
	_toggle_window(Utils.window_menus.NETWORK)

func _on_menu_cpu() -> void:
	_toggle_window(Utils.window_menus.CPU)

func _on_menu_gpu() -> void:
	_toggle_window(Utils.window_menus.GPU)

func _on_menu_research() -> void:
	_toggle_window(Utils.window_menus.RESEARCH)

func _on_menu_factory() -> void:
	_toggle_window(Utils.window_menus.FACTORY)

func _on_menu_hacking() -> void:
	_toggle_window(Utils.window_menus.HACKING)

func _on_menu_coding() -> void:
	_toggle_window(Utils.window_menus.CODING)

func _on_menu_utility() -> void:
	_toggle_window(Utils.window_menus.UTILITY)

func _on_menu_schematics() -> void:
	if _mod_main.get_tree().root.has_node("Signals"):
		Signals.set_menu.emit(Utils.menu_types.SCHEMATICS, 0)

func _on_menu_upgrades() -> void:
	_toggle_side_menu(Utils.menus.UPGRADES)

func _on_menu_tokens() -> void:
	_toggle_side_menu(Utils.menus.TOKENS)

func _on_menu_requests() -> void:
	_toggle_side_menu(Utils.menus.REQUESTS)

func _on_menu_achievements() -> void:
	_toggle_side_menu(Utils.menus.ACHIEVEMENTS)

func _on_menu_mod_settings() -> void:
	if _mod_main.ui:
		_mod_main.ui.set_visible(!_mod_main.ui.is_visible())


# ============== ACTION HANDLERS ==============

func _on_action_pause() -> void:
	if Globals.selections.is_empty():
		return
	for window in Globals.selections:
		if window.get("can_pause") and window.has_method("toggle_pause"):
			window.toggle_pause()
	Sound.play("click2")
	# Update the options bar icon to reflect new pause state
	var main = _mod_main.get_tree().root.get_node_or_null("Main")
	if main:
		var options_bar = main.get_node_or_null("HUD/Main/MainContainer/Overlay/OptionsBar")
		if options_bar and options_bar.has_method("update_buttons"):
			options_bar.update_buttons()


func _on_action_upgrade() -> void:
	if Globals.selections.is_empty():
		return
	for window in Globals.selections:
		if window.has_method("can_upgrade") and window.can_upgrade():
			if window.has_method("_on_upgrade_button_pressed"):
				window._on_upgrade_button_pressed()
			elif window.has_method("upgrade"):
				var arg_count = _get_method_arg_count(window, "upgrade")
				if arg_count == 0:
					window.upgrade()
				else:
					window.upgrade(1)
			Sound.play("upgrade")
			return


func _on_action_upgrade_all() -> void:
	if Globals.selections.is_empty():
		return
	# Use the options bar's Buy Max function for proper repeated upgrading
	var main = _mod_main.get_tree().root.get_node_or_null("Main")
	if main:
		var options_bar = main.get_node_or_null("HUD/Main/MainContainer/Overlay/OptionsBar")
		if options_bar and options_bar.has_method("_on_buy_max_pressed"):
			options_bar._on_buy_max_pressed()
			return
	# Fallback: check if any selected node is a group with upgrade_all_nodes method
	for window in Globals.selections:
		if window.has_method("upgrade_all_nodes"):
			window.upgrade_all_nodes()
			return


func _get_method_arg_count(obj: Object, method_name: String) -> int:
	var script = obj.get_script()
	if script:
		for method in script.get_script_method_list():
			if method.name == method_name:
				return method.args.size()
	return 1
