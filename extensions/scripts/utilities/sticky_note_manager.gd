# ==============================================================================
# Taj's Mod - Upload Labs
# Sticky Note Manager - Manages all sticky notes on the canvas
# Author: TajemnikTV
# ==============================================================================
extends Node
class_name TajsStickyNoteManager

const LOG_NAME = "TajsModded:StickyNoteManager"
const StickyNoteScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/sticky_note.gd")

# References
var _config = null
var _desktop: Control = null
var _notes_container: Control = null
var _mod_main = null

# State
var _notes: Dictionary = {} # note_id -> TajsStickyNote
var _next_id: int = 0
var _debug_enabled := false

func setup(config, tree: SceneTree, mod_main = null) -> void:
    _config = config
    _mod_main = mod_main
    
    # Use Globals.desktop which is already set by the game
    if not is_instance_valid(Globals.desktop):
        ModLoaderLog.warning("Globals.desktop not available for sticky notes", LOG_NAME)
        return
    
    _desktop = Globals.desktop
    
    # Create container for notes (child of Desktop so it follows camera)
    _notes_container = Control.new()
    _notes_container.name = "StickyNotesContainer"
    _notes_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _notes_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    _notes_container.z_index = 5 # Above nodes but below windows
    _desktop.add_child(_notes_container)
    
    # Load existing notes
    load_notes()
    
    _log("Sticky Note Manager initialized")

func _log(message: String, force: bool = false) -> void:
    if force or _debug_enabled:
        ModLoaderLog.info(message, LOG_NAME)

func set_debug_enabled(enabled: bool) -> void:
    _debug_enabled = enabled

# ==============================================================================
# NOTE CRUD OPERATIONS
# ==============================================================================

func create_note_at_camera_center():
    # Get camera center position in world coordinates
    var camera_center = Globals.camera_center if Globals else Vector2(500, 300)
    return create_note(camera_center - Vector2(125, 75)) # Center the note

func create_note(world_pos: Vector2, note_size: Vector2 = Vector2(250, 150)):
    if not _notes_container:
        ModLoaderLog.warning("Notes container not ready", LOG_NAME)
        return null
    
    var note = StickyNoteScript.new()
    var note_id = _generate_id()
    
    note.set_note_id(note_id)
    note.position = world_pos
    note.size = note_size
    note.set_manager(self)
    
    # Connect signals
    note.note_changed.connect(_on_note_changed)
    note.note_deleted.connect(_on_note_deleted)
    note.note_duplicated.connect(_on_note_duplicated)
    
    _notes_container.add_child(note)
    _notes[note_id] = note
    
    _log("Created note: " + note_id)
    save_notes()
    
    # Notify user
    Signals.notify.emit("check", "Note created!")
    
    return note

func delete_note(note_id: String) -> void:
    if not _notes.has(note_id):
        return
    
    var note = _notes[note_id]
    _notes.erase(note_id)
    
    if is_instance_valid(note):
        note.queue_free()
    
    _log("Deleted note: " + note_id)
    save_notes()
    Signals.notify.emit("check", "Note deleted")

func duplicate_note(note_id: String, new_position: Vector2):
    if not _notes.has(note_id):
        return null
    
    var original = _notes[note_id]
    var data = original.get_data()
    
    var new_note = create_note(new_position, original.size)
    if new_note:
        new_note.set_title(data.get("title", ""))
        new_note.set_body(data.get("body", ""))
        new_note.set_note_color(Color.html(data.get("color", "#3a3a5080")))
        save_notes()
        Signals.notify.emit("check", "Note duplicated!")
    
    return new_note

func _generate_id() -> String:
    _next_id += 1
    return "note_%d_%d" % [Time.get_ticks_msec(), _next_id]

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_note_changed(note_id: String) -> void:
    save_notes()

func _on_note_deleted(note_id: String) -> void:
    delete_note(note_id)

func _on_note_duplicated(note_id: String, new_position: Vector2) -> void:
    duplicate_note(note_id, new_position)

# ==============================================================================
# PERSISTENCE
# ==============================================================================

func save_notes() -> void:
    if not _config:
        return
    
    var notes_data: Array = []
    for note_id in _notes:
        var note = _notes[note_id]
        if is_instance_valid(note):
            notes_data.append(note.get_data())
    
    _config.set_value("sticky_notes", notes_data)
    _log("Saved %d notes" % notes_data.size())

func load_notes() -> void:
    if not _config:
        return
    
    var notes_data = _config.get_value("sticky_notes", [])
    if not notes_data is Array:
        notes_data = []
    
    # Clear existing notes
    for note_id in _notes:
        var note = _notes[note_id]
        if is_instance_valid(note):
            note.queue_free()
    _notes.clear()
    
    # Recreate notes from data
    for data in notes_data:
        if data is Dictionary:
            _create_note_from_data(data)
    
    _log("Loaded %d notes" % _notes.size(), true)

func _create_note_from_data(data: Dictionary):
    if not _notes_container:
        return null
    
    var note = StickyNoteScript.new()
    note.load_from_data(data)
    note.set_manager(self)
    
    # Connect signals
    note.note_changed.connect(_on_note_changed)
    note.note_deleted.connect(_on_note_deleted)
    note.note_duplicated.connect(_on_note_duplicated)
    
    _notes_container.add_child(note)
    _notes[note.note_id] = note
    
    return note

# ==============================================================================
# PUBLIC API
# ==============================================================================

func get_note_count() -> int:
    return _notes.size()

func get_all_notes() -> Array:
    var result = []
    for note_id in _notes:
        if is_instance_valid(_notes[note_id]):
            result.append(_notes[note_id])
    return result

func clear_all_notes() -> void:
    for note_id in _notes.keys():
        delete_note(note_id)
    Signals.notify.emit("check", "All notes cleared")
