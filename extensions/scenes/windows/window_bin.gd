extends "res://scenes/windows/window_bin.gd"

var _extra_inputs: Array[Control] = []

func _enter_tree() -> void:
    # 1. Unified Setup in _enter_tree
    # We setup BOTH Original and New inputs here.
    # This ensures they are ready for WindowBase's standard lifecycle mechanism (auto-restore).
    var original_input = get_node_or_null("PanelContainer/MainContainer/Input")
    var universal_script = load("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scenes/bin_input.gd")

    if original_input and universal_script:
        # A. Setup Original
        original_input.set_script(universal_script)
        
        # Ensure group membership for saving
        if !original_input.is_in_group("persistent_container"):
            original_input.add_to_group("persistent_container")
            
        # B. Setup New Inputs
        var parent_container = original_input.get_parent()
        for i in range(5):
            var new_input = original_input.duplicate()
            new_input.name = "Input_" + str(i + 2)
            
            new_input.set_script(universal_script)
            
            if !new_input.is_in_group("persistent_container"):
                new_input.add_to_group("persistent_container")
            
            parent_container.add_child(new_input)
            _extra_inputs.append(new_input)

    super._enter_tree()

func _ready() -> void:
    super._ready()
    
    # Ensure all inputs are actively ticking (so they receive items)
    var enable_tick = func(node):
        if "containers" in self and !containers.has(node):
             containers.append(node)
             
        if has_method("should_tick"):
            node.set_ticking(should_tick())
        else:
            node.set_ticking(true)

    # Original
    var original_input = get_node_or_null("PanelContainer/MainContainer/Input")
    if original_input:
        enable_tick.call(original_input)

    # New
    for input in _extra_inputs:
         enable_tick.call(input)

func process(delta: float) -> void:
    super.process(delta)
    # Empty extra inputs (Original is handled by super class process)
    for input in _extra_inputs:
        if input.has_method("pop_all"):
            input.pop_all()
