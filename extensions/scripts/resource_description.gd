# ==============================================================================
# Taj's Mod - Upload Labs
# Resource Description Extension - Adds Code properties to in-game tooltip
# Author: TajemnikTV
# ==============================================================================
extends "res://scripts/resource_description.gd"

# Dynamically load Code values from game source to stay in sync with updates
var _code_values: Dictionary = {}


func _ready() -> void:
    super ()
    _load_code_values()


func _load_code_values() -> void:
    # Load the window_commit.gd script to get the 'values' constant
    var commit_script = load("res://scenes/windows/window_commit.gd")
    if commit_script and "values" in commit_script:
        _code_values = commit_script.values.duplicate()
    else:
        # Fallback to known values if script loading fails
        _code_values = {
            "code_bugfix": 1.0,
            "code_optimization": 4.0,
            "code_application": 16.0,
            "code_driver": 64.0
        }

func update_resource() -> void:
    var resource: String = selected_resource.resource
    var variation: int = selected_resource.variation

    $InfoContainer/Name.text = Data.resources[resource].name
    $InfoContainer/Variations.visible = variation > 0
    if !Data.resources[resource].symbols.is_empty():
        $InfoContainer/Variations.text = Utils.get_resource_symbols(Data.resources[resource].symbols, variation)
    $InfoContainer/Description.text = Utils.format_description(tr(Data.resources[resource].description))

    # Check for File resources (original behavior)
    if Data.files.has(resource):
        $InfoContainer/FileInfoContainer.visible = true
        $InfoContainer/FileInfoContainer/Size.visible = true
        $InfoContainer/FileInfoContainer/Research.visible = true
        $InfoContainer/FileInfoContainer/Quality.text = tr("quality") + ": %.1f" % Utils.get_variation_quality_multiplier(variation)
        $InfoContainer/FileInfoContainer/Value.text = tr("value") + ": " + Utils.print_string(Utils.get_file_value(resource, variation), false)
        $InfoContainer/FileInfoContainer/Size.text = tr("size") + ": " + Utils.print_metric(Utils.get_file_size(resource, variation), false) + "b"
        $InfoContainer/FileInfoContainer/Research.text = tr("research") + ": " + Utils.print_string(Utils.get_file_research(resource, variation), false)
        return
    
    # Check for Code resources
    if _code_values.has(resource):
        $InfoContainer/FileInfoContainer.visible = true
        var base_value = _code_values[resource]
        var quality = Utils.get_code_value_multiplier(variation)
        var value = base_value * quality
        
        $InfoContainer/FileInfoContainer/Quality.text = tr("quality") + ": %.1f" % quality
        $InfoContainer/FileInfoContainer/Value.text = tr("value") + ": " + Utils.print_string(value, false)
        # Hide Size and Research for Code (not defined)
        $InfoContainer/FileInfoContainer/Size.visible = false
        $InfoContainer/FileInfoContainer/Research.visible = false
        return
    
    # Check if resource has "code" symbols (other code types not in _code_values)
    if Data.resources.has(resource) and Data.resources[resource].has("symbols"):
        if Data.resources[resource].symbols == "code":
            $InfoContainer/FileInfoContainer.visible = true
            var quality = Utils.get_code_value_multiplier(variation)
            var value = quality # Base value 1.0 for unknown code types
            
            $InfoContainer/FileInfoContainer/Quality.text = tr("quality") + ": %.1f" % quality
            $InfoContainer/FileInfoContainer/Value.text = tr("value") + ": " + Utils.print_string(value, false)
            $InfoContainer/FileInfoContainer/Size.visible = false
            $InfoContainer/FileInfoContainer/Research.visible = false
            return
    
    # Not a File or Code resource - hide properties
    $InfoContainer/FileInfoContainer.visible = false
