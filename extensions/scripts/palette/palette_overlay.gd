# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Overlay - Main UI for the command palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteOverlay
extends CanvasLayer

const LOG_NAME = "TajsModded:Palette"

const FuzzySearch = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/fuzzy_search.gd")
const Calculator = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/calculator.gd")
const NodeDefinitionPanel = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/node_definition_panel.gd")
const ResourceDefinitionPanel = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/resource_definition_panel.gd")
const ModifierDefinitionPanel = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modifier_definition_panel.gd")
const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

# Mode handlers
const CalculatorMode = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/calculator_mode.gd")
const HelpMode = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/help_mode.gd")
const PickerMode = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/picker_mode.gd")
const GroupPickerMode = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/group_picker_mode.gd")
const NotePickerMode = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/note_picker_mode.gd")

# References
var registry # TajsModCommandRegistry
var context # TajsModContextProvider
var palette_config # TajsModPaletteConfig
var node_metadata_service # TajsModNodeMetadataService

# UI Elements
var background: ColorRect
var panel: PanelContainer
var search_input: LineEdit
var results_container: VBoxContainer
var results_scroll: ScrollContainer
var breadcrumb_label: Label
var no_results_label: Label
var _node_def_panel: Control # NodeDefinitionPanel instance
var _resource_def_panel: Control # ResourceDefinitionPanel instance
var _modifier_def_panel: Control # ModifierDefinitionPanel instance
var _autocomplete_row: PanelContainer
var _autocomplete_text: RichTextLabel
var _autocomplete_hint: Label

# State
var _is_open: bool = false
var _current_path: Array[String] = [] # Current category navigation path
var _displayed_items: Array[Dictionary] = [] # Currently displayed commands
var _selected_index: int = 0
var _result_items: Array[Control] = [] # UI item references
var _debounce_timer: Timer
var _history_back: Array = [] # Navigation history for back button
var _history_forward: Array = [] # Navigation history for forward button
var _onboarding_hint: Control # Onboarding hint panel

# Definition Mode
var _def_mode: bool = false
var _resource_mode: bool = false
var _definition_query: String = ""
var _definition_results: Array = []
var _resource_from_def_mode: bool = false

# Node Picker Mode (for wire-drop feature)
var _picker_mode: bool = false
var _picker_origin_info: Dictionary = {}
var _picker_spawn_position: Vector2 = Vector2.ZERO
var _picker_nodes: Array[Dictionary] = []

# Group Picker Mode (for Jump to Group feature)
var _group_picker_mode: bool = false
var _group_picker_groups: Array = [] # Array of group node references

# Note Picker Mode (for Jump to Note feature)
var _note_picker_mode: bool = false
var _note_picker_notes: Array = [] # Array of sticky note references

# Calculator Mode (for inline math evaluation)
var _calc_mode: bool = false
var _calc_result: String = ""
var _calc_error: String = ""
var _calc_history: Array = [] # Array of {"expr": String, "result": String}
const CALC_MAX_HISTORY = 5

# Help Mode
var _help_mode: bool = false
var _help_detail_mode: bool = false
var _help_query: String = ""
var _help_detail_command_id: String = ""

# Autocomplete
var _autocomplete_suggestions: Array = []
var _autocomplete_index: int = 0

# Command cache (help + autocomplete)
var _command_cache: Array = [] # Array of command dictionaries
var _command_meta_cache: Dictionary = {} # id -> metadata
var _resource_cache: Array = [] # {id, name, raw_name, description}
var _resource_cache_built: bool = false
var _item_cache: Array = [] # {id, name, raw_name, description}
var _item_cache_built: bool = false

# Mode handler instances
var _calculator_mode_handler: TajsModCalculatorMode
var _help_mode_handler: TajsModHelpMode
var _picker_mode_handler: TajsModPickerMode
var _group_picker_mode_handler: TajsModGroupPickerMode
var _note_picker_mode_handler: TajsModNotePickerMode

# Styling
const PANEL_WIDTH = 600
const PANEL_HEIGHT = 500
const ITEM_HEIGHT = 50
const MAX_VISIBLE_ITEMS = 10

# Colors
const COLOR_BG_DIM = Color(0, 0, 0, 0.6)
const COLOR_SELECTED = Color(0.2, 0.4, 0.6, 0.8)
const COLOR_HOVER = Color(0.15, 0.25, 0.35, 0.5)
const COLOR_BADGE_SAFE = Color(0.3, 0.7, 0.4)
const COLOR_BADGE_OPTIN = Color(0.85, 0.65, 0.2)
const COLOR_BADGE_GAMEPLAY = Color(0.8, 0.3, 0.3)
const COLOR_TEXT_SHADOW = Color(0, 0, 0, 0.8)
const COLOR_TEXT_GLOW = Color(0.4, 0.65, 1.0, 0.5)

signal command_executed(command_id: String)
signal node_selected(window_id: String, spawn_pos: Vector2, origin_info: Dictionary)
signal group_selected(group) # Emitted when a group is selected in group picker mode
signal note_picker_selected(note) # Emitted when a note is selected in note picker mode
signal closed
signal opened


func _init() -> void:
    layer = 100 # Above most UI
    name = "TajsModPalette"


func _ready() -> void:
    _build_ui()
    _setup_debounce()
    _setup_mode_handlers()
    # Ensure palette starts hidden
    _is_open = false
    visible = false


func _setup_mode_handlers() -> void:
    # Initialize mode handlers
    _calculator_mode_handler = CalculatorMode.new()
    _calculator_mode_handler.overlay = self
    _calculator_mode_handler.items_updated.connect(_on_mode_items_updated)
    _calculator_mode_handler.breadcrumb_changed.connect(_on_mode_breadcrumb_changed)
    _calculator_mode_handler.request_close.connect(hide_palette)
    _calculator_mode_handler.action_completed.connect(_on_mode_action_completed)
    
    _help_mode_handler = HelpMode.new()
    _help_mode_handler.overlay = self
    _help_mode_handler.items_updated.connect(_on_mode_items_updated)
    _help_mode_handler.breadcrumb_changed.connect(_on_mode_breadcrumb_changed)
    _help_mode_handler.request_close.connect(hide_palette)
    _help_mode_handler.action_completed.connect(_on_mode_action_completed)
    
    _picker_mode_handler = PickerMode.new()
    _picker_mode_handler.overlay = self
    _picker_mode_handler.items_updated.connect(_on_mode_items_updated)
    _picker_mode_handler.breadcrumb_changed.connect(_on_mode_breadcrumb_changed)
    _picker_mode_handler.request_close.connect(hide_palette)
    _picker_mode_handler.node_selected.connect(_on_picker_node_selected)
    
    _group_picker_mode_handler = GroupPickerMode.new()
    _group_picker_mode_handler.overlay = self
    _group_picker_mode_handler.items_updated.connect(_on_mode_items_updated)
    _group_picker_mode_handler.breadcrumb_changed.connect(_on_mode_breadcrumb_changed)
    _group_picker_mode_handler.request_close.connect(hide_palette)
    _group_picker_mode_handler.group_selected.connect(_on_group_picker_selected)
    
    _note_picker_mode_handler = NotePickerMode.new()
    _note_picker_mode_handler.overlay = self
    _note_picker_mode_handler.items_updated.connect(_on_mode_items_updated)
    _note_picker_mode_handler.breadcrumb_changed.connect(_on_mode_breadcrumb_changed)
    _note_picker_mode_handler.request_close.connect(hide_palette)
    _note_picker_mode_handler.note_selected.connect(_on_note_picker_selected)


## Handle mode items updated signal
func _on_mode_items_updated(items: Array) -> void:
    # Clear existing items
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    # Convert untyped array to typed Array[Dictionary]  
    _displayed_items.clear()
    for item in items:
        _displayed_items.append(item)
    _selected_index = 0
    
    no_results_label.visible = items.is_empty()
    
    # Use mode's custom row rendering if available
    var active_mode = _get_active_mode_handler()
    
    for i in range(items.size()):
        var item = items[i]
        var row: Control = null
        
        # Try custom row from mode handler
        if active_mode:
            row = active_mode.create_custom_row(item, i)
        
        # Fall back to default row
        if not row:
            row = _create_result_row(item, i)
        
        row.mouse_entered.connect(func(): _on_item_hover(i))
        row.gui_input.connect(func(event): _on_item_click(event, i))
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


## Handle mode breadcrumb change signal
func _on_mode_breadcrumb_changed(text: String) -> void:
    breadcrumb_label.text = text


## Handle mode action completed signal
func _on_mode_action_completed(data: Dictionary) -> void:
    var action = data.get("action", "")
    match action:
        "fill_expression", "insert_text":
            var text = data.get("text", "")
            search_input.text = text
            search_input.caret_column = search_input.text.length()
            _perform_search()


## Handle picker node selected
func _on_picker_node_selected(node_id: String, spawn_pos: Vector2, origin_info: Dictionary) -> void:
    node_selected.emit(node_id, spawn_pos, origin_info)


## Handle group picker selected
func _on_group_picker_selected(group) -> void:
    group_selected.emit(group)


## Handle note picker selected
func _on_note_picker_selected(note) -> void:
    note_picker_selected.emit(note)


## Get the currently active mode handler, or null if none
func _get_active_mode_handler():
    if _calc_mode and _calculator_mode_handler:
        return _calculator_mode_handler
    if _help_mode and _help_mode_handler:
        return _help_mode_handler
    if _picker_mode and _picker_mode_handler:
        return _picker_mode_handler
    if _group_picker_mode and _group_picker_mode_handler:
        return _group_picker_mode_handler
    if _note_picker_mode and _note_picker_mode_handler:
        return _note_picker_mode_handler
    return null


func _input(event: InputEvent) -> void:
    if not _is_open:
        return
    
    # Handle mouse back button globally when palette is open
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_XBUTTON1:
            if _resource_mode:
                # Check which sub-panel is visible
                if _modifier_def_panel and _modifier_def_panel.visible:
                    _on_modifier_panel_back()
                else:
                    _on_resource_panel_back()
                get_viewport().set_input_as_handled()
            elif _def_mode:
                # Exit def mode back to search results
                _exit_def_mode()
                get_viewport().set_input_as_handled()
            elif _help_mode or _calc_mode or _picker_mode or _group_picker_mode or _note_picker_mode or not _current_path.is_empty():
                # Exit any special mode or navigate back in category hierarchy
                _go_back()
                get_viewport().set_input_as_handled()


func setup(reg, ctx, config, meta_service = null, wire_colors_ref = null) -> void:
    registry = reg
    context = ctx
    palette_config = config
    node_metadata_service = meta_service
    
    if registry and registry.has_signal("commands_changed"):
        if not registry.commands_changed.is_connected(_on_commands_changed):
            registry.commands_changed.connect(_on_commands_changed)
    _rebuild_command_cache()
    
    # Setup help mode handler with references
    if _help_mode_handler:
        _help_mode_handler.setup_references(registry, context, _command_cache, _command_meta_cache)
    
    if _node_def_panel and wire_colors_ref:
        _node_def_panel.set_wire_colors(wire_colors_ref)


