# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Overlay - Main UI for the command palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteOverlay
extends CanvasLayer

const LOG_NAME = "TajsModded:Palette"

const FuzzySearch = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/fuzzy_search.gd")
const Calculator = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/calculator.gd")
const NodeDefinitionPanel = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/node_definition_panel.gd")
const ResourceDefinitionPanel = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/resource_definition_panel.gd")

# References
var registry # TajsModCommandRegistry
var context # TajsModContextProvider
var palette_config # TajsModPaletteConfig
var node_metadata_service # TajsModNodeMetadataService

# UI Elements
var background: ColorRect
var panel: PanelContainer
var search_input: LineEdit
var results_container: VBoxContainer
var results_scroll: ScrollContainer
var breadcrumb_label: Label
var no_results_label: Label
var _node_def_panel: Control # NodeDefinitionPanel instance
var _resource_def_panel: Control # ResourceDefinitionPanel instance

# State
var _is_open: bool = false
var _current_path: Array[String] = [] # Current category navigation path
var _displayed_items: Array[Dictionary] = [] # Currently displayed commands
var _selected_index: int = 0
var _result_items: Array[Control] = [] # UI item references
var _debounce_timer: Timer
var _history_back: Array = [] # Navigation history for back button
var _history_forward: Array = [] # Navigation history for forward button
var _onboarding_hint: Control # Onboarding hint panel

# Definition Mode
var _def_mode: bool = false
var _resource_mode: bool = false

# Node Picker Mode (for wire-drop feature)
var _picker_mode: bool = false
var _picker_origin_info: Dictionary = {}
var _picker_spawn_position: Vector2 = Vector2.ZERO
var _picker_nodes: Array[Dictionary] = []

# Group Picker Mode (for Jump to Group feature)
var _group_picker_mode: bool = false
var _group_picker_groups: Array = [] # Array of group node references

# Note Picker Mode (for Jump to Note feature)
var _note_picker_mode: bool = false
var _note_picker_notes: Array = [] # Array of sticky note references

# Calculator Mode (for inline math evaluation)
var _calc_mode: bool = false
var _calc_result: String = ""
var _calc_error: String = ""
var _calc_history: Array = [] # Array of {"expr": String, "result": String}
const CALC_MAX_HISTORY = 5

# Styling
const PANEL_WIDTH = 600
const PANEL_HEIGHT = 500
const ITEM_HEIGHT = 50
const MAX_VISIBLE_ITEMS = 10

# Colors
const COLOR_BG_DIM = Color(0, 0, 0, 0.6)
const COLOR_SELECTED = Color(0.2, 0.4, 0.6, 0.8)
const COLOR_HOVER = Color(0.15, 0.25, 0.35, 0.5)
const COLOR_BADGE_SAFE = Color(0.3, 0.7, 0.4)
const COLOR_BADGE_OPTIN = Color(0.85, 0.65, 0.2)
const COLOR_BADGE_GAMEPLAY = Color(0.8, 0.3, 0.3)
const COLOR_TEXT_SHADOW = Color(0, 0, 0, 0.8)
const COLOR_TEXT_GLOW = Color(0.4, 0.65, 1.0, 0.5)

signal command_executed(command_id: String)
signal node_selected(window_id: String, spawn_pos: Vector2, origin_info: Dictionary)
signal group_selected(group) # Emitted when a group is selected in group picker mode
signal note_picker_selected(note) # Emitted when a note is selected in note picker mode
signal closed


func _init() -> void:
	layer = 100 # Above most UI
	name = "TajsModPalette"


func _ready() -> void:
	_build_ui()
	_setup_debounce()
	# Ensure palette starts hidden
	_is_open = false
	visible = false


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	
	# Handle mouse back button globally when palette is open
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_XBUTTON1:
			if _resource_mode:
				_on_resource_panel_back()
				get_viewport().set_input_as_handled()
			elif _def_mode:
				# Exit def mode back to search results
				_exit_def_mode()
				get_viewport().set_input_as_handled()
			elif _calc_mode or _picker_mode or _group_picker_mode or _note_picker_mode or not _current_path.is_empty():
				# Exit any special mode or navigate back in category hierarchy
				_go_back()
				get_viewport().set_input_as_handled()


func setup(reg, ctx, config, meta_service = null, wire_colors_ref = null) -> void:
	registry = reg
	context = ctx
	palette_config = config
	node_metadata_service = meta_service
	
	if _node_def_panel and wire_colors_ref:
		_node_def_panel.set_wire_colors(wire_colors_ref)


## Show node definition panel
func show_node_definition(node_id: String) -> void:
	if not node_metadata_service:
		Signals.notify.emit("exclamation", "Metadata service not available")
		return
	
	var details = node_metadata_service.get_node_details(node_id)
	if details.is_empty():
		Signals.notify.emit("exclamation", "Could not load node details")
		return
		
	_def_mode = true
	
	# Hide palette panel, show def panel
	# We hide the whole palette so the def panel (overlay child) is visible clearly
	panel.visible = false
	_node_def_panel.visible = true
	
	_node_def_panel.display_node(details)
	
	# Update UI state
	breadcrumb_label.text = "📘 Definition: " + details.get("name", "Unknown")
	# search_input.editable = false # Not needed if panel is hidden
	
	# Clean up selection
	_selected_index = -1
	_update_selection()


func _on_def_panel_back() -> void:
	_exit_def_mode()


## Enter node browser mode to show all available nodes
func enter_node_browser() -> void:
	search_input.placeholder_text = "Filter nodes..."
	_perform_node_search("")
	Sound.play("click")


func _exit_def_mode() -> void:
	if not _def_mode:
		return
		
	_def_mode = false
	
	# Restore UI
	panel.visible = true
	_node_def_panel.visible = false
	
	search_input.editable = true
	search_input.grab_focus()
	
	# Update breadcrumbs (simplified reset)
	if _picker_mode:
		_update_picker_breadcrumbs()
	elif _group_picker_mode:
		_update_group_picker_breadcrumbs()
	elif _note_picker_mode:
		_update_note_picker_breadcrumbs()
	else:
		_update_breadcrumbs()


