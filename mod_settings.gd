# ==============================================================================
# Taj's Mod - Upload Labs
# Settings Manager - Handles settings UI construction and callbacks
# Author: TajemnikTV
# ==============================================================================
class_name TajsModSettings
extends RefCounted

const LOG_NAME = "TajsModded:Settings"

# References from mod_main
var mod_main # Main mod instance
var config # ConfigManager instance
var ui # SettingsUI instance

# Component references (passed in via setup)
var screenshot_manager
var wire_colors
var palette_controller
var focus_handler
var smooth_scroll_manager
var disconnected_highlighter
var sticky_note_manager
var undo_manager
var workshop_sync
var cheat_manager
var keybinds_manager
var keybinds_ui
var node_group_z_fix
var buy_max_manager
var goto_group_panel

# State
var _debug_mode := false
var _node_info_label: Label = null
var _debug_log_label: Label = null
var _node_limit_slider: HSlider = null
var _node_limit_value_label: Label = null
var _extra_glow_toggle: CheckButton = null
var _extra_glow_sub: MarginContainer = null
var _settings_toggles: Dictionary = {} # config_key -> CheckButton reference
var _restart_original_values: Dictionary = {} # Tracks original values of restart-required settings


## Initialize settings with references to mod components
func setup(p_mod_main, p_config, p_ui, components: Dictionary) -> void:
	mod_main = p_mod_main
	config = p_config
	ui = p_ui
	
	# Extract component references
	screenshot_manager = components.get("screenshot_manager")
	wire_colors = components.get("wire_colors")
	palette_controller = components.get("palette_controller")
	focus_handler = components.get("focus_handler")
	smooth_scroll_manager = components.get("smooth_scroll_manager")
	disconnected_highlighter = components.get("disconnected_highlighter")
	sticky_note_manager = components.get("sticky_note_manager")
	undo_manager = components.get("undo_manager")
	workshop_sync = components.get("workshop_sync")
	cheat_manager = components.get("cheat_manager")
	keybinds_manager = components.get("keybinds_manager")
	keybinds_ui = components.get("keybinds_ui")
	node_group_z_fix = components.get("node_group_z_fix")
	buy_max_manager = components.get("buy_max_manager")
	goto_group_panel = components.get("goto_group_panel")


