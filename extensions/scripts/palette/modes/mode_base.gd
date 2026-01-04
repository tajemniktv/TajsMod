# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Mode Base - Abstract base class for palette modes
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteModeBase
extends RefCounted

## Emitted when the mode wants to display items
signal items_updated(items: Array)

## Emitted when the mode wants to update the breadcrumb
signal breadcrumb_changed(text: String)

## Emitted when the mode wants to close the palette
signal request_close()

## Emitted when a specific action completes
signal action_completed(data: Dictionary)

# Reference to the overlay (set by overlay when activating mode)
var overlay = null

# Mode state
var _is_active: bool = false


## Called when entering this mode
func enter() -> void:
	_is_active = true


## Called when exiting this mode
func exit() -> void:
	_is_active = false


## Check if mode is currently active
func is_active() -> bool:
	return _is_active


## Handle search/filter query
## Override in subclass to filter displayed items
func filter(query: String) -> void:
	pass


## Get the current breadcrumb text for this mode
func get_breadcrumb() -> String:
	return ""


## Get items to display
## Override in subclass to return mode-specific items
func get_items() -> Array[Dictionary]:
	return []


## Execute action on selected item
## Override in subclass to handle item selection
## Returns true if action was handled
func execute_selection(item: Dictionary) -> bool:
	return false


## Handle back navigation
## Returns true if mode handled the back action internally
## Returns false if overlay should exit this mode
func handle_back() -> bool:
	return false


## Create a result row for display
## Override in subclass for custom row rendering
## Returns null to use default row rendering
func create_custom_row(item: Dictionary, index: int) -> Control:
	return null


## Check if this mode wants to handle a specific input event
## Override for mode-specific input handling
func handle_input(event: InputEvent) -> bool:
	return false
