# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Controller - Orchestrates palette input and lifecycle
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteController
extends Node

const LOG_NAME = "TajsModded:PaletteController"

# Script references
const CommandRegistryScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/command_registry.gd")
const ContextProviderScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/context_provider.gd")
const PaletteConfigScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_config.gd")
const PaletteOverlayScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_overlay.gd")
const DefaultCommandsScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/default_commands.gd")

# Wire Drop scripts
const WireDropHandlerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/wire_drop/wire_drop_handler.gd")
const WireDropConnectorScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/wire_drop/wire_drop_connector.gd")
const NodeCompatibilityFilterScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/wire_drop/node_compatibility_filter.gd")

# Components
var registry: RefCounted # TajsModCommandRegistry
var context: RefCounted # TajsModContextProvider
var palette_config: RefCounted # TajsModPaletteConfig
var overlay: CanvasLayer # TajsModPaletteOverlay

# Wire Drop components
var wire_drop_handler # TajsModWireDropHandler
var wire_drop_connector # TajsModWireDropConnector
var node_filter # TajsModNodeCompatibilityFilter

# External references
var mod_config # Main TajsModConfigManager
var mod_ui # TajsModSettingsUI
var mod_main # Reference to mod_main.gd for calling apply functions

# State
var _initialized: bool = false

signal palette_opened
signal palette_closed
signal command_executed(command_id: String)


func _init() -> void:
	name = "PaletteController"


func _ready() -> void:
	pass


## Initialize the palette system
func initialize(tree: SceneTree, config, ui = null, mod_main_ref = null) -> void:
	if _initialized:
		return
	
	mod_config = config
	mod_ui = ui
	mod_main = mod_main_ref
	
	# Create core components
	registry = CommandRegistryScript.new()
	context = ContextProviderScript.new()
	palette_config = PaletteConfigScript.new()
	
	# Set up context
	context.set_tree(tree)
	context.set_config(mod_config)
	
	# Create overlay
	overlay = PaletteOverlayScript.new()
	tree.root.add_child(overlay)
	overlay.setup(registry, context, palette_config)
	
	# Connect signals
	overlay.closed.connect(_on_palette_closed)
	overlay.command_executed.connect(_on_command_executed)
	overlay.node_selected.connect(_on_node_selected)
	
	# Initialize wire drop system
	_init_wire_drop_system(config)
	
	# Register default commands
	_register_default_commands()
	
	_initialized = true
	ModLoaderLog.info("Palette system initialized with %d commands" % registry.get_count(), LOG_NAME)


## Initialize wire drop detection and node spawning
func _init_wire_drop_system(config) -> void:
	# Create wire drop handler
	wire_drop_handler = WireDropHandlerScript.new()
	wire_drop_handler.setup(config)
	wire_drop_handler.wire_dropped_on_canvas.connect(_on_wire_dropped_on_canvas)
	
	# Create wire drop connector
	wire_drop_connector = WireDropConnectorScript.new()
	
	# Create node filter and build cache
	node_filter = NodeCompatibilityFilterScript.new()
	# Defer cache building to not block startup
	call_deferred("_build_node_filter_cache")
	
	ModLoaderLog.info("Wire drop system initialized", LOG_NAME)


func _build_node_filter_cache() -> void:
	node_filter.build_cache()


## Register all default commands
func _register_default_commands() -> void:
	# Pass necessary references to the command registrar
	var refs = {
		"mod_config": mod_config,
		"mod_ui": mod_ui,
		"mod_main": mod_main,
		"context": context,
		"palette_config": palette_config,
		"controller": self,
		"registry": registry
	}
	DefaultCommandsScript.register_all(registry, refs)


func _input(event: InputEvent) -> void:
	if not _initialized:
		return
	
	# Mouse button handling
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				toggle()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_XBUTTON1: # Mouse back button
				if is_open():
					overlay._go_back()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_XBUTTON2: # Mouse forward button
				if is_open():
					overlay._go_forward()
					get_viewport().set_input_as_handled()


## Toggle the palette
func toggle() -> void:
	if not _initialized or not overlay:
		return
	overlay.toggle_palette()


## Open the palette
func open() -> void:
	if not _initialized or not overlay:
		return
	overlay.show_palette()
	palette_opened.emit()


## Close the palette
func close() -> void:
	if not _initialized or not overlay:
		return
	overlay.hide_palette()


## Check if palette is currently open
func is_open() -> bool:
	return overlay and overlay.is_open()


## Get the command registry for external registration
func get_registry() -> RefCounted:
	return registry


## Get the context provider
func get_context() -> RefCounted:
	return context


## Set wire drop menu enabled state
func set_wire_drop_enabled(enabled: bool) -> void:
	if wire_drop_handler:
		wire_drop_handler.set_enabled(enabled)


## Handle wire dropped on empty canvas
func _on_wire_dropped_on_canvas(origin_info: Dictionary, drop_position: Vector2) -> void:
	if not overlay:
		return
	
	# Get compatible nodes for this pin
	var origin_shape: String = origin_info.get("connection_shape", "")
	var origin_color: String = origin_info.get("connection_color", "")
	var origin_is_output: bool = origin_info.get("is_output", true)
	
	var compatible: Array[Dictionary] = node_filter.get_compatible_nodes(origin_shape, origin_color, origin_is_output)
	
	if compatible.is_empty():
		Signals.notify.emit("exclamation", "No compatible nodes found")
		return
	
	# Show the node picker
	overlay.show_node_picker(compatible, origin_info, drop_position)


## Handle node selection from picker
func _on_node_selected(window_id: String, spawn_pos: Vector2, origin_info: Dictionary) -> void:
	if not wire_drop_connector:
		return
	
	# Spawn the node and connect
	wire_drop_connector.spawn_and_connect(window_id, spawn_pos, origin_info)


func _on_palette_closed() -> void:
	palette_closed.emit()


func _on_command_executed(command_id: String) -> void:
	command_executed.emit(command_id)
