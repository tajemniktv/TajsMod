# ==============================================================================
# Taj's Mod - Upload Labs
# UndoManager - Core service for undo/redo functionality
# Author: TajemnikTV
# ==============================================================================
#
# EXTENSION GUIDE: How to add a new undoable action in 5 lines:
# 1. Create a command class extending TajsUndoCommand
# 2. Implement execute() and undo() methods
# 3. Call UndoManager.push_command(your_command) when the action occurs
#
# For transactions (grouping multiple changes):
#   undo_manager.begin_action("Move Nodes")
#   # ... make changes, push individual commands ...
#   undo_manager.commit_action()  # Groups all commands as one undo step
#
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:UndoManager"
const MoveNodesCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/move_nodes_command.gd")
const ConnectCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/connect_command.gd")
const DisconnectCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/disconnect_command.gd")
const NodeCreatedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/node_created_command.gd")
const NodeDeletedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/node_deleted_command.gd")
const StickyNoteCreatedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/sticky_note_created_command.gd")
const StickyNoteDeletedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/sticky_note_deleted_command.gd")
const StickyNoteMovedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/sticky_note_moved_command.gd")
const StickyNoteChangedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/sticky_note_changed_command.gd")
const GroupNodeChangedCommandScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/commands/group_node_changed_command.gd")

## Maximum number of undo steps to keep
const MAX_HISTORY_SIZE := 100

## The undo stack - most recent at end
var _undo_stack: Array = []

## The redo stack - most recent at end  
var _redo_stack: Array = []

## Whether undo/redo is enabled
var _enabled: bool = true

## Transaction state
var _in_transaction: bool = false
var _transaction_name: String = ""
var _transaction_commands: Array = []

## Movement tracking state
var _drag_start_positions: Dictionary = {} # window -> Vector2
var _is_dragging: bool = false

## Sticky Note tracking state
var _sticky_note_manager = null
var _sticky_note_drag_start_pos: Vector2 = Vector2.ZERO
var _sticky_note_clean_data: Dictionary = {} # note_id -> data (snapshot on selection)

## Group Node tracking state
var _window_clean_data: Dictionary = {} # window_name -> data (shadow copy)

## Debug mode (controlled by mod settings)
var _debug_enabled: bool = false

## Reference to config and tree
var _config = null
var _tree: SceneTree = null


## Set debug logging enabled state
func set_debug_enabled(enabled: bool) -> void:
    _debug_enabled = enabled


## Log a debug message (only if debug mode is on)
func _log_debug(message: String) -> void:
    if _debug_enabled:
        ModLoaderLog.info(message, LOG_NAME)


## Setup the manager with tree and config references
func setup(tree: SceneTree, config, mod_main_ref = null) -> void:
    _tree = tree
    _config = config
    _enabled = config.get_value("undo_redo_enabled", true)
    
    # Connect to game signals for automatic tracking
    _connect_signals()
    
    # Connect to Sticky Note Manager
    if mod_main_ref and mod_main_ref.sticky_note_manager:
        _sticky_note_manager = mod_main_ref.sticky_note_manager
        
        if not _sticky_note_manager.note_added.is_connected(_on_sticky_note_added):
            _sticky_note_manager.note_added.connect(_on_sticky_note_added)
        
        if not _sticky_note_manager.note_removed.is_connected(_on_sticky_note_removed):
            _sticky_note_manager.note_removed.connect(_on_sticky_note_removed)
            
        # Bind existing notes
        for note in _sticky_note_manager.get_all_notes():
             _on_sticky_note_added(note, false)
    
    ModLoaderLog.info("UndoManager initialized (enabled: %s)" % str(_enabled), LOG_NAME)


