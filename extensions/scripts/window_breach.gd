# ==============================================================================
# Taj's Mod - Upload Labs
# Window Breach Extension - Notifies BreachThreatManager on breach failure
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_breach.gd"


## Override fail() to notify the BreachThreatManager
func fail() -> void:
    # Notify the BreachThreatManager BEFORE calling super (which resets state)
    # This allows tracking of failed breaches for auto de-escalation
    if Globals.breach_threat_manager and Globals.breach_threat_manager.has_method("on_breach_failed"):
        Globals.breach_threat_manager.on_breach_failed(self)
    
    super ()
