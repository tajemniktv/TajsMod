# =============================================================================
# Taj's Mod - Upload Labs
# Patcher - Patches core game files
# Author: TajemnikTV
# =============================================================================
class_name TajsModPatcher
extends RefCounted

const LOG_NAME = "TajsModded:Patcher"

# We pass dependencies in method calls to keep this class stateless where possible
# or use global Singletons (Data, Globals) which are standard in this context.

static func inject_bin_window() -> void:
	if !Data.windows.has("bin"):
		Data.windows["bin"] = {
			"name": "Bin",
			"icon": "trash_bin",
			"description": "Deletes items.",
			"category": "utility",
			"sub_category": "organizer",
			"scene": "window_bin",
			"level": 0,
			"requirement": "",
			"hidden": false,
			"group": "",
			"data": {},
			"attributes": {
				"limit": - 1
			},
			"guide": ""
		}
		ModLoaderLog.info("Injected Bin Window into Data.windows", LOG_NAME)

static func sanitize_schematics() -> void:
	if !is_instance_valid(Data) or !Data.schematics:
		return

	var fixed_count = 0
	for schem_name in Data.schematics:
		var schem_data = Data.schematics[schem_name]
		if schem_data.has("windows") and schem_data["windows"] is Dictionary:
			var windows = schem_data["windows"]
			var keys_to_remove = []
			
			for key in windows:
				var win_entry = windows[key]
				if win_entry is Dictionary:
					if !win_entry.has("window"):
						# Attempt to fix from key (e.g. "Bin0" -> "bin")
						var inferred_window = _infer_window_type(key)
						if inferred_window != "" and Data.windows.has(inferred_window):
							win_entry["window"] = inferred_window
							ModLoaderLog.info("Fixed missing 'window' key for " + key + " in schematic " + schem_name, LOG_NAME)
							fixed_count += 1
						else:
							keys_to_remove.append(key)
							ModLoaderLog.warning("Removing corrupt window entry " + key + " in schematic " + schem_name, LOG_NAME)
			
			for k in keys_to_remove:
				windows.erase(k)

	if fixed_count > 0:
		ModLoaderLog.info("Sanitized schematics: Fixed " + str(fixed_count) + " entries.", LOG_NAME)

static func _infer_window_type(key: String) -> String:
	var regex = RegEx.new()
	regex.compile("^([a-zA-Z_]+)\\d*$")
	var result = regex.search(key)
	if result:
		var prefix = result.get_string(1).to_lower()
		if Data.windows.has(prefix):
			return prefix
		if Data.windows.has(prefix.to_lower()):
			return prefix.to_lower()
	return ""

static func patch_boot_screen(boot_node: Node, mod_version: String, icon_path: String) -> void:
	var name_label = boot_node.get_node_or_null("LogoContainer/Name")
	var init_label = boot_node.get_node_or_null("LogoContainer/Label")
	
	if name_label and !name_label.text.begins_with("Taj's Mod"):
		name_label.text = "Taj's Mod OS " + ProjectSettings.get_setting("application/config/version")
		
		if init_label:
			init_label.text = "Initializing - Mod v" + mod_version
			
		var logo_rect = boot_node.get_node_or_null("LogoContainer/Logo")
		if logo_rect and !logo_rect.has_node("TajsModIcon"):
			# Load explicitly from file to support exported zips where .import might be missing/invalid
			var custom_icon_tex: Texture2D = null
			if FileAccess.file_exists(icon_path):
				var image = Image.load_from_file(icon_path)
				if image:
					custom_icon_tex = ImageTexture.create_from_image(image)
			
			if custom_icon_tex:
				var new_icon = TextureRect.new()
				new_icon.name = "TajsModIcon"
				new_icon.texture = custom_icon_tex
				new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				
				var target_width = 500
				var target_height = 125
				
				new_icon.custom_minimum_size = Vector2(target_width, target_height)
				new_icon.size = Vector2(target_width, target_height)
				
				new_icon.position = Vector2(
					(logo_rect.size.x - new_icon.size.x) / 2,
					 - new_icon.size.y + 25
				)
				
				logo_rect.add_child(new_icon)

static func patch_desktop_script(desktop_script_path: String) -> bool:
	if !is_instance_valid(Globals.desktop):
		return false
		
	if Globals.desktop.get_script().resource_path == desktop_script_path:
		return true # Already patched

	ModLoaderLog.info("Attempting to safely patch Desktop script...", LOG_NAME)
	
	# Save state
	var old_resources = Globals.desktop.resources
	var old_connections = Globals.desktop.connections
	var old_win_selections = Globals.desktop.window_selections
	var old_grab_selections = Globals.desktop.grabber_selections
	
	# Apply
	var new_script = load(desktop_script_path)
	if new_script:
		Globals.desktop.set_script(new_script)
		
		# Restore state
		Globals.desktop.resources = old_resources
		Globals.desktop.connections = old_connections
		Globals.desktop.window_selections = old_win_selections
		Globals.desktop.grabber_selections = old_grab_selections
		
		ModLoaderLog.info("Desktop script patched successfully!", LOG_NAME)
		return true
	else:
		ModLoaderLog.error("Failed to load desktop patch script", LOG_NAME)
		return false