## Handle port click from NodeDefinitionPanel - show resource info
func _on_port_clicked(resource_id: String, shape: String, color: String, label: String) -> void:
	# Show resource definition panel
	_node_def_panel.visible = false
	_resource_def_panel.visible = true
	_resource_mode = true
	
	# Pass wire colors if available
	if _node_def_panel.has_method("_wire_colors"):
		_resource_def_panel.set_wire_colors(_node_def_panel._wire_colors)
	
	_resource_def_panel.display_resource(resource_id, shape, color, label)
	
	# Update breadcrumb
	breadcrumb_label.text = "📊 Resource: " + label


## Handle back from ResourceDefinitionPanel - return to NodeDefinitionPanel
func _on_resource_panel_back() -> void:
	_resource_mode = false
	_resource_def_panel.visible = false
	_node_def_panel.visible = true
	
	# Restore def mode breadcrumb
	breadcrumb_label.text = "📘 Definition"


## Handle "Show Nodes with Input" button
func _on_show_inputs(shape: String, color: String) -> void:
	_exit_resource_mode()
	_show_nodes_with_port(shape, color, true)


## Handle "Show Nodes with Output" button
func _on_show_outputs(shape: String, color: String) -> void:
	_exit_resource_mode()
	_show_nodes_with_port(shape, color, false)


func _exit_resource_mode() -> void:
	_resource_mode = false
	_def_mode = false
	_resource_def_panel.visible = false
	_node_def_panel.visible = false
	panel.visible = true


## Show filtered nodes with a specific port type
func _show_nodes_with_port(shape: String, color: String, is_input: bool) -> void:
	# Get compatible nodes from the filter
	var controller = get_parent()
	if controller and controller.has_method("get_node_filter"):
		var filter = controller.get_node_filter()
		if filter:
			var nodes: Array[Dictionary]
			if is_input:
				nodes = filter.get_nodes_with_input(shape, color)
			else:
				nodes = filter.get_nodes_with_output(shape, color)
			
			if nodes.is_empty():
				Signals.notify.emit("exclamation", "No nodes found with this port type")
				return
			
			# Display as picker results
			_display_picker_nodes(nodes)
			breadcrumb_label.text = "🔍 Nodes with %s (%s)" % [shape, "Input" if is_input else "Output"]
			search_input.placeholder_text = "Filter nodes..."
			search_input.grab_focus()
	else:
		Signals.notify.emit("exclamation", "Filter not available")


## Apply glow styling to a label for a polished look
func _apply_text_style(label: Label, use_glow: bool = true) -> void:
	# Glow effect via outline
	if use_glow:
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", COLOR_TEXT_GLOW)

func _build_ui() -> void:
	# Load game's main theme for consistent styling
	var game_theme: Theme = null
	if ResourceLoader.exists("res://themes/main.tres"):
		game_theme = load("res://themes/main.tres")
	
	# Background dim
	background = ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BG_DIM
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.gui_input.connect(_on_background_input)
	add_child(background)
	
	# Main panel
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = - PANEL_WIDTH / 2
	panel.offset_right = PANEL_WIDTH / 2
	panel.offset_top = - PANEL_HEIGHT / 2
	panel.offset_bottom = PANEL_HEIGHT / 2
	
	# Apply game theme for fonts
	if game_theme:
		panel.theme = game_theme
	
	# Apply styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = Color(0.3, 0.5, 0.7, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Header with search
	var header = _create_header()
	vbox.add_child(header)
	
	# Results area
	results_scroll = ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(results_scroll)
	
	results_container = VBoxContainer.new()
	results_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_container.add_theme_constant_override("separation", 2)
	results_scroll.add_child(results_container)
	
	# No results label
	no_results_label = Label.new()
	no_results_label.text = "No results found"
	no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_results_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	no_results_label.add_theme_font_size_override("font_size", 18)
	no_results_label.visible = false
	
	# Node Definition Panel
	_node_def_panel = NodeDefinitionPanel.new()
	_node_def_panel.visible = false
	_node_def_panel.back_requested.connect(_on_def_panel_back)
	_node_def_panel.close_requested.connect(hide_palette)
	_node_def_panel.port_clicked.connect(_on_port_clicked)
	
	# Add node def panel to OVERLAY, not VBOX, so it can be larger than the palette
	_node_def_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 10% margins for nearly fullscreen
	_node_def_panel.anchor_left = 0.1
	_node_def_panel.anchor_top = 0.1
	_node_def_panel.anchor_right = 0.9
	_node_def_panel.anchor_bottom = 0.9
	_node_def_panel.offset_left = 0
	_node_def_panel.offset_top = 0
	_node_def_panel.offset_right = 0
	_node_def_panel.offset_bottom = 0
	
	add_child(_node_def_panel)
	
	# Resource Definition Panel
	_resource_def_panel = ResourceDefinitionPanel.new()
	_resource_def_panel.visible = false
	_resource_def_panel.back_requested.connect(_on_resource_panel_back)
	_resource_def_panel.show_inputs_requested.connect(_on_show_inputs)
	_resource_def_panel.show_outputs_requested.connect(_on_show_outputs)
	
	# Same layout as node def panel
	_resource_def_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_resource_def_panel.anchor_left = 0.1
	_resource_def_panel.anchor_top = 0.1
	_resource_def_panel.anchor_right = 0.9
	_resource_def_panel.anchor_bottom = 0.9
	
	add_child(_resource_def_panel)
	
	# It should share space with results_scroll, so we'll toggle visibility
	# It should share space with results_scroll, so we'll toggle visibility
	
	# Onboarding hint (shown first time)
	_onboarding_hint = _create_onboarding_hint()
	_onboarding_hint.visible = false
	results_container.add_child(_onboarding_hint)
	results_container.add_child(no_results_label)
	
	# Footer with breadcrumbs
	var footer = _create_footer()
	vbox.add_child(footer)


