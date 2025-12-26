# =============================================================================
# Taj's Mod - Upload Labs
# Screenshot Manager - Captures full desktop images
# Author: TajemnikTV
# =============================================================================
class_name ScreenshotManager
extends RefCounted

## Modular screenshot manager for capturing full desktop images
## Handles tiled capture at configurable quality levels

const LOG_NAME = "TajsModded:Screenshot"

# Quality settings
var quality: int = 2 # 0=Low, 1=Med, 2=High, 3=Original
const CAPTURE_DELAY: int = 5 # Frames to wait per tile for proper rendering
var screenshot_folder: String = "user://screenshots" # Configurable folder

# References
var _tree: SceneTree
var _ui # SettingsUI reference for hiding during capture
var _config # ConfigManager reference for saving settings

# Callbacks
var _log_callback: Callable # Optional debug log callback


func set_tree(tree: SceneTree) -> void:
    _tree = tree


func set_ui(ui_ref) -> void:
    _ui = ui_ref


func set_log_callback(callback: Callable) -> void:
    _log_callback = callback


func set_config(config_manager) -> void:
    _config = config_manager


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
    # Low=JPG 0.5x, Med=JPG 0.6x, High=PNG 0.8x, Original=PNG 1.5x
    var capture_zoom = [0.5, 0.6, 0.8, 1.5][quality]
    var use_jpg = quality < 2 # Low and Med use JPG
    
    # === DISABLE ALL INPUT AT VIEWPORT LEVEL ===
    # This is the way to prevent any input from affecting the capture
    var viewport = _tree.root.get_viewport()
    viewport.set_disable_input(true)
    
    # Show capturing notification (must be before we block everything)
    Signals.notify.emit("check", "Capturing screenshot... please wait")
    
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
    if !main_camera:
        _log("ERROR: Camera not found!", true)
        Signals.notify.emit("exclamation", "Camera not found")
        viewport.set_disable_input(false) # Re-enable input before returning
        return
    
    var saved_cam_pos = main_camera.position
    var saved_cam_zoom = main_camera.zoom
    var saved_target_zoom = main_camera.get("target_zoom") if main_camera.get("target_zoom") else saved_cam_zoom
    var saved_zooming = main_camera.get("zooming") if main_camera.get("zooming") != null else false
    
    # CRITICAL: Block ALL signals on the camera - this prevents scroll wheel input
    # Signals like movement_input, joystick_input connect to input handlers
    main_camera.set_block_signals(true)
    
    # Also disable all processing methods
    main_camera.set_process(false)
    main_camera.set_physics_process(false)
    main_camera.set_process_input(false)
    main_camera.set_process_unhandled_input(false)
    main_camera.set_process_unhandled_key_input(false)
    main_camera.set_process_shortcut_input(false)
    
    # Find and disable the dragger GUI element that handles scroll wheel
    var dragger = _tree.root.get_node_or_null("Main/Main2D/Dragger")
    var saved_dragger_mouse_filter = Control.MOUSE_FILTER_PASS
    if dragger and dragger is Control:
        saved_dragger_mouse_filter = dragger.mouse_filter
        dragger.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    # Disable the zooming animation state
    if main_camera.get("zooming") != null:
        main_camera.set("zooming", false)
    
    # Force background grid (Lines) to be visible during capture
    # Grid normally hides at low zoom levels, but we want it in all screenshots
    var lines_node = desktop.get_node_or_null("Lines")
    var saved_lines_visible = true
    if lines_node:
        saved_lines_visible = lines_node.visible
        lines_node.visible = true
    
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
    
    # Capture each tile
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            # Calculate camera position for this tile
            var tile_center = Vector2(
                bounds.position.x + (tx + 0.5) * tile_world_size.x,
                bounds.position.y + (ty + 0.5) * tile_world_size.y
            )
            
            # Set camera position and zoom
            main_camera.position = tile_center
            main_camera.zoom = Vector2(capture_zoom, capture_zoom)
            if main_camera.get("target_zoom") != null:
                main_camera.set("target_zoom", Vector2(capture_zoom, capture_zoom))
            
            # Wait for render
            var frames_to_wait = CAPTURE_DELAY
            if tx == 0 and ty == 0:
                # Extra frames for first tile (visibility culling needs time to initialize)
                frames_to_wait += 5
            
            for _frame in range(frames_to_wait):
                # Keep camera locked during wait
                main_camera.position = tile_center
                main_camera.zoom = Vector2(capture_zoom, capture_zoom)
                await _tree.process_frame
            
            # Force render sync and wait one more frame
            RenderingServer.force_sync()
            await _tree.process_frame
            
            # Final camera lock before capture
            main_camera.position = tile_center
            main_camera.zoom = Vector2(capture_zoom, capture_zoom)
            
            # Capture
            var tile_image = viewport.get_texture().get_image()
            tile_image.convert(Image.FORMAT_RGBA8)
            
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
    
    # === RESTORE ORIGINAL STATE ===
    # Re-enable viewport input
    viewport.set_disable_input(false)
    
    # Unblock signals on camera
    main_camera.set_block_signals(false)
    
    # Re-enable camera processing
    main_camera.set_process(true)
    main_camera.set_physics_process(true)
    main_camera.set_process_input(true)
    main_camera.set_process_unhandled_input(true)
    main_camera.set_process_unhandled_key_input(true)
    main_camera.set_process_shortcut_input(true)
    
    # Restore dragger mouse filter
    if dragger and dragger is Control:
        dragger.mouse_filter = saved_dragger_mouse_filter
    
    # Restore camera position/zoom
    main_camera.position = saved_cam_pos
    main_camera.zoom = saved_cam_zoom
    if main_camera.get("target_zoom") != null:
        main_camera.set("target_zoom", saved_target_zoom)
    if main_camera.get("zooming") != null:
        main_camera.set("zooming", saved_zooming)
    
    # Restore grid visibility
    if lines_node:
        lines_node.visible = saved_lines_visible
    
    # Restore HUD
    if hud:
        hud.visible = hud_was_visible
    
    # Save the image
    var time = Time.get_datetime_string_from_system().replace(":", "-")
    var quality_names = ["low", "med", "high", "original"]
    var extension = ".jpg" if use_jpg else ".png"
    var path = screenshot_folder.path_join("fullboard_" + quality_names[quality] + "_" + time + extension)
    DirAccess.make_dir_recursive_absolute(screenshot_folder)
    
    if use_jpg:
        # Low=80% quality, Medium=90% quality for good size/quality balance
        var jpg_quality = 0.80 if quality == 0 else 0.90
        final_image.save_jpg(path, jpg_quality)
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
    
    # Screenshot Folder Section
    var folder_section = VBoxContainer.new()
    folder_section.add_theme_constant_override("separation", 5)
    container.add_child(folder_section)
    
    var folder_label = Label.new()
    folder_label.text = "Screenshot Folder"
    folder_label.add_theme_font_size_override("font_size", 28)
    folder_section.add_child(folder_label)
    
    # Current folder path display
    var path_label = Label.new()
    path_label.text = _get_display_path()
    path_label.add_theme_font_size_override("font_size", 14)
    path_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    folder_section.add_child(path_label)
    
    # Folder button row
    var folder_btn_row = HBoxContainer.new()
    folder_btn_row.add_theme_constant_override("separation", 5)
    folder_section.add_child(folder_btn_row)
    
    var self_ref = self
    
    # Open folder button
    var open_btn = Button.new()
    open_btn.text = "📁 Open Folder"
    open_btn.theme_type_variation = "TabButton"
    open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    open_btn.custom_minimum_size = Vector2(0, 50)
    open_btn.pressed.connect(func():
        self_ref.open_screenshot_folder()
    )
    folder_btn_row.add_child(open_btn)
    
    # Change folder button
    var change_btn = Button.new()
    change_btn.text = "🔄 Change Folder"
    change_btn.theme_type_variation = "TabButton"
    change_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    change_btn.custom_minimum_size = Vector2(0, 50)
    change_btn.pressed.connect(func():
        self_ref._show_folder_dialog(path_label, config_manager)
    )
    folder_btn_row.add_child(change_btn)


