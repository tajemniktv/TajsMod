# ==============================================================================
# Taj's Mod - Upload Labs
# Options Bar Extension - Adds lock button for group nodes and Buy Max for nodes
# Author: TajemnikTV
# ==============================================================================
extends "res://scripts/options_bar.gd"

const LOG_NAME = "TajsModded:OptionsBar"

var lock_button: Button = null
var buy_max_button: Button = null

func _ready() -> void:
    super._ready()
    ModLoaderLog.info("options_bar extension loaded", LOG_NAME)
    _inject_lock_button()
    _inject_buy_max_button()

func _inject_lock_button() -> void:
    # Get WindowOptions container
    var window_options = get_node_or_null("WindowOptions")
    if window_options == null:
        push_error("[TajsModded] WindowOptions not found in options_bar")
        return
    
    ModLoaderLog.info("WindowOptions found, injecting lock button...", LOG_NAME)
    
    # Create lock button matching game style
    lock_button = Button.new()
    lock_button.name = "Lock"
    lock_button.custom_minimum_size = Vector2(80, 80)
    lock_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
    lock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    lock_button.focus_mode = Control.FOCUS_NONE
    lock_button.theme_type_variation = "ButtonMenu"
    lock_button.icon = load("res://textures/icons/padlock.png")
    lock_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lock_button.expand_icon = true
    lock_button.visible = false
    lock_button.tooltip_text = "Lock/Unlock Group Position"
    lock_button.pressed.connect(_on_lock_pressed)
    
    # Add to WindowOptions container - insert before Delete button
    window_options.add_child(lock_button)
    var delete_btn = window_options.get_node_or_null("Delete")
    if delete_btn:
        var delete_idx = delete_btn.get_index()
        window_options.move_child(lock_button, delete_idx)
    
    ModLoaderLog.info("Lock button injected successfully", LOG_NAME)


## Inject the Buy Max button for upgrading selected nodes
func _inject_buy_max_button() -> void:
    var window_options = get_node_or_null("WindowOptions")
    if window_options == null:
        return
    
    # Check if already exists
    if window_options.has_node("BuyMaxAll"):
        buy_max_button = window_options.get_node("BuyMaxAll")
        return
    
    # Create Buy Max button matching game style
    buy_max_button = Button.new()
    buy_max_button.name = "BuyMaxAll"
    buy_max_button.custom_minimum_size = Vector2(80, 80)
    buy_max_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
    buy_max_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    buy_max_button.focus_mode = Control.FOCUS_NONE
    buy_max_button.theme_type_variation = "ButtonMenu"
    buy_max_button.icon = load("res://textures/icons/upgrade.png") # Use upgrade icon if available
    buy_max_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    buy_max_button.expand_icon = true
    buy_max_button.visible = false
    buy_max_button.tooltip_text = "Upgrade All Selected (Buy Max)"
    buy_max_button.pressed.connect(_on_buy_max_pressed)
    
    # Add to WindowOptions container
    window_options.add_child(buy_max_button)
    
    # Move before Lock button if it exists
    if lock_button:
        var lock_idx = lock_button.get_index()
        window_options.move_child(buy_max_button, lock_idx)
    
    ModLoaderLog.info("Buy Max All button injected successfully", LOG_NAME)


func update_buttons() -> void:
    super.update_buttons()
    _update_lock_button()
    _update_buy_max_button()


func _update_lock_button() -> void:
    if lock_button == null:
        return
    
    # Show lock button if ANY selection is a group node (has toggle_lock method)
    var show_lock = false
    var any_locked = false
    
    for window in Globals.selections:
        # Check if this is a group node by checking for the toggle_lock method
        var has_toggle = window.has_method("toggle_lock")
        if has_toggle:
            show_lock = true # Found at least one group
            if window.has_method("is_locked") and window.is_locked():
                any_locked = true
    
    # Debug logging removed - too verbose during normal use
    lock_button.visible = show_lock
    
    # Update icon based on lock state
    if any_locked:
        lock_button.icon = load("res://textures/icons/padlock_open.png")
        lock_button.tooltip_text = "Unlock Group Position"
    else:
        lock_button.icon = load("res://textures/icons/padlock.png")
        lock_button.tooltip_text = "Lock Group Position"


## Update Buy Max button visibility based on selection
func _update_buy_max_button() -> void:
    if buy_max_button == null:
        return
    
    # Show Buy Max if any selected node has an upgrade method and visible upgrade_button
    var show_buy_max = false
    var can_afford_any = false
    var total_cost: float = 0.0
    
    for window in Globals.selections:
        if not _is_upgradeable(window):
            continue
        show_buy_max = true
        
        var cost = _get_upgrade_cost(window)
        if cost > 0 and Globals.currencies.get("money", 0) >= cost:
            can_afford_any = true
            total_cost += cost
    
    buy_max_button.visible = show_buy_max
    buy_max_button.disabled = not can_afford_any
    
    if total_cost > 0:
        buy_max_button.tooltip_text = "Upgrade All Selected (Cost: %s)" % Utils.print_string(total_cost, false)
    else:
        buy_max_button.tooltip_text = "Upgrade All Selected (Buy Max)"


func _on_lock_pressed() -> void:
    for window in Globals.selections:
        if window.has_method("toggle_lock"):
            window.toggle_lock()
    _update_lock_button()
    Sound.play("click2")


## Handle Buy Max button press - upgrade all selected nodes as much as possible
func _on_buy_max_pressed() -> void:
    var total_upgrades = 0
    var upgraded_any = true
    
    # Round-robin loop: keep upgrading until no more can be afforded
    while upgraded_any:
        upgraded_any = false
        
        for window in Globals.selections:
            if not _is_upgradeable(window):
                continue
            
            var cost = _get_upgrade_cost(window)
            if cost <= 0:
                continue
            
            if Globals.currencies.get("money", 0) >= cost:
                # Perform upgrade
                if window.get_method_argument_count("upgrade") == 0:
                    window.upgrade()
                else:
                    window.upgrade(1)
                
                Globals.currencies["money"] -= cost
                total_upgrades += 1
                upgraded_any = true
    
    if total_upgrades > 0:
        Sound.play("upgrade")
        Signals.notify.emit("check", "Upgraded %d times" % total_upgrades)
    else:
        Sound.play("error")
        Signals.notify.emit("exclamation", "Cannot afford any upgrades")
    
    _update_buy_max_button()


## Check if a window node is upgradeable
func _is_upgradeable(window) -> bool:
    if not window.has_method("upgrade"):
        return false
    
    # Check if it has a visible upgrade button
    if not window.has_method("get") or not window.get("upgrade_button"):
        return false
    
    var upgrade_btn = window.get("upgrade_button")
    if not upgrade_btn or not is_instance_valid(upgrade_btn):
        return false
    
    if not upgrade_btn.get("visible"):
        return false
    
    return true


## Get the cost to upgrade a window node
func _get_upgrade_cost(window) -> float:
    # Try different cost methods that nodes might have
    if window.has_method("get_cost") and window.has_method("get"):
        var level = window.get("level")
        if level != null:
            return float(window.get_cost(level))
    
    if window.has_method("get_upgrade_cost") and window.has_method("get"):
        var level = window.get("level")
        if level != null:
            return float(window.get_upgrade_cost(level))
    
    # Fallback: try to get cost property directly
    if window.has_method("get") and window.get("cost"):
        return float(window.get("cost"))
    
    return 0.0