## Show node definition panel
func show_node_definition(node_id: String) -> void:
    if not node_metadata_service:
        Signals.notify.emit("exclamation", "Metadata service not available")
        return
    
    var details = node_metadata_service.get_node_details(node_id)
    if details.is_empty():
        Signals.notify.emit("exclamation", "Could not load node details")
        return
        
    _def_mode = true
    
    # Hide palette panel, show def panel
    # We hide the whole palette so the def panel (overlay child) is visible clearly
    panel.visible = false
    _node_def_panel.visible = true
    
    _node_def_panel.display_node(details)
    
    # Update UI state
    breadcrumb_label.text = "📘 Definition: " + details.get("name", "Unknown")
    # search_input.editable = false # Not needed if panel is hidden
    
    # Clean up selection
    _selected_index = -1
    _update_selection()


func _on_def_panel_back() -> void:
    _exit_def_mode()


## Enter node browser mode to show all available nodes
func enter_node_browser() -> void:
    search_input.placeholder_text = "Filter nodes..."
    _perform_node_search("")
    Sound.play("click")


func _exit_def_mode() -> void:
    if not _def_mode:
        return
        
    _def_mode = false
    
    # Restore UI
    panel.visible = true
    _node_def_panel.visible = false
    
    search_input.editable = true
    search_input.grab_focus()
    
    # Update breadcrumbs (simplified reset)
    if _picker_mode:
        _update_picker_breadcrumbs()
    elif _group_picker_mode:
        _update_group_picker_breadcrumbs()
    elif _note_picker_mode:
        _update_note_picker_breadcrumbs()
    else:
        _update_breadcrumbs()


## Restore definition results after viewing a resource (when _resource_from_def_mode is true)
func _restore_definition_results() -> void:
    # Restore the search input and display previous results
    if not _definition_query.is_empty():
        search_input.text = "def " + _definition_query
    else:
        search_input.text = "def "
    _perform_node_search(_definition_query)
    search_input.grab_focus()


## Handle port click from NodeDefinitionPanel - show resource info
func _on_port_clicked(resource_id: String, shape: String, color: String, label: String, applied_modifiers: Array = []) -> void:
    # Show resource definition panel
    _node_def_panel.visible = false
    _resource_def_panel.visible = true
    _resource_mode = true
    
    # Pass wire colors if available
    if _node_def_panel.has_method("_wire_colors"):
        _resource_def_panel.set_wire_colors(_node_def_panel._wire_colors)
    
    _resource_def_panel.display_resource(resource_id, shape, color, label, applied_modifiers)
    
    # Update breadcrumb
    breadcrumb_label.text = "📊 Resource: " + label


## Handle modifier click from NodeDefinitionPanel - show modifier info
func _on_modifier_clicked(modifier_id: String) -> void:
    if modifier_id.is_empty():
        return
    
    _node_def_panel.visible = false
    _modifier_def_panel.visible = true
    _resource_mode = true # Use resource_mode flag to track we're in a sub-panel
    
    _modifier_def_panel.display_modifier(modifier_id)
    breadcrumb_label.text = "📋 Modifier: " + modifier_id.capitalize()


## Handle back from ModifierDefinitionPanel - return to NodeDefinitionPanel
func _on_modifier_panel_back() -> void:
    _resource_mode = false
    _modifier_def_panel.visible = false
    _node_def_panel.visible = true
    
    # Restore def mode breadcrumb
    breadcrumb_label.text = "📘 Definition"


## Handle "Show Nodes that Add Modifier" button from ModifierDefinitionPanel
func _on_show_nodes_that_add_modifier(modifier_id: String) -> void:
    # Exit modifier panel
    _resource_mode = false
    _def_mode = false
    _modifier_def_panel.visible = false
    _node_def_panel.visible = false
    panel.visible = true
    
    # Get nodes that add this modifier from our hardcoded mapping
    var controller = get_parent()
    if controller and controller.has_method("get_node_metadata_service"):
        var service = controller.get_node_metadata_service()
        if service:
            # Search for nodes that have this modifier in their modifiers_added
            var matching_nodes: Array[Dictionary] = []
            var all_nodes = service.get_all_nodes()
            
            for node_summary in all_nodes:
                var details = service.get_node_details(node_summary.get("id", ""))
                var mods = details.get("modifiers_added", [])
                for mod in mods:
                    if str(mod.get("id", "")).to_lower() == modifier_id.to_lower():
                        matching_nodes.append(node_summary)
                        break
            
            if matching_nodes.is_empty():
                Signals.notify.emit("exclamation", "No nodes found that add this modifier")
                return
            
            _display_picker_nodes(matching_nodes)
            breadcrumb_label.text = "🔍 Nodes that add: " + modifier_id.capitalize()
            search_input.placeholder_text = "Filter nodes..."
            search_input.grab_focus()
    else:
        Signals.notify.emit("exclamation", "Metadata service not available")


## Handle back from ResourceDefinitionPanel - return to NodeDefinitionPanel
func _on_resource_panel_back() -> void:
    if _resource_from_def_mode:
        _resource_mode = false
        _resource_from_def_mode = false
        _resource_def_panel.visible = false
        panel.visible = true
        _restore_definition_results()
        return
    
    _resource_mode = false
    _resource_def_panel.visible = false
    _node_def_panel.visible = true
    
    # Restore def mode breadcrumb
    breadcrumb_label.text = "📘 Definition"


## Handle "Show Nodes with Input" button
func _on_show_inputs(shape: String, color: String) -> void:
    _exit_resource_mode()
    _show_nodes_with_port(shape, color, true)


## Handle "Show Nodes with Output" button
func _on_show_outputs(shape: String, color: String) -> void:
    _exit_resource_mode()
    _show_nodes_with_port(shape, color, false)


func _exit_resource_mode() -> void:
    _resource_mode = false
    _def_mode = false
    _resource_def_panel.visible = false
    _modifier_def_panel.visible = false
    _node_def_panel.visible = false
    panel.visible = true


## Show filtered nodes with a specific port type
func _show_nodes_with_port(shape: String, color: String, is_input: bool) -> void:
    # Get compatible nodes from the filter
    var controller = get_parent()
    if controller and controller.has_method("get_node_filter"):
        var filter = controller.get_node_filter()
        if filter:
            var nodes: Array[Dictionary]
            if is_input:
                nodes = filter.get_nodes_with_input(shape, color)
            else:
                nodes = filter.get_nodes_with_output(shape, color)
            
            if nodes.is_empty():
                Signals.notify.emit("exclamation", "No nodes found with this port type")
                return
            
            # Display as picker results
            _display_picker_nodes(nodes)
            breadcrumb_label.text = "🔍 Nodes with %s (%s)" % [shape, "Input" if is_input else "Output"]
            search_input.placeholder_text = "Filter nodes..."
            search_input.grab_focus()
    else:
        Signals.notify.emit("exclamation", "Filter not available")


## Apply glow styling to a label for a polished look
func _apply_text_style(label: Label, use_glow: bool = true) -> void:
    # Glow effect via outline
    if use_glow:
        label.add_theme_constant_override("outline_size", 5)
        label.add_theme_color_override("font_outline_color", COLOR_TEXT_GLOW)

func _build_ui() -> void:
    # Load game's main theme for consistent styling
    var game_theme: Theme = null
    if ResourceLoader.exists("res://themes/main.tres"):
        game_theme = load("res://themes/main.tres")
    
    # Background dim
    background = ColorRect.new()
    background.name = "Background"
    background.color = COLOR_BG_DIM
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_STOP
    background.gui_input.connect(_on_background_input)
    add_child(background)
    
    # Main panel
    panel = PanelContainer.new()
    panel.name = "Panel"
    panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = - PANEL_WIDTH / 2
    panel.offset_right = PANEL_WIDTH / 2
    panel.offset_top = - PANEL_HEIGHT / 2
    panel.offset_bottom = PANEL_HEIGHT / 2
    
    # Apply game theme for fonts
    if game_theme:
        panel.theme = game_theme
    
    # Apply styling
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
    style.border_color = Color(0.3, 0.5, 0.7, 0.6)
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0, 0, 0, 0.5)
    style.shadow_size = 10
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    panel.add_child(vbox)
    
    # Header with search
    var header = _create_header()
    vbox.add_child(header)
    
    # Results area
    results_scroll = ScrollContainer.new()
    results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vbox.add_child(results_scroll)
    
    results_container = VBoxContainer.new()
    results_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    results_container.add_theme_constant_override("separation", 2)
    results_scroll.add_child(results_container)
    
    # Autocomplete hint row (top of results)
    _autocomplete_row = _create_autocomplete_row()
    _autocomplete_row.visible = false
    results_container.add_child(_autocomplete_row)
    
    # No results label
    no_results_label = Label.new()
    no_results_label.text = "No results found"
    no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    no_results_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    no_results_label.add_theme_font_size_override("font_size", 18)
    no_results_label.visible = false
    
    # Node Definition Panel
    _node_def_panel = NodeDefinitionPanel.new()
    _node_def_panel.visible = false
    _node_def_panel.back_requested.connect(_on_def_panel_back)
    _node_def_panel.close_requested.connect(hide_palette)
    _node_def_panel.port_clicked.connect(_on_port_clicked)
    _node_def_panel.modifier_clicked.connect(_on_modifier_clicked)
    
    # Add node def panel to OVERLAY, not VBOX, so it can be larger than the palette
    _node_def_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    # 10% margins for nearly fullscreen
    _node_def_panel.anchor_left = 0.1
    _node_def_panel.anchor_top = 0.1
    _node_def_panel.anchor_right = 0.9
    _node_def_panel.anchor_bottom = 0.9
    _node_def_panel.offset_left = 0
    _node_def_panel.offset_top = 0
    _node_def_panel.offset_right = 0
    _node_def_panel.offset_bottom = 0
    
    add_child(_node_def_panel)
    
    # Resource Definition Panel
    _resource_def_panel = ResourceDefinitionPanel.new()
    _resource_def_panel.visible = false
    _resource_def_panel.back_requested.connect(_on_resource_panel_back)
    _resource_def_panel.show_inputs_requested.connect(_on_show_inputs)
    _resource_def_panel.show_outputs_requested.connect(_on_show_outputs)
    
    # Same layout as node def panel
    _resource_def_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _resource_def_panel.anchor_left = 0.1
    _resource_def_panel.anchor_top = 0.1
    _resource_def_panel.anchor_right = 0.9
    _resource_def_panel.anchor_bottom = 0.9
    
    add_child(_resource_def_panel)
    
    # Modifier Definition Panel
    _modifier_def_panel = ModifierDefinitionPanel.new()
    _modifier_def_panel.visible = false
    _modifier_def_panel.back_requested.connect(_on_modifier_panel_back)
    _modifier_def_panel.show_nodes_that_add.connect(_on_show_nodes_that_add_modifier)
    
    # Same layout as other def panels
    _modifier_def_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _modifier_def_panel.anchor_left = 0.1
    _modifier_def_panel.anchor_top = 0.1
    _modifier_def_panel.anchor_right = 0.9
    _modifier_def_panel.anchor_bottom = 0.9
    
    add_child(_modifier_def_panel)
    
    # Onboarding hint (shown first time)
    _onboarding_hint = _create_onboarding_hint()
    _onboarding_hint.visible = false
    results_container.add_child(_onboarding_hint)
    results_container.add_child(no_results_label)
    
    # Footer with breadcrumbs
    var footer = _create_footer()
    vbox.add_child(footer)