## Connect to game signals for automatic action tracking
func _connect_signals() -> void:
    # Movement tracking via dragging_set signal (fires when Globals.dragging changes)
    if not Signals.dragging_set.is_connected(_on_dragging_set):
        Signals.dragging_set.connect(_on_dragging_set)
    
    # Connection tracking
    if not Signals.connection_created.is_connected(_on_connection_created):
        Signals.connection_created.connect(_on_connection_created)
    if not Signals.connection_deleted.is_connected(_on_connection_deleted):
        Signals.connection_deleted.connect(_on_connection_deleted)
    
    # Window creation/deletion tracking
    if not Signals.window_created.is_connected(_on_window_created):
        Signals.window_created.connect(_on_window_created)
    if not Signals.window_deleted.is_connected(_on_window_deleted):
        Signals.window_deleted.connect(_on_window_deleted)

    # Listen for new windows to attach property listeners
    if Globals.desktop:
        var windows_root = Globals.desktop.get_node_or_null("Windows")
        if windows_root:
            if not windows_root.child_entered_tree.is_connected(_check_new_window):
                windows_root.child_entered_tree.connect(_check_new_window)
            
            # Snapshot existing windows and attach listeners
            for window in windows_root.get_children():
                _track_window(window)
    
    ModLoaderLog.info("UndoManager connected to game signals", LOG_NAME)


## Enable or disable undo/redo
func set_enabled(value: bool) -> void:
    _enabled = value
    if not _enabled:
        clear_history()
        ModLoaderLog.info("Undo/Redo disabled - history cleared", LOG_NAME)
    else:
        ModLoaderLog.info("Undo/Redo enabled", LOG_NAME)


## Check if undo/redo is enabled
func is_enabled() -> bool:
    return _enabled


## Clear all history
func clear_history() -> void:
    _undo_stack.clear()
    _redo_stack.clear()
    _transaction_commands.clear()
    _in_transaction = false


## Check if undo is available
func can_undo() -> bool:
    return _enabled and _undo_stack.size() > 0


## Check if redo is available
func can_redo() -> bool:
    return _enabled and _redo_stack.size() > 0


## Perform undo
func undo() -> bool:
    if not _enabled:
        Signals.notify.emit("exclamation", "Undo/Redo disabled in settings")
        return false
    
    if _undo_stack.size() == 0:
        Signals.notify.emit("exclamation", "Nothing to undo")
        return false
    
    var command = _undo_stack.pop_back()
    
    # Validate command is still applicable
    if not command.is_valid():
        Signals.notify.emit("exclamation", "Cannot undo: nodes no longer exist")
        return false
    
    # Execute undo
    _is_undoing_or_redoing = true
    var success = command.undo()
    _is_undoing_or_redoing = false
    
    if success:
        _redo_stack.push_back(command)
        _cap_stack(_redo_stack)
        Signals.notify.emit("check", "Undo: " + command.get_description())
        Sound.play("close")
        return true
    else:
        Signals.notify.emit("exclamation", "Undo failed")
        return false


## Perform redo
func redo() -> bool:
    if not _enabled:
        Signals.notify.emit("exclamation", "Undo/Redo disabled in settings")
        return false
    
    if _redo_stack.size() == 0:
        Signals.notify.emit("exclamation", "Nothing to redo")
        return false
    
    var command = _redo_stack.pop_back()
    
    # Validate command is still applicable
    if not command.is_valid():
        Signals.notify.emit("exclamation", "Cannot redo: nodes no longer exist")
        return false
    
    # Execute redo
    _is_undoing_or_redoing = true
    var success = command.execute()
    _is_undoing_or_redoing = false
    
    if success:
        _undo_stack.push_back(command)
        _cap_stack(_undo_stack)
        Signals.notify.emit("check", "Redo: " + command.get_description())
        Sound.play("open")
        return true
    else:
        Signals.notify.emit("exclamation", "Redo failed")
        return false


## Begin a transaction (grouped action)
func begin_action(action_name: String) -> void:
    if _in_transaction:
        push_warning("UndoManager: begin_action called while already in transaction")
        return
    _in_transaction = true
    _transaction_name = action_name
    _transaction_commands.clear()


## Commit (finalize) the current transaction
func commit_action() -> void:
    if not _in_transaction:
        push_warning("UndoManager: commit_action called without begin_action")
        return
    
    _in_transaction = false
    
    if _transaction_commands.size() == 0:
        # No commands recorded, nothing to commit
        return
    
    if _transaction_commands.size() == 1:
        # Single command, just push it directly
        _push_to_undo_stack(_transaction_commands[0])
    else:
        # Multiple commands, wrap in a transaction command
        var transaction = TransactionCommand.new(_transaction_name, _transaction_commands.duplicate())
        _push_to_undo_stack(transaction)
    
    _transaction_commands.clear()


