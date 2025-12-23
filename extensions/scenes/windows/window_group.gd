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
        
        # Inject Pattern Button into TitleContainer
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
            pattern_btn.tooltip_text = "Change Pattern"
            
            title_container.add_child(pattern_btn)
            # Attempt to place after ColorButton (index 3 hopefully)
            # Children: Icon, Title, ColorButton, RenameButton
            if title_container.get_child_count() >= 3:
                title_container.move_child(pattern_btn, 3)
            
            pattern_btn.pressed.connect(cycle_pattern)
            
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
    $TitlePanel.self_modulate = Color(NEW_COLORS[color])
    $PanelContainer.self_modulate = Color(NEW_COLORS[color])

func cycle_color() -> void:
    color += 1
    if color >= NEW_COLORS.size():
        color = 0
    update_color()
    color_changed.emit()

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
    return data

func export() -> Dictionary:
    var data = super.export()
    data["pattern_index"] = pattern_index
    return data
