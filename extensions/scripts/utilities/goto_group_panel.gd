# ==============================================================================
# Taj's Mod - Upload Labs
# Go To Group Panel - UI for navigating to Node Groups
# Author: TajemnikTV
# ==============================================================================
extends Control

const LOG_NAME = "TajsModded:GotoGroupPanel"

# Manager reference
var manager = null

# UI components
var toggle_btn: Button = null
var popup_panel: PanelContainer = null
var scroll_container: ScrollContainer = null
var groups_container: VBoxContainer = null

# State
var is_popup_open: bool = false


func _ready() -> void:
	_build_ui()
	
	# Initially hide popup
	if popup_panel:
		popup_panel.visible = false


func setup(goto_manager) -> void:
	manager = goto_manager
	# Note: We intentionally don't connect to groups_changed signal
	# since the popup is closed when changes can happen


func _build_ui() -> void:
	# Main container - positioned in bottom-left area
	name = "GotoGroupPanel"
	
	# Create a horizontal container to hold the button
	var hbox = HBoxContainer.new()
	hbox.name = "GotoContainer"
	add_child(hbox)
	
	# Toggle button - opens the popup
	toggle_btn = Button.new()
	toggle_btn.name = "GotoGroupButton"
	toggle_btn.custom_minimum_size = Vector2(60, 60)
	toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.theme_type_variation = "ButtonMenu"
	toggle_btn.icon = load("res://textures/icons/crosshair.png")
	toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle_btn.expand_icon = true
	toggle_btn.tooltip_text = "Go To Node Group"
	toggle_btn.add_theme_constant_override("icon_max_width", 36)
	toggle_btn.pressed.connect(_on_toggle_pressed)
	hbox.add_child(toggle_btn)
	
	# Popup panel - appears above the button
	popup_panel = PanelContainer.new()
	popup_panel.name = "GotoPopup"
	popup_panel.visible = false
	popup_panel.custom_minimum_size = Vector2(280, 0)
	
	# Style the popup
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	panel_style.border_color = Color(0.3, 0.35, 0.5, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(8)
	popup_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(popup_panel)
	
	# Scroll container for groups list
	scroll_container = ScrollContainer.new()
	scroll_container.name = "GroupsScroll"
	scroll_container.custom_minimum_size = Vector2(260, 60)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	popup_panel.add_child(scroll_container)
	
	# Groups container (vertical list)
	groups_container = VBoxContainer.new()
	groups_container.name = "GroupsList"
	groups_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups_container.add_theme_constant_override("separation", 4)
	scroll_container.add_child(groups_container)


func _process(delta: float) -> void:
	# Close popup if ESC is pressed
	if is_popup_open and Input.is_action_just_pressed("ui_cancel"):
		_close_popup()


func _input(event: InputEvent) -> void:
	# Close popup when clicking outside
	if is_popup_open and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is outside popup and button
			var local_pos = popup_panel.get_local_mouse_position()
			var btn_local = toggle_btn.get_local_mouse_position()
			
			var in_popup = Rect2(Vector2.ZERO, popup_panel.size).has_point(local_pos)
			var in_btn = Rect2(Vector2.ZERO, toggle_btn.size).has_point(btn_local)
			
			if not in_popup and not in_btn:
				_close_popup()


func _on_toggle_pressed() -> void:
	Sound.play("click2")
	
	if is_popup_open:
		_close_popup()
	else:
		_open_popup()


func _open_popup() -> void:
	is_popup_open = true
	
	# Refresh groups list BEFORE showing popup to avoid visual glitches
	_refresh_groups_buttons()
	
	# Reset scroll position
	scroll_container.scroll_vertical = 0
	
	# Show popup
	popup_panel.visible = true
	
	# Position popup above the button
	_position_popup()


func _close_popup() -> void:
	is_popup_open = false
	popup_panel.visible = false


func _position_popup() -> void:
	# Position the popup above the toggle button, centered horizontally
	await get_tree().process_frame # Wait for size calculation
	
	var btn_global = toggle_btn.global_position
	var btn_size = toggle_btn.size
	var popup_size = popup_panel.size
	
	# Center horizontally relative to button, position above with gap
	var center_x = btn_global.x + (btn_size.x / 2) - (popup_size.x / 2)
	popup_panel.global_position = Vector2(
		center_x,
		btn_global.y - popup_size.y - 8
	)
	
	# Make sure it doesn't go off-screen
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Keep within left edge
	if popup_panel.global_position.x < 10:
		popup_panel.global_position.x = 10
	
	# Keep within right edge
	if popup_panel.global_position.x + popup_size.x > viewport_size.x - 10:
		popup_panel.global_position.x = viewport_size.x - popup_size.x - 10
	
	# If not enough space above, show below
	if popup_panel.global_position.y < 10:
		popup_panel.global_position.y = btn_global.y + btn_size.y + 8


func _refresh_groups_buttons() -> void:
	if not manager:
		return
	
	# Clear existing buttons immediately (not queue_free to avoid visual glitches)
	for child in groups_container.get_children():
		groups_container.remove_child(child)
		child.free()
	
	var groups = manager.get_all_groups()
	
	if groups.is_empty():
		# Show "No groups" message
		var label = Label.new()
		label.text = "No Node Groups found"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		groups_container.add_child(label)
		
		# Adjust popup size
		scroll_container.custom_minimum_size.y = 40
		return
	
	# Calculate appropriate height - use fixed max height to avoid scroll issues
	var max_visible = 8
	var item_height = 52
	var total_height = groups.size() * item_height + (groups.size() - 1) * 4 # 4 = separation
	var max_height = max_visible * item_height
	scroll_container.custom_minimum_size.y = min(total_height, max_height)
	
	# Create a button for each group
	for group in groups:
		if not is_instance_valid(group):
			continue
		
		var btn = _create_group_button(group)
		groups_container.add_child(btn)


func _create_group_button(group) -> Button:
	var btn = Button.new()
	btn.name = "Group_" + str(group.get_instance_id())
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Get group info
	var group_name = manager.get_group_name(group)
	var group_color = manager.get_group_color(group)
	var icon_path = manager.get_group_icon_path(group)
	
	# Set text and icon
	btn.text = "  " + group_name # Add padding for icon
	btn.tooltip_text = group_name
	
	# Load icon
	var icon_texture = load(icon_path)
	if icon_texture:
		btn.icon = icon_texture
	
	# Apply color modulation via stylebox
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(group_color.r, group_color.g, group_color.b, 0.3)
	style_normal.border_color = group_color
	style_normal.border_width_left = 4
	style_normal.set_corner_radius_all(6)
	style_normal.set_content_margin_all(6)
	style_normal.content_margin_left = 10
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(group_color.r, group_color.g, group_color.b, 0.5)
	style_hover.border_color = group_color.lightened(0.2)
	style_hover.border_width_left = 4
	style_hover.set_corner_radius_all(6)
	style_hover.set_content_margin_all(6)
	style_hover.content_margin_left = 10
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(group_color.r, group_color.g, group_color.b, 0.7)
	style_pressed.border_color = group_color.lightened(0.3)
	style_pressed.border_width_left = 4
	style_pressed.set_corner_radius_all(6)
	style_pressed.set_content_margin_all(6)
	style_pressed.content_margin_left = 10
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	# Icon styling
	btn.add_theme_constant_override("icon_max_width", 28)
	btn.add_theme_font_size_override("font_size", 18)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Connect click handler
	btn.pressed.connect(_on_group_button_pressed.bind(group))
	
	return btn


func _on_group_button_pressed(group) -> void:
	if manager:
		manager.navigate_to_group(group)
	_close_popup()