## Cancel the current transaction (discard pending commands)
func cancel_action() -> void:
    _in_transaction = false
    _transaction_commands.clear()


## Push a single command
func push_command(command) -> void:
    if not _enabled:
        return
    
    if _in_transaction:
        _transaction_commands.push_back(command)
    else:
        _push_to_undo_stack(command)


## Internal: push to undo stack and clear redo
func _push_to_undo_stack(command) -> void:
    # Check if we can merge with the previous command
    if not _undo_stack.is_empty():
        var top = _undo_stack.back()
        if top.has_method("merge_with"):
            if top.merge_with(command):
                # Merged command into previous undo step
                return
    
    _undo_stack.push_back(command)
    _redo_stack.clear() # New action invalidates redo history
    _cap_stack(_undo_stack)


## Cap a stack to MAX_HISTORY_SIZE
func _cap_stack(stack: Array) -> void:
    while stack.size() > MAX_HISTORY_SIZE:
        stack.pop_front()


# ==============================================================================
# SIGNAL HANDLERS - Automatic action tracking
# ==============================================================================

## Handle dragging state changes for movement tracking
## Snapshots all window positions at drag start, then compares to find moved windows
func _on_dragging_set() -> void:
    if not _enabled:
        return
    
    if Globals.dragging and not _is_dragging:
        # Drag started - snapshot positions of ALL windows
        _is_dragging = true
        _snapshot_all_window_positions()
    elif not Globals.dragging and _is_dragging:
        # Drag ended - create command for any windows that moved
        _is_dragging = false
        _create_move_command_if_changed()


## Snapshot positions of ALL windows (not just selection)
## This catches cases where selection happens after drag starts
func _snapshot_all_window_positions() -> void:
    _drag_start_positions.clear()
    
    if not Globals.desktop:
        _log_debug("Warning: No desktop available")
        return
    
    var windows_container = Globals.desktop.get_node_or_null("Windows")
    if not windows_container:
        _log_debug("Warning: No Windows container found")
        return
    
    for window in windows_container.get_children():
        if is_instance_valid(window):
            # Store reference to window object as key
            _drag_start_positions[window] = window.position
    
    _log_debug("Snapshotted %d window positions" % _drag_start_positions.size())


## Create a move command for any windows that changed position
func _create_move_command_if_changed() -> void:
    if _drag_start_positions.is_empty():
        _log_debug("No positions to compare")
        return
    
    var before_positions: Dictionary = {}
    var after_positions: Dictionary = {}
    
    for window in _drag_start_positions:
        if not is_instance_valid(window):
            continue
        
        var before_pos: Vector2 = _drag_start_positions[window]
        var after_pos: Vector2 = window.position
        
        # Only record if position actually changed
        if before_pos.distance_to(after_pos) > 0.1:
            var window_name = str(window.name)
            before_positions[window_name] = before_pos
            after_positions[window_name] = after_pos
            _log_debug("Window moved: %s from %s to %s" % [window_name, before_pos, after_pos])
    
    if not before_positions.is_empty():
        var cmd = MoveNodesCommandScript.new()
        cmd.setup(before_positions, after_positions)
        push_command(cmd)
        _log_debug("Created move command for %d nodes" % before_positions.size())
    
    
    _drag_start_positions.clear()


## Handle connection created
func _on_connection_created(output_id: String, input_id: String) -> void:
    if not _enabled:
        return
    
    # Don't record if we're currently in an undo/redo operation
    if _is_undoing_or_redoing:
        return
    
    var output_window = _get_window_from_resource_id(output_id)
    var input_window = _get_window_from_resource_id(input_id)
    
    if not output_window or not input_window:
        _log_debug("Could not resolve windows for connection: %s -> %s" % [output_id, input_id])
        return
    
    # Calculate relative paths to the resources within their windows
    var output_res = Globals.desktop.get_resource(output_id)
    var input_res = Globals.desktop.get_resource(input_id)
    
    var output_path = str(output_window.get_path_to(output_res))
    var input_path = str(input_window.get_path_to(input_res))
    
    var cmd = ConnectCommandScript.new()
    cmd.setup(str(output_window.name), output_path, str(input_window.name), input_path)
    push_command(cmd)
    _log_debug("Recorded connection: %s(%s) -> %s(%s)" % [output_window.name, output_path, input_window.name, input_path])


