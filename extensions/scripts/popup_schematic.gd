# =============================================================================
# Taj's Mod - Upload Labs
# Popup Schematic - Handles schematic creation with enhanced icon browser
# Author: TajemnikTV
# =============================================================================
extends "res://scripts/popup_schematic.gd"

## Preload the icon browser class
const IconBrowserClass = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/icon_browser.gd")

## Reference to the icon browser
var _icon_browser = null

## Currently selected icon name
var _selected_icon_name: String = "blueprint"


func _ready() -> void:
    # Initialize the icon browser
    _icon_browser = IconBrowserClass.new()
    _icon_browser.icon_selected.connect(_on_browser_icon_selected)
    
    # Get the info container where we'll inject our UI
    var info_container = $PortalContainer/MainPanel/InfoContainer
    
    # Hide the original IconsContainer (base game icons)
    var original_icons = $PortalContainer/MainPanel/InfoContainer/IconsContainer
    if original_icons:
        original_icons.visible = false
    
    # Build the icon browser UI
    _icon_browser.build_ui(info_container)
    
    # Expand the popup size to nearly fullscreen with padding
    _expand_popup_size()
    
    # Connect the save signal
    Signals.save_schematic.connect(_on_save_schematic)
    
    # Style the name input to be distinct from search
    _style_name_input()


## Expands the popup to nearly fullscreen with padding
func _expand_popup_size() -> void:
    # Use anchor-based sizing for responsive fullscreen-ish layout
    anchors_preset = Control.PRESET_FULL_RECT
    anchor_left = 0.05
    anchor_top = 0.08 # Moved down slightly from 0.05
    anchor_right = 0.95
    anchor_bottom = 0.95
    offset_left = 0
    offset_right = 0
    offset_top = 0
    offset_bottom = 0


## Styles the schematic name input to be visually distinct from search
func _style_name_input() -> void:
    var name_input = $PortalContainer/MainPanel/InfoContainer/Label
    if name_input:
        name_input.custom_minimum_size = Vector2(0, 50)
        name_input.add_theme_font_size_override("font_size", 24)
        # Add a label above it
        var name_label = Label.new()
        name_label.name = "NameLabel"
        name_label.text = "Schematic Name:"
        name_label.add_theme_font_size_override("font_size", 18)
        name_label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812))
        
        var info_container = $PortalContainer/MainPanel/InfoContainer
        var name_index = name_input.get_index()
        info_container.add_child(name_label)
        info_container.move_child(name_label, name_index)


## Override _gui_input to prevent scroll wheel from closing popup
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        # Block scroll wheel events from propagating
        if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            accept_event()


## Handles icon selection from the browser
func _on_browser_icon_selected(icon_name: String, _icon_path: String) -> void:
    _selected_icon_name = icon_name
    Sound.play("click_toggle2")


## Override hide to reset the browser state
func hide() -> void:
    super ()
    $PortalContainer/MainPanel/InfoContainer/Label.text = ""
    _selected_icon_name = "blueprint"
    if _icon_browser:
        _icon_browser.set_selected_icon("blueprint")


## Override save to use our selected icon
func _on_save_pressed() -> void:
    # Use the icon name from our browser
    data["icon"] = _selected_icon_name
    
    var schem_name: String = $PortalContainer/MainPanel/InfoContainer/Label.text
    if schem_name.is_empty():
        schem_name = "Schematic"
    
    # Call global Data save
    Data.save_schematic(schem_name, data)
    
    close()
    Sound.play("click2")


## Override to avoid calling the base _ready which connects icon buttons
func _on_icon_button_pressed(_index: int) -> void:
    # Do nothing - we handle this in _on_browser_icon_selected
    pass
