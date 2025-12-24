# ==============================================================================
# Taj's Mod - Upload Labs
# Group Window Extension - Expanded color palette and patterns
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_group.gd"

# Expanded color palette
const NEW_COLORS: Array[String] = [
    "1a202c", "1a2b22", "1a292b", "1a1b2b", "211a2b", "2b1a27", "2b1a1a",
    "BE4242", "FFA500", "FFFF00", "00FF00", "00FFFF", "0000FF", "800080", "FF00FF", "252525", "000000"
]

var pattern_index: int = 0
var pattern_drawers: Array[Control] = []
var custom_color: Color = Color.TRANSPARENT # Custom RGB color (TRANSPARENT = use preset)
var color_picker_btn: ColorPickerButton = null

class PatternDrawer extends Control:
    var pattern_type: int = 0
    var color: Color = Color(0, 0, 0, 0.4) # Increased alpha

    func _ready() -> void:
        resized.connect(queue_redraw)
        clip_contents = true # Prevent drawing outside bounds

    func _draw() -> void:
        if pattern_type == 0: return
        
        var size = get_size()
        var step = 20.0 # Increased spacing
        var width = 4.0 # Increased width
        
        if pattern_type == 1: # Horizontal Stripes
            var y = 0.0
            while y < size.y:
                draw_line(Vector2(0, y), Vector2(size.x, y), color, width)
                y += step
                
        elif pattern_type == 2: # Vertical Stripes
            var x = 0.0
            while x < size.x:
                draw_line(Vector2(x, 0), Vector2(x, size.y), color, width)
                x += step

        elif pattern_type == 3: # Slash /
            var x = - size.y
            while x < size.x:
                draw_line(Vector2(x, 0), Vector2(x + size.y, size.y), color, width)
                x += step
                
        elif pattern_type == 4: # Backslash \
            var x = 0.0
            while x < size.x + size.y:
                draw_line(Vector2(x, 0), Vector2(x - size.y, size.y), color, width)
                x += step

        elif pattern_type == 5: # Checkerboard (Grid)
            var x = 0.0
            while x < size.x:
                draw_line(Vector2(x, 0), Vector2(x, size.y), color, width)
                x += step
            var y = 0.0
            while y < size.y:
                draw_line(Vector2(0, y), Vector2(size.x, y), color, width)
                y += step
                
        elif pattern_type == 6: # Diamond (Crosshatch)
            var x = - size.y
            while x < size.x:
                draw_line(Vector2(x, 0), Vector2(x + size.y, size.y), color, width)
                x += step
            x = 0.0
            while x < size.x + size.y:
                draw_line(Vector2(x, 0), Vector2(x - size.y, size.y), color, width)
                x += step
    
    func set_pattern(p: int):
        pattern_type = p
        queue_redraw()