## Build the complete settings menu with all tabs
func build_settings_menu() -> void:
	# --- GENERAL ---
	var gen_vbox = ui.add_tab("General", "res://textures/icons/cog.png")
	
	# Wire Drop Node Menu toggle
	_settings_toggles["wire_drop_menu_enabled"] = ui.add_toggle(gen_vbox, "Wire Drop Node Menu", config.get_value("wire_drop_menu_enabled"), func(v):
		config.set_value("wire_drop_menu_enabled", v)
		palette_controller.set_wire_drop_enabled(v)
	, "Show a quick-add menu when dropping a wire onto the canvas.")
	
	# 6-Input Containers toggle (Issue #18) - requires restart
	_restart_original_values["six_input_containers"] = config.get_value("six_input_containers")
	_settings_toggles["six_input_containers"] = ui.add_toggle(gen_vbox, "6-Input Containers ⟳", config.get_value("six_input_containers"), func(v):
		config.set_value("six_input_containers", v)
		_check_restart_required()
	, "Allow containers to have 6 inputs instead of 5. Requires restart.")
	
	# Command Palette toggle
	_settings_toggles["command_palette_enabled"] = ui.add_toggle(gen_vbox, "Command Palette (MMB)", config.get_value("command_palette_enabled"), func(v):
		config.set_value("command_palette_enabled", v)
		if palette_controller:
			palette_controller.set_palette_enabled(v)
	, "Open a searchable command palette with Middle Mouse Button.")

	# Palette Tab Autocomplete toggle
	var tab_autocomplete_enabled = true
	if palette_controller and palette_controller.palette_config:
		tab_autocomplete_enabled = palette_controller.palette_config.get_value("tab_autocomplete", true)
	_settings_toggles["palette_tab_autocomplete"] = ui.add_toggle(gen_vbox, "Palette: Tab Autocomplete", tab_autocomplete_enabled, func(v):
		if palette_controller:
			palette_controller.set_tab_autocomplete_enabled(v)
	, "Use Tab to autocomplete command names in the palette (Ctrl+Space always works).")
	
	# Undo/Redo toggle
	_settings_toggles["undo_redo_enabled"] = ui.add_toggle(gen_vbox, "Undo/Redo (Ctrl+Z)", config.get_value("undo_redo_enabled", true), func(v):
		config.set_value("undo_redo_enabled", v)
		if undo_manager:
			undo_manager.set_enabled(v)
	, "Enable undo/redo for node movements and connections.")
	
	# Right-click Wire Clear toggle
	var wire_clear_handler = mod_main.wire_clear_handler
	_settings_toggles["right_click_clear_enabled"] = ui.add_toggle(gen_vbox, "Right-click Wire Clear", config.get_value("right_click_clear_enabled"), func(v):
		config.set_value("right_click_clear_enabled", v)
		if wire_clear_handler:
			wire_clear_handler.set_enabled(v)
	, "Right-click on output slots to disconnect wires.")
	
	# Select All (Ctrl+A) toggle
	_settings_toggles["select_all_enabled"] = ui.add_toggle(gen_vbox, "Ctrl+A Select All", config.get_value("select_all_enabled"), func(v):
		config.set_value("select_all_enabled", v)
		Globals.select_all_enabled = v
	, "Use Ctrl+A to select all nodes on the board.")
	
	# Go To Group Panel toggle
	_settings_toggles["goto_group_enabled"] = ui.add_toggle(gen_vbox, "Go To Group Button", config.get_value("goto_group_enabled"), func(v):
		config.set_value("goto_group_enabled", v)
		mod_main._set_goto_group_visible(v)
	, "Show a button to quickly jump to any Node Group on the board.")
	
	# Buy Max Button toggle
	_settings_toggles["buy_max_enabled"] = ui.add_toggle(gen_vbox, "Buy Max Button", config.get_value("buy_max_enabled"), func(v):
		config.set_value("buy_max_enabled", v)
		mod_main._set_buy_max_visible(v)
	, "Add a button to buy the maximum affordable upgrades at once.")
	
	# Upgrade Multiplier Slider
	var saved_mult = config.get_value("upgrade_multiplier", 10)
	Globals.custom_upgrade_multiplier = saved_mult
	ui.add_slider(gen_vbox, "Upgrade Multiplier (Ctrl)", saved_mult, 2, 100, 1, "x", func(v):
		config.set_value("upgrade_multiplier", v)
		Globals.custom_upgrade_multiplier = v
	)
	
	# Z-Order Fix toggle
	_settings_toggles["z_order_fix_enabled"] = ui.add_toggle(gen_vbox, "Group Z-Order Fix", config.get_value("z_order_fix_enabled"), func(v):
		config.set_value("z_order_fix_enabled", v)
		if node_group_z_fix:
			node_group_z_fix.set_enabled(v)
	, "Nested node groups render on top of their containers.")
	
	# Disable Slider Scroll toggle
	_settings_toggles["disable_slider_scroll"] = ui.add_toggle(gen_vbox, "Disable Slider Scroll", config.get_value("disable_slider_scroll"), func(v):
		config.set_value("disable_slider_scroll", v)
	, "Prevent mouse wheel from accidentally changing slider values.")
	
	# Smooth Scroll toggle
	_settings_toggles["smooth_scroll_enabled"] = ui.add_toggle(gen_vbox, "Smooth Scrolling", config.get_value("smooth_scroll_enabled", false), func(v):
		config.set_value("smooth_scroll_enabled", v)
		smooth_scroll_manager.set_enabled(v)
	, "Enable smooth scrolling for all scrollable containers (vanilla and modded).")
	
	# Toast History Panel toggle
	_settings_toggles["notification_log_enabled"] = ui.add_toggle(gen_vbox, "Toast History Panel", config.get_value("notification_log_enabled", true), func(v):
		config.set_value("notification_log_enabled", v)
		mod_main._set_notification_log_visible(v)
	, "Show a bell icon to view recent notifications and messages.")
	
	# Highlight Disconnected Nodes section
	_add_disconnected_highlight_section(gen_vbox)
	
	# Node Info Label (Custom)
	var info_row = HBoxContainer.new()
	_node_info_label = Label.new()
	_node_info_label.text = "Nodes: ... / ..."
	_node_info_label.add_theme_font_size_override("font_size", 24)
	_node_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_node_info_label)
	gen_vbox.add_child(info_row)
	
	# Node Limit (Custom with ∞ support)
	_add_node_limit_slider(gen_vbox)
	
	# Screenshot Section
	screenshot_manager.add_screenshot_section(gen_vbox, ui, config)
	
	# Focus Mute Section (Issue #11)
	var fh = focus_handler
	_settings_toggles["mute_on_focus_loss"] = ui.add_toggle(gen_vbox, "Mute on Focus Loss", config.get_value("mute_on_focus_loss"), func(v):
		fh.set_enabled(v)
	, "Automatically lower volume when the game window loses focus.")
	ui.add_slider(gen_vbox, "Background Volume", config.get_value("background_volume"), 0, 100, 5, "%", func(v):
		fh.set_background_volume(v)
	)

	# Disable Controller Input toggle
	_settings_toggles["disable_controller_input"] = ui.add_toggle(gen_vbox, "Disable Controller Input", config.get_value("disable_controller_input", false), func(v):
		config.set_value("disable_controller_input", v)
	, "Completely disable all controller/joypad inputs. Useful if you have a controller connected for another game.")
	
	# --- VISUALS ---
	var vis_vbox = ui.add_tab("Visuals", "res://textures/icons/eye_ball.png")
	
	# Wire Colors Section
	_add_wire_color_section(vis_vbox)
	
	# Glow toggle + sub-settings container
	var glow_container = VBoxContainer.new()
	glow_container.add_theme_constant_override("separation", 10)
	vis_vbox.add_child(glow_container)
	
	# Sub-settings (initially hidden)
	var glow_sub = MarginContainer.new()
	glow_sub.name = "glow_sub_settings"
	glow_sub.add_theme_constant_override("margin_left", 30)
	glow_sub.visible = config.get_value("extra_glow")
	
	var glow_sub_vbox = VBoxContainer.new()
	glow_sub_vbox.add_theme_constant_override("separation", 10)
	glow_sub.add_child(glow_sub_vbox)
	
	_extra_glow_toggle = ui.add_toggle(glow_container, "Extra Glow", config.get_value("extra_glow"), func(v):
		config.set_value("extra_glow", v)
		glow_sub.visible = v
		_apply_extra_glow(v)
	, "Enable enhanced glow effects on the game board.")
	_extra_glow_sub = glow_sub
	
	glow_container.add_child(glow_sub)
	
	ui.add_slider(glow_sub_vbox, "Intensity", config.get_value("glow_intensity"), 0.0, 5.0, 0.1, "x", func(v):
		config.set_value("glow_intensity", v)
		_apply_extra_glow(true)
	)
	ui.add_slider(glow_sub_vbox, "Strength", config.get_value("glow_strength"), 0.5, 2.0, 0.05, "x", func(v):
		config.set_value("glow_strength", v)
		_apply_extra_glow(true)
	)
	ui.add_slider(glow_sub_vbox, "Bloom", config.get_value("glow_bloom"), 0.0, 0.5, 0.05, "", func(v):
		config.set_value("glow_bloom", v)
		_apply_extra_glow(true)
	)
	ui.add_slider(glow_sub_vbox, "Sensitivity", config.get_value("glow_sensitivity"), 0.0, 1.0, 0.05, "", func(v):
		config.set_value("glow_sensitivity", v)
		_apply_extra_glow(true)
	)
	
	ui.add_slider(vis_vbox, "UI Opacity", config.get_value("ui_opacity"), 50, 100, 5, "%", func(v):
		config.set_value("ui_opacity", v)
		mod_main._apply_ui_opacity(v)
	)
	
	# --- KEYBINDS ---
	var keybinds_vbox = ui.add_tab("Keybinds", "res://mods-unpacked/TajemnikTV-TajsModded/textures/icons/Keyboard.svg")
	if keybinds_manager:
		keybinds_ui = mod_main.KeybindsUIScript.new()
		keybinds_ui.setup(keybinds_manager, ui, keybinds_vbox)
	
	# --- CHEATS ---
	var cheat_vbox = ui.add_tab("Cheats", "res://textures/icons/money.png")
	cheat_manager = mod_main.CheatManagerScript.new()
	cheat_manager.build_cheats_tab(cheat_vbox)
	
	# --- MOD MANAGER ---
	var modmgr_vbox = ui.add_tab("Mod Manager", "res://mods-unpacked/TajemnikTV-TajsModded/textures/icons/Module-Puzzle-2.svg")
	
	# Workshop Sync on Startup toggle
	_settings_toggles["workshop_sync_on_startup"] = ui.add_toggle(modmgr_vbox, "Workshop Sync on Startup", config.get_value("workshop_sync_on_startup", true), func(v):
		config.set_value("workshop_sync_on_startup", v)
		if workshop_sync:
			workshop_sync.sync_on_startup = v
	, "Automatically check and trigger downloads for outdated Workshop mods at game startup.")
	
	# High Priority Downloads toggle
	_settings_toggles["workshop_high_priority"] = ui.add_toggle(modmgr_vbox, "High Priority Downloads", config.get_value("workshop_high_priority", true), func(v):
		config.set_value("workshop_high_priority", v)
		if workshop_sync:
			workshop_sync.high_priority_downloads = v
	, "Use high priority for Workshop downloads to speed up updates.")
	
	# Force Download All toggle (bypasses unreliable NeedsUpdate flag)
	_settings_toggles["workshop_force_all"] = ui.add_toggle(modmgr_vbox, "Force Download All Items", config.get_value("workshop_force_all", true), func(v):
		config.set_value("workshop_force_all", v)
		if workshop_sync:
			workshop_sync.force_download_all = v
	, "Always request downloads for ALL subscribed items. Recommended ON - Steam's update detection is unreliable.")
	
	# Force Sync Now button
	ui.add_button(modmgr_vbox, "Force Workshop Sync Now", func():
		if workshop_sync:
			workshop_sync.start_sync()
			Signals.notify.emit("download", "Workshop sync started...")
		else:
			Signals.notify.emit("cross", "Workshop Sync not available")
	)
	
	# Status info
	var steam_status = Label.new()
	steam_status.add_theme_font_size_override("font_size", 20)
	steam_status.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.8))
	if workshop_sync and workshop_sync.is_steam_available():
		steam_status.text = "✓ Steam Workshop available"
		steam_status.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 0.9))
	else:
		steam_status.text = "✗ Steam not available"
		steam_status.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5, 0.9))
	modmgr_vbox.add_child(steam_status)
	
	# --- DEBUG ---
	var debug_vbox = ui.add_tab("Debug", "res://textures/icons/bug.png")
	
	ui.add_button(debug_vbox, "Reset All Settings", func():
		config.reset_to_defaults()
		# Apply defaults immediately
		Globals.custom_node_limit = config.get_value("node_limit")
		screenshot_manager.quality = int(config.get_value("screenshot_quality", 2))
		screenshot_manager.screenshot_folder = config.get_value("screenshot_folder", "user://screenshots")
		screenshot_manager.watermark_enabled = config.get_value("screenshot_watermark", true)
		wire_colors.set_enabled(config.get_value("custom_wire_colors", true))
		_apply_extra_glow(config.get_value("extra_glow"))
		mod_main._apply_ui_opacity(config.get_value("ui_opacity"))
		add_debug_log("Settings reset to defaults")
		Signals.notify.emit("check", "Settings reset!")
	)
	
	# Custom Boot Screen toggle - requires restart
	_restart_original_values["custom_boot_screen"] = config.get_value("custom_boot_screen", true)
	_settings_toggles["custom_boot_screen"] = ui.add_toggle(debug_vbox, "Custom Boot Screen ⟳", config.get_value("custom_boot_screen", true), func(v):
		config.set_value("custom_boot_screen", v)
		_check_restart_required()
	, "Show a custom boot screen with mod version info. Requires restart.")
	
	# Debug mode toggle
	var saved_debug = config.get_value("debug_mode", false)
	_debug_mode = saved_debug
	# Apply initial debug state to components that need it
	if sticky_note_manager:
		sticky_note_manager.set_debug_enabled(saved_debug)
	if undo_manager:
		undo_manager.set_debug_enabled(saved_debug)
	
	var debug_toggle = ui.add_toggle(debug_vbox, "Enable Debug Logging", saved_debug, func(v):
		_debug_mode = v
		config.set_value("debug_mode", v)
		if sticky_note_manager:
			sticky_note_manager.set_debug_enabled(v)
		if undo_manager:
			undo_manager.set_debug_enabled(v)
		add_debug_log("Debug mode " + ("enabled" if v else "disabled"), true)
	, "Log extra debug information to the console and debug tab.")
	
	# Debug info buttons
	ui.add_button(debug_vbox, "Log Debug Info", func():
		add_debug_log("=== DEBUG INFO ===", true)
		add_debug_log("Money: " + str(Globals.currencies.get("money", 0)), true)
		add_debug_log("Research: " + str(Globals.currencies.get("research", 0)), true)
		add_debug_log("Tokens: " + str(Globals.currencies.get("token", 0)), true)
		add_debug_log("Node Limit: " + str(Globals.custom_node_limit), true)
		add_debug_log("Max Money: " + str(Globals.max_money), true)
		add_debug_log("Max Research: " + str(Globals.max_research), true)
	)
	
	# Debug log label
	var log_label = Label.new()
	log_label.name = "DebugLogLabel"
	log_label.text = "Debug Log:\n"
	log_label.add_theme_font_size_override("font_size", 18)
	log_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	debug_vbox.add_child(log_label)
	_debug_log_label = log_label