func _create_header() -> Control:
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 8)
    
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 12)
    margin.add_child(hbox)
    
    # Search icon
    var icon_label = Label.new()
    icon_label.text = "🔍"
    icon_label.add_theme_font_size_override("font_size", 24)
    hbox.add_child(icon_label)
    
    # Search input
    search_input = LineEdit.new()
    search_input.placeholder_text = "Search commands..."
    search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search_input.add_theme_font_size_override("font_size", 20)
    search_input.flat = true
    search_input.caret_blink = true
    
    var input_style = StyleBoxFlat.new()
    input_style.bg_color = Color(0.12, 0.14, 0.18, 0.8)
    input_style.set_corner_radius_all(8)
    input_style.content_margin_left = 12
    input_style.content_margin_right = 12
    input_style.content_margin_top = 8
    input_style.content_margin_bottom = 8
    search_input.add_theme_stylebox_override("normal", input_style)
    
    search_input.text_changed.connect(_on_search_changed)
    search_input.gui_input.connect(_on_search_input)
    hbox.add_child(search_input)
    
    return margin


func _create_footer() -> Control:
    var footer = PanelContainer.new()
    footer.custom_minimum_size = Vector2(0, 40)
    
    var footer_style = StyleBoxFlat.new()
    footer_style.bg_color = Color(0.06, 0.08, 0.1, 0.8)
    footer_style.corner_radius_bottom_left = 10
    footer_style.corner_radius_bottom_right = 10
    footer.add_theme_stylebox_override("panel", footer_style)
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    footer.add_child(margin)
    
    var hbox = HBoxContainer.new()
    margin.add_child(hbox)
    
    breadcrumb_label = Label.new()
    breadcrumb_label.text = "Home"
    breadcrumb_label.add_theme_font_size_override("font_size", 14)
    breadcrumb_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    breadcrumb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(breadcrumb_label)
    
    # Hint text
    var hint = Label.new()
    hint.text = "↑↓ Navigate • Enter Select • Esc Close • Tab Autocomplete"
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
    hbox.add_child(hint)
    
    return footer


func _create_onboarding_hint() -> Control:
    var hint_panel = PanelContainer.new()
    hint_panel.name = "OnboardingHint"
    
    var hint_style = StyleBoxFlat.new()
    hint_style.bg_color = Color(0.15, 0.25, 0.35, 0.95)
    hint_style.border_color = Color(0.4, 0.6, 0.8, 0.8)
    hint_style.set_border_width_all(2)
    hint_style.set_corner_radius_all(8)
    hint_style.content_margin_left = 16
    hint_style.content_margin_right = 16
    hint_style.content_margin_top = 12
    hint_style.content_margin_bottom = 12
    hint_panel.add_theme_stylebox_override("panel", hint_style)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    hint_panel.add_child(vbox)
    
    # Title
    var title = Label.new()
    title.text = "✨ Welcome to the Command Palette!"
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
    _apply_text_style(title, true)
    vbox.add_child(title)
    
    # Hotkey tips
    var tips = [
        "• MMB (Middle Mouse): Open/close palette",
        "• ↑↓: Navigate • Enter: Select • Esc: Close",
        "• Ctrl+F: Toggle favorite on selected command",
		"• Drop a wire on empty canvas → Node Picker!"
    ]
    
    for tip_text in tips:
        var tip = Label.new()
        tip.text = tip_text
        tip.add_theme_font_size_override("font_size", 13)
        tip.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
        vbox.add_child(tip)
    
    # Got it button
    var btn_container = HBoxContainer.new()
    btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(btn_container)
    
    var got_it_btn = Button.new()
    got_it_btn.text = "Got it!"
    got_it_btn.custom_minimum_size = Vector2(100, 32)
    got_it_btn.pressed.connect(_dismiss_onboarding)
    btn_container.add_child(got_it_btn)
    
    return hint_panel


func _create_autocomplete_row() -> Control:
    var panel = PanelContainer.new()
    panel.name = "AutocompleteRow"
    panel.custom_minimum_size = Vector2(0, 20)
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.18, 0.24, 0.9)
    style.border_color = Color(0.4, 0.6, 0.8, 0.6)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    panel.add_theme_stylebox_override("panel", style)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    panel.add_child(vbox)
    
    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    vbox.add_child(header)
    
    var title = Label.new()
    title.text = tr("Autocomplete")
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
    header.add_child(title)
    
    _autocomplete_hint = Label.new()
    _autocomplete_hint.text = ""
    _autocomplete_hint.add_theme_font_size_override("font_size", 11)
    _autocomplete_hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
    _autocomplete_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(_autocomplete_hint)
    
    _autocomplete_text = RichTextLabel.new()
    _autocomplete_text.bbcode_enabled = true
    _autocomplete_text.fit_content = true
    _autocomplete_text.scroll_active = false
    _autocomplete_text.autowrap_mode = TextServer.AUTOWRAP_WORD
    _autocomplete_text.add_theme_font_size_override("normal_font_size", 16)
    _autocomplete_text.add_theme_font_size_override("bold_font_size", 24)
    _autocomplete_text.add_theme_color_override("default_color", Color(0.9, 0.95, 1.0))
    vbox.add_child(_autocomplete_text)
    
    return panel


func _dismiss_onboarding() -> void:
    if _onboarding_hint:
        _onboarding_hint.visible = false
    if palette_config:
        palette_config.set_onboarded(true)
    Sound.play("click")


## Show the onboarding hint (called from Help command)
func show_onboarding_hint() -> void:
    if _onboarding_hint:
        _onboarding_hint.visible = true
        # Scroll to make it visible
        await get_tree().process_frame
        results_scroll.ensure_control_visible(_onboarding_hint)


func _setup_debounce() -> void:
    _debounce_timer = Timer.new()
    _debounce_timer.one_shot = true
    _debounce_timer.wait_time = 0.03 # 30ms debounce
    _debounce_timer.timeout.connect(_perform_search)
    add_child(_debounce_timer)


func _on_commands_changed() -> void:
    _rebuild_command_cache()


func _rebuild_command_cache() -> void:
    _command_cache.clear()
    _command_meta_cache.clear()
    
    if not registry:
        return
    
    var commands = registry.get_all_executable_commands()
    for cmd in commands:
        var meta = _build_command_meta(cmd)
        _command_cache.append(cmd)
        if not meta.get("id", "").is_empty():
            _command_meta_cache[meta.get("id", "")] = meta


func _build_command_meta(cmd: Dictionary) -> Dictionary:
    var meta = {
        "id": cmd.get("id", ""),
        "display_name": cmd.get("display_name", ""),
        "aliases": cmd.get("aliases", []),
        "description": cmd.get("description", ""),
        "usage": cmd.get("usage", ""),
        "examples": cmd.get("examples", []),
        "category": cmd.get("category", ""),
        "tags": cmd.get("tags", []),
        "hidden": cmd.get("hidden", false),
        "has_metadata": cmd.get("_has_metadata", false),
        "title": cmd.get("title", ""),
        "command_text": ""
    }
    
    if str(meta.get("display_name", "")).strip_edges().is_empty():
        meta["display_name"] = cmd.get("title", "")
    
    if str(meta.get("description", "")).strip_edges().is_empty():
        meta["description"] = cmd.get("hint", "")
    
    var tag_list: Array = meta.get("tags", []) if meta.get("tags", []) is Array else []
    if tag_list.is_empty():
        tag_list = cmd.get("keywords", [])
    meta["tags"] = tag_list
    
    if str(meta.get("category", "")).strip_edges().is_empty():
        var path = cmd.get("category_path", [])
        if path is Array and path.size() > 0:
            meta["category"] = str(path[0])
        else:
            meta["category"] = "Other"
    
    var alias_list: Array = []
    for alias in meta.get("aliases", []):
        var alias_text = str(alias).strip_edges()
        if not alias_text.is_empty() and alias_text not in alias_list:
            alias_list.append(alias_text)
    meta["aliases"] = alias_list
    
    if str(meta.get("usage", "")).strip_edges().is_empty():
        meta["usage"] = meta.get("display_name", "")
    
    meta["command_text"] = str(meta.get("display_name", "")).strip_edges()
    return meta


func _build_resource_cache() -> void:
    if _resource_cache_built:
        return
    
    _resource_cache.clear()
    if not Data or not "resources" in Data:
        return
    
    for id in Data.resources:
        var res = Data.resources[id]
        var raw_name = str(id)
        var desc = ""
        if res is Dictionary:
            raw_name = str(res.get("name", id))
            desc = str(res.get("description", ""))
        var display_name = tr(raw_name)
        _resource_cache.append({
            "id": str(id),
            "name": display_name,
            "raw_name": raw_name,
            "description": desc
        })
    
    _resource_cache_built = true


func _build_item_cache() -> void:
    if _item_cache_built:
        return
    
    _item_cache.clear()
    if not Data or not "items" in Data:
        return
    
    for id in Data.items:
        var item = Data.items[id]
        var raw_name = str(id)
        var desc = ""
        if item is Dictionary:
            raw_name = str(item.get("name", id))
            desc = str(item.get("description", ""))
        var display_name = tr(raw_name)
        _item_cache.append({
            "id": str(id),
            "name": display_name,
            "raw_name": raw_name,
            "description": desc
        })
    
    _item_cache_built = true


func _score_definition_text(query: String, text: String) -> float:
    if query.is_empty() or text.is_empty():
        return 0.0
    
    var t = text.to_lower()
    if t == query:
        return 100.0
    if t.begins_with(query):
        return 80.0
    if query in t:
        return 60.0
    if _fuzzy_match_text(query, t):
        return 40.0
    return 0.0


func _find_resources(query: String) -> Array:
    _build_resource_cache()
    var results: Array = []
    var q = query.to_lower()
    
    for res in _resource_cache:
        var score = 0.0
        score = max(score, _score_definition_text(q, str(res.get("name", ""))))
        score = max(score, _score_definition_text(q, str(res.get("raw_name", ""))))
        score = max(score, _score_definition_text(q, str(res.get("id", ""))))
        score = max(score, _score_definition_text(q, str(res.get("description", ""))) * 0.5)
        
        if score > 0.0:
            results.append({
                "id": res.get("id", ""),
                "name": res.get("name", ""),
                "description": res.get("description", ""),
                "score": score
            })
    
    results.sort_custom(func(a, b): return a.get("score", 0.0) > b.get("score", 0.0))
    return results


func _find_items(query: String) -> Array:
    _build_item_cache()
    var results: Array = []
    var q = query.to_lower()
    
    for item in _item_cache:
        var score = 0.0
        score = max(score, _score_definition_text(q, str(item.get("name", ""))))
        score = max(score, _score_definition_text(q, str(item.get("raw_name", ""))))
        score = max(score, _score_definition_text(q, str(item.get("id", ""))))
        score = max(score, _score_definition_text(q, str(item.get("description", ""))) * 0.5)
        
        if score > 0.0:
            results.append({
                "id": item.get("id", ""),
                "name": item.get("name", ""),
                "description": item.get("description", ""),
                "score": score
            })
    
    results.sort_custom(func(a, b): return a.get("score", 0.0) > b.get("score", 0.0))
    return results


# ==============================================================================
# Public API
# ==============================================================================

