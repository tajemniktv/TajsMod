# ==============================================================================
# Taj's Mod - Upload Labs
# Sticky Note Edit Popup - Modal popup for editing sticky note title and icon
# Styled to match Node Group edit popup, with full Icon Browser support
# Author: TajemnikTV
# ==============================================================================
extends PanelContainer
class_name TajsStickyNoteEditPopup

signal confirmed(new_title: String, new_icon: String)
signal cancelled()

const LOG_NAME = "TajsModded:StickyNoteEditPopup"

# Preload Icon Browser
const IconBrowserClass = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/icon_browser.gd")

# State
var _selected_icon: String = "document"
var _initial_title: String = ""
var _initial_icon: String = "document"

# UI References
var _title_input: LineEdit
var _cancel_btn: Button
var _confirm_btn: Button
var _icon_browser: RefCounted # TajIconBrowser instance

func _init() -> void:
    name = "StickyNoteEditPopup"
    custom_minimum_size = Vector2(720, 500)

func _ready() -> void:
    _build_ui()
    _apply_styling()

func _build_ui() -> void:
    # Main VBox
    var vbox = VBoxContainer.new()
    vbox.name = "MainVBox"
    vbox.add_theme_constant_override("separation", 12)
    add_child(vbox)
    
    # Header label
    var header = Label.new()
    header.name = "Header"
    header.text = "Edit Note"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 18)
    header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    vbox.add_child(header)
    
    # Icon browser container
    var icon_container = VBoxContainer.new()
    icon_container.name = "IconBrowserContainer"
    icon_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(icon_container)
    
    # Create and build the Icon Browser
    _icon_browser = IconBrowserClass.new()
    _icon_browser.build_ui(icon_container)
    _icon_browser.icon_selected.connect(_on_icon_selected)
    
    # Title input with label
    var title_label = Label.new()
    title_label.text = "Note Title:"
    title_label.add_theme_font_size_override("font_size", 14)
    title_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
    vbox.add_child(title_label)
    
    _title_input = LineEdit.new()
    _title_input.name = "TitleInput"
    _title_input.placeholder_text = "Enter note title..."
    _title_input.custom_minimum_size = Vector2(0, 40)
    _title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_input.add_theme_font_size_override("font_size", 16)
    _title_input.text_submitted.connect(_on_title_submitted)
    vbox.add_child(_title_input)
    
    # Button row
    var btn_row = HBoxContainer.new()
    btn_row.name = "ButtonRow"
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_row.add_theme_constant_override("separation", 20)
    vbox.add_child(btn_row)
    
    _cancel_btn = Button.new()
    _cancel_btn.name = "CancelButton"
    _cancel_btn.text = "Cancel"
    _cancel_btn.custom_minimum_size = Vector2(120, 40)
    _cancel_btn.pressed.connect(_on_cancel_pressed)
    btn_row.add_child(_cancel_btn)
    
    _confirm_btn = Button.new()
    _confirm_btn.name = "ConfirmButton"
    _confirm_btn.text = "Confirm"
    _confirm_btn.custom_minimum_size = Vector2(120, 40)
    _confirm_btn.pressed.connect(_on_confirm_pressed)
    btn_row.add_child(_confirm_btn)

func _apply_styling() -> void:
    # Panel styling - dark, semi-transparent, rounded
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = Color(0.3, 0.35, 0.4, 0.5)
    style.shadow_color = Color(0, 0, 0, 0.4)
    style.shadow_size = 8
    style.set_content_margin_all(16)
    add_theme_stylebox_override("panel", style)

func _on_icon_selected(icon_name: String, _icon_path: String) -> void:
    _selected_icon = icon_name
    Sound.play("click2")

func _on_title_submitted(_text: String) -> void:
    _on_confirm_pressed()

func _on_cancel_pressed() -> void:
    Sound.play("close")
    cancelled.emit()

func _on_confirm_pressed() -> void:
    var new_title = _title_input.text.strip_edges()
    if new_title.is_empty():
        new_title = "Note"
    Sound.play("click2")
    confirmed.emit(new_title, _selected_icon)

## Opens the popup with the given initial values
func open(current_title: String, current_icon: String) -> void:
    _initial_title = current_title
    _initial_icon = current_icon if current_icon else "document"
    
    _title_input.text = current_title
    _selected_icon = _initial_icon
    
    # Set the icon browser's selection
    if _icon_browser:
        _icon_browser.set_selected_icon(_initial_icon)
    
    visible = true
    
    # Focus the title input and select all
    await get_tree().process_frame
    _title_input.grab_focus()
    _title_input.select_all()

## Closes the popup
func close() -> void:
    visible = false

## Handle Escape key to cancel
func _input(event: InputEvent) -> void:
    if not visible:
        return
    
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _on_cancel_pressed()
            accept_event()