# ==============================================================================
# SETTINGS SECTIONS
# ==============================================================================

func _add_disconnected_highlight_section(parent: Control) -> void:
	var highlight_container = VBoxContainer.new()
	highlight_container.add_theme_constant_override("separation", 10)
	parent.add_child(highlight_container)
	
	# Sub-settings (shown when toggle is on)
	var highlight_sub = MarginContainer.new()
	highlight_sub.name = "highlight_disconnected_sub"
	highlight_sub.add_theme_constant_override("margin_left", 20)
	highlight_sub.visible = config.get_value("highlight_disconnected_enabled", true)
	
	var highlight_sub_vbox = VBoxContainer.new()
	highlight_sub_vbox.add_theme_constant_override("separation", 8)
	highlight_sub.add_child(highlight_sub_vbox)
	
	var sub_ref = highlight_sub
	var highlighter_ref = disconnected_highlighter
	
	# Main toggle
	_settings_toggles["highlight_disconnected_enabled"] = ui.add_toggle(highlight_container, "Highlight Disconnected Nodes", config.get_value("highlight_disconnected_enabled", true), func(v):
		config.set_value("highlight_disconnected_enabled", v)
		sub_ref.visible = v
		if highlighter_ref:
			highlighter_ref.set_enabled(v)
			if v:
				# Trigger immediate recomputation when enabled
				highlighter_ref.recompute_disconnected()
	, "Highlight nodes that are not connected to the main graph for their connection type.")
	
	highlight_container.add_child(highlight_sub)
	
	# Style dropdown
	var style_row = HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 10)
	highlight_sub_vbox.add_child(style_row)
	
	var style_label = Label.new()
	style_label.text = "Highlight Style"
	style_label.add_theme_font_size_override("font_size", 22)
	style_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_row.add_child(style_label)
	
	var style_option = OptionButton.new()
	style_option.add_item("Pulse Tint", 0)
	style_option.add_item("Outline Tint", 1)
	var current_style = config.get_value("highlight_disconnected_style", "pulse")
	style_option.selected = 1 if current_style == "outline" else 0
	style_option.custom_minimum_size = Vector2(150, 40)
	style_option.item_selected.connect(func(idx):
		var style = "outline" if idx == 1 else "pulse"
		config.set_value("highlight_disconnected_style", style)
		if highlighter_ref:
			highlighter_ref.set_style(style)
	)
	style_row.add_child(style_option)
	
	# Intensity slider
	ui.add_slider(highlight_sub_vbox, "Intensity", config.get_value("highlight_disconnected_intensity", 0.5) * 100, 0, 100, 5, "%", func(v):
		var intensity = v / 100.0
		config.set_value("highlight_disconnected_intensity", intensity)
		if highlighter_ref:
			highlighter_ref.set_intensity(intensity)
	)