func _ready() -> void:
    super._ready()
    
    # Inject Pattern Drawer into TitlePanel
    var title_panel = get_node_or_null("TitlePanel")
    if title_panel:
        var title_drawer = PatternDrawer.new()
        title_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
        title_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        title_panel.add_child(title_drawer)
        title_panel.move_child(title_drawer, 0)
        pattern_drawers.append(title_drawer)
        
        # Inject Pattern Button with PopupMenu into TitleContainer
        var title_container = title_panel.get_node_or_null("TitleContainer")
        if title_container:
            var pattern_btn = Button.new()
            pattern_btn.name = "PatternButton"
            pattern_btn.custom_minimum_size = Vector2(40, 40)
            pattern_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            pattern_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            pattern_btn.focus_mode = Control.FOCUS_NONE
            pattern_btn.theme_type_variation = "SettingButton"
            pattern_btn.add_theme_constant_override("icon_max_width", 20)
            pattern_btn.icon = load("res://textures/icons/grid.png")
            pattern_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            pattern_btn.expand_icon = true
            pattern_btn.tooltip_text = "Select Pattern"
            
            # Create PopupMenu for pattern selection
            var pattern_popup = PopupMenu.new()
            pattern_popup.name = "PatternPopup"
            pattern_popup.add_item("None", 0)
            pattern_popup.add_item("Horizontal Lines", 1)
            pattern_popup.add_item("Vertical Lines", 2)
            pattern_popup.add_item("Diagonal /", 3)
            pattern_popup.add_item("Diagonal \\", 4)
            pattern_popup.add_item("Grid", 5)
            pattern_popup.add_item("Diamond", 6)
            
            # Style the popup to match game
            var pattern_panel_style = StyleBoxFlat.new()
            pattern_panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.98)
            pattern_panel_style.border_color = Color(0.2, 0.25, 0.35, 1.0)
            pattern_panel_style.set_border_width_all(2)
            pattern_panel_style.set_corner_radius_all(8)
            pattern_panel_style.set_content_margin_all(8)
            pattern_popup.add_theme_stylebox_override("panel", pattern_panel_style)
            pattern_popup.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
            pattern_popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))
            
            pattern_popup.id_pressed.connect(_on_pattern_selected)
            
            pattern_btn.add_child(pattern_popup)
            pattern_btn.pressed.connect(func():
                pattern_popup.position = pattern_btn.global_position + Vector2(0, pattern_btn.size.y)
                pattern_popup.popup()
                Sound.play("click2")
            )
            
            title_container.add_child(pattern_btn)
            if title_container.get_child_count() >= 3:
                title_container.move_child(pattern_btn, 3)
            
            # Keep original ColorButton but rewire it to open picker
            var old_color_btn = title_container.get_node_or_null("ColorButton")
            
            # Create hidden ColorPickerButton (for the picker functionality)
            color_picker_btn = ColorPickerButton.new()
            color_picker_btn.name = "ColorPickerBtn"
            color_picker_btn.visible = false # Hidden - we use original button
            color_picker_btn.edit_alpha = true # Enable alpha
            
            # Set initial color
            if custom_color != Color.TRANSPARENT:
                color_picker_btn.color = custom_color
            else:
                color_picker_btn.color = Color(NEW_COLORS[color])
            
            # Setup picker options - compact mode (wheel only)
            var picker = color_picker_btn.get_picker()
            picker.picker_shape = ColorPicker.SHAPE_VHS_CIRCLE # Color wheel
            picker.color_modes_visible = false # Hide mode toggle
            picker.sliders_visible = false # Hide sliders (compact!)
            picker.hex_visible = false # Hide hex input
            picker.presets_visible = true # Show preset swatches
            picker.sampler_visible = false # Hide eyedropper
            
            # Add preset colors
            for preset_hex in NEW_COLORS:
                picker.add_preset(Color(preset_hex))
            
            # Style the color picker popup
            var picker_popup = color_picker_btn.get_popup()
            picker_popup.transparent_bg = false
            picker_popup.borderless = true
            picker_popup.unresizable = false
            
            # Create dark panel style matching the game
            var picker_panel_style = StyleBoxFlat.new()
            picker_panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.98)
            picker_panel_style.border_color = Color(0.2, 0.25, 0.35, 1.0)
            picker_panel_style.set_border_width_all(2)
            picker_panel_style.set_corner_radius_all(12)
            picker_panel_style.set_content_margin_all(10)
            picker_popup.add_theme_stylebox_override("panel", picker_panel_style)
            
            # Style the picker font
            picker.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
            
            title_container.add_child(color_picker_btn)
            
            color_picker_btn.color_changed.connect(_on_color_picked)
            
            # Rewire original button to open the picker popup
            if old_color_btn:
                # Disconnect old signal if connected
                if old_color_btn.pressed.is_connected(_on_color_button_pressed):
                    old_color_btn.pressed.disconnect(_on_color_button_pressed)
                old_color_btn.pressed.connect(func():
                    color_picker_btn.get_popup().popup_centered()
                    Sound.play("click2")
                )
            
            # Inject Upgrade All Button
            var upgrade_btn = Button.new()
            upgrade_btn.name = "UpgradeAllButton"
            upgrade_btn.custom_minimum_size = Vector2(40, 40)
            upgrade_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            upgrade_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            upgrade_btn.focus_mode = Control.FOCUS_NONE
            upgrade_btn.theme_type_variation = "SettingButton"
            upgrade_btn.add_theme_constant_override("icon_max_width", 20)
            upgrade_btn.icon = load("res://textures/icons/up_arrow.png")
            upgrade_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            upgrade_btn.expand_icon = true
            upgrade_btn.tooltip_text = "Upgrade All Nodes in Group"
            
            title_container.add_child(upgrade_btn)
            if title_container.get_child_count() >= 4:
                title_container.move_child(upgrade_btn, 4)
            
            upgrade_btn.pressed.connect(upgrade_all_nodes)

    # Inject Pattern Drawer into PanelContainer (Content)
    var body_panel = get_node_or_null("PanelContainer")
    if body_panel:
        var body_drawer = PatternDrawer.new()
        body_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
        body_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        body_panel.add_child(body_drawer)
        body_panel.move_child(body_drawer, 0)
        pattern_drawers.append(body_drawer)

    # Apply initial pattern (e.g. from save)
    update_pattern()

