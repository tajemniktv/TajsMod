# =============================================================================
# Taj's Mod - Upload Labs
# Icon Browser - Manages the scrollable, searchable icon browser UI
# Author: TajemnikTV
# =============================================================================
class_name TajIconBrowser
extends RefCounted

## Signal emitted when an icon is selected
signal icon_selected(icon_name: String, icon_path: String)

## Icon directories to scan
const ICON_DIRECTORIES: Array[String] = [
	"res://textures/icons/",
	"res://mods-unpacked/TajemnikTV-TajsModded/textures/icons/"
]

## Icon data structure
class IconData:
	var name: String
	var path: String
	var texture: Texture2D
	
	func _init(p_name: String, p_path: String) -> void:
		name = p_name
		path = p_path

## All discovered icons
var all_icons: Array[IconData] = []
## Currently filtered icons
var filtered_icons: Array[IconData] = []
## Currently selected icon index
var selected_index: int = 0

## UI References
var search_input: LineEdit
var scroll_container: ScrollContainer
var icons_grid: GridContainer
var _icon_buttons: Array[Button] = []

## Configuration
const GRID_COLUMNS: int = 10
const ICON_SIZE: int = 64
const ICON_SPACING: int = 6
const MAX_VISIBLE_ICONS: int = 300 # Limit for performance

func _init() -> void:
	_scan_all_icons()