func _create_header() -> Control:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	
	# Search icon
	var icon_label = Label.new()
	icon_label.text = "🔍"
	icon_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(icon_label)
	
	# Search input
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search commands..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.add_theme_font_size_override("font_size", 20)
	search_input.flat = true
	search_input.caret_blink = true
	
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.12, 0.14, 0.18, 0.8)
	input_style.set_corner_radius_all(8)
	input_style.content_margin_left = 12
	input_style.content_margin_right = 12
	input_style.content_margin_top = 8
	input_style.content_margin_bottom = 8
	search_input.add_theme_stylebox_override("normal", input_style)
	
	search_input.text_changed.connect(_on_search_changed)
	search_input.gui_input.connect(_on_search_input)
	hbox.add_child(search_input)
	
	return margin


func _create_footer() -> Control:
	var footer = PanelContainer.new()
	footer.custom_minimum_size = Vector2(0, 40)
	
	var footer_style = StyleBoxFlat.new()
	footer_style.bg_color = Color(0.06, 0.08, 0.1, 0.8)
	footer_style.corner_radius_bottom_left = 10
	footer_style.corner_radius_bottom_right = 10
	footer.add_theme_stylebox_override("panel", footer_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	footer.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	breadcrumb_label = Label.new()
	breadcrumb_label.text = "Home"
	breadcrumb_label.add_theme_font_size_override("font_size", 14)
	breadcrumb_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	breadcrumb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(breadcrumb_label)
	
	# Hint text
	var hint = Label.new()
	hint.text = "↑↓ Navigate • Enter Select • Esc Close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	hbox.add_child(hint)
	
	return footer


func _create_onboarding_hint() -> Control:
	var hint_panel = PanelContainer.new()
	hint_panel.name = "OnboardingHint"
	
	var hint_style = StyleBoxFlat.new()
	hint_style.bg_color = Color(0.15, 0.25, 0.35, 0.95)
	hint_style.border_color = Color(0.4, 0.6, 0.8, 0.8)
	hint_style.set_border_width_all(2)
	hint_style.set_corner_radius_all(8)
	hint_style.content_margin_left = 16
	hint_style.content_margin_right = 16
	hint_style.content_margin_top = 12
	hint_style.content_margin_bottom = 12
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	hint_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "✨ Welcome to the Command Palette!"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_apply_text_style(title, true)
	vbox.add_child(title)
	
	# Hotkey tips
	var tips = [
		"• MMB (Middle Mouse): Open/close palette",
		"• ↑↓: Navigate • Enter: Select • Esc: Close",
		"• Ctrl+F: Toggle favorite on selected command",
		"• Drop a wire on empty canvas → Node Picker!"
	]
	
	for tip_text in tips:
		var tip = Label.new()
		tip.text = tip_text
		tip.add_theme_font_size_override("font_size", 13)
		tip.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		vbox.add_child(tip)
	
	# Got it button
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)
	
	var got_it_btn = Button.new()
	got_it_btn.text = "Got it!"
	got_it_btn.custom_minimum_size = Vector2(100, 32)
	got_it_btn.pressed.connect(_dismiss_onboarding)
	btn_container.add_child(got_it_btn)
	
	return hint_panel


func _dismiss_onboarding() -> void:
	if _onboarding_hint:
		_onboarding_hint.visible = false
	if palette_config:
		palette_config.set_onboarded(true)
	Sound.play("click")


## Show the onboarding hint (called from Help command)
func show_onboarding_hint() -> void:
	if _onboarding_hint:
		_onboarding_hint.visible = true
		# Scroll to make it visible
		await get_tree().process_frame
		results_scroll.ensure_control_visible(_onboarding_hint)


func _setup_debounce() -> void:
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = 0.03 # 30ms debounce
	_debounce_timer.timeout.connect(_perform_search)
	add_child(_debounce_timer)


# ==============================================================================
# Public API
# ==============================================================================

func show_palette() -> void:
	if _is_open:
		return
	
	_is_open = true
	visible = true
	if panel:
		panel.visible = true
	search_input.text = ""
	_selected_index = 0
	_current_path = []
	_history_back.clear()
	_history_forward.clear()
	
	# Refresh context
	if context:
		context.refresh()
	
	# Show home screen
	_show_home_screen()
	_update_breadcrumbs()
	
	# Show onboarding hint on first open
	if palette_config and not palette_config.is_onboarded():
		if _onboarding_hint:
			_onboarding_hint.visible = true
	else:
		if _onboarding_hint:
			_onboarding_hint.visible = false
	
	# Focus search input
	search_input.grab_focus()
	
	# Play sound
	if Engine.has_singleton("Sound"):
		Sound.play("menu_open")


func hide_palette() -> void:
	_is_open = false
	visible = false
	
	# Reset picker mode state
	_picker_mode = false
	_picker_origin_info.clear()
	_picker_nodes.clear()
	
	# Reset group picker mode state
	_group_picker_mode = false
	_group_picker_groups.clear()
	
	# Reset note picker mode state
	_note_picker_mode = false
	_note_picker_notes.clear()
	
	# Reset calculator mode state
	_calc_mode = false
	_calc_result = ""
	_calc_error = ""
	
	# Reset def mode
	_def_mode = false
	if _node_def_panel:
		_node_def_panel.visible = false
	
	# Reset resource mode
	_resource_mode = false
	if _resource_def_panel:
		_resource_def_panel.visible = false
	
	if results_scroll:
		results_scroll.visible = true
	if search_input:
		search_input.editable = true
	
	closed.emit()
	
	if Engine.has_singleton("Sound"):
		Sound.play("menu_close")


func toggle_palette() -> void:
	if _is_open:
		hide_palette()
	else:
		show_palette()


func is_open() -> bool:
	return _is_open


## Show the node picker for wire-drop feature
## Displays compatible nodes that can connect to the origin pin
func show_node_picker(compatible_nodes: Array[Dictionary], origin_info: Dictionary, spawn_position: Vector2) -> void:
	if _is_open:
		hide_palette()
	
	_picker_mode = true
	_picker_origin_info = origin_info.duplicate() # Duplicate to ensure we have our own copy
	_picker_spawn_position = spawn_position
	_picker_nodes = compatible_nodes.duplicate()
	
	_is_open = true
	visible = true
	search_input.text = ""
	search_input.placeholder_text = "Search nodes to add..."
	_selected_index = 0
	_current_path = []
	_history_back.clear()
	_history_forward.clear()
	
	# Display compatible nodes
	_display_picker_nodes(_picker_nodes)
	_update_picker_breadcrumbs()
	
	# Focus search input
	search_input.grab_focus()
	
	Sound.play("menu_open")


