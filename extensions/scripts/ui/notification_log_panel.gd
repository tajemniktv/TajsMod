# ==============================================================================
# Taj's Mod - Upload Labs
# Notification Log Panel - Toast History UI
# Author: TajemnikTV
# ==============================================================================
extends Control

const LOG_NAME = "TajsModded:NotificationLog"
const MAX_NOTIFICATIONS = 20

# UI components
var toggle_btn: Button = null
var popup_panel: PanelContainer = null
var scroll_container: ScrollContainer = null
var notifications_container: VBoxContainer = null
var clear_btn: Button = null
var empty_label: Label = null

# State
var is_popup_open: bool = false
var notifications: Array = [] # Array of {icon: String, text: String, time: int}
var unread_count: int = 0
var unread_badge: Label = null


func _ready() -> void:
	_build_ui()
	
	# Initially hide popup
	if popup_panel:
		popup_panel.visible = false


func _build_ui() -> void:
	name = "NotificationLogPanel"
	
	# Toggle button - bell icon
	toggle_btn = Button.new()
	toggle_btn.name = "NotificationLogButton"
	toggle_btn.custom_minimum_size = Vector2(50, 50)
	toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.theme_type_variation = "ButtonMenu"
	toggle_btn.icon = load("res://textures/icons/exclamation.png")
	toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle_btn.expand_icon = true
	toggle_btn.tooltip_text = "Notification History"
	toggle_btn.add_theme_constant_override("icon_max_width", 28)
	toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(toggle_btn)
	
	# Unread badge (small label on button)
	unread_badge = Label.new()
	unread_badge.name = "UnreadBadge"
	unread_badge.text = ""
	unread_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unread_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unread_badge.add_theme_font_size_override("font_size", 12)
	unread_badge.add_theme_color_override("font_color", Color.WHITE)
	unread_badge.custom_minimum_size = Vector2(18, 18)
	unread_badge.visible = false
	
	# Badge background style
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	badge_style.set_corner_radius_all(9)
	unread_badge.add_theme_stylebox_override("normal", badge_style)
	
	# Position badge in top-right of button
	unread_badge.position = Vector2(32, -4)
	toggle_btn.add_child(unread_badge)
	
	# Popup panel
	popup_panel = PanelContainer.new()
	popup_panel.name = "NotificationLogPopup"
	popup_panel.visible = false
	popup_panel.custom_minimum_size = Vector2(400, 0) # Wider panel
	
	# Use game's theme variation for consistent styling
	popup_panel.theme_type_variation = "MenuPanel"
	add_child(popup_panel)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	popup_panel.add_child(main_vbox)
	
	# Header with title and clear button
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "Notification History"
	title.add_theme_font_size_override("font_size", 24) # Larger title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(80, 36) # Bigger button
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.theme_type_variation = "TabButton" # Match game style
	clear_btn.pressed.connect(_on_clear_pressed)
	header.add_child(clear_btn)
	
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	main_vbox.add_child(sep)
	
	# Scroll container for notifications
	scroll_container = ScrollContainer.new()
	scroll_container.name = "NotificationsScroll"
	scroll_container.custom_minimum_size = Vector2(380, 80) # Larger scroll area
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll_container)
	
	# Notifications list container
	notifications_container = VBoxContainer.new()
	notifications_container.name = "NotificationsList"
	notifications_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notifications_container.add_theme_constant_override("separation", 6) # More spacing
	scroll_container.add_child(notifications_container)
	
	# Empty state label
	empty_label = Label.new()
	empty_label.text = "No notifications yet"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	empty_label.add_theme_font_size_override("font_size", 18) # Larger empty text
	notifications_container.add_child(empty_label)


func _process(_delta: float) -> void:
	# Close popup if ESC is pressed
	if is_popup_open and Input.is_action_just_pressed("ui_cancel"):
		_close_popup()


func _input(event: InputEvent) -> void:
	# Close popup when clicking outside
	if is_popup_open and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
	
	# Mark all as read
	unread_count = 0
	_update_badge()
	
	# Refresh display
	_refresh_notifications_display()
	
	# Reset scroll position
	scroll_container.scroll_vertical = 0
	
	# Show popup
	popup_panel.visible = true
	
	# Position popup below the button
	_position_popup()


func _close_popup() -> void:
	is_popup_open = false
	popup_panel.visible = false


