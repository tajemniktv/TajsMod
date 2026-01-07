# ==============================================================================
# Taj's Mod - Upload Labs
# Breach Threat Manager - Auto-adjusts threat level based on breach outcomes
# Author: TajemnikTV
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:BreachThreat"

## Whether the auto-escalation feature is enabled
var _enabled: bool = true

## Whether the auto-de-escalation feature is enabled
var _deescalation_enabled: bool = true

## Number of consecutive successful breaches before level-up
var _threshold: int = 3

## Number of consecutive failed breaches before level-down
var _deescalation_threshold: int = 5

## Number of successful breaches to wait after de-escalation before allowing escalation again
var _escalation_cooldown: int = 10

## Tracks consecutive successful breaches per window (keyed by instance ID)
var _success_streak: Dictionary = {}

## Tracks consecutive failed breaches per window (keyed by instance ID)
var _failure_streak: Dictionary = {}

## Tracks remaining cooldown breaches per window before escalation is allowed again
var _escalation_cooldown_remaining: Dictionary = {}

## Debug mode flag
var _debug_enabled: bool = false
## Callback for debug logging to UI
var _log_callback: Callable = Callable()


## Initialize the manager with config values
func setup(config, debug_enabled: bool = false, log_callback: Callable = Callable()) -> void:
    _enabled = config.get_value("breach_escalation_enabled", true)
    _deescalation_enabled = config.get_value("breach_deescalation_enabled", true)
    _threshold = config.get_value("breach_escalation_threshold", 3)
    _deescalation_threshold = config.get_value("breach_deescalation_threshold", 5)
    _escalation_cooldown = config.get_value("breach_escalation_cooldown", 10)
    _debug_enabled = debug_enabled
    _log_callback = log_callback
    
    _log("Breach Threat Manager setup (enabled=%s, threshold=%d, deesc_enabled=%s, deesc_threshold=%d, cooldown=%d)" % [
        _enabled, _threshold, _deescalation_enabled, _deescalation_threshold, _escalation_cooldown
    ])


func _ready() -> void:
    # Connect to the game's breached signal (success)
    if Signals and Signals.has_signal("breached"):
        if not Signals.breached.is_connected(_on_breach_success):
            Signals.breached.connect(_on_breach_success)
            _log("Connected to Signals.breached")
    else:
        _log("Error: Signals.breached not found!", true)
    
    _log("BreachThreatManager ready - failures tracked via Globals.breach_threat_manager")


## Called when a breach succeeds
func _on_breach_success(window) -> void:
    if not _enabled:
        return
    
    # Safety check: ensure window has the necessary methods
    if not window.has_method("get_level") or not window.has_method("get_max_level") or not window.has_method("level_up"):
        _log("Window missing required methods, skipping", true)
        return
    
    var id = window.get_instance_id()
    
    # Increment success streak, reset failure streak (consecutive mode)
    _success_streak[id] = _success_streak.get(id, 0) + 1
    _failure_streak[id] = 0
    
    # Decrement cooldown if active
    if _escalation_cooldown_remaining.get(id, 0) > 0:
        _escalation_cooldown_remaining[id] -= 1
    
    var current_streak = _success_streak[id]
    var current_level = window.get_level()
    var max_level = window.get_max_level()
    var cooldown_left = _escalation_cooldown_remaining.get(id, 0)
    
    _log("Breach SUCCESS on window %d (streak: %d/%d, level: %d/%d, cooldown: %d)" % [id, current_streak, _threshold, current_level, max_level, cooldown_left])
    
    if current_streak >= _threshold:
        # Check cooldown - if still in cooldown period, don't escalate
        if cooldown_left > 0:
            _log("Escalation blocked - still in cooldown (%d breaches remaining)" % cooldown_left)
            # Reset streak but don't escalate
            _success_streak[id] = 0
        # Only level up if not at max
        elif current_level < max_level:
            window.level_up(1)
            _log("Auto-escalated threat level to %d" % (current_level + 1))
            Signals.notify.emit("breach", "Threat escalated! Level %d" % (current_level + 1))
            # Reset counter
            _success_streak[id] = 0
        else:
            _log("Already at max level, no escalation")
            _success_streak[id] = 0


## Called when a breach fails (public method for direct calls from window_breach.gd)
func on_breach_failed(window) -> void:
    if not _enabled or not _deescalation_enabled:
        return
    
    # Safety check: ensure window has the necessary methods
    if not window.has_method("get_level") or not window.has_method("level_down"):
        _log("Window missing required methods for de-escalation, skipping", true)
        return
    
    var id = window.get_instance_id()
    
    # Increment failure streak, reset success streak (consecutive mode)
    _failure_streak[id] = _failure_streak.get(id, 0) + 1
    _success_streak[id] = 0
    
    var current_streak = _failure_streak[id]
    var current_level = window.get_level()
    
    _log("Breach FAILED on window %d (streak: %d/%d, level: %d)" % [id, current_streak, _deescalation_threshold, current_level])
    
    if current_streak >= _deescalation_threshold:
        # Only level down if above minimum (0)
        if current_level > 0:
            window.level_down(1)
            _log("Auto-de-escalated threat level to %d" % (current_level - 1))
            Signals.notify.emit("breach", "Threat reduced! Level %d" % (current_level - 1))
            
            # Start escalation cooldown - prevent immediate re-escalation
            _escalation_cooldown_remaining[id] = _escalation_cooldown
            _log("Escalation cooldown started: %d breaches" % _escalation_cooldown)
        else:
            _log("Already at minimum level, no de-escalation")
        
        # Reset counter
        _failure_streak[id] = 0


## Enable or disable the feature at runtime
func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    _log("Breach adjustment %s" % ("enabled" if enabled else "disabled"))


## Enable or disable de-escalation at runtime
func set_deescalation_enabled(enabled: bool) -> void:
    _deescalation_enabled = enabled
    _log("Breach de-escalation %s" % ("enabled" if enabled else "disabled"))


## Update the escalation threshold at runtime
func set_threshold(threshold: int) -> void:
    _threshold = max(1, threshold) # Minimum of 1
    _log("Breach escalation threshold set to %d" % _threshold)


## Update the de-escalation threshold at runtime
func set_deescalation_threshold(threshold: int) -> void:
    _deescalation_threshold = max(1, threshold) # Minimum of 1
    _log("Breach de-escalation threshold set to %d" % _deescalation_threshold)


## Update the escalation cooldown at runtime
func set_escalation_cooldown(cooldown: int) -> void:
    _escalation_cooldown = max(0, cooldown) # Minimum of 0 (no cooldown)
    _log("Breach escalation cooldown set to %d" % _escalation_cooldown)


## Set debug mode
func set_debug_enabled(enabled: bool) -> void:
    _debug_enabled = enabled


## Helper for debug logging
func _log(message: String, force: bool = false) -> void:
    if _debug_enabled or force:
        ModLoaderLog.info(message, LOG_NAME)
        if _log_callback.is_valid():
            _log_callback.call(message)