## Display nodes in picker mode
func _display_picker_nodes(nodes: Array[Dictionary]) -> void:
	# Clear existing items
	for child in _result_items:
		child.queue_free()
	_result_items.clear()
	
	_displayed_items.clear()
	_selected_index = 0
	
	# Convert node data to display format
	for node_data in nodes:
		var item := {
			"id": node_data.id,
			"title": node_data.get("name", node_data.id),
			"hint": node_data.get("description", ""),
			"category_path": [node_data.get("category", ""), node_data.get("sub_category", "")],
			"icon_path": "res://textures/icons/" + node_data.get("icon", "cog") + ".png",
			"is_category": false,
			"badge": "SAFE",
			"_node_id": node_data.id
		}
		_displayed_items.append(item)
	
	no_results_label.visible = _displayed_items.is_empty()
	
	for i in range(_displayed_items.size()):
		var item = _displayed_items[i]
		var row = _create_result_row(item, i)
		results_container.add_child(row)
		_result_items.append(row)
	
	_update_selection()


## Update breadcrumbs for picker mode
func _update_picker_breadcrumbs() -> void:
	var origin_desc := ""
	if _picker_origin_info.get("is_output", true):
		origin_desc = "connecting output → input"
	else:
		origin_desc = "connecting input ← output"
	breadcrumb_label.text = "🔌 Add Node (%s)" % origin_desc


## Filter picker nodes by search query
func _filter_picker_nodes(query: String) -> void:
	if query.is_empty():
		_display_picker_nodes(_picker_nodes)
		return
	
	var filtered: Array[Dictionary] = []
	var query_lower := query.to_lower()
	
	for node in _picker_nodes:
		var name_lower: String = node.get("name", "").to_lower()
		var desc_lower: String = node.get("description", "").to_lower()
		var cat_lower: String = node.get("category", "").to_lower()
		
		if query_lower in name_lower or query_lower in desc_lower or query_lower in cat_lower:
			filtered.append(node)
	
	_display_picker_nodes(filtered)


# ==============================================================================
# Group Picker Mode (for Jump to Group feature)
# ==============================================================================

## Show the group picker for Jump to Group feature
## Displays all groups on the desktop for quick navigation
func show_group_picker(groups: Array, goto_group_manager) -> void:
	# Reset picker mode if active (not group picker - that's handled separately)
	_picker_mode = false
	_picker_origin_info.clear()
	_picker_nodes.clear()
	
	_group_picker_mode = true
	_group_picker_groups = groups.duplicate()
	
	# If already open, just transition; if not, open
	if not _is_open:
		_is_open = true
		visible = true
	
	search_input.text = ""
	search_input.placeholder_text = "Search groups to jump to..."
	_selected_index = 0
	_current_path = []
	_history_back.clear()
	_history_forward.clear()
	
	# Store the manager reference for later use
	set_meta("goto_group_manager", goto_group_manager)
	
	# Display groups
	_display_group_picker(_group_picker_groups)
	_update_group_picker_breadcrumbs()
	
	# Focus search input
	search_input.grab_focus()
	
	Sound.play("menu_open")


## Display groups in the group picker mode
func _display_group_picker(groups: Array) -> void:
	# Clear existing items
	for child in _result_items:
		child.queue_free()
	_result_items.clear()
	
	_displayed_items.clear()
	_selected_index = 0
	
	var goto_manager = get_meta("goto_group_manager", null)
	
	# Convert group data to display format
	for group in groups:
		if not is_instance_valid(group):
			continue
		
		var group_name := "Group"
		if goto_manager and goto_manager.has_method("get_group_name"):
			group_name = goto_manager.get_group_name(group)
		elif group.has_method("get_window_name"):
			group_name = group.get_window_name()
		elif group.get("custom_name") and not group.custom_name.is_empty():
			group_name = group.custom_name
		
		var icon_path := "res://textures/icons/window.png"
		if goto_manager and goto_manager.has_method("get_group_icon_path"):
			icon_path = goto_manager.get_group_icon_path(group)
		
		var item := {
			"id": str(group.get_instance_id()),
			"title": group_name,
			"hint": "",
			"category_path": [],
			"icon_path": icon_path,
			"is_category": false,
			"badge": "SAFE",
			"_group_ref": group
		}
		_displayed_items.append(item)
	
	no_results_label.visible = _displayed_items.is_empty()
	if _displayed_items.is_empty():
		no_results_label.text = "No groups found on desktop"
	
	for i in range(_displayed_items.size()):
		var item = _displayed_items[i]
		var row = _create_result_row(item, i)
		results_container.add_child(row)
		_result_items.append(row)
	
	_update_selection()


## Update breadcrumbs for group picker mode
func _update_group_picker_breadcrumbs() -> void:
	breadcrumb_label.text = "📍 Jump to Group (%d groups)" % _group_picker_groups.size()


## Filter group picker by search query
func _filter_group_picker(query: String) -> void:
	if query.is_empty():
		_display_group_picker(_group_picker_groups)
		return
	
	var filtered: Array = []
	var query_lower := query.to_lower()
	var goto_manager = get_meta("goto_group_manager", null)
	
	for group in _group_picker_groups:
		if not is_instance_valid(group):
			continue
		
		var group_name := ""
		if goto_manager and goto_manager.has_method("get_group_name"):
			group_name = goto_manager.get_group_name(group)
		elif group.has_method("get_window_name"):
			group_name = group.get_window_name()
		elif group.get("custom_name") and not group.custom_name.is_empty():
			group_name = group.custom_name
		
		if query_lower in group_name.to_lower():
			filtered.append(group)
	
	_display_group_picker(filtered)


# ==============================================================================
# Note Picker Mode (for Jump to Note feature)
# ==============================================================================