func _add_wire_color_section(parent: Control) -> void:
	var wire_container = VBoxContainer.new()
	wire_container.add_theme_constant_override("separation", 10)
	parent.add_child(wire_container)
	
	# Sub-settings (shown when toggle is on)
	var wire_sub = MarginContainer.new()
	wire_sub.name = "wire_color_sub"
	wire_sub.add_theme_constant_override("margin_left", 20)
	wire_sub.visible = config.get_value("custom_wire_colors", true)
	
	var wire_sub_vbox = VBoxContainer.new()
	wire_sub_vbox.add_theme_constant_override("separation", 6)
	wire_sub.add_child(wire_sub_vbox)
	
	var wc = wire_colors
	var sub_ref = wire_sub
	var self_ref = self
	
	# Main toggle
	ui.add_toggle(wire_container, "Custom Wire Colors", config.get_value("custom_wire_colors", true), func(v):
		config.set_value("custom_wire_colors", v)
		sub_ref.visible = v
		wc.set_enabled(v)
		self_ref._refresh_all_connectors()
	, "Customize the colors of wires by resource type.")
	
	wire_container.add_child(wire_sub)
	
	# Define categories
	var categories = {
		"⚡ Speeds": ["download_speed", "upload_speed", "clock_speed", "gpu_speed", "code_speed", "work_speed"],
		"💰 Resources": ["money", "research", "token", "power", "research_power", "contribution"],
		"🔓 Hacking": ["hack_power", "hack_experience", "virus", "trojan", "infected_computer"],
		"📊 Data Types": ["bool", "char", "int", "float", "bitflag", "bigint", "decimal", "string", "vector"],
		"🧠 AI / Neural": ["ai", "neuron_text", "neuron_image", "neuron_sound", "neuron_video", "neuron_program", "neuron_game"],
		"🚀 Boosts": ["boost_component", "boost_research", "boost_hack", "boost_code", "overclock"],
		"📦 Other": ["heat", "vulnerability", "storage", "corporation_data", "government_data", "litecoin", "bitcoin", "ethereum"]
	}
	
	var configurable = wire_colors.get_configurable_wires()
	
	# Create collapsible sections for each category
	for category_name in categories:
		var resource_ids = categories[category_name]
		_add_wire_category(wire_sub_vbox, category_name, resource_ids, configurable)
	
	# Apply button to refresh all connectors
	var apply_btn = Button.new()
	apply_btn.text = "🔄 Apply Colors"
	apply_btn.tooltip_text = "Refresh all visible wires with new colors"
	apply_btn.theme_type_variation = "TabButton"
	apply_btn.custom_minimum_size = Vector2(0, 45)
	apply_btn.pressed.connect(_refresh_all_connectors)
	wire_sub_vbox.add_child(apply_btn)


