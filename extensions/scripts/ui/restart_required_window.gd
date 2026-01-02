# =============================================================================
# Taj's Mod - Upload Labs
# Restart Required Window - Modal popup when Workshop updates finish
# Author: TajemnikTV
# =============================================================================
extends CanvasLayer

const LOG_NAME = "TajsModded:RestartWindow"

var _panel: PanelContainer
var _on_dismiss_callback: Callable = Callable()

func _init():
	layer = 200 # Very high z-index to overlay everything

func _ready() -> void:
	_create_ui()

func _create_ui() -> void:
	# Dimmed backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 280)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.98)
	style.set_corner_radius_all(12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.55, 0.15, 1.0) # Amber border
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	
	# Content VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)
	
	# Header with icon
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header)
	
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture = load("res://textures/icons/reload.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.self_modulate = Color(1.0, 0.7, 0.3, 1.0)
	header.add_child(icon)
	
	var title = Label.new()
	title.text = "Restart Required"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	header.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "Workshop mods have been updated.\nPlease restart the game to load the latest versions."
	message.add_theme_font_size_override("font_size", 22)
	message.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(message)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 20)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_row)
	
	# Dismiss button
	var dismiss_btn = Button.new()
	dismiss_btn.text = "Continue Playing"
	dismiss_btn.custom_minimum_size = Vector2(180, 50)
	dismiss_btn.focus_mode = Control.FOCUS_NONE
	
	var dismiss_style = StyleBoxFlat.new()
	dismiss_style.bg_color = Color(0.25, 0.25, 0.3, 1.0)
	dismiss_style.set_corner_radius_all(8)
	dismiss_style.content_margin_left = 15
	dismiss_style.content_margin_right = 15
	dismiss_style.content_margin_top = 10
	dismiss_style.content_margin_bottom = 10
	dismiss_btn.add_theme_stylebox_override("normal", dismiss_style)
	
	var dismiss_hover = dismiss_style.duplicate()
	dismiss_hover.bg_color = Color(0.35, 0.35, 0.4, 1.0)
	dismiss_btn.add_theme_stylebox_override("hover", dismiss_hover)
	dismiss_btn.add_theme_stylebox_override("pressed", dismiss_hover)
	
	dismiss_btn.add_theme_font_size_override("font_size", 20)
	dismiss_btn.pressed.connect(_on_dismiss)
	button_row.add_child(dismiss_btn)
	
	# Exit button
	var exit_btn = Button.new()
	exit_btn.text = "Exit Game"
	exit_btn.custom_minimum_size = Vector2(180, 50)
	exit_btn.focus_mode = Control.FOCUS_NONE
	
	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.85, 0.4, 0.15, 1.0)
	exit_style.set_corner_radius_all(8)
	exit_style.content_margin_left = 15
	exit_style.content_margin_right = 15
	exit_style.content_margin_top = 10
	exit_style.content_margin_bottom = 10
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	
	var exit_hover = exit_style.duplicate()
	exit_hover.bg_color = Color(1.0, 0.5, 0.2, 1.0)
	exit_btn.add_theme_stylebox_override("hover", exit_hover)
	exit_btn.add_theme_stylebox_override("pressed", exit_hover)
	
	exit_btn.add_theme_font_size_override("font_size", 20)
	exit_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	exit_btn.pressed.connect(_on_exit)
	button_row.add_child(exit_btn)
	
	# Animate in
	_panel.modulate.a = 0
	_panel.scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_panel, "scale", Vector2(1, 1), 0.3)
	
	Sound.play("menu_open")

func set_dismiss_callback(callback: Callable) -> void:
	_on_dismiss_callback = callback

func _on_dismiss() -> void:
	Sound.play("menu_close")
	
	# Call dismiss callback (will trigger restart banner in settings)
	if _on_dismiss_callback.is_valid():
		_on_dismiss_callback.call()
	
	# Animate out and remove
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func(): queue_free())

func _on_exit() -> void:
	get_tree().quit()