## Show the note picker for Jump to Note feature
func show_note_picker(notes: Array, sticky_manager) -> void:
	# Reset other modes
	_picker_mode = false
	_picker_origin_info.clear()
	_picker_nodes.clear()
	_group_picker_mode = false
	_group_picker_groups.clear()
	
	_note_picker_mode = true
	_note_picker_notes = notes.duplicate()
	
	# If already open, just transition; if not, open
	if not _is_open:
		_is_open = true
		visible = true
	
	search_input.text = ""
	search_input.placeholder_text = "Search notes to jump to..."
	_selected_index = 0
	_current_path = []
	_history_back.clear()
	_history_forward.clear()
	
	# Store the manager reference for later use
	set_meta("sticky_note_manager", sticky_manager)
	
	# Display notes
	_display_note_picker(_note_picker_notes)
	_update_note_picker_breadcrumbs()
	
	# Focus search input
	search_input.grab_focus()
	
	Sound.play("menu_open")

## Display notes in the note picker mode
func _display_note_picker(notes: Array) -> void:
	# Clear existing items
	for child in _result_items:
		child.queue_free()
	_result_items.clear()
	
	_displayed_items.clear()
	_selected_index = 0
	
	# Convert note data to display format
	for note in notes:
		if not is_instance_valid(note):
			continue
		
		var title = note.title_text if "title_text" in note else "Note"
		var body = note.body_text if "body_text" in note else ""
		
		# Truncate body for hint
		var hint = body.replace("\n", " ").substr(0, 50)
		if body.length() > 50: hint += "..."
		
		var item := {
			"id": str(note.get_instance_id()),
			"title": title,
			"hint": hint,
			"category_path": [],
			"icon_path": "res://textures/icons/star.png",
			"is_category": false,
			"badge": "SAFE",
			"_note_ref": note
		}
		_displayed_items.append(item)
	
	no_results_label.visible = _displayed_items.is_empty()
	if _displayed_items.is_empty():
		no_results_label.text = "No notes found on desktop"
	
	for i in range(_displayed_items.size()):
		var item = _displayed_items[i]
		var row = _create_result_row(item, i)
		results_container.add_child(row)
		_result_items.append(row)
	
	_update_selection()


## Update breadcrumbs for note picker mode
func _update_note_picker_breadcrumbs() -> void:
	breadcrumb_label.text = "📍 Jump to Note (%d notes)" % _note_picker_notes.size()


## Filter note picker by search query
func _filter_note_picker(query: String) -> void:
	if query.is_empty():
		_display_note_picker(_note_picker_notes)
		return
	
	var filtered: Array = []
	var query_lower := query.to_lower()
	
	for note in _note_picker_notes:
		if not is_instance_valid(note):
			continue
		
		var title: String = note.title_text if "title_text" in note else ""
		var body: String = note.body_text if "body_text" in note else ""
		
		if query_lower in title.to_lower() or query_lower in body.to_lower():
			filtered.append(note)
	
	_display_note_picker(filtered)


# ==============================================================================
# Calculator Mode (for inline math evaluation)
# ==============================================================================

## Display calculator result or error
func _display_calculator_result(expression: String) -> void:
	# Clear existing items
	for child in _result_items:
		child.queue_free()
	_result_items.clear()
	
	_displayed_items.clear()
	_selected_index = 0
	
	# Update breadcrumbs for calculator mode
	breadcrumb_label.text = "🧮 Calculator"
	
	var item: Dictionary
	var items_to_display: Array[Dictionary] = []
	
	if expression.is_empty():
		# Show hint for empty expression
		item = {
			"id": "_calc_hint",
			"title": "Type an expression",
			"hint": "e.g. = 2+2, = sqrt(144), = pi * 2^3",
			"icon_path": "res://textures/icons/info.png",
			"is_category": false,
			"badge": "HINT",
			"_is_calc_result": false
		}
		items_to_display.append(item)
		_calc_result = ""
		_calc_error = ""
		
		# Add recent expressions from history
		for i in range(_calc_history.size()):
			var hist = _calc_history[i]
			var hist_item = {
				"id": "_calc_history_%d" % i,
				"title": hist.expr,
				"hint": "= " + hist.result,
				"icon_path": "res://textures/icons/time.png",
				"is_category": false,
				"badge": "RECENT",
				"_is_calc_result": false,
				"_is_calc_history": true,
				"_calc_expr": hist.expr
			}
			items_to_display.append(hist_item)
	else:
		# Evaluate expression
		var result = Calculator.evaluate(expression)
		
		if result.success:
			_calc_result = Calculator.format_result(result.value)
			_calc_error = ""
			item = {
				"id": "_calc_result",
				"title": "Result: " + _calc_result,
				"hint": "Enter = copy to clipboard",
				"icon_path": "res://textures/icons/check.png",
				"is_category": false,
				"badge": "SAFE",
				"_is_calc_result": true,
				"_calc_expr": expression
			}
		else:
			_calc_result = ""
			_calc_error = result.error
			item = {
				"id": "_calc_error",
				"title": "Invalid expression",
				"hint": result.error,
				"icon_path": "res://textures/icons/exclamation.png",
				"is_category": false,
				"badge": "ERROR",
				"_is_calc_result": false
			}
		items_to_display.append(item)
	
	for display_item in items_to_display:
		_displayed_items.append(display_item)
	no_results_label.visible = false
	
	for i in range(items_to_display.size()):
		var display_item = items_to_display[i]
		var row = _create_calculator_result_row(display_item, i)
		results_container.add_child(row)
		_result_items.append(row)
	
	_update_selection()


## Create a result row specifically for calculator mode with custom styling
func _create_calculator_result_row(item: Dictionary, index: int) -> Control:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ITEM_HEIGHT + 10)
	
	var row_style = StyleBoxFlat.new()
	
	# Different styling based on result type
	if item.get("_is_calc_result", false):
		row_style.bg_color = Color(0.1, 0.25, 0.15, 0.8) # Green tint for success
	elif item.badge == "ERROR":
		row_style.bg_color = Color(0.25, 0.1, 0.1, 0.8) # Red tint for error
	else:
		row_style.bg_color = Color(0.1, 0.12, 0.16, 0.5) # Default
	
	row_style.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel", row_style)
	
	row.mouse_entered.connect(func(): _on_item_hover(index))
	row.gui_input.connect(func(event): _on_item_click(event, index))
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)
	
	# Icon
	var icon_path = item.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon = TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)
	
	# Title (Result value)
	var title = Label.new()
	title.text = item.get("title", "")
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if item.get("_is_calc_result", false):
		title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5)) # Green for success
	elif item.badge == "ERROR":
		title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4)) # Red for error
	
	_apply_text_style(title, true)
	hbox.add_child(title)
	
	# Hint (action or error message)
	var hint = Label.new()
	hint.text = item.get("hint", "")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vbox.add_child(hint)
	
	return row


