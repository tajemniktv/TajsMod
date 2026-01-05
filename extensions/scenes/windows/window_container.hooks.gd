# ==============================================================================
# Taj's Mod - Upload Labs
# Window Container Hooks - Override position clamping for expanded workspace
# Uses Script Hooks API (ModLoader 7.x) to hook class_name scripts
# Author: TajemnikTV
# ==============================================================================
extends Object

const WorkspaceBounds = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workspace_bounds.gd")
const LOG_NAME = "TajsModded:WorkspaceHooks"

const DEBUG = false # Set to true to see hook execution logs


## Hook for WindowContainer._on_gui_input
## Function name MUST match vanilla exactly when using install_script_hooks()
## Replaces drag clamping entirely when expanded workspace is enabled and limit > 5000
static func _on_gui_input(chain: ModLoaderHookChain, event: InputEvent) -> void:
    var window = chain.reference_object as WindowContainer
    
    if DEBUG and event is InputEventScreenDrag:
        ModLoaderLog.debug("_on_gui_input called - ScreenDrag event, enabled=%s, multiplier=%s, grabbing=%s" % [
            WorkspaceBounds.is_enabled(),
            WorkspaceBounds.get_multiplier(),
            window.grabbing if window else "null"
        ], LOG_NAME)
    
    # If not enabled or multiplier is 1.0, use vanilla behavior
    if not WorkspaceBounds.is_enabled() or WorkspaceBounds.get_multiplier() <= 1.0:
        chain.execute_next([event])
        return
    
    # For ScreenDrag events while grabbing, we need to handle the clamping ourselves
    if event is InputEventScreenDrag and window.grabbing:
        if DEBUG:
            ModLoaderLog.debug("Handling drag with expanded bounds! limit=%s" % WorkspaceBounds.get_limit(), LOG_NAME)
        
        # Skip the vanilla execution and handle drag ourselves with expanded bounds
        # This replicates the vanilla logic but with expanded limits
        
        if event.index >= 1:
            Signals.movement_input.emit(event, window.global_position)
            return
        
        window.dragged = true
        
        var limit = WorkspaceBounds.get_limit()
        var new_pos: Vector2 = (window.get_global_mouse_position() - window.grabbing_pos).snappedf(50)
        new_pos.x = clampf(new_pos.x, -limit, limit - window.size.x)
        new_pos.y = clampf(new_pos.y, -limit, limit - window.size.y)
        
        if DEBUG:
            ModLoaderLog.debug("  new_pos=%s" % new_pos, LOG_NAME)
        
        if Globals.selections.has(window):
            Signals.move_connectors.emit(new_pos - window.global_position)
            Signals.move_selection.emit(new_pos - window.global_position)
        else:
            window.move(new_pos)
            if window.can_select:
                Globals.set_selection([window], [], 1)
        
        # Don't call vanilla - we handled it
        return
    
    # For all other events, use vanilla behavior
    chain.execute_next([event])


## Hook for WindowContainer._ready
## Function name MUST match vanilla exactly when using install_script_hooks()
## Clamps initial position to expanded bounds instead of vanilla
static func _ready(chain: ModLoaderHookChain) -> void:
    var window = chain.reference_object as WindowContainer
    
    if DEBUG:
        ModLoaderLog.debug("_ready hook called for window", LOG_NAME)
    
    # Store the original position before vanilla _ready clamps it
    var original_pos = window.global_position
    
    # Let vanilla _ready run (which will clamp to -5000, 4650)
    chain.execute_next([])
    
    # If expanded workspace is enabled and original position was outside vanilla bounds,
    # restore the original position (clamped to expanded bounds)
    if WorkspaceBounds.is_enabled() and WorkspaceBounds.get_multiplier() > 1.0:
        var limit = WorkspaceBounds.get_limit()
        # If the original position was outside vanilla bounds, restore it
        if absf(original_pos.x) > 4650 or absf(original_pos.y) > 4650:
            var restored_pos = original_pos.clampf(-limit, limit - 350).snappedf(50)
            window.global_position = restored_pos
            if DEBUG:
                ModLoaderLog.debug("Restored position from %s to %s" % [original_pos, restored_pos], LOG_NAME)
