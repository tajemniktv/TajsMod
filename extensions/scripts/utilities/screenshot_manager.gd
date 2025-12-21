class_name ScreenshotManager
extends RefCounted

## Modular screenshot manager for capturing full desktop images
## Handles tiled capture at configurable quality levels

const LOG_NAME = "TajsModded:Screenshot"

# Quality settings
var quality: int = 2 # 0=Low, 1=Med, 2=High, 3=Original
var debug_mode: bool = false

# References
var _tree: SceneTree
var _ui # SettingsUI reference for hiding during capture

# Callbacks
var _log_callback: Callable # Optional debug log callback


func set_tree(tree: SceneTree) -> void:
    _tree = tree


func set_ui(ui_ref) -> void:
    _ui = ui_ref


func set_log_callback(callback: Callable) -> void:
    _log_callback = callback


func _log(message: String, force: bool = false) -> void:
    if _log_callback.is_valid():
        _log_callback.call(message, force)
    else:
        ModLoaderLog.info(message, LOG_NAME)


## Take a full desktop screenshot with current quality settings
func take_screenshot() -> void:
    _log("Taking full desktop screenshot...")
    
    # Get desktop and calculate bounds of all windows
    var desktop = Globals.desktop if is_instance_valid(Globals.desktop) else null
    if !desktop:
        _log("ERROR: Desktop not found!", true)
        Signals.notify.emit("exclamation", "Could not capture - desktop not found")
        return
    
    var windows_container = desktop.get_node_or_null("Windows")
    if !windows_container:
        _log("ERROR: Windows container not found!", true)
        Signals.notify.emit("exclamation", "Could not capture - no windows")
        return
    
    # Calculate bounding rect of all windows
    var bounds = Rect2()
    var first = true
    for child in windows_container.get_children():
        if child is Control:
            var child_rect = Rect2(child.position, child.size)
            if first:
                bounds = child_rect
                first = false
            else:
                bounds = bounds.merge(child_rect)
    
    if first:
        _log("No windows to capture", true)
        Signals.notify.emit("exclamation", "No windows to capture")
        return
    
    _log("Bounds: " + str(bounds.size))
    
    # Quality settings: determines the capture zoom level and format
    # Grid hides at zoom <= 0.3, so minimum is 0.35 for grid visibility
    # Low=JPG 0.35x, Med=JPG 0.6x, High=PNG 0.8x, Original=PNG 1.5x
    var capture_zoom = [0.35, 0.6, 0.8, 1.5][quality]
    var use_jpg = quality < 2 # Low and Med use JPG
    
    # Hide HUD
    var hud = _tree.root.get_node_or_null("Main/HUD")
    var hud_was_visible = true
    if hud:
        hud_was_visible = hud.visible
        hud.visible = false
    
    # Also hide mod menu
    if _ui and _ui.is_visible():
        _ui.set_visible(false)
    
    # Get the main camera and save its state
    var main_camera = _tree.root.get_node_or_null("Main/Main2D/Camera2D")
    var saved_cam_pos = Vector2.ZERO
    var saved_cam_zoom = Vector2.ONE
    
    if !main_camera:
        _log("ERROR: Camera not found!", true)
        Signals.notify.emit("exclamation", "Camera not found")
        return
    
    saved_cam_pos = main_camera.position
    saved_cam_zoom = main_camera.zoom
    
    var viewport = _tree.root.get_viewport()
    var viewport_size = viewport.size
    
    # Calculate initial tile size in world coordinates
    var tile_world_size = viewport_size / capture_zoom
    
    # Add small padding to ensure edges are captured (15% of tile size)
    bounds = bounds.grow(max(tile_world_size.x, tile_world_size.y) * 0.15)
    
    # Calculate how many tiles we need
    var tiles_x = int(ceil(bounds.size.x / tile_world_size.x))
    var tiles_y = int(ceil(bounds.size.y / tile_world_size.y))
    
    # Calculate expected output size
    var final_width = int(tiles_x * viewport_size.x)
    var final_height = int(tiles_y * viewport_size.y)
    
    # If too large, reduce zoom to fit within limit
    var max_dimension = 16384
    if final_width > max_dimension or final_height > max_dimension:
        var scale_down = min(float(max_dimension) / final_width, float(max_dimension) / final_height)
        capture_zoom = capture_zoom * scale_down
        _log("Reduced zoom to " + str(capture_zoom) + " to fit size limit")
        
        # Recalculate tiles with new zoom
        tile_world_size = viewport_size / capture_zoom
        tiles_x = int(ceil(bounds.size.x / tile_world_size.x))
        tiles_y = int(ceil(bounds.size.y / tile_world_size.y))
        final_width = int(tiles_x * viewport_size.x)
        final_height = int(tiles_y * viewport_size.y)
    
    _log("Capturing " + str(tiles_x) + "x" + str(tiles_y) + " tiles at zoom " + str(snapped(capture_zoom, 0.01)))
    
    var final_image = Image.create(final_width, final_height, false, Image.FORMAT_RGBA8)
    final_image.fill(Color(0.12, 0.14, 0.18, 1.0)) # Dark blue background
    
    # Set camera zoom
    main_camera.zoom = Vector2(capture_zoom, capture_zoom)
    
    # Capture each tile
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            # Calculate camera position for this tile
            var tile_center = Vector2(
                bounds.position.x + (tx + 0.5) * tile_world_size.x,
                bounds.position.y + (ty + 0.5) * tile_world_size.y
            )
            main_camera.position = tile_center
            
            # Wait for render - extra frames for first tile to let nodes become visible
            await _tree.process_frame
            await _tree.process_frame
            if tx == 0 and ty == 0:
                # Extra frames for first tile (visibility culling needs time)
                await _tree.process_frame
                await _tree.process_frame
                await _tree.process_frame
            
            # Capture
            var tile_image = viewport.get_texture().get_image()
            tile_image.convert(Image.FORMAT_RGBA8) # Match format with final_image
            
            # Paste into final image
            var paste_x = tx * int(viewport_size.x)
            var paste_y = ty * int(viewport_size.y)
            final_image.blit_rect(tile_image, Rect2i(0, 0, int(viewport_size.x), int(viewport_size.y)), Vector2i(paste_x, paste_y))
    
    # Crop to actual bounds size (remove extra tile padding)
    var target_width = int(bounds.size.x * capture_zoom)
    var target_height = int(bounds.size.y * capture_zoom)
    if target_width < final_width or target_height < final_height:
        var cropped = Image.create(target_width, target_height, false, Image.FORMAT_RGBA8)
        cropped.blit_rect(final_image, Rect2i(0, 0, target_width, target_height), Vector2i.ZERO)
        final_image = cropped
        final_width = target_width
        final_height = target_height
        _log("Cropped to " + str(target_width) + "x" + str(target_height))
    else:
        _log("Final image: " + str(final_width) + "x" + str(final_height))
    
    # Restore camera
    main_camera.position = saved_cam_pos
    main_camera.zoom = saved_cam_zoom
    
    # Restore HUD
    if hud:
        hud.visible = hud_was_visible
    
    # Save the image
    var time = Time.get_datetime_string_from_system().replace(":", "-")
    var quality_names = ["low", "med", "high", "original"]
    var extension = ".jpg" if use_jpg else ".png"
    var path = "user://screenshots/fullboard_" + quality_names[quality] + "_" + time + extension
    DirAccess.make_dir_recursive_absolute("user://screenshots")
    
    if use_jpg:
        final_image.save_jpg(path, 0.85) # 85% quality for good compression
    else:
        final_image.save_png(path)
    
    _log("Full desktop saved: " + path, true)
    Signals.notify.emit("check", "Screenshot saved! (" + str(final_width) + "x" + str(final_height) + ")")