## Scans all icon directories and builds the icon list
func _scan_all_icons() -> void:
	all_icons.clear()
	var seen_names: Dictionary = {}
	
	for dir_path in ICON_DIRECTORIES:
		_scan_directory(dir_path, seen_names)
	
	# Sort icons alphabetically by name
	all_icons.sort_custom(func(a: IconData, b: IconData) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	
	filtered_icons = all_icons.duplicate()
	ModLoaderLog.info("Icon Browser: Discovered %d icons" % all_icons.size(), "TajsModded:IconBrowser")

## Scans a single directory for PNG icons
## Works in both editor and exported builds
func _scan_directory(dir_path: String, seen_names: Dictionary) -> void:
	# First try DirAccess (works in editor and for unpacked mod folders)
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var icon_name = file_name.get_basename()
				# Skip if we've already seen this icon name (base game takes priority)
				if not seen_names.has(icon_name):
					var full_path = dir_path + file_name
					all_icons.append(IconData.new(icon_name, full_path))
					seen_names[icon_name] = true
			file_name = dir.get_next()
		
		dir.list_dir_end()
		return
	
	# Fallback: For packed resources, use ResourceLoader to check known icon paths
	# In exported builds, we can't list directories, so we use a known list
	# This scans for .import files which indicate what resources exist
	ModLoaderLog.info("Falling back to resource check for: " + dir_path, "TajsModded:IconBrowser")
	
	# Try to load a manifest or known icons list for packed resources
	# For base game icons at res://textures/icons/, try loading directly
	if dir_path == "res://textures/icons/":
		_scan_base_game_icons(dir_path, seen_names)
	elif dir_path.contains("mods-unpacked"):
		_scan_mod_icons(dir_path, seen_names)

## Scan base game icons by checking known common icon names
func _scan_base_game_icons(dir_path: String, seen_names: Dictionary) -> void:
	# Base game has a known set of icons - we load them via resource check
	# Common base game icon names (extracted from the game's icon usage)
	var known_base_icons: Array[String] = [
		"blueprint", "cog", "eye_ball", "money", "bug", "puzzle", "reload",
		"magnifying_glass", "research", "speed", "cpu", "gpu", "network",
		"factory", "hacking", "coding", "battery", "time", "star", "warning",
		"check", "cross", "info", "download", "upload", "save", "load",
		"pause", "play", "stop", "forward", "backward", "plus", "minus",
		"lock", "unlock", "trash", "folder", "file", "copy", "paste",
		"cut", "undo", "redo", "home", "settings", "search", "filter",
		"sort", "grid", "list", "expand", "collapse", "maximize", "minimize"
	]
	
	for icon_name in known_base_icons:
		if seen_names.has(icon_name):
			continue
		var full_path = dir_path + icon_name + ".png"
		if ResourceLoader.exists(full_path):
			all_icons.append(IconData.new(icon_name, full_path))
			seen_names[icon_name] = true

## Scan mod icons directory using the pre-generated icon list
func _scan_mod_icons(dir_path: String, seen_names: Dictionary) -> void:
	# For mod icons, we use a curated list that's generated at export time
	# or check for common patterns
	var mod_icon_names: Array[String] = _get_mod_icon_list()
	
	for icon_name in mod_icon_names:
		if seen_names.has(icon_name):
			continue
		var full_path = dir_path + icon_name + ".png"
		if ResourceLoader.exists(full_path):
			all_icons.append(IconData.new(icon_name, full_path))
			seen_names[icon_name] = true

## Returns a list of mod icon names (curated from the icons folder)
## This list must be kept in sync with the actual icons in textures/icons/
func _get_mod_icon_list() -> Array[String]:
	# This is a representative subset - full list would be too long
	# The main icons that users would commonly search for
	return [
		"Keyboard", "Module-Puzzle-2", "Cog", "Check", "Delete", "Save",
		"Analytics-Bars-3-D", "Analytics-Graph-Lines-2", "Analytics-Pie-3",
		"Award-Trophy-1", "Award-Medal-4", "Award-Badge-Star",
		"Book-Open-Bookmark", "Book-Search", "Book-Star",
		"Browser-Page-Layout", "Browser-Com",
		"Button-Play", "Button-Stop", "Button-Loop", "Button-Fast-Forward-1",
		"Calculator", "Calendar-3", "Camera-Small", "Camera-Tripod",
		"Cash-Briefcase", "Cash-Network", "Cash-Payment-Bill",
		"Check-Badge", "Check-Square", "Checklist",
		"Cloud-Add", "Cloud-Data-Transfer", "Cloud-File", "Cloud-Loading",
		"Cog", "Cog-Search-1", "Cog-Hand-Give-1",
		"Computer-Chip-32", "Computer-Chip-Core", "Computer-Chip-Flash",
		"Controls-Pause", "Controls-Forward", "Controls-Previous",
		"Crypto-Currency-Bitcoin-Chip", "Crypto-Currency-Bitcoin-Code",
		"Database-1", "Database-2", "Database-Disable", "Database-Share-1",
		"Delete", "Delete-2", "Duplicate",
		"Email-Action-Add", "Email-Action-Search-1",
		"Factory-Building-1", "Factory-Industrial-Robot-Arm-1",
		"Filter-1", "Filter-2-1",
		"Floppy-Disk-1", "Flow-1", "Flow-Chart-Hierachy",
		"Folder-Add", "Folder-Share",
		"Gateway", "Gauge-Dashboard",
		"Gift-Box-1", "Gold-Bars",
		"Hard-Drive-1", "Harddrive-Download-2",
		"Information-Circle", "Insurance-Hand",
		"Keyboard", "Keyboard-Wireless", "Keyboard-Option",
		"Lab-Tube", "Lab-Tube-Experiment",
		"Laptop", "Laptop-Clock", "Laptop-Download",
		"Layout", "Layout-Dashboard", "Layout-Content",
		"Loading", "Loading-Circle", "Lock-5", "Lock-Shield",
		"Module-Puzzle-2", "Module-Three", "Module-Hands-Puzzle",
		"Monitor", "Monitor-Download", "Monitor-Flash", "Monitor-Sync",
		"Network-Browser", "Network-Pin", "Network-Search", "Network-Signal",
		"Notes-Book", "Notes-Tasks", "Notes-Upload",
		"Office-Chair", "Office-Drawer", "Office-Employee",
		"Power-Button", "Programming-Book", "Programming-Browser-1",
		"Receipt", "Receipt-Dollar",
		"Router-Signal", "Rss-Feed",
		"Safety-Float", "Satellite", "Scanner", "Science-Molecule",
		"Server-Add", "Server-Refresh-1", "Server-Share",
		"Settings-Slider-Desktop-Horizontal", "Shape-Cube", "Shapes",
		"Share", "Share-2", "Shield-Check-1",
		"Startup-Product-Rocket-Box", "Stopwatch",
		"Tag-Dollar", "Tags-1", "Tags-Favorite",
		"Time-Clock-Circle", "Timer-10", "Tool-Box",
		"Touch-Id", "Tracking",
		"Upload-Circle", "Usb-Cable", "User-Network",
		"Video-Call", "Video-Player-Movie",
		"Warehouse-Storage-2", "Web-Hook",
		"Wifi-Signal-2", "Wifi-Signal-4"
	]

## Builds the icon browser UI and injects it into the parent container
func build_ui(parent_container: Control) -> void:
	# Create search container with icon
	var search_container = HBoxContainer.new()
	search_container.name = "SearchContainer"
	search_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_container.add_theme_constant_override("separation", 8)
	
	# Create search icon - fixed size, no expansion
	var search_icon = TextureRect.new()
	search_icon.name = "SearchIcon"
	search_icon.custom_minimum_size = Vector2(28, 28)
	search_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	search_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	search_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	search_icon.modulate = Color(0.627, 0.776, 0.812) # Light blue tint
	var magnify_texture = load("res://textures/icons/magnifying_glass.png")
	if magnify_texture:
		search_icon.texture = magnify_texture
	search_container.add_child(search_icon)
	
	# Create search input with distinct styling
	search_input = LineEdit.new()
	search_input.name = "SearchInput"
	search_input.placeholder_text = "Search icons..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size = Vector2(0, 44)
	search_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.6, 0.7))
	search_input.text_changed.connect(_on_search_text_changed)
	search_container.add_child(search_input)
	
	# Create scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "IconScrollContainer"
	scroll_container.custom_minimum_size = Vector2(0, 350)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# Create icons grid - use expand fill for proper width
	icons_grid = GridContainer.new()
	icons_grid.name = "IconsGrid"
	icons_grid.columns = GRID_COLUMNS
	icons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icons_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icons_grid.add_theme_constant_override("h_separation", ICON_SPACING)
	icons_grid.add_theme_constant_override("v_separation", ICON_SPACING)
	
	scroll_container.add_child(icons_grid)
	
	# Add to parent - insert at the beginning
	parent_container.add_child(search_container)
	parent_container.move_child(search_container, 0)
	parent_container.add_child(scroll_container)
	parent_container.move_child(scroll_container, 1)
	
	# Build the initial icon grid
	_rebuild_icon_grid()

