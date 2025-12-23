# =============================================================================
# Taj's Mod - Upload Labs
# Wire Color Overrides - User-configurable wire colors
# Author: TajemnikTV
# =============================================================================
class_name WireColorOverrides
extends RefCounted

## User-configurable wire color system
## Allows changing any wire/connector color via RGB picker

const LOG_NAME = "TajsModded:WireColors"

# All wire types organized by category
# Format: resource_id -> display_name
const CONFIGURABLE_WIRES = {
    # === Speeds / Processing ===
    "download_speed": "Download Speed",
    "upload_speed": "Upload Speed",
    "clock_speed": "Clock Speed",
    "gpu_speed": "GPU Speed",
    "code_speed": "Code Speed",
    "work_speed": "Work Speed",
    
    # === Resources ===
    "money": "Money",
    "research": "Research",
    "token": "Token",
    "power": "Power",
    "research_power": "Research Power",
    "contribution": "Contribution",
    
    # === Hacking ===
    "hack_power": "Hack Power",
    "hack_experience": "Hack Experience",
    "virus": "Virus",
    "trojan": "Trojan",
    "infected_computer": "Infected Computer",
    
    # === Data Types ===
    "bool": "Bool",
    "char": "Char",
    "int": "Int",
    "float": "Float",
    "bitflag": "Bitflag",
    "bigint": "BigInt",
    "decimal": "Decimal",
    "string": "String",
    "vector": "Vector",
    
    # === AI / Neural ===
    "ai": "AI",
    "neuron_text": "Neuron (Text)",
    "neuron_image": "Neuron (Image)",
    "neuron_sound": "Neuron (Sound)",
    "neuron_video": "Neuron (Video)",
    "neuron_program": "Neuron (Program)",
    "neuron_game": "Neuron (Game)",
    
    # === Boosts ===
    "boost_component": "Boost Component",
    "boost_research": "Boost Research",
    "boost_hack": "Boost Hack",
    "boost_code": "Boost Code",
    "overclock": "Overclock",
    
    # === Other ===
    "heat": "Heat",
    "vulnerability": "Vulnerability",
    "storage": "Storage",
    "corporation_data": "Corporation Data",
    "government_data": "Government Data",
    "litecoin": "Litecoin",
    "bitcoin": "Bitcoin",
    "ethereum": "Ethereum"
}

var _enabled: bool = true
var _config = null
var _original_colors: Dictionary = {} # resource_id -> original color name
var _custom_hex: Dictionary = {} # resource_id -> hex color string (saved to config)


func setup(config_manager) -> void:
    _config = config_manager
    
    # Load saved custom hex colors
    _custom_hex = _config.get_value("wire_colors_hex", {})
    
    # Store original colors for each configurable wire
    for resource_id in CONFIGURABLE_WIRES:
        if Data.resources.has(resource_id):
            _original_colors[resource_id] = Data.resources[resource_id].color
    
    # Recreate custom connectors from saved hex values
    for resource_id in _custom_hex:
        var hex = _custom_hex[resource_id]
        _ensure_custom_connector(resource_id, hex)


## Ensure a custom connector exists for this resource
func _ensure_custom_connector(resource_id: String, hex_color: String) -> void:
    var color_key = "custom_" + resource_id
    Data.connectors[color_key] = {
        "letter": resource_id.substr(0, 1).to_upper(),
        "color": hex_color
    }


## Apply all wire color overrides
func apply_overrides() -> void:
    for resource_id in _custom_hex:
        var color_key = "custom_" + resource_id
        if Data.resources.has(resource_id):
            Data.resources[resource_id].color = color_key


## Revert all wire color overrides to defaults
func revert_overrides() -> void:
    for resource_id in _original_colors:
        if Data.resources.has(resource_id):
            Data.resources[resource_id].color = _original_colors[resource_id]


## Toggle overrides on/off
func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    if enabled:
        apply_overrides()
    else:
        revert_overrides()


## Set color from Color object (main entry point for UI)
func set_color_from_rgb(resource_id: String, color: Color) -> void:
    var hex = color.to_html(false) # Get hex without alpha
    
    # Create/update custom connector
    _ensure_custom_connector(resource_id, hex)
    
    # Store hex and save to config
    _custom_hex[resource_id] = hex
    if _config:
        _config.set_value("wire_colors_hex", _custom_hex)
    
    # Apply immediately if enabled
    if _enabled and Data.resources.has(resource_id):
        Data.resources[resource_id].color = "custom_" + resource_id


## Get current color for a resource as Color
func get_color(resource_id: String) -> Color:
    # First check if we have a custom color saved
    if _custom_hex.has(resource_id):
        return Color(_custom_hex[resource_id])
    
    # Otherwise get from game data
    if Data.resources.has(resource_id):
        var color_name = Data.resources[resource_id].color
        if Data.connectors.has(color_name):
            return Color(Data.connectors[color_name].color)
    return Color.WHITE


## Get the original (default) color for a resource
func get_original_color(resource_id: String) -> Color:
    if _original_colors.has(resource_id):
        var color_name = _original_colors[resource_id]
        if Data.connectors.has(color_name):
            return Color(Data.connectors[color_name].color)
    return Color.WHITE


## Reset a specific resource to its original color
func reset_color(resource_id: String) -> void:
    # Remove from custom colors
    if _custom_hex.has(resource_id):
        _custom_hex.erase(resource_id)
        if _config:
            _config.set_value("wire_colors_hex", _custom_hex)
    
    # Restore original
    if _original_colors.has(resource_id) and Data.resources.has(resource_id):
        Data.resources[resource_id].color = _original_colors[resource_id]


## Get list of configurable wire types
func get_configurable_wires() -> Dictionary:
    return CONFIGURABLE_WIRES


## Check if overrides are enabled
func is_enabled() -> bool:
    return _enabled