## Handle connection deleted
func _on_connection_deleted(output_id: String, input_id: String) -> void:
    if not _enabled:
        return
    
    # Don't record if we're currently in an undo/redo operation
    if _is_undoing_or_redoing:
        return
    
    var output_window = _get_window_from_resource_id(output_id)
    var input_window = _get_window_from_resource_id(input_id)
    
    if not output_window or not input_window:
        _log_debug("Could not resolve windows for disconnection: %s -> %s" % [output_id, input_id])
        return
    
    # Calculate relative paths to the resources within their windows
    var output_res = Globals.desktop.get_resource(output_id)
    var input_res = Globals.desktop.get_resource(input_id)
    
    var output_path = str(output_window.get_path_to(output_res))
    var input_path = str(input_window.get_path_to(input_res))
    
    var cmd = DisconnectCommandScript.new()
    cmd.setup(str(output_window.name), output_path, str(input_window.name), input_path)
    push_command(cmd)
    _log_debug("Recorded disconnection: %s(%s) -> %s(%s)" % [output_window.name, output_path, input_window.name, input_path])


## Helper to find WindowContainer from Resource ID
func _get_window_from_resource_id(resource_id: String) -> WindowContainer:
    if not Globals.desktop:
        return null
        
    var resource = Globals.desktop.get_resource(resource_id)
    if not resource:
        return null
    
    # Traverse up to find WindowContainer
    var parent = resource.get_parent()
    while parent:
        if parent is WindowContainer:
            return parent
        parent = parent.get_parent()
        
    return null


## Handle window created (node spawned)
func _on_window_created(window: WindowContainer) -> void:
    if not _enabled:
        return
    
    # Don't record if we're currently in an undo/redo operation
    if _is_undoing_or_redoing:
        return
    
    # Only record if the window is actually in the tree
    if not window.is_inside_tree():
        return
    
    var cmd = NodeCreatedCommandScript.new()
    cmd.setup(str(window.name))
    push_command(cmd)
    _log_debug("Recorded window creation: %s" % window.name)


## Handle window deleted (node removed)
func _on_window_deleted(window: WindowContainer) -> void:
    if not _enabled:
        return
    
    # Don't record if we're currently in an undo/redo operation
    if _is_undoing_or_redoing:
        return
    
    # Capture window data before it's gone
    var export_data: Dictionary = {}
    if window.has_method("export"):
        export_data = window.export()
    
    var position = window.position
    var importing: bool = window.get("importing") if window.get("importing") != null else false
    
    var cmd = NodeDeletedCommandScript.new()
    cmd.setup(str(window.name), export_data, position, importing)
    push_command(cmd)
    _log_debug("Recorded window deletion: %s" % window.name)


## Flag to prevent recursive recording during undo/redo
var _is_undoing_or_redoing: bool = false


## Helper to find window by name
func _find_window_by_name(window_name: String) -> Node:
    if not Globals.desktop:
        return null
    var windows = Globals.desktop.get_node_or_null("Windows")
    if not windows:
        return null
    return windows.get_node_or_null(window_name)


# ==============================================================================
# HELPER METHODS FOR EXTENSION
# ==============================================================================

## Record a property change (convenience method)
## Usage: undo_manager.record_property_change(node, "position", old_val, new_val, "Move Node")
func record_property_change(target: Object, property: String, before, after, label: String = "") -> void:
    if not _enabled or not is_instance_valid(target):
        return
    var cmd = PropertyChangeCommand.new(target, property, before, after, label)
    push_command(cmd)


## Record a callable action (convenience method)
## Usage: undo_manager.record_call(do_func, undo_func, "Custom Action")
func record_call(do_func: Callable, undo_func: Callable, label: String = "") -> void:
    if not _enabled:
        return
    var cmd = CallableCommand.new(do_func, undo_func, label)
    push_command(cmd)


