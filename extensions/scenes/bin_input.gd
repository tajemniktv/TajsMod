extends "res://scenes/resource_container.gd"

# MOD: Universal Receiver Logic
# We override shape and color getters to match whatever is trying to connect to us.

func get_connection_shape() -> String:
    # 1. Dragging logic (Connection Creation Phase)
    # If we are checking connection compatibility during drag
    if !Globals.connecting.is_empty() and Globals.desktop:
        var source = Globals.desktop.get_resource(Globals.connecting)
        if source and source != self:
             return source.get_connection_shape()

    # 2. Persistence logic (Connection Established Phase)
    # If we are already connected to a source (input is set), mirror it
    # so checks initiated by the Source (like _on_output_resource_set) pass.
    if input:
        return input.get_connection_shape()
             
    return super.get_connection_shape()

func get_connector_color() -> String:
    # 1. Dragging logic
    if !Globals.connecting.is_empty() and Globals.desktop:
        var source = Globals.desktop.get_resource(Globals.connecting)
        if source and source != self:
             return source.get_connector_color()

    # 2. Persistence logic
    if input:
        return input.get_connector_color()
             
    return super.get_connector_color()

func can_set(to: String) -> bool:
    # Check 1: Can we accept this resource? (Always yes for Bin)
    return true

func can_connect(to: ResourceContainer) -> bool:
    # Check 2: Can we connect to this container?
    # This overrides STRICT validation. 
    # Since we are Universal, we usually say YES.
    # Note: Logic in base class checks shape/color equality.
    # By returning true here, we bypass that check when WE are asked.
    # (When the other guy asks us, he uses his logic vs our get_connection_shape).
    return true

func should_tick() -> bool:
    # CRITICAL: Always return true so WindowBase enables ticking for us.
    # Base class returns false if transfer.size() == 0 (no outputs).
    # Since Bin is a sink, it has no outputs, but MUST tick to receive items.
    return true
