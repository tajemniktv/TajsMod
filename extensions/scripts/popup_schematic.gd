# =============================================================================
# Taj's Mod - Upload Labs
# Popup Schematic - Handles schematic creation and saving logic
# Author: TajemnikTV
# =============================================================================
extends "res://scripts/popup_schematic.gd"

# Define extra icons to add
var _extra_icons_data = [
	{"name": "warehouse", "texture": "res://textures/icons/warehouse.png"},
	{"name": "robot_arm", "texture": "res://textures/icons/robot_arm.png"},
	{"name": "power_plant", "texture": "res://textures/icons/power_plant.png"},
	{"name": "storage", "texture": "res://textures/icons/storage.png"},
	{"name": "conveyor", "texture": "res://textures/icons/conveyor.png"}
]

# This list must allow growing with new icons
# We start with the known base icons to maintain index alignment
var _all_icon_names = ["blueprint", "globe", "processor", "research", "hacker", "code", "brain"]

func _ready() -> void:
	# Update our local name list
	for item in _extra_icons_data:
		_all_icon_names.append(item.name)

	# Add buttons physically to the scene
	var container = $PortalContainer/MainPanel/InfoContainer/IconsContainer
	if container.get_child_count() > 0:
		var template_btn = container.get_child(0)
		
		for item in _extra_icons_data:
			var new_btn = template_btn.duplicate()
			new_btn.name = "Btn_" + item.name.capitalize()
			new_btn.icon = load(item.texture)
			# Validate texture loading
			if not new_btn.icon:
				ModLoaderLog.error("Failed to load icon: " + item.texture, "TajsModded:PopupSchematic")
			
			new_btn.button_pressed = false
			container.add_child(new_btn)
			
	# Call super._ready() to connect ALL buttons (including new ones)
	super._ready()


func _on_save_pressed() -> void:
	# Override to use our extended list of names
	if icon_index >= 0 and icon_index < _all_icon_names.size():
		data["icon"] = _all_icon_names[icon_index]
	else:
		data["icon"] = "blueprint" # Fallback

	var schem_name: String = $PortalContainer/MainPanel/InfoContainer/Label.text
	if schem_name.is_empty():
		schem_name = "Schematic"
		
	# Call global Data save
	Data.save_schematic(schem_name, data)

	close()
	Sound.play("click2")