## Rebuilds the icon grid with current filtered icons
func _rebuild_icon_grid() -> void:
	# Clear existing buttons
	for btn in _icon_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_icon_buttons.clear()
	
	# Create buttons for filtered icons (limited for performance)
	var icons_to_show = filtered_icons.slice(0, MAX_VISIBLE_ICONS)
	
	for i in range(icons_to_show.size()):
		var icon_data = icons_to_show[i]
		var btn = _create_icon_button(icon_data, i)
		icons_grid.add_child(btn)
		_icon_buttons.append(btn)
	
	# Update selection
	_update_selection()

## Creates a single icon button
func _create_icon_button(icon_data: IconData, index: int) -> Button:
	var btn = Button.new()
	btn.name = "IconBtn_" + icon_data.name
	btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = true
	btn.theme_type_variation = "ButtonDarker"
	btn.add_theme_constant_override("icon_max_width", ICON_SIZE - 10)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.tooltip_text = icon_data.name.replace("-", " ").replace("_", " ")
	
	# Load icon texture (lazy loading)
	var texture = load(icon_data.path)
	if texture:
		btn.icon = texture
		icon_data.texture = texture
	
	btn.pressed.connect(_on_icon_button_pressed.bind(index))
	
	return btn

## Handles search text changes
func _on_search_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		filtered_icons = all_icons.duplicate()
	else:
		var search_lower = new_text.to_lower()
		filtered_icons.clear()
		for icon_data in all_icons:
			# Search in icon name (replace separators for better matching)
			var searchable_name = icon_data.name.to_lower().replace("-", " ").replace("_", " ")
			if searchable_name.contains(search_lower) or icon_data.name.to_lower().contains(search_lower):
				filtered_icons.append(icon_data)
	
	# Reset selection
	selected_index = 0
	_rebuild_icon_grid()

## Handles icon button press
func _on_icon_button_pressed(index: int) -> void:
	selected_index = index
	_update_selection()
	
	if index >= 0 and index < filtered_icons.size():
		var icon_data = filtered_icons[index]
		icon_selected.emit(icon_data.name, icon_data.path)

## Updates the visual selection state
func _update_selection() -> void:
	for i in range(_icon_buttons.size()):
		if is_instance_valid(_icon_buttons[i]):
			_icon_buttons[i].button_pressed = (i == selected_index)

## Gets the currently selected icon name
func get_selected_icon_name() -> String:
	if selected_index >= 0 and selected_index < filtered_icons.size():
		return filtered_icons[selected_index].name
	return "blueprint" # Fallback

## Sets the selected icon by name
func set_selected_icon(icon_name: String) -> void:
	for i in range(filtered_icons.size()):
		if filtered_icons[i].name == icon_name:
			selected_index = i
			_update_selection()
			return
	
	# If not found, try to find in all icons and update filter
	for i in range(all_icons.size()):
		if all_icons[i].name == icon_name:
			selected_index = 0
			# Clear search to show all icons
			if search_input:
				search_input.text = ""
				filtered_icons = all_icons.duplicate()
				_rebuild_icon_grid()
				# Now find and select
				for j in range(filtered_icons.size()):
					if filtered_icons[j].name == icon_name:
						selected_index = j
						_update_selection()
						return
			return

## Cleans up resources
func cleanup() -> void:
	for btn in _icon_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_icon_buttons.clear()