func _add_wire_category(parent: Control, category_name: String, resource_ids: Array, all_wires: Dictionary) -> void:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	
	# Content container (collapsible)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.visible = false
	
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 15)
	content_margin.add_child(content)
	
	# Header button to toggle
	var header = Button.new()
	header.text = "▶ " + category_name
	header.theme_type_variation = "TabButton"
	header.custom_minimum_size = Vector2(0, 35)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	var content_ref = content
	header.pressed.connect(func():
		content_ref.visible = !content_ref.visible
		header.text = ("▼ " if content_ref.visible else "▶ ") + category_name
	)
	
	section.add_child(header)
	section.add_child(content_margin)
	
	# Add color pickers for each resource in this category
	for resource_id in resource_ids:
		if all_wires.has(resource_id):
			_add_wire_color_picker(content, all_wires[resource_id], resource_id)


func _add_wire_color_picker(parent: Control, label_text: String, resource_id: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	
	# Custom Color Button using shared picker
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 36)
	
	# Current color state
	var current_col = wire_colors.get_color(resource_id)
	
	# Style the button to show color
	var style = StyleBoxFlat.new()
	style.bg_color = current_col
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	var wc = wire_colors
	var res_id = resource_id
	var self_ref = self
	
	# Open shared picker on press
	btn.pressed.connect(func():
		mod_main._open_color_picker(wc.get_color(res_id), func(new_col):
			# Update storage
			wc.set_color_from_rgb(res_id, new_col)
			# Clear metadata cache to ensure Node Definition panel updates
			if self_ref.palette_controller:
				self_ref.palette_controller.clear_metadata_cache()
			
			# Update button visual
			style.bg_color = new_col
		)
	)
	
	row.add_child(btn)
	
	# Reset button
	var reset_btn = Button.new()
	reset_btn.text = "↺"
	reset_btn.tooltip_text = "Reset to default"
	reset_btn.custom_minimum_size = Vector2(36, 36)
	reset_btn.pressed.connect(func():
		wc.reset_color(res_id)
		if self_ref.palette_controller:
			self_ref.palette_controller.clear_metadata_cache()
		var def_col = wc.get_original_color(res_id)
		style.bg_color = def_col
		self_ref._refresh_all_connectors()
	)
	row.add_child(reset_btn)