func show_palette() -> void:
    if _is_open:
        return
    
    _is_open = true
    visible = true
    if panel:
        panel.visible = true
    search_input.text = ""
    _selected_index = 0
    _current_path = []
    _history_back.clear()
    _history_forward.clear()
    _help_mode = false
    _help_detail_mode = false
    _help_query = ""
    _help_detail_command_id = ""
    _clear_autocomplete()
    
    # Refresh context
    if context:
        context.refresh()
    
    # Show home screen
    _show_home_screen()
    _update_breadcrumbs()
    
    # Show onboarding hint on first open
    if palette_config and not palette_config.is_onboarded():
        if _onboarding_hint:
            _onboarding_hint.visible = true
    else:
        if _onboarding_hint:
            _onboarding_hint.visible = false
    
    # Focus search input
    search_input.grab_focus()
    
    # Play sound
    if Engine.has_singleton("Sound"):
        Sound.play("menu_open")
    
    opened.emit()


func hide_palette() -> void:
    _is_open = false
    visible = false
    
    # Reset picker mode state
    _picker_mode = false
    _picker_origin_info.clear()
    _picker_nodes.clear()
    
    # Reset group picker mode state
    _group_picker_mode = false
    _group_picker_groups.clear()
    
    # Reset note picker mode state
    _note_picker_mode = false
    _note_picker_notes.clear()
    
    # Reset calculator mode state
    _calc_mode = false
    _calc_result = ""
    _calc_error = ""
    
    # Reset help mode state
    _help_mode = false
    _help_detail_mode = false
    _help_query = ""
    _help_detail_command_id = ""
    _clear_autocomplete()
    
    # Reset def mode
    _def_mode = false
    if _node_def_panel:
        _node_def_panel.visible = false
    
    # Reset resource mode
    _resource_mode = false
    if _resource_def_panel:
        _resource_def_panel.visible = false
    _resource_from_def_mode = false
    
    if results_scroll:
        results_scroll.visible = true
    if search_input:
        search_input.editable = true
    
    closed.emit()
    
    if Engine.has_singleton("Sound"):
        Sound.play("menu_close")


func toggle_palette() -> void:
    if _is_open:
        hide_palette()
    else:
        show_palette()


func is_open() -> bool:
    return _is_open


## Show the node picker for wire-drop feature
## Displays compatible nodes that can connect to the origin pin
func show_node_picker(compatible_nodes: Array[Dictionary], origin_info: Dictionary, spawn_position: Vector2) -> void:
    if _is_open:
        hide_palette()
    
    _picker_mode = true
    _picker_origin_info = origin_info.duplicate() # Duplicate to ensure we have our own copy
    _picker_spawn_position = spawn_position
    _picker_nodes = compatible_nodes.duplicate()
    _clear_autocomplete()
    
    # Setup picker mode handler
    if _picker_mode_handler:
        _picker_mode_handler.setup(compatible_nodes, origin_info, spawn_position)
        _picker_mode_handler.enter()
    
    _is_open = true
    visible = true
    if panel:
        panel.visible = true
    search_input.text = ""
    search_input.placeholder_text = "Search nodes to add..."
    _selected_index = 0
    _current_path = []
    _history_back.clear()
    _history_forward.clear()
    
    # Display compatible nodes via mode handler
    if _picker_mode_handler:
        _picker_mode_handler.filter("")
        breadcrumb_label.text = _picker_mode_handler.get_breadcrumb()
    else:
        _display_picker_nodes(_picker_nodes)
        _update_picker_breadcrumbs()
    
    # Focus search input
    search_input.grab_focus()
    
    Sound.play("menu_open")


## Display nodes in picker mode
func _display_picker_nodes(nodes: Array[Dictionary]) -> void:
    # Clear existing items
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    _displayed_items.clear()
    _selected_index = 0
    
    # Convert node data to display format
    for node_data in nodes:
        var item := {
            "id": node_data.id,
            "title": node_data.get("name", node_data.id),
            "hint": node_data.get("description", ""),
            "category_path": [node_data.get("category", ""), node_data.get("sub_category", "")],
            "icon_path": "res://textures/icons/" + node_data.get("icon", "cog") + ".png",
            "is_category": false,
            "badge": "SAFE",
            "_node_id": node_data.id
        }
        _displayed_items.append(item)
    
    no_results_label.visible = _displayed_items.is_empty()
    
    for i in range(_displayed_items.size()):
        var item = _displayed_items[i]
        var row = _create_result_row(item, i)
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


## Update breadcrumbs for picker mode
func _update_picker_breadcrumbs() -> void:
    var origin_desc := ""
    if _picker_origin_info.get("is_output", true):
        origin_desc = "connecting output → input"
    else:
        origin_desc = "connecting input ← output"
    breadcrumb_label.text = "🔌 Add Node (%s)" % origin_desc


## Filter picker nodes by search query
func _filter_picker_nodes(query: String) -> void:
    if query.is_empty():
        _display_picker_nodes(_picker_nodes)
        return
    
    var filtered: Array[Dictionary] = []
    var query_lower := query.to_lower()
    
    for node in _picker_nodes:
        var name_lower: String = node.get("name", "").to_lower()
        var desc_lower: String = node.get("description", "").to_lower()
        var cat_lower: String = node.get("category", "").to_lower()
        
        if query_lower in name_lower or query_lower in desc_lower or query_lower in cat_lower:
            filtered.append(node)
    
    _display_picker_nodes(filtered)


# ==============================================================================
# Group Picker Mode (for Jump to Group feature)
# ==============================================================================

## Show the group picker for Jump to Group feature
## Displays all groups on the desktop for quick navigation
func show_group_picker(groups: Array, goto_group_manager) -> void:
    # Reset picker mode if active (not group picker - that's handled separately)
    _picker_mode = false
    _picker_origin_info.clear()
    _picker_nodes.clear()
    
    _group_picker_mode = true
    _group_picker_groups = groups.duplicate()
    _clear_autocomplete()
    
    # Setup group picker mode handler
    if _group_picker_mode_handler:
        _group_picker_mode_handler.setup(groups, goto_group_manager)
        _group_picker_mode_handler.enter()
    
    # If already open, just transition; if not, open
    if not _is_open:
        _is_open = true
        visible = true
    if panel:
        panel.visible = true
    
    search_input.text = ""
    search_input.placeholder_text = "Search groups to jump to..."
    _selected_index = 0
    _current_path = []
    _history_back.clear()
    _history_forward.clear()
    
    # Store the manager reference for later use
    set_meta("goto_group_manager", goto_group_manager)
    
    # Display groups via mode handler
    if _group_picker_mode_handler:
        _group_picker_mode_handler.filter("")
        breadcrumb_label.text = _group_picker_mode_handler.get_breadcrumb()
    else:
        _display_group_picker(_group_picker_groups)
        _update_group_picker_breadcrumbs()
    
    # Focus search input
    search_input.grab_focus()
    
    Sound.play("menu_open")


## Display groups in the group picker mode
func _display_group_picker(groups: Array) -> void:
    # Clear existing items
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    _displayed_items.clear()
    _selected_index = 0
    
    var goto_manager = get_meta("goto_group_manager", null)
    
    # Convert group data to display format
    for group in groups:
        if not is_instance_valid(group):
            continue
        
        var group_name := "Group"
        if goto_manager and goto_manager.has_method("get_group_name"):
            group_name = goto_manager.get_group_name(group)
        elif group.has_method("get_window_name"):
            group_name = group.get_window_name()
        elif group.get("custom_name") and not group.custom_name.is_empty():
            group_name = group.custom_name
        
        var icon_path := "res://textures/icons/window.png"
        if goto_manager and goto_manager.has_method("get_group_icon_path"):
            icon_path = goto_manager.get_group_icon_path(group)
        
        var item := {
            "id": str(group.get_instance_id()),
            "title": group_name,
            "hint": "",
            "category_path": [],
            "icon_path": icon_path,
            "is_category": false,
            "badge": "SAFE",
            "_group_ref": group
        }
        _displayed_items.append(item)
    
    no_results_label.visible = _displayed_items.is_empty()
    if _displayed_items.is_empty():
        no_results_label.text = "No groups found on desktop"
    
    for i in range(_displayed_items.size()):
        var item = _displayed_items[i]
        var row = _create_result_row(item, i)
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


## Update breadcrumbs for group picker mode
func _update_group_picker_breadcrumbs() -> void:
    breadcrumb_label.text = "📍 Jump to Group (%d groups)" % _group_picker_groups.size()


## Filter group picker by search query
func _filter_group_picker(query: String) -> void:
    if query.is_empty():
        _display_group_picker(_group_picker_groups)
        return
    
    var filtered: Array = []
    var query_lower := query.to_lower()
    var goto_manager = get_meta("goto_group_manager", null)
    
    for group in _group_picker_groups:
        if not is_instance_valid(group):
            continue
        
        var group_name := ""
        if goto_manager and goto_manager.has_method("get_group_name"):
            group_name = goto_manager.get_group_name(group)
        elif group.has_method("get_window_name"):
            group_name = group.get_window_name()
        elif group.get("custom_name") and not group.custom_name.is_empty():
            group_name = group.custom_name
        
        if query_lower in group_name.to_lower():
            filtered.append(group)
    
    _display_group_picker(filtered)


# ==============================================================================
# Note Picker Mode (for Jump to Note feature)
# ==============================================================================

## Show the note picker for Jump to Note feature
func show_note_picker(notes: Array, sticky_manager) -> void:
    # Reset other modes
    _picker_mode = false
    _picker_origin_info.clear()
    _picker_nodes.clear()
    _group_picker_mode = false
    _group_picker_groups.clear()
    
    _note_picker_mode = true
    _note_picker_notes = notes.duplicate()
    _clear_autocomplete()
    
    # Setup note picker mode handler
    if _note_picker_mode_handler:
        _note_picker_mode_handler.setup(notes, sticky_manager)
        _note_picker_mode_handler.enter()
    
    # If already open, just transition; if not, open
    if not _is_open:
        _is_open = true
        visible = true
    if panel:
        panel.visible = true
    
    search_input.text = ""
    search_input.placeholder_text = "Search notes to jump to..."
    _selected_index = 0
    _current_path = []
    _history_back.clear()
    _history_forward.clear()
    
    # Store the manager reference for later use
    set_meta("sticky_note_manager", sticky_manager)
    
    # Display notes via mode handler
    if _note_picker_mode_handler:
        _note_picker_mode_handler.filter("")
        breadcrumb_label.text = _note_picker_mode_handler.get_breadcrumb()
    else:
        _display_note_picker(_note_picker_notes)
        _update_note_picker_breadcrumbs()
    
    # Focus search input
    search_input.grab_focus()
    
    Sound.play("menu_open")

## Display notes in the note picker mode
func _display_note_picker(notes: Array) -> void:
    # Clear existing items
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    _displayed_items.clear()
    _selected_index = 0
    
    # Convert note data to display format
    for note in notes:
        if not is_instance_valid(note):
            continue
        
        var title = note.title_text if "title_text" in note else "Note"
        var body = note.body_text if "body_text" in note else ""
        
        # Truncate body for hint
        var hint = body.replace("\n", " ").substr(0, 50)
        if body.length() > 50: hint += "..."
        
        var item := {
            "id": str(note.get_instance_id()),
            "title": title,
            "hint": hint,
            "category_path": [],
            "icon_path": "res://textures/icons/star.png",
            "is_category": false,
            "badge": "SAFE",
            "_note_ref": note
        }
        _displayed_items.append(item)
    
    no_results_label.visible = _displayed_items.is_empty()
    if _displayed_items.is_empty():
        no_results_label.text = "No notes found on desktop"
    
    for i in range(_displayed_items.size()):
        var item = _displayed_items[i]
        var row = _create_result_row(item, i)
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