# ==============================================================================
# INNER CLASSES - Helper commands
# ==============================================================================

## Transaction command - wraps multiple commands as one undo step
class TransactionCommand extends RefCounted:
    var description: String
    var commands: Array
    
    func _init(desc: String, cmds: Array) -> void:
        description = desc
        commands = cmds
    
    func execute() -> bool:
        for cmd in commands:
            if not cmd.execute():
                return false
        return true
    
    func undo() -> bool:
        # Undo in reverse order
        for i in range(commands.size() - 1, -1, -1):
            if not commands[i].undo():
                return false
        return true
    
    func get_description() -> String:
        return description
    
    func is_valid() -> bool:
        for cmd in commands:
            if not cmd.is_valid():
                return false
        return true


## Property change command - for simple property changes
class PropertyChangeCommand extends RefCounted:
    var description: String
    var _target_ref: WeakRef
    var _property: String
    var _before
    var _after
    
    func _init(target: Object, property: String, before, after, label: String = "") -> void:
        _target_ref = weakref(target)
        _property = property
        _before = before
        _after = after
        description = label if label else "Change " + property
    
    func execute() -> bool:
        var target = _target_ref.get_ref()
        if not target:
            return false
        target.set(_property, _after)
        return true
    
    func undo() -> bool:
        var target = _target_ref.get_ref()
        if not target:
            return false
        target.set(_property, _before)
        return true
    
    func get_description() -> String:
        return description
    
    func is_valid() -> bool:
        return _target_ref.get_ref() != null


## Callable command - for custom do/undo functions
class CallableCommand extends RefCounted:
    var description: String
    var _do_func: Callable
    var _undo_func: Callable
    
    func _init(do_func: Callable, undo_func: Callable, label: String = "") -> void:
        _do_func = do_func
        _undo_func = undo_func
        description = label if label else "Custom Action"
    
    func execute() -> bool:
        if _do_func.is_valid():
            _do_func.call()
            return true
        return false
    
    func undo() -> bool:
        if _undo_func.is_valid():
            _undo_func.call()
            return true
        return false
    
    func get_description() -> String:
        return description
    
    func is_valid() -> bool:
        return _do_func.is_valid() and _undo_func.is_valid()


# ==============================================================================
# STICKY NOTE HANDLERS
# ==============================================================================

## Handle sticky note created
func _on_sticky_note_added(note: Control, record_creation: bool = true) -> void:
    if not _enabled: return
    
    # Connect note signals with bindings to pass the specific note instance
    if not note.drag_started.is_connected(_on_sticky_note_drag_started):
        note.drag_started.connect(_on_sticky_note_drag_started.bind(note))
    if not note.drag_ended.is_connected(_on_sticky_note_drag_ended):
        note.drag_ended.connect(_on_sticky_note_drag_ended.bind(note))
    if not note.selection_changed.is_connected(_on_sticky_note_selection_changed):
        note.selection_changed.connect(_on_sticky_note_selection_changed.bind(note))
    if not note.note_changed.is_connected(_on_sticky_note_changed_signal):
        note.note_changed.connect(_on_sticky_note_changed_signal.bind(note))
        
    if record_creation and not _is_undoing_or_redoing:
        var cmd = StickyNoteCreatedCommandScript.new()
        cmd.setup(_sticky_note_manager, note)
        push_command(cmd)
        _log_debug("Recorded sticky note creation: " + note.note_id)

## Handle sticky note deleted
func _on_sticky_note_removed(note_id: String, note_data: Dictionary) -> void:
    if not _enabled or _is_undoing_or_redoing: return
    
    var cmd = StickyNoteDeletedCommandScript.new()
    cmd.setup(_sticky_note_manager, note_id, note_data)
    push_command(cmd)
    _log_debug("Recorded sticky note deletion: " + note_id)

## Handle sticky note drag start
func _on_sticky_note_drag_started(note: Control) -> void:
    if not _enabled: return
    _sticky_note_drag_start_pos = note.position