# ==============================================================================
# Navigation & Display
# ==============================================================================

func _show_home_screen() -> void:
	var items: Array[Dictionary] = []
	
	# Show favorites first (if any and query empty)
	if palette_config:
		var favorites = palette_config.get_favorites()
		for fav_id in favorites:
			var cmd = registry.get_command(fav_id)
			if not cmd.is_empty() and _is_command_visible(cmd):
				cmd = cmd.duplicate()
				cmd["_is_favorite"] = true
				items.append(cmd)
	
	# Show recents (if any)
	if palette_config and items.size() < 5:
		var recents = palette_config.get_recents()
		for recent_id in recents:
			# Skip if already in favorites
			var already_shown = false
			for item in items:
				if item["id"] == recent_id:
					already_shown = true
					break
			if already_shown:
				continue
			
			var cmd = registry.get_command(recent_id)
			if not cmd.is_empty() and _is_command_visible(cmd):
				cmd = cmd.duplicate()
				cmd["_is_recent"] = true
				items.append(cmd)
				if items.size() >= 5:
					break
	
	# Add root categories
	var root_items = registry.get_root_items()
	for item in root_items:
		if _is_command_visible(item):
			var already_shown = false
			for existing in items:
				if existing["id"] == item["id"]:
					already_shown = true
					break
			if not already_shown:
				items.append(item)
	
	_display_items(items)


func _show_category(path: Array[String]) -> void:
	_current_path = path.duplicate()
	_update_breadcrumbs()
	
	var items = registry.get_commands_in_category(path)
	var visible_items: Array[Dictionary] = []
	
	for item in items:
		if _is_command_visible(item):
			visible_items.append(item)
	
	_display_items(visible_items)


func _is_command_visible(cmd: Dictionary) -> bool:
	# Check tools visibility
	var badge = cmd.get("badge", "SAFE")
	if badge in ["OPT-IN", "GAMEPLAY"]:
		if context and not context.are_tools_enabled():
			return false
	
	# Check can_run
	var can_run_func = cmd.get("can_run", Callable())
	if can_run_func.is_valid() and context:
		return can_run_func.call(context)
	
	return true


func _display_items(items: Array[Dictionary]) -> void:
	# Clear existing items
	for child in _result_items:
		child.queue_free()
	_result_items.clear()
	
	_displayed_items = items
	_selected_index = 0
	
	no_results_label.visible = items.is_empty()
	
	for i in range(items.size()):
		var item = items[i]
		var row = _create_result_row(item, i)
		results_container.add_child(row)
		_result_items.append(row)
	
	_update_selection()


func _create_result_row(item: Dictionary, index: int) -> Control:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.1, 0.12, 0.16, 0.3)
	row_style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", row_style)
	
	row.mouse_entered.connect(func(): _on_item_hover(index))
	row.gui_input.connect(func(event): _on_item_click(event, index))
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	row.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	
	# Favorite indicator
	if item.get("_is_favorite", false):
		var star = Label.new()
		star.text = "★"
		star.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		star.add_theme_font_size_override("font_size", 16)
		hbox.add_child(star)
	elif item.get("_is_recent", false):
		var clock = Label.new()
		clock.text = "⏱"
		clock.add_theme_font_size_override("font_size", 14)
		clock.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		hbox.add_child(clock)
	
	# Icon
	var icon_path = item.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon = TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)
	
	# Title - support dynamic titles via get_title callable
	var title = Label.new()
	var title_func = item.get("get_title", Callable())
	if title_func.is_valid():
		title.text = title_func.call()
	else:
		title.text = item.get("title", "Unknown")
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_text_style(title, true)
	hbox.add_child(title)
	
	# Category path (if not at home)
	var cat_path = item.get("category_path", [])
	if not cat_path.is_empty() and _current_path.is_empty():
		var path_label = Label.new()
		path_label.text = " > ".join(cat_path)
		path_label.add_theme_font_size_override("font_size", 12)
		path_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		_apply_text_style(path_label, false) # Shadow only, no glow
		hbox.add_child(path_label)
	
	# Category indicator
	if item.get("is_category", false):
		var arrow = Label.new()
		arrow.text = "→"
		arrow.add_theme_font_size_override("font_size", 18)
		arrow.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		_apply_text_style(arrow, true)
		hbox.add_child(arrow)
	else:
		# Badge
		var badge_text = item.get("badge", "SAFE")
		if badge_text != "SAFE" or true: # Always show badge for clarity
			var badge = Label.new()
			badge.text = "[%s]" % badge_text
			badge.add_theme_font_size_override("font_size", 12)
			
			match badge_text:
				"SAFE":
					badge.add_theme_color_override("font_color", COLOR_BADGE_SAFE)
				"OPT-IN":
					badge.add_theme_color_override("font_color", COLOR_BADGE_OPTIN)
				"GAMEPLAY":
					badge.add_theme_color_override("font_color", COLOR_BADGE_GAMEPLAY)
			
			_apply_text_style(badge, false) # Shadow only
			hbox.add_child(badge)
	
	return row


func _update_selection() -> void:
	for i in range(_result_items.size()):
		var row = _result_items[i]
		var style = row.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		
		if i == _selected_index:
			style.bg_color = COLOR_SELECTED
			style.border_color = Color(0.4, 0.6, 0.8, 0.6)
			style.set_border_width_all(1)
		else:
			style.bg_color = Color(0.1, 0.12, 0.16, 0.3)
			style.set_border_width_all(0)
		
		row.add_theme_stylebox_override("panel", style)
	
	# Scroll to selected item
	if _selected_index >= 0 and _selected_index < _result_items.size():
		var item = _result_items[_selected_index]
		# Ensure item is visible in scroll container
		await get_tree().process_frame
		results_scroll.ensure_control_visible(item)