func update_color() -> void:
    var use_color: Color
    if custom_color != Color.TRANSPARENT:
        use_color = custom_color
    else:
        use_color = Color(NEW_COLORS[color])
    $TitlePanel.self_modulate = use_color
    $PanelContainer.self_modulate = use_color

func cycle_color() -> void:
    # Called when color button is pressed - now we open color picker instead
    if color_picker_btn:
        # Trigger the color picker popup
        color_picker_btn.get_popup().popup_centered()
    else:
        # Fallback to old behavior
        color += 1
        if color >= NEW_COLORS.size():
            color = 0
        custom_color = Color.TRANSPARENT
        update_color()
        color_changed.emit()

func _on_pattern_selected(id: int) -> void:
    pattern_index = id
    update_pattern()
    Sound.play("click2")
func _on_color_picked(new_color: Color) -> void:
    custom_color = new_color
    update_color()
    color_changed.emit()
    Sound.play("click2")

func cycle_pattern() -> void:
    pattern_index += 1
    if pattern_index > 6:
        pattern_index = 0
    update_pattern()
    Sound.play("click2")

func update_pattern() -> void:
    for drawer in pattern_drawers:
        drawer.set_pattern(pattern_index)


func upgrade_all_nodes() -> void:
    # Find all windows inside this group's bounds
    var upgraded_count = 0
    var skipped_count = 0
    var my_rect = get_rect()
    
    for window in get_tree().get_nodes_in_group("selectable"):
        if window == self:
            continue
        if !my_rect.encloses(window.get_rect()):
            continue
        
        # Check if window has upgrade capability
        if !window.has_method("upgrade"):
            continue
        
        # Check if can afford the upgrade
        if window.has_method("can_upgrade"):
            if !window.can_upgrade():
                skipped_count += 1
                continue
            # Windows with can_upgrade() usually handle their own cost deduction
            # when _on_upgrade_button_pressed is called, so simulate that
            if window.has_method("_on_upgrade_button_pressed"):
                window._on_upgrade_button_pressed()
                upgraded_count += 1
                continue
        
        # For windows without can_upgrade, check cost manually
        var cost = window.get("cost")
        if cost != null and cost > 0:
            if cost > Globals.currencies.get("money", 0):
                skipped_count += 1
                continue
            # Deduct cost
            Globals.currencies["money"] -= cost
        
        # Call upgrade with appropriate arguments
        var arg_count = _get_method_arg_count(window, "upgrade")
        if arg_count == 0:
            window.upgrade()
        else:
            window.upgrade(1)
        upgraded_count += 1
    
    # Provide feedback
    if upgraded_count > 0:
        Sound.play("upgrade")
        var msg = "Upgraded " + str(upgraded_count) + " nodes"
        if skipped_count > 0:
            msg += " (" + str(skipped_count) + " skipped - can't afford)"
        Signals.notify.emit("check", msg)
    else:
        Sound.play("error")
        if skipped_count > 0:
            Signals.notify.emit("exclamation", "Can't afford any upgrades (" + str(skipped_count) + " nodes)")
        else:
            Signals.notify.emit("exclamation", "No upgradeable nodes in group")


func _get_method_arg_count(obj: Object, method_name: String) -> int:
    # Get the number of arguments a method expects
    var script = obj.get_script()
    if script:
        for method in script.get_script_method_list():
            if method.name == method_name:
                return method.args.size()
    # Default: assume 1 argument
    return 1

# Overrides for Persistence
func save() -> Dictionary:
    var data = super.save()
    data["pattern_index"] = pattern_index
    if custom_color != Color.TRANSPARENT:
        data["custom_color"] = custom_color.to_html(true) # Include alpha
    return data

func export() -> Dictionary:
    var data = super.export()
    data["pattern_index"] = pattern_index
    if custom_color != Color.TRANSPARENT:
        data["custom_color"] = custom_color.to_html(true)
    return data

func _load_custom_data() -> void:
    # Called after loading to restore custom color
    if has_meta("custom_color"):
        var color_str = get_meta("custom_color")
        custom_color = Color.html(color_str)
        update_color()