## Update breadcrumbs for note picker mode
func _update_note_picker_breadcrumbs() -> void:
    breadcrumb_label.text = "📍 Jump to Note (%d notes)" % _note_picker_notes.size()


## Filter note picker by search query
func _filter_note_picker(query: String) -> void:
    if query.is_empty():
        _display_note_picker(_note_picker_notes)
        return
    
    var filtered: Array = []
    var query_lower := query.to_lower()
    
    for note in _note_picker_notes:
        if not is_instance_valid(note):
            continue
        
        var title: String = note.title_text if "title_text" in note else ""
        var body: String = note.body_text if "body_text" in note else ""
        
        if query_lower in title.to_lower() or query_lower in body.to_lower():
            filtered.append(note)
    
    _display_note_picker(filtered)


# ==============================================================================
# Calculator Mode (for inline math evaluation)
# ==============================================================================

## Display calculator result or error
func _display_calculator_result(expression: String) -> void:
    # Clear existing items
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    _displayed_items.clear()
    _selected_index = 0
    
    # Update breadcrumbs for calculator mode
    breadcrumb_label.text = "🧮 Calculator"
    
    var item: Dictionary
    var items_to_display: Array[Dictionary] = []
    
    if expression.is_empty():
        # Show hint for empty expression
        item = {
            "id": "_calc_hint",
            "title": "Type an expression",
            "hint": "e.g. = 2+2, = sqrt(144), = pi * 2^3",
            "icon_path": "res://textures/icons/info.png",
            "is_category": false,
            "badge": "HINT",
            "_is_calc_result": false
        }
        items_to_display.append(item)
        _calc_result = ""
        _calc_error = ""
        
        # Add recent expressions from history
        for i in range(_calc_history.size()):
            var hist = _calc_history[i]
            var hist_item = {
                "id": "_calc_history_%d" % i,
                "title": hist.expr,
                "hint": "= " + hist.result,
                "icon_path": "res://textures/icons/time.png",
                "is_category": false,
                "badge": "RECENT",
                "_is_calc_result": false,
                "_is_calc_history": true,
                "_calc_expr": hist.expr
            }
            items_to_display.append(hist_item)
    else:
        # Evaluate expression
        var result = Calculator.evaluate(expression)
        
        if result.success:
            _calc_result = Calculator.format_result(result.value)
            _calc_error = ""
            item = {
                "id": "_calc_result",
                "title": "Result: " + _calc_result,
                "hint": "Enter = copy to clipboard",
                "icon_path": "res://textures/icons/check.png",
                "is_category": false,
                "badge": "SAFE",
                "_is_calc_result": true,
                "_calc_expr": expression
            }
        else:
            _calc_result = ""
            _calc_error = result.error
            item = {
                "id": "_calc_error",
                "title": "Invalid expression",
                "hint": result.error,
                "icon_path": "res://textures/icons/exclamation.png",
                "is_category": false,
                "badge": "ERROR",
                "_is_calc_result": false
            }
        items_to_display.append(item)
    
    for display_item in items_to_display:
        _displayed_items.append(display_item)
    no_results_label.visible = false
    
    for i in range(items_to_display.size()):
        var display_item = items_to_display[i]
        var row = _create_calculator_result_row(display_item, i)
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


## Create a result row specifically for calculator mode with custom styling
func _create_calculator_result_row(item: Dictionary, index: int) -> Control:
    var row = PanelContainer.new()
    row.custom_minimum_size = Vector2(0, ITEM_HEIGHT + 10)
    
    var row_style = StyleBoxFlat.new()
    
    # Different styling based on result type
    if item.get("_is_calc_result", false):
        row_style.bg_color = Color(0.1, 0.25, 0.15, 0.8) # Green tint for success
    elif item.badge == "ERROR":
        row_style.bg_color = Color(0.25, 0.1, 0.1, 0.8) # Red tint for error
    else:
        row_style.bg_color = Color(0.1, 0.12, 0.16, 0.5) # Default
    
    row_style.set_corner_radius_all(8)
    row.add_theme_stylebox_override("panel", row_style)
    
    row.mouse_entered.connect(func(): _on_item_hover(index))
    row.gui_input.connect(func(event): _on_item_click(event, index))
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    row.add_child(margin)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    margin.add_child(vbox)
    
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 12)
    vbox.add_child(hbox)
    
    # Icon
    var icon_path = item.get("icon_path", "")
    if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
        var icon = TextureRect.new()
        icon.texture = load(icon_path)
        icon.custom_minimum_size = Vector2(28, 28)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hbox.add_child(icon)
    
    # Title (Result value)
    var title = Label.new()
    title.text = item.get("title", "")
    title.add_theme_font_size_override("font_size", 22)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    if item.get("_is_calc_result", false):
        title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5)) # Green for success
    elif item.badge == "ERROR":
        title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4)) # Red for error
    
    _apply_text_style(title, true)
    hbox.add_child(title)
    
    # Hint (action or error message)
    var hint = Label.new()
    hint.text = item.get("hint", "")
    hint.add_theme_font_size_override("font_size", 13)
    hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    vbox.add_child(hint)
    
    return row


# ==============================================================================
# Navigation & Display
# ==============================================================================

func _show_home_screen() -> void:
    _clear_autocomplete()
    var items: Array[Dictionary] = []
    
    # Show favorites first (if any and query empty)
    if palette_config:
        var favorites = palette_config.get_favorites()
        for fav_id in favorites:
            var cmd = registry.get_command(fav_id)
            if not cmd.is_empty() and _is_command_visible(cmd):
                cmd = cmd.duplicate()
                cmd["_is_favorite"] = true
                items.append(cmd)
    
    # Show recents (if any)
    if palette_config and items.size() < 5:
        var recents = palette_config.get_recents()
        for recent_id in recents:
            # Skip if already in favorites
            var already_shown = false
            for item in items:
                if item["id"] == recent_id:
                    already_shown = true
                    break
            if already_shown:
                continue
            
            var cmd = registry.get_command(recent_id)
            if not cmd.is_empty() and _is_command_visible(cmd):
                cmd = cmd.duplicate()
                cmd["_is_recent"] = true
                items.append(cmd)
                if items.size() >= 5:
                    break
    
    # Add root categories
    var root_items = registry.get_root_items()
    for item in root_items:
        if _is_command_visible(item):
            var already_shown = false
            for existing in items:
                if existing["id"] == item["id"]:
                    already_shown = true
                    break
            if not already_shown:
                items.append(item)
    
    _display_items(items)


func _show_category(path: Array[String]) -> void:
    _clear_autocomplete()
    _current_path = path.duplicate()
    _update_breadcrumbs()
    
    var items = registry.get_commands_in_category(path)
    var visible_items: Array[Dictionary] = []
    
    for item in items:
        if _is_command_visible(item):
            visible_items.append(item)
    
    _display_items(visible_items)


func _is_command_visible(cmd: Dictionary) -> bool:
    # Check tools visibility
    var badge = cmd.get("badge", "SAFE")
    if badge in ["OPT-IN", "GAMEPLAY"]:
        if context and not context.are_tools_enabled():
            return false
    
    # Check can_run
    var can_run_func = cmd.get("can_run", Callable())
    if can_run_func.is_valid() and context:
        return can_run_func.call(context)
    
    return true


func _display_items(items: Array[Dictionary]) -> void:
    # Clear existing items
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    _displayed_items = items
    _selected_index = 0
    
    no_results_label.visible = items.is_empty()
    
    for i in range(items.size()):
        var item = items[i]
        var row = _create_result_row(item, i)
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


