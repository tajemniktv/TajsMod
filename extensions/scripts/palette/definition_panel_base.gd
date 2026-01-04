# ==============================================================================
# Taj's Mod - Upload Labs
# Definition Panel Base - Shared base class for all definition panels
# Author: TajemnikTV
# ==============================================================================
class_name TajsModDefinitionPanelBase
extends Control

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

signal back_requested()

# Common UI elements
var _scroll_container: ScrollContainer
var _content_margin: MarginContainer
var _content_vbox: VBoxContainer
var _header_panel: PanelContainer
var _back_button: Button

# Wire colors reference (for resource display)
var _wire_colors = null


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	# Handle mouse back button
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_XBUTTON1 and event.pressed:
			back_requested.emit()
			get_viewport().set_input_as_handled()


func set_wire_colors(wc) -> void:
	_wire_colors = wc


## Build the common base UI structure
## Call this from subclass _build_ui() before adding custom content
func _build_base_ui() -> void:
	# Main style
	var style = PaletteTheme.create_definition_panel_style()
	
	var panel = PanelContainer.new()
	panel.name = "MainPanel"
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(main_vbox)
	
	# Header panel
	_header_panel = _create_header_panel(main_vbox)
	
	# Scrollable content area
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll_container)
	
	_content_margin = MarginContainer.new()
	_content_margin.add_theme_constant_override("margin_left", 24)
	_content_margin.add_theme_constant_override("margin_right", 24)
	_content_margin.add_theme_constant_override("margin_top", 16)
	_content_margin.add_theme_constant_override("margin_bottom", 16)
	_scroll_container.add_child(_content_margin)
	
	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 16)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_margin.add_child(_content_vbox)


func _create_header_panel(parent: Control) -> PanelContainer:
	var header = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	header_style.corner_radius_top_left = 10
	header_style.corner_radius_top_right = 10
	header.add_theme_stylebox_override("panel", header_style)
	parent.add_child(header)
	return header


## Create a titled section with content container
## Returns the content VBoxContainer where items should be added
func _create_section(title: String, parent: Control) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	section.add_child(title_label)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	section.add_child(content)
	
	return content


## Create a section with panel background
func _create_section_panel(title: String, parent: Control) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = PaletteTheme.create_section_style()
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	# Section title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(title_label)
	
	# Container for list items
	var item_container = VBoxContainer.new()
	vbox.add_child(item_container)
	
	# Metadata to retrieve container later
	panel.set_meta("container", item_container)
	
	return panel


## Create a styled back button
func _create_back_button() -> Button:
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(60, 28)
	_back_button.add_theme_font_size_override("font_size", 12)
	_back_button.pressed.connect(func(): back_requested.emit())
	return _back_button


## Add a placeholder row to a container
func _add_placeholder(container: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	container.add_child(label)


## Clear all children from a container
func _clear_container(container: Control) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()


## Apply glow style to a label
func _apply_text_glow(label: Label, use_glow: bool = true) -> void:
	PaletteTheme.apply_text_glow(label, use_glow)