func _add_node_limit_slider(parent: Control) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var header := HBoxContainer.new()
	container.add_child(header)
	
	var label := Label.new()
	label.text = "Node Limit"
	label.add_theme_font_size_override("font_size", 32)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	
	_node_limit_value_label = Label.new()
	var current_val = config.get_value("node_limit")
	_node_limit_value_label.text = "∞" if current_val == -1 else str(int(current_val))
	_node_limit_value_label.add_theme_font_size_override("font_size", 32)
	header.add_child(_node_limit_value_label)
	
	# Slider: Use 0-2050 range, where 2050 represents ∞ (-1 internally)
	_node_limit_slider = HSlider.new()
	_node_limit_slider.min_value = 50
	_node_limit_slider.max_value = 2050 # 2050 = ∞
	_node_limit_slider.step = 50
	# Map -1 to 2050 for display
	_node_limit_slider.value = 2050 if current_val == -1 else current_val
	_node_limit_slider.focus_mode = Control.FOCUS_NONE
	
	# Block scroll wheel input when setting is enabled
	var cfg = config
	_node_limit_slider.gui_input.connect(func(event: InputEvent):
		if cfg and cfg.get_value("disable_slider_scroll", false):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_node_limit_slider.accept_event()
	)
	
	var vl = _node_limit_value_label
	_node_limit_slider.value_changed.connect(func(v):
		var actual_val = -1 if v >= 2050 else int(v)
		vl.text = "∞" if actual_val == -1 else str(actual_val)
		config.set_value("node_limit", actual_val)
		Globals.custom_node_limit = actual_val
	)
	container.add_child(_node_limit_slider)


