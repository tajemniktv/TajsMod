# ==============================================================================
# Taj's Mod - Upload Labs
# Cheat Manager - Handles currency and attribute cheats
# Author: TajemnikTV
# ==============================================================================
class_name TajsCheatManager
extends RefCounted

const LOG_NAME = "TajsModded:Cheats"

# Cheat definitions: [label, key, icon, is_attribute]
const CHEATS := [
    # Currencies (percentage-based)
    ["Money", "money", "res://textures/icons/money.png", false],
    ["Research", "research", "res://textures/icons/research.png", false],
    ["Corp Data", "corporation_data", "res://textures/icons/data.png", false],
    ["Gov Data", "government_data", "res://textures/icons/eye_ball.png", false],
    # Attributes (fixed-value)
    ["Hack Points", "hack_points", "res://textures/icons/star.png", true],
    ["Optimization", "optimization", "res://textures/icons/work.png", true],
    ["Application", "application", "res://textures/icons/bracket.png", true],
]

# Minimum amounts for percentage changes when values are low
const MIN_AMOUNTS := {
    "money": 1000.0, "research": 100.0,
    "corporation_data": 100.0, "government_data": 100.0,
}

# Fixed values for attribute cheats
const FIXED_VALUES := [1, 3, 5, 10]


func build_cheats_tab(parent: Control) -> void:
    # Warning label
    var warn = Label.new()
    warn.text = "⚠️ Using cheats may affect game balance!"
    warn.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
    warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(warn)
    
    # Build cheat rows
    for cheat in CHEATS:
        _add_cheat_row(parent, cheat[0], cheat[1], cheat[2], cheat[3])


func _add_cheat_row(parent: Control, label_text: String, type: String, icon_path: String, is_attribute: bool) -> void:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    
    # Icon
    var icon = TextureRect.new()
    icon.texture = load(icon_path)
    icon.custom_minimum_size = Vector2(32, 32)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(icon)
    
    var l = Label.new()
    l.text = label_text
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    l.add_theme_font_size_override("font_size", 28)
    row.add_child(l)
    
    # Capture for closures
    var t = type
    
    # Zero button (always present)
    var btn_zero = Button.new()
    btn_zero.text = "→0"
    btn_zero.theme_type_variation = "TabButton"
    btn_zero.custom_minimum_size = Vector2(60, 50)
    btn_zero.pressed.connect(func(): set_to_zero(t, is_attribute))
    row.add_child(btn_zero)
    
    if is_attribute:
        # Fixed value buttons for attributes
        for val in FIXED_VALUES:
            var btn = Button.new()
            btn.text = "+%d" % val
            btn.theme_type_variation = "TabButton"
            btn.custom_minimum_size = Vector2(70, 50)
            var v = val
            btn.pressed.connect(func(): add_fixed(t, v))
            row.add_child(btn)
    else:
        # Percentage buttons for currencies
        for pct in [-0.1, 0.1, 0.3, 0.5]:
            var btn = Button.new()
            btn.text = "%+d%%" % int(pct * 100)
            btn.theme_type_variation = "TabButton"
            btn.custom_minimum_size = Vector2(80, 50)
            var p = pct
            btn.pressed.connect(func(): modify_percent(t, p))
            row.add_child(btn)


func add_fixed(type: String, amount: int) -> void:
    """Add a fixed amount to an attribute."""
    if not Attributes.attributes.has(type):
        ModLoaderLog.error("Attribute type not found: " + type, LOG_NAME)
        return
    
    Attributes.attributes[type].add(amount, 0, 0, 0)
    
    if Globals.has_method("process"):
        Globals.process(0)
    
    var label = type.replace("_", " ").capitalize()
    Signals.notify.emit("check", "%s +%d" % [label, amount])
    Sound.play("click")


func modify_percent(type: String, percent: float) -> void:
    """Modify a currency by a percentage."""
    if not Globals.currencies.has(type):
        ModLoaderLog.error("Currency type not found: " + type, LOG_NAME)
        return
    
    var current = Globals.currencies[type]
    var amount_to_change = current * percent
    var min_amount = MIN_AMOUNTS.get(type, 1.0)
    
    if percent > 0 and abs(amount_to_change) < min_amount:
        amount_to_change = min_amount
    
    var new_value = current + amount_to_change
    if new_value < 0:
        new_value = 0
    
    Globals.currencies[type] = new_value
    
    if type == "money":
        Globals.max_money = max(Globals.max_money, new_value)
    elif type == "research":
        Globals.max_research = max(Globals.max_research, new_value)
    
    if Globals.has_method("process"):
        Globals.process(0)
    
    var sign_str = "+" if percent > 0 else ""
    var label = type.replace("_", " ").capitalize()
    Signals.notify.emit("check", "%s %s%d%%" % [label, sign_str, int(percent * 100)])
    Sound.play("click")


func set_to_zero(type: String, is_attribute: bool = false) -> void:
    """Set a resource to zero."""
    if is_attribute:
        if not Attributes.attributes.has(type):
            ModLoaderLog.error("Attribute type not found: " + type, LOG_NAME)
            return
        var current = Attributes.get_attribute(type)
        Attributes.attributes[type].add(-current, 0, 0, 0)
    else:
        if not Globals.currencies.has(type):
            ModLoaderLog.error("Currency type not found: " + type, LOG_NAME)
            return
        Globals.currencies[type] = 0
    
    if Globals.has_method("process"):
        Globals.process(0)
    
    var label = type.replace("_", " ").capitalize()
    Signals.notify.emit("check", "%s set to 0" % label)
    Sound.play("click")
