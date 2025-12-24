# ==============================================================================
# Taj's Mod - Upload Labs
# Options Bar Extension - Adds lock button for group nodes
# Author: TajemnikTV
# ==============================================================================
extends "res://scripts/options_bar.gd"

const LOG_NAME = "TajsModded:OptionsBar"

var lock_button: Button = null

func _ready() -> void:
    super._ready()
    ModLoaderLog.info("options_bar extension loaded", LOG_NAME)
    _inject_lock_button()

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

func update_buttons() -> void:
    super.update_buttons()
    _update_lock_button()

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

func _on_lock_pressed() -> void:
    for window in Globals.selections:
        if window.has_method("toggle_lock"):
            window.toggle_lock()
    _update_lock_button()
    Sound.play("click2")