# ==============================================================================
# HELPERS
# ==============================================================================

func _refresh_all_connectors() -> void:
	var tree = mod_main.get_tree()
	# Refresh wire lines (Connector nodes that draw the actual lines)
	var connectors = tree.get_nodes_in_group("connector")
	for connector in connectors:
		# Connector class stores color and has output ResourceContainer
		if connector is Connector:
			# Get the output connector button to read the current color
			var output_res = connector.output
			if output_res:
				var output_connector_btn = output_res.get_node_or_null("OutputConnector")
				if output_connector_btn and output_connector_btn.has_method("get_connector_color"):
					var color_name = output_connector_btn.get_connector_color()
					if Data.connectors.has(color_name):
						connector.color = Color(Data.connectors[color_name].color)
						# Also update the pivot color
						if connector.pivot:
							connector.pivot.self_modulate = connector.color
						# Redraw the wire
						connector.draw_update()
	
	# Refresh connector buttons (the input/output circles on windows)
	var windows = tree.get_nodes_in_group("window")
	for window in windows:
		var buttons = _find_connector_buttons(window)
		for btn in buttons:
			if btn.has_method("update_connector_button"):
				btn.update_connector_button()
	
	Signals.notify.emit("check", "Wire colors refreshed!")


func _find_connector_buttons(node: Node) -> Array:
	var result = []
	if node.has_method("update_connector_button"):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_connector_buttons(child))
	return result