func _position_popup() -> void:
	await get_tree().process_frame
	
	var btn_global = toggle_btn.global_position
	var btn_size = toggle_btn.size
	var popup_size = popup_panel.size
	
	# Position below button, extending to the right
	popup_panel.global_position = Vector2(
		btn_global.x, # Align left edge with button
		btn_global.y + btn_size.y + 8
	)
	
	# Keep within screen bounds
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Keep within right edge
	if popup_panel.global_position.x + popup_size.x > viewport_size.x - 10:
		popup_panel.global_position.x = viewport_size.x - popup_size.x - 10
	
	# Keep within left edge
	if popup_panel.global_position.x < 10:
		popup_panel.global_position.x = 10
	
	# Keep within bottom edge - if not enough space below, show above
	if popup_panel.global_position.y + popup_size.y > viewport_size.y - 10:
		popup_panel.global_position.y = btn_global.y - popup_size.y - 8


## Add a notification to the log
func add_notification(icon: String, text: String) -> void:
	var entry = {
		"icon": icon,
		"text": text,
		"time": Time.get_unix_time_from_system()
	}
	
	# Add to front (newest first)
	notifications.insert(0, entry)
	
	# Trim to max size
	while notifications.size() > MAX_NOTIFICATIONS:
		notifications.pop_back()
	
	# Increment unread count if popup is closed
	if not is_popup_open:
		unread_count = mini(unread_count + 1, 99)
		_update_badge()
	else:
		# If popup is open, refresh immediately
		_refresh_notifications_display()


func _update_badge() -> void:
	if unread_count > 0:
		unread_badge.text = str(unread_count) if unread_count < 100 else "99+"
		unread_badge.visible = true
	else:
		unread_badge.visible = false


func _on_clear_pressed() -> void:
	Sound.play("click2")
	notifications.clear()
	unread_count = 0
	_update_badge()
	_refresh_notifications_display()


func _refresh_notifications_display() -> void:
	# Clear existing entries (except empty_label which we'll manage)
	for child in notifications_container.get_children():
		if child != empty_label:
			notifications_container.remove_child(child)
			child.queue_free()
	
	if notifications.is_empty():
		empty_label.visible = true
		scroll_container.custom_minimum_size.y = 40
		return
	
	empty_label.visible = false
	
	# Calculate height - show up to 6 items before scrolling
	var item_height = 56 # Taller rows
	var max_visible = 6
	var total_height = notifications.size() * item_height + (notifications.size() - 1) * 6
	var max_height = max_visible * item_height
	scroll_container.custom_minimum_size.y = min(total_height, max_height)
	
	# Create entry for each notification
	for entry in notifications:
		var row = _create_notification_row(entry)
		notifications_container.add_child(row)


func _create_notification_row(entry: Dictionary) -> Control:
	# Style the row using game-like panel
	var row_panel = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 52) # Taller rows
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	row_style.border_color = Color(0.2, 0.25, 0.35, 0.5)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(8)
	row_style.set_content_margin_all(10)
	row_panel.add_theme_stylebox_override("panel", row_style)
	
	var row_content = HBoxContainer.new()
	row_content.add_theme_constant_override("separation", 12) # More spacing
	row_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_child(row_content)
	
	# Icon - larger
	var icon_tex = TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(28, 28) # Bigger icons
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var icon_path = "res://textures/icons/" + entry.icon + ".png"
	if ResourceLoader.exists(icon_path):
		icon_tex.texture = load(icon_path)
	else:
		icon_tex.texture = load("res://textures/icons/exclamation.png")
	
	row_content.add_child(icon_tex)
	
	# Text - larger font
	var text_label = Label.new()
	text_label.text = tr(entry.text) # Translate if it's a translation key
	text_label.add_theme_font_size_override("font_size", 18) # Bigger text
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_label.clip_text = true
	row_content.add_child(text_label)
	
	# Time ago - slightly larger
	var time_label = Label.new()
	time_label.text = _format_time_ago(entry.time)
	time_label.add_theme_font_size_override("font_size", 14) # Bigger timestamp
	time_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.custom_minimum_size = Vector2(50, 0)
	row_content.add_child(time_label)
	
	return row_panel


func _format_time_ago(timestamp: int) -> String:
	var now = Time.get_unix_time_from_system()
	var diff = int(now - timestamp)
	
	if diff < 60:
		return "now"
	elif diff < 3600:
		var mins = diff / 60
		return str(mins) + "m"
	elif diff < 86400:
		var hours = diff / 3600
		return str(hours) + "h"
	else:
		var days = diff / 86400
		return str(days) + "d"