## Get display-friendly path for the current screenshot folder
func _get_display_path() -> String:
    if screenshot_folder.begins_with("user://"):
        return ProjectSettings.globalize_path(screenshot_folder)
    return screenshot_folder


## Open the screenshot folder in the system file explorer
func open_screenshot_folder() -> void:
    DirAccess.make_dir_recursive_absolute(screenshot_folder)
    var global_path = screenshot_folder
    if screenshot_folder.begins_with("user://"):
        global_path = ProjectSettings.globalize_path(screenshot_folder)
    
    _log("Opening folder: " + global_path)
    var err = OS.shell_open(global_path)
    if err != OK:
        _log("Failed to open folder: " + str(err), true)
        Signals.notify.emit("exclamation", "Could not open folder")


## Show file dialog to change screenshot folder
func _show_folder_dialog(path_label: Label, config_manager) -> void:
    # Create FileDialog
    var dialog = FileDialog.new()
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.title = "Select Screenshot Folder"
    dialog.size = Vector2(800, 500)
    
    # Set initial path to current folder
    var initial_path = screenshot_folder
    if initial_path.begins_with("user://"):
        initial_path = ProjectSettings.globalize_path(initial_path)
    dialog.current_dir = initial_path
    
    var self_ref = self
    dialog.dir_selected.connect(func(dir: String):
        self_ref.screenshot_folder = dir
        config_manager.set_value("screenshot_folder", dir)
        path_label.text = dir
        self_ref._log("Screenshot folder changed to: " + dir, true)
        Signals.notify.emit("check", "Screenshot folder updated")
        dialog.queue_free()
    )
    
    dialog.canceled.connect(func():
        dialog.queue_free()
    )
    
    # Add to the tree and show
    if _tree:
        _tree.root.add_child(dialog)
        dialog.popup_centered()