func _apply_extra_glow(enabled: bool) -> void:
	var main = mod_main.get_tree().root.get_node_or_null("Main")
	if !main: return
	
	var env_node = main.find_child("WorldEnvironment", true, false)
	if !env_node or !env_node.environment: return
	
	var env: Environment = env_node.environment
	
	if enabled:
		env.glow_enabled = true
		env.glow_intensity = config.get_value("glow_intensity")
		env.glow_strength = config.get_value("glow_strength")
		env.glow_bloom = config.get_value("glow_bloom")
		env.glow_hdr_threshold = config.get_value("glow_sensitivity")
	else:
		env.glow_enabled = false


func _check_restart_required() -> void:
	if not ui:
		return
	
	var needs_restart := false
	for key in _restart_original_values:
		var original = _restart_original_values[key]
		var current = config.get_value(key, original)
		if current != original:
			needs_restart = true
			break
	
	if needs_restart:
		ui.show_restart_banner()
	else:
		ui.hide_restart_banner()


## Called from mod_main._process to update node count display
func update_node_label() -> void:
	if !_node_info_label or !ui.is_visible(): return
	
	if is_instance_valid(Globals):
		var current = Globals.max_window_count
		var limit = Globals.custom_node_limit if "custom_node_limit" in Globals else -1
		var limit_str = "∞" if limit == -1 else str(limit)
		
		_node_info_label.text = "Nodes: %d / %s" % [current, limit_str]
		
		if limit != -1 and current >= limit:
			_node_info_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			_node_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


# ==============================================================================
# PUBLIC API
# ==============================================================================

## Public method to update node limit from palette
func set_node_limit(value: int) -> void:
	config.set_value("node_limit", value)
	Globals.custom_node_limit = value
	if _node_limit_slider:
		_node_limit_slider.value = 2050 if value == -1 else value
	if _node_limit_value_label:
		_node_limit_value_label.text = "∞" if value == -1 else str(value)


## Public method to update extra glow from palette
func set_extra_glow(enabled: bool) -> void:
	config.set_value("extra_glow", enabled)
	_apply_extra_glow(enabled)
	if _extra_glow_toggle:
		_extra_glow_toggle.button_pressed = enabled
	if _extra_glow_sub:
		_extra_glow_sub.visible = enabled


## Sync a settings toggle UI with its config value (called from palette commands)
func sync_settings_toggle(config_key: String) -> void:
	if _settings_toggles.has(config_key):
		var toggle = _settings_toggles[config_key]
		if toggle and is_instance_valid(toggle):
			toggle.set_pressed_no_signal(config.get_value(config_key, true))


## Add a debug log entry
func add_debug_log(message: String, force: bool = false) -> void:
	# Skip verbose logs if debug mode is off (unless forced)
	if not _debug_mode and not force:
		return
	
	var timestamp = Time.get_time_string_from_system()
	var log_line = "[" + timestamp + "] " + message
	ModLoaderLog.info(message, LOG_NAME)
	if _debug_log_label:
		_debug_log_label.text += log_line + "\n"
		# Keep only last 20 lines
		var lines = _debug_log_label.text.split("\n")
		if lines.size() > 21:
			lines = lines.slice(lines.size() - 21)
			_debug_log_label.text = "\n".join(lines)


## Check if debug mode is enabled
func is_debug_mode() -> bool:
	return _debug_mode