func _create_result_row(item: Dictionary, index: int) -> Control:
    var row = PanelContainer.new()
    row.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
    
    var row_style = StyleBoxFlat.new()
    row_style.bg_color = Color(0.1, 0.12, 0.16, 0.3)
    row_style.set_corner_radius_all(6)
    row.add_theme_stylebox_override("panel", row_style)
    
    row.mouse_entered.connect(func(): _on_item_hover(index))
    row.gui_input.connect(func(event): _on_item_click(event, index))
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    row.add_child(margin)
    
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 12)
    margin.add_child(hbox)
    
    # Favorite indicator
    if item.get("_is_favorite", false):
        var star = Label.new()
        star.text = "★"
        star.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
        star.add_theme_font_size_override("font_size", 16)
        hbox.add_child(star)
    elif item.get("_is_recent", false):
        var clock = Label.new()
        clock.text = "⏱"
        clock.add_theme_font_size_override("font_size", 14)
        clock.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
        hbox.add_child(clock)
    
    # Icon
    var icon_path = item.get("icon_path", "")
    if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
        var icon = TextureRect.new()
        icon.texture = load(icon_path)
        icon.custom_minimum_size = Vector2(24, 24)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        hbox.add_child(icon)
    
    # Title - support dynamic titles via get_title callable
    var title = Label.new()
    var title_func = item.get("get_title", Callable())
    if title_func.is_valid():
        title.text = title_func.call()
    else:
        title.text = item.get("title", "Unknown")
    title.add_theme_font_size_override("font_size", 18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _apply_text_style(title, true)
    hbox.add_child(title)
    
    # Category path (if not at home)
    var cat_path = item.get("category_path", [])
    if not cat_path.is_empty() and _current_path.is_empty():
        var path_label = Label.new()
        path_label.text = " > ".join(cat_path)
        path_label.add_theme_font_size_override("font_size", 12)
        path_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
        _apply_text_style(path_label, false) # Shadow only, no glow
        hbox.add_child(path_label)
    
    # Category indicator
    if item.get("is_category", false):
        var arrow = Label.new()
        arrow.text = "→"
        arrow.add_theme_font_size_override("font_size", 18)
        arrow.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
        _apply_text_style(arrow, true)
        hbox.add_child(arrow)
    else:
        # Badge
        var badge_text = item.get("badge", "SAFE")
        if badge_text != "SAFE" or true: # Always show badge for clarity
            var badge = Label.new()
            badge.text = "[%s]" % badge_text
            badge.add_theme_font_size_override("font_size", 12)
            
            match badge_text:
                "SAFE":
                    badge.add_theme_color_override("font_color", COLOR_BADGE_SAFE)
                "OPT-IN":
                    badge.add_theme_color_override("font_color", COLOR_BADGE_OPTIN)
                "GAMEPLAY":
                    badge.add_theme_color_override("font_color", COLOR_BADGE_GAMEPLAY)
            
            _apply_text_style(badge, false) # Shadow only
            hbox.add_child(badge)
    
    return row


func _update_selection() -> void:
    for i in range(_result_items.size()):
        var row = _result_items[i]
        var style = row.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
        
        if i == _selected_index:
            style.bg_color = COLOR_SELECTED
            style.border_color = Color(0.4, 0.6, 0.8, 0.6)
            style.set_border_width_all(1)
        else:
            style.bg_color = Color(0.1, 0.12, 0.16, 0.3)
            style.set_border_width_all(0)
        
        row.add_theme_stylebox_override("panel", style)
    
    # Scroll to selected item
    if _selected_index >= 0 and _selected_index < _result_items.size():
        var item = _result_items[_selected_index]
        # Ensure item is visible in scroll container
        await get_tree().process_frame
        results_scroll.ensure_control_visible(item)


func _update_breadcrumbs() -> void:
    if _current_path.is_empty():
        breadcrumb_label.text = "🏠 Home"
    else:
        breadcrumb_label.text = "🏠 Home > " + " > ".join(_current_path)


# ==============================================================================
# Search
# ==============================================================================

func _is_help_query(query: String) -> bool:
    var q = query.strip_edges().to_lower()
    return q == "help" or q.begins_with("help ")


func _extract_help_query(query: String) -> String:
    var q = query.strip_edges()
    if q.to_lower().begins_with("help"):
        return q.substr(4).strip_edges()
    return ""


func _display_help_view(query: String) -> void:
    _help_mode = true
    _help_detail_mode = false
    _help_query = query
    _help_detail_command_id = ""
    _clear_autocomplete()
    
    var items = _build_help_items(query)
    _display_help_items(items, false)
    
    if query.is_empty():
        breadcrumb_label.text = "Help"
    else:
        breadcrumb_label.text = "Help: " + query


func _build_help_items(query: String) -> Array:
    var items_by_category: Dictionary = {}
    var query_lower = query.to_lower()
    
    if _command_meta_cache.is_empty():
        _rebuild_command_cache()
    
    for cmd in _command_cache:
        if not _is_command_visible(cmd):
            continue
        
        var meta = _command_meta_cache.get(cmd.get("id", ""), _build_command_meta(cmd))
        if meta.get("hidden", false):
            continue
        
        var score = 1.0 if query_lower.is_empty() else _help_match_score(query_lower, meta)
        if score <= 0.0:
            continue
        
        var category = meta.get("category", "Other")
        if not items_by_category.has(category):
            items_by_category[category] = []
        
        var item = {
            "id": meta.get("id", ""),
            "title": meta.get("display_name", ""),
            "hint": meta.get("description", ""),
            "usage": meta.get("usage", ""),
            "_help_entry": true,
            "_help_meta": meta,
            "_help_score": score
        }
        items_by_category[category].append(item)
    
    var items: Array = []
    var categories = items_by_category.keys()
    categories.sort()
    
    for category in categories:
        var group = items_by_category[category]
        group.sort_custom(func(a, b):
            if a.get("_help_score", 0.0) == b.get("_help_score", 0.0):
                return str(a.get("title", "")) < str(b.get("title", ""))
            return a.get("_help_score", 0.0) > b.get("_help_score", 0.0)
        )
        
        items.append({
            "id": "_help_cat_" + str(category),
            "title": str(category),
            "_is_help_category": true
        })
        
        for entry in group:
            items.append(entry)
    
    return items


func _help_match_score(query: String, meta: Dictionary) -> float:
    var score = 0.0
    
    score = max(score, _score_autocomplete_text(query, str(meta.get("display_name", ""))) * 1.2)
    
    for alias in meta.get("aliases", []):
        score = max(score, _score_autocomplete_text(query, str(alias)) * 1.0)
    
    for tag in meta.get("tags", []):
        score = max(score, _score_autocomplete_text(query, str(tag)) * 0.7)
    
    var desc = str(meta.get("description", "")).to_lower()
    if not desc.is_empty() and query in desc:
        score = max(score, 30.0)
    
    if score > 0.0:
        score += 10.0 / (str(meta.get("display_name", "")).length() + 1)
    return score


func _display_help_items(items: Array, detail_mode: bool) -> void:
    for child in _result_items:
        child.queue_free()
    _result_items.clear()
    
    # Convert untyped array to typed Array[Dictionary]
    _displayed_items.clear()
    for item in items:
        _displayed_items.append(item)
    if items.is_empty():
        _selected_index = -1
    elif detail_mode:
        _selected_index = 0
        for i in range(items.size()):
            if items[i].get("_help_action", false):
                _selected_index = i
                break
    else:
        _selected_index = 0
    
    no_results_label.visible = items.is_empty()
    
    for i in range(items.size()):
        var item = items[i]
        var row = _create_help_row(item, i, detail_mode)
        results_container.add_child(row)
        _result_items.append(row)
    
    _update_selection()


func _create_help_row(item: Dictionary, index: int, detail_mode: bool) -> Control:
    if detail_mode:
        return _create_help_detail_row(item, index)
    
    if item.get("_is_help_category", false):
        var row = PanelContainer.new()
        row.custom_minimum_size = Vector2(0, ITEM_HEIGHT - 10)
        
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
        style.set_corner_radius_all(6)
        row.add_theme_stylebox_override("panel", style)
        
        var margin = MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 12)
        margin.add_theme_constant_override("margin_right", 12)
        row.add_child(margin)
        
        var label = Label.new()
        label.text = item.get("title", "Other")
        label.add_theme_font_size_override("font_size", 14)
        label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
        margin.add_child(label)
        
        return row
    
    var row = PanelContainer.new()
    row.custom_minimum_size = Vector2(0, ITEM_HEIGHT + 6)
    
    var row_style = StyleBoxFlat.new()
    row_style.bg_color = Color(0.1, 0.12, 0.16, 0.3)
    row_style.set_corner_radius_all(6)
    row.add_theme_stylebox_override("panel", row_style)
    
    row.mouse_entered.connect(func(): _on_item_hover(index))
    row.gui_input.connect(func(event): _on_item_click(event, index))
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    row.add_child(margin)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    margin.add_child(vbox)
    
    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    vbox.add_child(header)
    
    var title = Label.new()
    title.text = item.get("title", "")
    title.add_theme_font_size_override("font_size", 18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _apply_text_style(title, true)
    header.add_child(title)
    
    var usage = str(item.get("usage", "")).strip_edges()
    if usage.is_empty():
        usage = "-"
    
    var usage_label = Label.new()
    usage_label.text = tr("Usage") + ": " + usage
    usage_label.add_theme_font_size_override("font_size", 12)
    usage_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
    header.add_child(usage_label)
    
    var desc = Label.new()
    desc.text = tr(item.get("hint", ""))
    desc.add_theme_font_size_override("font_size", 13)
    desc.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD
    vbox.add_child(desc)
    
    return row


func _create_help_detail_row(item: Dictionary, index: int) -> Control:
    var row = PanelContainer.new()
    row.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
    
    var row_style = StyleBoxFlat.new()
    row_style.bg_color = Color(0.1, 0.12, 0.16, 0.35)
    row_style.set_corner_radius_all(6)
    row.add_theme_stylebox_override("panel", row_style)
    
    if item.get("_help_action", false):
        row.mouse_entered.connect(func(): _on_item_hover(index))
        row.gui_input.connect(func(event): _on_item_click(event, index))
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    row.add_child(margin)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    margin.add_child(vbox)
    
    var title = Label.new()
    title.text = item.get("title", "")
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
    vbox.add_child(title)
    
    var value = RichTextLabel.new()
    value.bbcode_enabled = true
    value.fit_content = true
    value.scroll_active = false
    value.autowrap_mode = TextServer.AUTOWRAP_WORD
    value.add_theme_font_size_override("font_size", 16)
    value.add_theme_color_override("default_color", Color(0.9, 0.95, 1.0))
    value.text = item.get("value", "")
    vbox.add_child(value)
    
    if item.get("_help_action", false):
        var hint = Label.new()
        hint.text = item.get("hint", "")
        hint.add_theme_font_size_override("font_size", 12)
        hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
        vbox.add_child(hint)
    
    return row


func _show_help_details(command_id: String) -> void:
    if _command_meta_cache.is_empty():
        _rebuild_command_cache()
    
    var meta = _command_meta_cache.get(command_id, {})
    if meta.is_empty():
        return
    
    _help_mode = true
    _help_detail_mode = true
    _help_detail_command_id = command_id
    _clear_autocomplete()
    
    var desc_text = tr(meta.get("description", "")) if not str(meta.get("description", "")).is_empty() else "-"
    var usage_text = str(meta.get("usage", "")).strip_edges()
    if usage_text.is_empty():
        usage_text = "-"
    var alias_text = "-"
    if meta.get("aliases", []).size() > 0:
        alias_text = ", ".join(meta.get("aliases", []))
    var example_text = "-"
    if meta.get("examples", []).size() > 0:
        example_text = "\n".join(meta.get("examples", []))
    
    var items: Array = []
    items.append({"id": "_help_desc", "title": tr("Description"), "value": desc_text})
    items.append({"id": "_help_usage", "title": tr("Usage"), "value": usage_text})
    items.append({"id": "_help_aliases", "title": tr("Aliases"), "value": alias_text})
    items.append({"id": "_help_examples", "title": tr("Examples"), "value": example_text})
    
    var insert_text = meta.get("command_text", "")
    if insert_text.is_empty():
        insert_text = meta.get("display_name", "")
    
    items.append({
        "id": "_help_insert",
        "title": tr("Insert into input"),
        "value": insert_text + " ",
        "hint": tr("Press Enter to insert"),
        "_help_action": true,
        "_help_insert": true,
        "_help_insert_text": insert_text
    })
    
    _display_help_items(items, true)
    breadcrumb_label.text = "Help: " + str(meta.get("display_name", ""))


func _show_help_list_from_state() -> void:
    _display_help_view(_help_query)


func _is_autocomplete_enabled() -> bool:
    if palette_config:
        return palette_config.get_value("tab_autocomplete", true)
    return true


func _clear_autocomplete() -> void:
    _autocomplete_suggestions.clear()
    _autocomplete_index = 0
    if _autocomplete_row:
        _autocomplete_row.visible = false


func _update_autocomplete(raw_query: String) -> void:
    var token = raw_query.strip_edges()
    
    if token.is_empty():
        _clear_autocomplete()
        return
    
    if token.find(" ") != -1:
        _clear_autocomplete()
        return
    
    if token.begins_with("=") or token.to_lower().begins_with("calc "):
        _clear_autocomplete()
        return
    
    if _help_mode or _def_mode or _calc_mode or _picker_mode or _group_picker_mode or _note_picker_mode:
        _clear_autocomplete()
        return
    
    var suggestions = _build_autocomplete_suggestions(token)
    _autocomplete_suggestions = suggestions
    _autocomplete_index = 0
    _refresh_autocomplete_row(token)


func _refresh_autocomplete_row(query: String) -> void:
    if _autocomplete_suggestions.is_empty():
        _clear_autocomplete()
        return
    
    if not _autocomplete_row:
        return
    
    _autocomplete_row.visible = true
    
    var pieces: Array[String] = []
    var display_count = min(_autocomplete_suggestions.size(), 5)
    for i in range(display_count):
        var suggestion = _autocomplete_suggestions[i]
        var text = _format_autocomplete_text(query, str(suggestion.get("text", "")), i == _autocomplete_index)
        pieces.append(text)
    
    _autocomplete_text.text = "[color=#405060]  •  [/color]".join(pieces)
    
    var usage_hint = _format_autocomplete_usage_hint(_autocomplete_suggestions[_autocomplete_index].get("meta", {}))
    _autocomplete_hint.text = usage_hint


func _format_autocomplete_text(query: String, text: String, selected: bool) -> String:
    if selected:
        # Highly visible selected state: Gold, Bold, Underlined
        return "[u][b][color=#ffd700]" + text + "[/color][/b][/u]"
    
    # Unselected state: Dimmed gray with Blue match highlight
    var lower = text.to_lower()
    var q = query.to_lower()
    var idx = lower.find(q)
    
    if idx >= 0 and not q.is_empty():
        var before = text.substr(0, idx)
        var match = text.substr(idx, q.length())
        var after = text.substr(idx + q.length())
        return "[color=#708090]" + before + "[/color]" + "[color=#9ad0ff]" + match + "[/color]" + "[color=#708090]" + after + "[/color]"
    
    return "[color=#708090]" + text + "[/color]"


func _format_autocomplete_usage_hint(meta: Dictionary) -> String:
    var usage = str(meta.get("usage", "")).strip_edges()
    if usage.is_empty():
        return ""
    
    var name = str(meta.get("display_name", "")).strip_edges()
    if not name.is_empty() and usage.begins_with(name):
        var rest = usage.substr(name.length()).strip_edges()
        if not rest.is_empty():
            return tr("Expects") + ": " + rest
    
    return tr("Usage") + ": " + usage


func _build_autocomplete_suggestions(query: String) -> Array:
    if _command_meta_cache.is_empty():
        _rebuild_command_cache()
    
    var suggestions: Array = []
    var seen: Dictionary = {}
    
    for cmd in _command_cache:
        if not _is_command_visible(cmd):
            continue
        
        var meta = _command_meta_cache.get(cmd.get("id", ""), _build_command_meta(cmd))
        if meta.get("hidden", false):
            continue
        
        var primary = str(meta.get("display_name", "")).strip_edges()
        if not primary.is_empty():
            var score = _score_autocomplete_text(query, primary)
            if score > 0.0 and not seen.has(primary):
                seen[primary] = true
                suggestions.append({
                    "text": primary,
                    "score": score + 10.0,
                    "is_alias": false,
                    "meta": meta
                })
        
        for alias in meta.get("aliases", []):
            var alias_text = str(alias).strip_edges()
            if alias_text.is_empty() or seen.has(alias_text):
                continue
            
            var alias_score = _score_autocomplete_text(query, alias_text)
            if alias_score > 0.0:
                seen[alias_text] = true
                suggestions.append({
                    "text": alias_text,
                    "score": alias_score - 5.0,
                    "is_alias": true,
                    "meta": meta
                })
    
    suggestions.sort_custom(func(a, b):
        if a.get("score", 0.0) == b.get("score", 0.0):
            if a.get("is_alias", false) == b.get("is_alias", false):
                return str(a.get("text", "")).length() < str(b.get("text", "")).length()
            return a.get("is_alias", false) == false
        return a.get("score", 0.0) > b.get("score", 0.0)
    )
    
    if suggestions.size() > 6:
        suggestions.resize(6)
    
    return suggestions


func _score_autocomplete_text(query: String, text: String) -> float:
    var q = query.to_lower()
    var t = text.to_lower()
    
    if t == q:
        return 120.0
    if t.begins_with(q):
        return 100.0
    if q in t:
        return 70.0
    if _fuzzy_match_text(q, t):
        return 45.0
    return 0.0


func _fuzzy_match_text(query: String, text: String) -> bool:
    var query_idx = 0
    var text_idx = 0
    
    while query_idx < query.length() and text_idx < text.length():
        if query[query_idx] == text[text_idx]:
            query_idx += 1
        text_idx += 1
    
    return query_idx == query.length()


func _can_accept_autocomplete() -> bool:
    if not _is_autocomplete_enabled():
        return false
    if _autocomplete_suggestions.is_empty():
        return false
    if not search_input:
        return false
    
    var text = search_input.text
    if text.find(" ") != -1:
        return false
    if search_input.caret_column < text.length():
        return false
    return true


func _accept_autocomplete(force: bool = false) -> bool:
    if _autocomplete_suggestions.is_empty():
        return false
    
    if not force and not _can_accept_autocomplete():
        return false
    
    var suggestion = _autocomplete_suggestions[_autocomplete_index]
    search_input.text = str(suggestion.get("text", "")) + " "
    search_input.caret_column = search_input.text.length()
    _perform_search()
    return true


func _cycle_autocomplete(direction: int) -> void:
    if _autocomplete_suggestions.is_empty():
        return
    
    _autocomplete_index = wrapi(_autocomplete_index + direction, 0, _autocomplete_suggestions.size())
    _refresh_autocomplete_row(search_input.text.strip_edges())

func _on_search_changed(new_text: String) -> void:
    _debounce_timer.stop()
    _debounce_timer.start()


func _perform_search() -> void:
    var raw_query = search_input.text
    var query = raw_query.strip_edges()
    
    # Handle picker mode search - delegate to mode handler
    if _picker_mode and _picker_mode_handler:
        _picker_mode_handler.filter(query)
        breadcrumb_label.text = _picker_mode_handler.get_breadcrumb()
        return
    
    # Handle group picker mode search - delegate to mode handler
    if _group_picker_mode and _group_picker_mode_handler:
        _group_picker_mode_handler.filter(query)
        breadcrumb_label.text = _group_picker_mode_handler.get_breadcrumb()
        return
        
    # Handle note picker mode search - delegate to mode handler
    if _note_picker_mode and _note_picker_mode_handler:
        _note_picker_mode_handler.filter(query)
        breadcrumb_label.text = _note_picker_mode_handler.get_breadcrumb()
        return
    
    # Help command mode - delegate to mode handler
    if _is_help_query(query) and _help_mode_handler:
        var help_query = _extract_help_query(query)
        _help_mode = true
        _clear_autocomplete()
        _help_mode_handler.enter()
        _help_mode_handler.filter(help_query)
        breadcrumb_label.text = _help_mode_handler.get_breadcrumb()
        return
    elif _help_mode:
        _help_mode = false
        _help_detail_mode = false
        _help_query = ""
        _help_detail_command_id = ""
        if _help_mode_handler:
            _help_mode_handler.exit()

    # Check for calculator mode (= or calc prefix) - delegate to mode handler
    var calc_expression = ""
    if query.begins_with("="):
        calc_expression = query.substr(1).strip_edges()
        _calc_mode = true
    elif query.to_lower().begins_with("calc "):
        calc_expression = query.substr(5).strip_edges()
        _calc_mode = true
    else:
        _calc_mode = false
    
    # Check for node definition mode (def/nodeinfo prefix)
    # WE USE RAW_QUERY HERE to distinguish "def" from "def "
    if raw_query.to_lower().begins_with("def ") or query.begins_with("? ") or query.to_lower().begins_with("nodeinfo "):
        var search_term = ""
        if raw_query.to_lower().begins_with("def "): search_term = raw_query.substr(4)
        elif query.begins_with("? "): search_term = query.substr(2)
        elif query.to_lower().begins_with("nodeinfo "): search_term = query.substr(9)
        
        _clear_autocomplete()
        _perform_node_search(search_term.strip_edges())
        return

    # Handle calculator mode - delegate to mode handler
    if _calc_mode and _calculator_mode_handler:
        _clear_autocomplete()
        _calculator_mode_handler.enter()
        _calculator_mode_handler.filter(calc_expression)
        breadcrumb_label.text = _calculator_mode_handler.get_breadcrumb()
        return
    
    if query.is_empty():
        _clear_autocomplete()
        if _current_path.is_empty():
            _show_home_screen()
        else:
            _show_category(_current_path)
        return
    
    _update_autocomplete(raw_query)
    
    # Perform fuzzy search
    var all_commands = registry.get_all_executable_commands()
    var results = FuzzySearch.search(query, all_commands, context, MAX_VISIBLE_ITEMS)
    
    var items: Array[Dictionary] = []
    for result in results:
        items.append(result["command"])
    
    _display_items(items)


# ==============================================================================
# Input Handling
# ==============================================================================

func _on_search_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed:
        return
    
    match event.keycode:
        KEY_ESCAPE:
            hide_palette()
            get_viewport().set_input_as_handled()
        
        KEY_ENTER, KEY_KP_ENTER:
            # If autocomplete is active and we don't have exact match yet, Enter accepts it
            if _autocomplete_row and _autocomplete_row.visible and not _autocomplete_suggestions.is_empty():
                var text = search_input.text.strip_edges()
                var suggestion = str(_autocomplete_suggestions[_autocomplete_index].get("text", ""))
                if text != suggestion:
                    _accept_autocomplete(true)
                    get_viewport().set_input_as_handled()
                    return

            _execute_selected()
            get_viewport().set_input_as_handled()
        
        KEY_UP:
            _select_previous()
            get_viewport().set_input_as_handled()
        
        KEY_DOWN:
            _select_next()
            get_viewport().set_input_as_handled()
        
        KEY_TAB:
            if _autocomplete_row and _autocomplete_row.visible and not _autocomplete_suggestions.is_empty():
                var dir = -1 if event.shift_pressed else 1
                _cycle_autocomplete(dir)
                get_viewport().set_input_as_handled()
            else:
                if not event.shift_pressed:
                    _enter_category()
                    get_viewport().set_input_as_handled()
        
        KEY_RIGHT:
            _enter_category()
            get_viewport().set_input_as_handled()
        
        KEY_LEFT, KEY_BACKSPACE:
            if search_input.text.is_empty():
                _go_back()
                get_viewport().set_input_as_handled()
        
        KEY_F:
            if event.ctrl_pressed:
                _toggle_favorite_selected()
                get_viewport().set_input_as_handled()
        
        KEY_A:
            if event.ctrl_pressed:
                # Select all text in search field (not nodes on desktop)
                search_input.select_all()
                get_viewport().set_input_as_handled()
        
        KEY_SPACE:
            if event.ctrl_pressed:
                if _accept_autocomplete(true):
                    get_viewport().set_input_as_handled()


func _on_background_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                hide_palette()
            MOUSE_BUTTON_XBUTTON1: # Mouse back button
                _go_back()
                get_viewport().set_input_as_handled()
            MOUSE_BUTTON_XBUTTON2: # Mouse forward button
                _go_forward()
                get_viewport().set_input_as_handled()


func _on_item_hover(index: int) -> void:
    _selected_index = index
    _update_selection()


func _on_item_click(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _selected_index = index
        _execute_selected()


func _select_previous() -> void:
    if _displayed_items.is_empty():
        return
    _selected_index = max(0, _selected_index - 1)
    _update_selection()


func _select_next() -> void:
    if _displayed_items.is_empty():
        return
    _selected_index = min(_displayed_items.size() - 1, _selected_index + 1)
    _update_selection()


func _execute_selected() -> void:
    if _selected_index < 0 or _selected_index >= _displayed_items.size():
        return
    
    var item = _displayed_items[_selected_index]
    
    # Handle picker mode - delegate to mode handler
    if _picker_mode and _picker_mode_handler:
        if _picker_mode_handler.execute_selection(item):
            return
    elif _picker_mode:
        _execute_picker_selection(item)
        return
    
    # Handle group picker mode - delegate to mode handler
    if _group_picker_mode and _group_picker_mode_handler:
        if _group_picker_mode_handler.execute_selection(item):
            return
    elif _group_picker_mode:
        _execute_group_selection(item)
        return
        
    # Handle note picker mode - delegate to mode handler
    if _note_picker_mode and _note_picker_mode_handler:
        if _note_picker_mode_handler.execute_selection(item):
            return
    elif _note_picker_mode:
        _execute_note_picker_selection(item)
        return
    
    # Handle calculator mode - delegate to mode handler
    if _calc_mode and _calculator_mode_handler:
        if _calculator_mode_handler.execute_selection(item):
            return
    elif _calc_mode:
        _execute_calculator_action(item)
        return
    
    # Handle help mode - delegate to mode handler
    if _help_mode and _help_mode_handler:
        if _help_mode_handler.execute_selection(item):
            return
    elif _help_mode:
        _execute_help_selection(item)
        return
    
    # Handle definition results
    if item.get("_is_def_result", false) or item.get("_is_node_def_result", false):
        _execute_node_def_selection(item)
        return
    
    # If it's a category, enter it
    if item.get("is_category", false):
        _enter_category()
        return
    
    # Execute command
    var id = item.get("id", "")
    if registry.run(id, context):
        command_executed.emit(id)
        
        # Add to recents
        if palette_config:
            palette_config.add_recent(id)
        
        # Close unless keep_open is set
        if not item.get("keep_open", false):
            hide_palette()
        
        Sound.play("click")


## Execute a picker mode selection (spawn node from wire drop)
func _execute_picker_selection(item: Dictionary) -> void:
    var node_id: String = item.get("_node_id", item.get("id", ""))
    
    if node_id.is_empty():
        return
    
    # Emit signal for controller to handle spawning
    # IMPORTANT: Pass a duplicate because hide_palette() clears _picker_origin_info
    # and spawn_and_connect uses await, so the dictionary would be cleared before use
    node_selected.emit(node_id, _picker_spawn_position, _picker_origin_info.duplicate())
    
    Sound.play("click")
    hide_palette()


## Execute a group picker selection (navigate to group)
func _execute_group_selection(item: Dictionary) -> void:
    var group = item.get("_group_ref", null)
    
    if not is_instance_valid(group):
        Signals.notify.emit("exclamation", "Group no longer exists")
        hide_palette()
        return
    
    # Emit signal for controller/caller to handle navigation
    group_selected.emit(group)
    
    Sound.play("click")
    hide_palette()


## Execute a note picker selection (navigate to note)
func _execute_note_picker_selection(item: Dictionary) -> void:
    var note = item.get("_note_ref", null)
    
    if not is_instance_valid(note):
        Signals.notify.emit("exclamation", "Note no longer exists")
        hide_palette()
        return
    
    # Emit signal for controller/caller to handle navigation
    note_picker_selected.emit(note)
    
    Sound.play("click")
    hide_palette()


## Execute a calculator action (copy result to clipboard)
func _execute_calculator_action(item: Dictionary) -> void:
    # Handle history item click - fill in the expression
    if item.get("_is_calc_history", false):
        var expr = item.get("_calc_expr", "")
        if not expr.is_empty():
            search_input.text = "= " + expr
            search_input.caret_column = search_input.text.length()
            _perform_search()
            Sound.play("click")
        return
    
    # Only copy if we have a valid result
    if not item.get("_is_calc_result", false) or _calc_result.is_empty():
        # Can't copy hint or error
        Sound.play("error")
        return
    
    # Add to history (most recent first)
    var expr = item.get("_calc_expr", "")
    if not expr.is_empty():
        # Remove duplicate if exists
        for i in range(_calc_history.size() - 1, -1, -1):
            if _calc_history[i].expr == expr:
                _calc_history.remove_at(i)
        
        # Add to front
        _calc_history.insert(0, {"expr": expr, "result": _calc_result})
        
        # Limit history size
        while _calc_history.size() > CALC_MAX_HISTORY:
            _calc_history.pop_back()
    
    # Copy to clipboard
    DisplayServer.clipboard_set(_calc_result)
    
    # Show notification
    Signals.notify.emit("check", "Copied: " + _calc_result)
    
    Sound.play("click")
    hide_palette()


func _execute_help_selection(item: Dictionary) -> void:
    if item.get("_is_help_category", false):
        return
    
    if item.get("_help_insert", false):
        var insert_text = str(item.get("_help_insert_text", "")).strip_edges()
        if not insert_text.is_empty():
            search_input.text = insert_text + " "
            search_input.caret_column = search_input.text.length()
            _help_mode = false
            _help_detail_mode = false
            _help_query = ""
            _help_detail_command_id = ""
            _perform_search()
            Sound.play("click")
        return
    
    if item.get("_help_entry", false):
        var meta = item.get("_help_meta", {})
        _show_help_details(meta.get("id", item.get("id", "")))
        Sound.play("click")


## Perform search for node definitions
func _perform_node_search(query: String) -> void:
    if not node_metadata_service:
        # Show error item
        var items: Array[Dictionary] = []
        items.append({
            "id": "_node_def_error",
            "title": "Service Not Initialized",
            "hint": "Please restart the game to use this feature.",
            "icon_path": "res://textures/icons/exclamation.png",
            "is_category": false,
            "badge": "ERROR",
            "_is_node_def_result": true,
            "_node_id": ""
        })
        _display_items(items)
        breadcrumb_label.text = "?? Node Definitions: Error"
        return
        
    var nodes = node_metadata_service.find_nodes(query)
    var q = query.strip_edges()
    var items: Array[Dictionary] = []
    
    for node in nodes:
        var item = {
            "id": node.id,
            "title": node.name,
            "hint": node.get("description", ""),
            "category_path": [node.get("category", "")],
            "icon_path": "res://textures/icons/" + node.get("icon", "cog") + ".png",
            "is_category": false,
            "badge": "INFO",
            "_is_def_result": true,
            "_def_type": "node",
            "_def_score": node.get("score", 0.0),
            "_node_id": node.id
        }
        items.append(item)
    
    if not q.is_empty():
        var resources = _find_resources(q)
        for res in resources:
            var res_desc = str(res.get("description", "")).strip_edges()
            var hint = "Resource"
            if not res_desc.is_empty():
                hint = "Resource - " + tr(res_desc)
            items.append({
                "id": res.get("id", ""),
                "title": res.get("name", ""),
                "hint": hint,
                "category_path": ["Resources"],
                "icon_path": "res://textures/icons/info.png",
                "is_category": false,
                "badge": "INFO",
                "_is_def_result": true,
                "_def_type": "resource",
                "_def_score": res.get("score", 0.0),
                "_def_id": res.get("id", "")
            })
        
        var item_defs = _find_items(q)
        for item_def in item_defs:
            var item_desc = str(item_def.get("description", "")).strip_edges()
            var item_hint = "Item"
            if not item_desc.is_empty():
                item_hint = "Item - " + tr(item_desc)
            items.append({
                "id": item_def.get("id", ""),
                "title": item_def.get("name", ""),
                "hint": item_hint,
                "category_path": ["Items"],
                "icon_path": "res://textures/icons/info.png",
                "is_category": false,
                "badge": "INFO",
                "_is_def_result": true,
                "_def_type": "item",
                "_def_score": item_def.get("score", 0.0),
                "_def_id": item_def.get("id", "")
            })
    
    items.sort_custom(func(a, b): return a.get("_def_score", 0.0) > b.get("_def_score", 0.0))
    
    _definition_query = q
    _definition_results = items
    _display_items(items)
    
    # Force update breadcrumb to show mode
    if query.is_empty():
        breadcrumb_label.text = "?? Node Definitions (Type to filter)"
    else:
        breadcrumb_label.text = "?? Definitions: " + query


## Execute a node definition selection
func _execute_node_def_selection(item: Dictionary) -> void:
    # Handle error item
    if item.get("id", "") == "_node_def_error":
        Signals.notify.emit("exclamation", "Restart Required")
        Sound.play("error")
        return

    if item.get("_def_type", "") in ["resource", "item"]:
        var def_id = item.get("_def_id", item.get("id", ""))
        var label = item.get("title", "")
        if not def_id.is_empty():
            _show_resource_definition_from_def(def_id, label)
            Sound.play("click")
        return

    var node_id = item.get("_node_id", "")
    if not node_id.is_empty():
        show_node_definition(node_id)
        Sound.play("click")


func _show_resource_definition_from_def(resource_id: String, label: String) -> void:
    _resource_from_def_mode = true
    _resource_mode = true
    panel.visible = false
    _resource_def_panel.visible = true
    if _node_def_panel and _node_def_panel.has_method("_wire_colors"):
        _resource_def_panel.set_wire_colors(_node_def_panel._wire_colors)
    _resource_def_panel.display_resource(resource_id, "circle", resource_id, label)
    breadcrumb_label.text = "?? Resource: " + (label if label != "" else resource_id)


func _enter_category() -> void:
    if _selected_index < 0 or _selected_index >= _displayed_items.size():
        return
    
    var item = _displayed_items[_selected_index]
    
    if item.get("is_category", false):
        # Save current path to back history
        _history_back.append(_current_path.duplicate())
        _history_forward.clear() # Clear forward history when navigating
        
        var new_path = _current_path.duplicate()
        new_path.append(item.get("title", ""))
        _show_category(new_path)
        search_input.text = ""
        Sound.play("click")


func _go_back() -> void:
    # Help mode navigation
    if _help_mode:
        if _help_detail_mode:
            _help_detail_mode = false
            _show_help_list_from_state()
            Sound.play("click")
            return
        
        _help_mode = false
        _help_query = ""
        search_input.text = ""
        search_input.placeholder_text = "Search commands..."
        _show_home_screen()
        _update_breadcrumbs()
        Sound.play("click")
        return
    
    # Handle special modes - exit back to normal mode
    if _calc_mode or _picker_mode or _group_picker_mode or _note_picker_mode:
        _calc_mode = false
        _picker_mode = false
        _picker_origin_info.clear()
        _picker_nodes.clear()
        _group_picker_mode = false
        _group_picker_groups.clear()
        _note_picker_mode = false
        _note_picker_notes.clear()
        _current_path = []
        search_input.text = ""
        search_input.placeholder_text = "Search commands..."
        _show_home_screen()
        _update_breadcrumbs()
        Sound.play("click")
        return
    
    if _history_back.is_empty():
        # If no history, go up one level in category path
        if _current_path.is_empty():
            return
        _history_forward.append(_current_path.duplicate())
        _current_path.pop_back()
    else:
        # Use history
        _history_forward.append(_current_path.duplicate())
        _current_path = _history_back.pop_back()
    
    search_input.text = ""
    
    if _current_path.is_empty():
        _show_home_screen()
    else:
        _show_category(_current_path)
    
    _update_breadcrumbs()
    Sound.play("click")


func _go_forward() -> void:
    if _history_forward.is_empty():
        return
    
    # Save current path to back history
    _history_back.append(_current_path.duplicate())
    _current_path = _history_forward.pop_back()
    
    search_input.text = ""
    
    if _current_path.is_empty():
        _show_home_screen()
    else:
        _show_category(_current_path)
    
    _update_breadcrumbs()
    Sound.play("click")


func _toggle_favorite_selected() -> void:
    if _selected_index < 0 or _selected_index >= _displayed_items.size():
        return
    
    var item = _displayed_items[_selected_index]
    if item.get("is_category", false):
        return # Can't favorite categories
    
    var id = item.get("id", "")
    if palette_config:
        var is_now_fav = palette_config.toggle_favorite(id)
        Signals.notify.emit("check" if is_now_fav else "exclamation",
            "Added to favorites" if is_now_fav else "Removed from favorites")
        
        # Refresh display
        if search_input.text.is_empty():
            _show_home_screen()