## Handle sticky note drag end
func _on_sticky_note_drag_ended(note: Control) -> void:
    if not _enabled or _is_undoing_or_redoing: return
    
    if note.position.distance_to(_sticky_note_drag_start_pos) > 0.1:
        var cmd = StickyNoteMovedCommandScript.new()
        cmd.setup(_sticky_note_manager, note.note_id, _sticky_note_drag_start_pos, note.position)
        push_command(cmd)
        _log_debug("Recorded sticky note move: " + note.note_id)

## Handle sticky note selection change (for snapshotting data before edits)
func _on_sticky_note_selection_changed(selected: bool, note: Control) -> void:
    if not _enabled: return
    
    if selected:
        # Snapshot data when selected
        _sticky_note_clean_data[note.note_id] = note.get_data()
        _log_debug("Snapshotted note data for: " + note.note_id)

## Handle sticky note content change
func _on_sticky_note_changed_signal(note_id: String, note: Control) -> void:
    if not _enabled or _is_undoing_or_redoing: return
    
    # Check if we have a clean state
    if not _sticky_note_clean_data.has(note_id):
        return
        
    var before = _sticky_note_clean_data[note_id]
    var after = note.get_data()
    
    # Check for meaningful diff (ignoring position, as MovedCommand handles that)
    # We create copies to strictly compare non-position data
    var before_check = before.duplicate()
    var after_check = after.duplicate()
    
    # Remove fields handled by other commands or transient
    before_check.erase("position")
    after_check.erase("position")
    before_check.erase("id")
    after_check.erase("id")
    
    # If ONLY position changed (and id is same), it's a move, not an edit.
    # Compare fields robustly to ignore float noise
    var changed: bool = false
    for k in before_check.keys():
        var v1 = before_check[k]
        var v2 = after_check.get(k)
        
        if v1 is Vector2 and v2 is Vector2:
            if v1.distance_to(v2) > 0.1:
                changed = true
                break
        elif v1 is Array and v2 is Array and v1.size() == 2 and v2.size() == 2 and (v1[0] is float or v1[0] is int):
             # Handle serialized Vector2 (e.g. size [w, h])
             var vec1 = Vector2(v1[0], v1[1])
             var vec2 = Vector2(v2[0], v2[1])
             if vec1.distance_to(vec2) > 0.1:
                 changed = true
                 break
        elif v1 is Color and v2 is Color:
            if not v1.is_equal_approx(v2):
                changed = true
                break
        elif v1 != v2:
            changed = true
            break
            
    if not changed:
        # No meaningful change (only position or noise)
        _sticky_note_clean_data[note_id] = after
        return
    
    var cmd = StickyNoteChangedCommandScript.new()
    cmd.setup(_sticky_note_manager, note_id, before, after)
    push_command(cmd)
    
    # Update snapshot for subsequent changes
    _sticky_note_clean_data[note_id] = after


# ==============================================================================
# GROUP NODE HANDLERS
# ==============================================================================

## Check if new child is a window we should track
func _check_new_window(node: Node) -> void:
    if not _enabled: return
    _track_window(node)

## Attach listeners and snapshot window
func _track_window(window: Node) -> void:
    # Check if it has save method (implies data)
    if not window.has_method("save"):
        return
        
    var window_name = str(window.name)
    
    # Snapshot initial state
    _window_clean_data[window_name] = window.save()
    
    # Connect signals
    if window.has_signal("group_changed"):
        if not window.group_changed.is_connected(_on_group_node_changed.bind(window)):
            window.group_changed.connect(_on_group_node_changed.bind(window))
            

## Handle Group Node changes
func _on_group_node_changed(window: Node) -> void:
    if not _enabled or _is_undoing_or_redoing: return
    
    var window_name = str(window.name)
    var after = window.save()
    
    if not _window_clean_data.has(window_name):
        _window_clean_data[window_name] = after
        return
        
    var before = _window_clean_data[window_name]
    
    if before.hash() == after.hash():
        return
        
    var cmd = GroupNodeChangedCommandScript.new()
    cmd.setup(window_name, before, after)
    
    if _debug_enabled:
        ModLoaderLog.info("Group Change: " + str(cmd._changed_keys), LOG_NAME)
        
    push_command(cmd)
    
    _window_clean_data[window_name] = after
