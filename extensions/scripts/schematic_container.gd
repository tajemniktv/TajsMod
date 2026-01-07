# =============================================================================
# Taj's Mod - Upload Labs
# Schematic Container - Handles schematic button logic and custom icon loading
# Author: TajemnikTV
# =============================================================================
extends "res://scenes/schematic_container.gd"


## Icon directories to search (in order of priority)
const ICON_DIRECTORIES: Array[String] = [
    "res://textures/icons/",
    "res://mods-unpacked/TajemnikTV-TajsModded/textures/icons/"
]


func _ready() -> void:
    Signals.deleted_schematic.connect(_on_delete_schematic)
    Signals.window_created.connect(_on_window_created)
    Signals.window_deleted.connect(_on_window_deleted)

    # Load icon from multiple possible locations
    var icon_name: String = Data.schematics[schematic].icon
    var icon_texture = _load_icon(icon_name)
    if icon_texture:
        $SchematicButton/Icon.texture = icon_texture
    else:
        # Fallback to blueprint if icon not found
        $SchematicButton/Icon.texture = load("res://textures/icons/blueprint.png")
        ModLoaderLog.warning("Could not find icon: " + icon_name, "TajsModded:SchematicContainer")


    $SchematicButton/InfoContainer/Name.text = schematic

    for i: String in Data.schematics[schematic].windows:
        var window_type: String = Data.schematics[schematic].windows[i].window
        if requirements.has(window_type):
            requirements[window_type] += 1
        else:
            requirements[window_type] = 1
        required += 1

    if $DetailsPanel/DetailsContainer.get_child_count() == 0:
        for i: String in requirements:
            # Validate that the window type exists in the game's attributes
            if not Attributes.window_attributes.has(i):
                ModLoaderLog.warning("Schematic '%s' contains unknown window type: %s (skipping)" % [schematic, i], "TajsModded:SchematicContainer")
                continue
            var instance: Control = load("res://scenes/schematic_window_container.tscn").instantiate()
            instance.window = i
            instance.required = requirements[i]
            $DetailsPanel/DetailsContainer.add_child(instance)

    update_all()


## Loads an icon texture from multiple directories
func _load_icon(icon_name: String) -> Texture2D:
    for dir_path in ICON_DIRECTORIES:
        var full_path = dir_path + icon_name + ".png"
        if ResourceLoader.exists(full_path):
            return load(full_path)
    return null


func update_all() -> void:
    # MOD MATCH: Use Globals.custom_node_limit check
    # Original: requirement_met = (Globals.max_window_count + required) <= Utils.MAX_WINDOW
    var limit = Globals.custom_node_limit
    var max_limit = Utils.MAX_WINDOW
    
    # If custom limit is set, use it. If -1, it's unlimited (conceptually infinite)
    if limit != -1:
        max_limit = limit
    else:
        # If unlimited, we effectively set max_limit to a number always larger than current + required
        # or just set requirement_met to true directly
        pass
        
    $SchematicButton/InfoContainer/Requirement.text = tr("nodes_required").replace("#", "%d" % required)
    
    if limit == -1:
         requirement_met = true
    else:
         requirement_met = (Globals.max_window_count + required) <= max_limit

    # Update color logic
    if requirement_met:
        $SchematicButton/InfoContainer/Requirement.add_theme_color_override("font_color", Color("a0c6cf"))
    else:
        $SchematicButton/InfoContainer/Requirement.add_theme_color_override("font_color", Color.RED)

    $SchematicButton/Add.disabled = !requirement_met
