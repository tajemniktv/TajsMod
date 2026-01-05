# ==============================================================================
# Taj's Mod - Upload Labs
# Breach Threat Manager - Auto-escalates threat level after successful breaches
# Author: TajemnikTV
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:BreachThreat"

## Whether the auto-escalation feature is enabled
var _enabled: bool = true

## Number of successful breaches before level-up
var _threshold: int = 3

## Tracks breach counts per window (keyed by instance ID)
var _breach_counts: Dictionary = {}

## Debug mode flag
var _debug_enabled: bool = false


## Initialize the manager with config values
func setup(config, debug_enabled: bool = false) -> void:
    _enabled = config.get_value("breach_escalation_enabled", true)
    _threshold = config.get_value("breach_escalation_threshold", 3)
    _debug_enabled = debug_enabled
    
    _log("Breach Threat Manager setup complete (enabled=%s, threshold=%d)" % [_enabled, _threshold])


func _ready() -> void:
    # Connect to the game's breached signal safely in _ready
    if Signals and Signals.has_signal("breached"):
        if not Signals.breached.is_connected(_on_breach_success):
            Signals.breached.connect(_on_breach_success)
            _log("Connected to Signals.breached")
    else:
        _log("Error: Signals singleton or breached signal not found!", true)


## Called when a breach succeeds
func _on_breach_success(window) -> void:
    if not _enabled:
        return
    
    # Safety check: ensure window has the necessary methods
    if not window.has_method("get_level") or not window.has_method("get_max_level") or not window.has_method("level_up"):
        _log("Window missing required methods, skipping", true)
        return
    
    var id = window.get_instance_id()
    _breach_counts[id] = _breach_counts.get(id, 0) + 1
    
    var current_count = _breach_counts[id]
    var current_level = window.get_level()
    var max_level = window.get_max_level()
    
    _log("Breach success on window %d (count: %d/%d, level: %d/%d)" % [id, current_count, _threshold, current_level, max_level])
    
    if current_count >= _threshold:
        # Only level up if not at max
        if current_level < max_level:
            window.level_up(1)
            _log("Auto-escalated threat level to %d" % (current_level + 1))
            Signals.notify.emit("breach", "Threat escalated! Level %d" % (current_level + 1))
        else:
            _log("Already at max level, no escalation")
        
        # Reset counter
        _breach_counts[id] = 0


## Enable or disable the feature at runtime
func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    _log("Breach escalation %s" % ("enabled" if enabled else "disabled"))


## Update the threshold at runtime
func set_threshold(threshold: int) -> void:
    _threshold = max(1, threshold) # Minimum of 1
    _log("Breach escalation threshold set to %d" % _threshold)


## Set debug mode
func set_debug_enabled(enabled: bool) -> void:
    _debug_enabled = enabled


## Helper for debug logging
func _log(message: String, force: bool = false) -> void:
    if _debug_enabled or force:
        ModLoaderLog.info(message, LOG_NAME)
