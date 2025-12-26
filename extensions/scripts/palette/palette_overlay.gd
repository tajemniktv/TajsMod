# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Overlay - Main UI for the command palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteOverlay
extends CanvasLayer

const LOG_NAME = "TajsModded:Palette"

const FuzzySearch = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/fuzzy_search.gd")

# References
var registry # TajsModCommandRegistry
var context # TajsModContextProvider
var palette_config # TajsModPaletteConfig

# UI Elements
var background: ColorRect
var panel: PanelContainer
var search_input: LineEdit
var results_container: VBoxContainer
var results_scroll: ScrollContainer
var breadcrumb_label: Label
var no_results_label: Label

# State
var _is_open: bool = false
var _current_path: Array[String] = [] # Current category navigation path
var _displayed_items: Array[Dictionary] = [] # Currently displayed commands
var _selected_index: int = 0
var _result_items: Array[Control] = [] # UI item references
var _debounce_timer: Timer
var _history_back: Array = [] # Navigation history for back button
var _history_forward: Array = [] # Navigation history for forward button

# Node Picker Mode (for wire-drop feature)
var _picker_mode: bool = false
var _picker_origin_info: Dictionary = {}
var _picker_spawn_position: Vector2 = Vector2.ZERO
var _picker_nodes: Array[Dictionary] = []

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

signal command_executed(command_id: String)
signal node_selected(window_id: String, spawn_pos: Vector2, origin_info: Dictionary)
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


func setup(reg, ctx, config) -> void:
	registry = reg
	context = ctx
	palette_config = config


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
	hbox.add_child(title)
	
	# Category path (if not at home)
	var cat_path = item.get("category_path", [])
	if not cat_path.is_empty() and _current_path.is_empty():
		var path_label = Label.new()
		path_label.text = " > ".join(cat_path)
		path_label.add_theme_font_size_override("font_size", 12)
		path_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		hbox.add_child(path_label)
	
	# Category indicator
	if item.get("is_category", false):
		var arrow = Label.new()
		arrow.text = "→"
		arrow.add_theme_font_size_override("font_size", 18)
		arrow.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
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
	var query = search_input.text.strip_edges()
	
	# Handle picker mode search
	if _picker_mode:
		_filter_picker_nodes(query)
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