func _update_breadcrumbs() -> void:
	if _current_path.is_empty():
		breadcrumb_label.text = "🏠 Home"
	else:
		breadcrumb_label.text = "🏠 Home > " + " > ".join(_current_path)


# ==============================================================================
# Search
# ==============================================================================

func _on_search_changed(new_text: String) -> void:
	_debounce_timer.stop()
	_debounce_timer.start()


func _perform_search() -> void:
	var raw_query = search_input.text
	var query = raw_query.strip_edges()
	
	# Handle picker mode search
	if _picker_mode:
		_filter_picker_nodes(query)
		return
	
	# Handle group picker mode search
	if _group_picker_mode:
		_filter_group_picker(query)
		return
		
	# Handle note picker mode search
	if _note_picker_mode:
		_filter_note_picker(query)
		return
	
	# Check for calculator mode (= or calc prefix)
	var calc_expression = ""
	if query.begins_with("="):
		calc_expression = query.substr(1).strip_edges()
		_calc_mode = true
	elif query.to_lower().begins_with("calc "):
		calc_expression = query.substr(5).strip_edges()
		_calc_mode = true
	else:
		_calc_mode = false
	
	# Check for node definition mode (def/nodeinfo prefix)
	# WE USE RAW_QUERY HERE to distinguish "def" from "def "
	if raw_query.to_lower().begins_with("def ") or query.begins_with("? ") or query.to_lower().begins_with("nodeinfo "):
		var search_term = ""
		if raw_query.to_lower().begins_with("def "): search_term = raw_query.substr(4)
		elif query.begins_with("? "): search_term = query.substr(2)
		elif query.to_lower().begins_with("nodeinfo "): search_term = query.substr(9)
		
		_perform_node_search(search_term.strip_edges())
		return

	# Handle calculator mode
	if _calc_mode:
		_display_calculator_result(calc_expression)
		return
	
	if query.is_empty():
		if _current_path.is_empty():
			_show_home_screen()
		else:
			_show_category(_current_path)
		return
	
	# Perform fuzzy search
	var all_commands = registry.get_all_executable_commands()
	var results = FuzzySearch.search(query, all_commands, context, MAX_VISIBLE_ITEMS)
	
	var items: Array[Dictionary] = []
	for result in results:
		items.append(result["command"])
	
	_display_items(items)


# ==============================================================================
# Input Handling
# ==============================================================================

func _on_search_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	match event.keycode:
		KEY_ESCAPE:
			hide_palette()
			get_viewport().set_input_as_handled()
		
		KEY_ENTER, KEY_KP_ENTER:
			_execute_selected()
			get_viewport().set_input_as_handled()
		
		KEY_UP:
			_select_previous()
			get_viewport().set_input_as_handled()
		
		KEY_DOWN:
			_select_next()
			get_viewport().set_input_as_handled()
		
		KEY_TAB:
			if not event.shift_pressed:
				_enter_category()
				get_viewport().set_input_as_handled()
		
		KEY_RIGHT:
			_enter_category()
			get_viewport().set_input_as_handled()
		
		KEY_LEFT, KEY_BACKSPACE:
			if search_input.text.is_empty():
				_go_back()
				get_viewport().set_input_as_handled()
		
		KEY_F:
			if event.ctrl_pressed:
				_toggle_favorite_selected()
				get_viewport().set_input_as_handled()
		
		KEY_A:
			if event.ctrl_pressed:
				# Select all text in search field (not nodes on desktop)
				search_input.select_all()
				get_viewport().set_input_as_handled()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				hide_palette()
			MOUSE_BUTTON_XBUTTON1: # Mouse back button
				_go_back()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_XBUTTON2: # Mouse forward button
				_enter_category()
				get_viewport().set_input_as_handled()


func _on_item_hover(index: int) -> void:
	_selected_index = index
	_update_selection()


