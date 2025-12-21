extends "res://scenes/schematic_container.gd"

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