## Add screenshot UI section to a parent control
func add_screenshot_section(parent: Control, ui_builder, config_manager) -> void:
    var container = VBoxContainer.new()
    container.add_theme_constant_override("separation", 10)
    parent.add_child(container)
    
    var label = Label.new()
    label.text = "Screenshot Quality"
    label.add_theme_font_size_override("font_size", 28)
    container.add_child(label)
    
    var btn_row = HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 5)
    container.add_child(btn_row)
    
    var quality_names = ["Low", "Medium", "High", "Original"]
    var quality_buttons: Array[Button] = []
    
    for i in range(4):
        var btn = Button.new()
        btn.text = quality_names[i]
        btn.toggle_mode = true
        btn.theme_type_variation = "TabButton"
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.custom_minimum_size = Vector2(0, 50)
        btn.button_pressed = (i == quality)
        
        var idx = i
        var self_ref = self
        btn.pressed.connect(func():
            self_ref.quality = idx
            config_manager.set_value("screenshot_quality", idx)
            for j in range(quality_buttons.size()):
                quality_buttons[j].set_pressed_no_signal(j == idx)
        )
        
        btn_row.add_child(btn)
        quality_buttons.append(btn)
    
    # Take Screenshot button
    var take_btn = Button.new()
    take_btn.text = "📷 Take Screenshot"
    take_btn.theme_type_variation = "TabButton"
    take_btn.custom_minimum_size = Vector2(0, 60)
    take_btn.pressed.connect(take_screenshot)
    container.add_child(take_btn)