func _on_item_click(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_index = index
		_execute_selected()


func _select_previous() -> void:
	if _displayed_items.is_empty():
		return
	_selected_index = max(0, _selected_index - 1)
	_update_selection()


func _select_next() -> void:
	if _displayed_items.is_empty():
		return
	_selected_index = min(_displayed_items.size() - 1, _selected_index + 1)
	_update_selection()


func _execute_selected() -> void:
	if _selected_index < 0 or _selected_index >= _displayed_items.size():
		return
	
	var item = _displayed_items[_selected_index]
	
	# Handle picker mode separately
	if _picker_mode:
		_execute_picker_selection(item)
		return
	
	# Handle group picker mode
	if _group_picker_mode:
		_execute_group_selection(item)
		return
		
	# Handle note picker mode
	if _note_picker_mode:
		_execute_note_picker_selection(item)
		return
	
	# Handle calculator mode
	if _calc_mode:
		_execute_calculator_action(item)
		return
	
	# Handle node def results
	if item.get("_is_node_def_result", false):
		_execute_node_def_selection(item)
		return
	
	# If it's a category, enter it
	if item.get("is_category", false):
		_enter_category()
		return
	
	# Execute command
	var id = item.get("id", "")
	if registry.run(id, context):
		command_executed.emit(id)
		
		# Add to recents
		if palette_config:
			palette_config.add_recent(id)
		
		# Close unless keep_open is set
		if not item.get("keep_open", false):
			hide_palette()
		
		Sound.play("click")


## Execute a picker mode selection (spawn node from wire drop)
func _execute_picker_selection(item: Dictionary) -> void:
	var node_id: String = item.get("_node_id", item.get("id", ""))
	
	if node_id.is_empty():
		return
	
	# Emit signal for controller to handle spawning
	# IMPORTANT: Pass a duplicate because hide_palette() clears _picker_origin_info
	# and spawn_and_connect uses await, so the dictionary would be cleared before use
	node_selected.emit(node_id, _picker_spawn_position, _picker_origin_info.duplicate())
	
	Sound.play("click")
	hide_palette()


## Execute a group picker selection (navigate to group)
func _execute_group_selection(item: Dictionary) -> void:
	var group = item.get("_group_ref", null)
	
	if not is_instance_valid(group):
		Signals.notify.emit("exclamation", "Group no longer exists")
		hide_palette()
		return
	
	# Emit signal for controller/caller to handle navigation
	group_selected.emit(group)
	
	Sound.play("click")
	hide_palette()


## Execute a note picker selection (navigate to note)
func _execute_note_picker_selection(item: Dictionary) -> void:
	var note = item.get("_note_ref", null)
	
	if not is_instance_valid(note):
		Signals.notify.emit("exclamation", "Note no longer exists")
		hide_palette()
		return
	
	# Emit signal for controller/caller to handle navigation
	note_picker_selected.emit(note)
	
	Sound.play("click")
	hide_palette()


## Execute a calculator action (copy result to clipboard)
func _execute_calculator_action(item: Dictionary) -> void:
	# Handle history item click - fill in the expression
	if item.get("_is_calc_history", false):
		var expr = item.get("_calc_expr", "")
		if not expr.is_empty():
			search_input.text = "= " + expr
			search_input.caret_column = search_input.text.length()
			_perform_search()
			Sound.play("click")
		return
	
	# Only copy if we have a valid result
	if not item.get("_is_calc_result", false) or _calc_result.is_empty():
		# Can't copy hint or error
		Sound.play("error")
		return
	
	# Add to history (most recent first)
	var expr = item.get("_calc_expr", "")
	if not expr.is_empty():
		# Remove duplicate if exists
		for i in range(_calc_history.size() - 1, -1, -1):
			if _calc_history[i].expr == expr:
				_calc_history.remove_at(i)
		
		# Add to front
		_calc_history.insert(0, {"expr": expr, "result": _calc_result})
		
		# Limit history size
		while _calc_history.size() > CALC_MAX_HISTORY:
			_calc_history.pop_back()
	
	# Copy to clipboard
	DisplayServer.clipboard_set(_calc_result)
	
	# Show notification
	Signals.notify.emit("check", "Copied: " + _calc_result)
	
	Sound.play("click")
	hide_palette()


## Perform search for node definitions
func _perform_node_search(query: String) -> void:
	if not node_metadata_service:
		# Show error item
		var items: Array[Dictionary] = []
		items.append({
			"id": "_node_def_error",
			"title": "Service Not Initialized",
			"hint": "Please restart the game to use this feature.",
			"icon_path": "res://textures/icons/exclamation.png",
			"is_category": false,
			"badge": "ERROR",
			"_is_node_def_result": true,
			"_node_id": ""
		})
		_display_items(items)
		breadcrumb_label.text = "📘 Node Definitions: Error"
		return
		
	var nodes = node_metadata_service.find_nodes(query)
	
	var items: Array[Dictionary] = []
	
	if nodes.is_empty():
		# Empty state or no results
		_displayed_items.clear()
		# Use default "no results" label
	
	for node in nodes:
		var item = {
			"id": node.id,
			"title": node.name,
			"hint": node.get("description", ""),
			"category_path": [node.get("category", "")],
			"icon_path": "res://textures/icons/" + node.get("icon", "cog") + ".png",
			"is_category": false,
			"badge": "INFO",
			"_is_node_def_result": true,
			"_node_id": node.id
		}
		items.append(item)
	
	_display_items(items)
	
	# Force update breadcrumb to show mode
	if query.is_empty():
		breadcrumb_label.text = "📘 Node Definitions (Type to filter)"
	else:
		breadcrumb_label.text = "📘 Node Definitions: " + query


## Execute a node definition selection
func _execute_node_def_selection(item: Dictionary) -> void:
	# Handle error item
	if item.get("id", "") == "_node_def_error":
		Signals.notify.emit("exclamation", "Restart Required")
		Sound.play("error")
		return

	var node_id = item.get("_node_id", "")
	if not node_id.is_empty():
		show_node_definition(node_id)
		Sound.play("click")


func _enter_category() -> void:
	if _selected_index < 0 or _selected_index >= _displayed_items.size():
		return
	
	var item = _displayed_items[_selected_index]
	
	if item.get("is_category", false):
		# Save current path to back history
		_history_back.append(_current_path.duplicate())
		_history_forward.clear() # Clear forward history when navigating
		
		var new_path = _current_path.duplicate()
		new_path.append(item.get("title", ""))
		_show_category(new_path)
		search_input.text = ""
		Sound.play("click")


func _go_back() -> void:
	# Handle special modes - exit back to normal mode
	if _calc_mode or _picker_mode or _group_picker_mode or _note_picker_mode:
		_calc_mode = false
		_picker_mode = false
		_picker_origin_info.clear()
		_picker_nodes.clear()
		_group_picker_mode = false
		_group_picker_groups.clear()
		_note_picker_mode = false
		_note_picker_notes.clear()
		_current_path = []
		search_input.text = ""
		search_input.placeholder_text = "Search commands..."
		_show_home_screen()
		_update_breadcrumbs()
		Sound.play("click")
		return
	
	if _history_back.is_empty():
		# If no history, go up one level in category path
		if _current_path.is_empty():
			return
		_history_forward.append(_current_path.duplicate())
		_current_path.pop_back()
	else:
		# Use history
		_history_forward.append(_current_path.duplicate())
		_current_path = _history_back.pop_back()
	
	search_input.text = ""
	
	if _current_path.is_empty():
		_show_home_screen()
	else:
		_show_category(_current_path)
	
	_update_breadcrumbs()
	Sound.play("click")


func _go_forward() -> void:
	if _history_forward.is_empty():
		return
	
	# Save current path to back history
	_history_back.append(_current_path.duplicate())
	_current_path = _history_forward.pop_back()
	
	search_input.text = ""
	
	if _current_path.is_empty():
		_show_home_screen()
	else:
		_show_category(_current_path)
	
	_update_breadcrumbs()
	Sound.play("click")


func _toggle_favorite_selected() -> void:
	if _selected_index < 0 or _selected_index >= _displayed_items.size():
		return
	
	var item = _displayed_items[_selected_index]
	if item.get("is_category", false):
		return # Can't favorite categories
	
	var id = item.get("id", "")
	if palette_config:
		var is_now_fav = palette_config.toggle_favorite(id)
		Signals.notify.emit("check" if is_now_fav else "exclamation",
			"Added to favorites" if is_now_fav else "Removed from favorites")
		
		# Refresh display
		if search_input.text.is_empty():
			_show_home_screen()
