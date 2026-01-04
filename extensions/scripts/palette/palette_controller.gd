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
var _palette_enabled: bool = true # Can be toggled via settings

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
    
    # Initialize palette enabled state from config
    _palette_enabled = mod_config.get_value("command_palette_enabled", true)
    
    # Create core components
    registry = CommandRegistryScript.new()
    context = ContextProviderScript.new()
    palette_config = PaletteConfigScript.new()
    palette_config.setup(mod_config)
    
    # Set up context
    context.set_tree(tree)
    context.set_config(mod_config)
    
    # Initialize node filter EARLY so metadata service can use it
    node_filter = NodeCompatibilityFilterScript.new()
    # Defer cache building to not block startup
    call_deferred("_build_node_filter_cache")
    
    # Initialize metadata service (MUST be before overlay setup)
    _init_node_metadata_service()
    
    # Create overlay
    overlay = PaletteOverlayScript.new()
    tree.root.add_child(overlay)
    overlay.setup(registry, context, palette_config, node_metadata_service, mod_main.wire_colors if mod_main else null)
    
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
    
    # Node filter is now initialized in initialize() to support palette
    
    ModLoaderLog.info("Wire drop system initialized", LOG_NAME)


# Node Metadata Service (Inner Class to avoid loading issues)
var node_metadata_service # NodeMetadataService instance

class NodeMetadataService extends RefCounted:
    const LOG_NAME = "TajsModded:NodeMetadataService"
    
    # Cache and references
    var _node_cache: Array[Dictionary] = []
    var _node_details_cache: Dictionary = {}
    var _cache_built: bool = false
    var _node_filter # Reference to NodeCompatibilityFilter
    
    func _init(filter_ref) -> void:
        _node_filter = filter_ref
    
    ## Get all nodes available in the game
    func get_all_nodes() -> Array[Dictionary]:
        if not _cache_built:
            _build_cache()
        return _node_cache

    ## Clear the details cache to force refresh
    func clear_cache() -> void:
        _node_details_cache.clear()
        if _node_filter and _node_filter.has_method("clear_cache"):
            _node_filter.clear_cache()
    
    ## Find nodes matching a query
    func find_nodes(query: String) -> Array[Dictionary]:
        if not _cache_built:
            _build_cache()
        
        if query.is_empty():
            return _node_cache
        
        var results: Array[Dictionary] = []
        var q_lower = query.to_lower()
        
        for node in _node_cache:
            # Score against internal name
            var name_score = _score_text(q_lower, node.name)
            # Score against display name (translated) - this is what users see
            var display_name = tr(node.name)
            var display_score = _score_text(q_lower, display_name) * 1.2 # Prioritize display name
            # Also search description and category for better recall
            var desc_score = _score_text(q_lower, node.get("description", "")) * 0.5
            var cat_score = _score_text(q_lower, node.get("category", "")) * 0.7
            
            var final_score = max(display_score, max(name_score, max(desc_score, cat_score)))
            
            if final_score > 0.0:
                var result = node.duplicate()
                result.score = final_score
                results.append(result)
        
        results.sort_custom(func(a, b): return a.score > b.score)
        return results
    
    func _score_text(query: String, text: String) -> float:
        if query.is_empty() or text.is_empty():
            return 0.0
            
        var t_lower = text.to_lower()
        
        if t_lower == query:
            return 100.0
        if t_lower.begins_with(query):
            return 80.0
        if query in t_lower:
            return 60.0
            
        # Simple sequence match
        var q_idx = 0
        var t_idx = 0
        while q_idx < query.length() and t_idx < t_lower.length():
            if query[q_idx] == t_lower[t_idx]:
                q_idx += 1
            t_idx += 1
            
        if q_idx == query.length():
            return 40.0
            
        return 0.0
    
    ## Get detailed information for a specific node
    func get_node_details(node_id: String) -> Dictionary:
        if _node_details_cache.has(node_id):
            return _node_details_cache[node_id]
        
        if not Data.windows.has(node_id):
            return {}
        
        var window_data = Data.windows[node_id]
        var details = _extract_node_details(node_id, window_data)
        _node_details_cache[node_id] = details
        return details
    
    ## Build the initial cache of node summaries
    func _build_cache() -> void:
        _node_cache.clear()
        
        if not Data or not "windows" in Data:
            ModLoaderLog.error("Data.windows not found", LOG_NAME)
            return
        
        for id in Data.windows:
            var data = Data.windows[id]
            if not data.has("name"):
                continue
                
            var node_summary = {
                "id": id,
                "name": data.get("name", id),
                "category": data.get("category", "Unknown"),
                "sub_category": data.get("sub_category", ""),
                "icon": data.get("icon", "cog"),
                "description": data.get("description", "")
            }
            _node_cache.append(node_summary)
        
        _cache_built = true
        ModLoaderLog.info("Built node metadata cache for %d nodes" % _node_cache.size(), LOG_NAME)
    
    func _extract_node_details(node_id: String, data: Dictionary) -> Dictionary:
        var details = {
            "id": node_id,
            "name": data.get("name", node_id),
            "category": data.get("category", "Unknown"),
            "sub_category": data.get("sub_category", ""),
            "icon": data.get("icon", "cog"),
            "description": data.get("description", ""),
            "inputs": [],
            "outputs": [],
            "modifiers_added": [],
            "scene_path": ""
        }
        
        # Reuse logic from NodeCompatibilityFilter for reliable port extraction
        if _node_filter:
            var connect_info = _node_filter.get_connector_info(node_id)
            if not connect_info.is_empty():
                # Filter format is slightly different, need to group them
                # Filter returns flat list of {shape, color, name} in inputs/outputs
                for p in connect_info.get("inputs", []):
                    _add_port_to_list(details.inputs, _convert_filter_port(p))
                for p in connect_info.get("outputs", []):
                    _add_port_to_list(details.outputs, _convert_filter_port(p))
        
        details.unlock_info = _get_unlock_info(node_id, data)
        details.modifiers_added = _extract_modifiers(node_id, data)
        return details

    # Hardcoded mapping of nodes to the modifiers they add
    # This is necessary because modifiers are applied programmatically in scripts, not in JSON
    const NODE_MODIFIERS = {
        # Scanners / Antivirus
        "virus_scanner": ["scanned", "infected"],
        "antivirus_pro": ["scanned"],
        "quarantine": ["scanned"],
        # Verifiers
        "verifier": ["validated", "corrupted"],
        # Compressors
        "compressor": ["compressed"],
        "encompressor": ["compressed", "enhanced"],
        # Enhancers
        "enhancer": ["enhanced"],
        # Processing
        "refiner": ["refined"],
        "analyzer": ["analyzed"],
        "distillator": ["distilled"],
        "decryptor": ["decrypted"],
        # Virus/Hacking
        "virus_extractor": ["infected"],
        "trojan_injector": ["trojan"],
        "data_lab": ["analyzed"],
        # Torrent browsers
        "torrent_browser_scanned": ["scanned"],
        "torrent_browser_verified": ["validated"],
        "torrent_browser_analyzed": ["analyzed"],
        "torrent_browser_encrypted": ["encrypted"],
        # Encryption
        "encryptor": ["encrypted"],
        # AI Generators (output AI-generated files)
        "generator_text": ["ai"],
        "generator_image": ["ai"],
        "generator_sound": ["ai"],
        "generator_video": ["ai"],
        "generator_program": ["ai"],
        "generator_game": ["ai"],
    }

    func _extract_modifiers(node_id: String, data: Dictionary) -> Array:
        var modifier_ids: Array = []
        var seen: Dictionary = {}
        
        var known_keys = [
            "modifier",
            "modifiers",
            "adds_modifier",
            "adds_modifiers",
            "add_modifier",
            "add_modifiers",
            "file_modifier",
            "file_modifiers",
            "output_modifier",
            "output_modifiers",
            "input_modifier",
            "input_modifiers",
            "modifiers_add",
            "modifier_add"
        ]
        
        for key in known_keys:
            if data.has(key):
                _append_modifier_value(modifier_ids, seen, data[key])
        
        # Fallback: scan any key containing "modifier"
        for key in data.keys():
            if str(key).to_lower().find("modifier") == -1:
                continue
            _append_modifier_value(modifier_ids, seen, data[key])
        
        # If no modifiers found in data, check our hardcoded mapping
        if modifier_ids.is_empty() and NODE_MODIFIERS.has(node_id):
            for mod in NODE_MODIFIERS[node_id]:
                if not seen.has(mod):
                    seen[mod] = true
                    modifier_ids.append(mod)
        
        var result: Array = []
        for mid in modifier_ids:
            var meta = _resolve_modifier_meta(mid)
            result.append(meta)
        
        return result

    func _append_modifier_value(list: Array, seen: Dictionary, value) -> void:
        if value == null:
            return
        if value is String:
            var id = str(value)
            if not id.is_empty() and not seen.has(id):
                seen[id] = true
                list.append(id)
        elif value is Array:
            for entry in value:
                _append_modifier_value(list, seen, entry)
        elif value is Dictionary:
            if value.has("id"):
                _append_modifier_value(list, seen, value["id"])
            elif value.has("modifier"):
                _append_modifier_value(list, seen, value["modifier"])

    # Known file modifiers from Utils.file_variations enum
    # These don't exist in Data.modifiers, so we define them here
    const FILE_MODIFIERS = {
        "scanned": {"name": "Scanned", "icon": "antivirus", "description_key": "guide_file_modifiers_scanned"},
        "validated": {"name": "Validated", "icon": "puzzle", "description_key": "guide_file_modifiers_validated"},
        "compressed": {"name": "Compressed", "icon": "minimize", "description_key": "guide_file_modifiers_compressed"},
        "enhanced": {"name": "Enhanced", "icon": "up_arrow", "description_key": "guide_file_modifiers_enhanced"},
        "infected": {"name": "Infected", "icon": "virus", "description_key": "guide_file_modifiers_infected"},
        "refined": {"name": "Refined", "icon": "filter", "description_key": "guide_file_modifiers_refined"},
        "distilled": {"name": "Distilled", "icon": "connections", "description_key": "guide_file_modifiers_distilled"},
        "analyzed": {"name": "Analyzed", "icon": "magnifying_glass", "description_key": "guide_file_modifiers_analyzed"},
        "hacked": {"name": "Hacked", "icon": "hacker", "description_key": "guide_file_modifiers_hacked"},
        "corrupted": {"name": "Corrupted", "icon": "warning", "description_key": "guide_file_modifiers_corrupted"},
        "ai": {"name": "AI", "icon": "brain", "description_key": "guide_file_modifiers_ai"},
        "encrypted": {"name": "Encrypted", "icon": "padlock", "description_key": "guide_file_modifiers_encrypted"},
        "decrypted": {"name": "Decrypted", "icon": "padlock_open", "description_key": "guide_file_modifiers_decrypted"},
        "trojan": {"name": "Trojan", "icon": "trojan", "description_key": "guide_file_modifiers_trojan"},
    }
    
    func _resolve_modifier_meta(modifier_id: String) -> Dictionary:
        var meta = {
            "id": modifier_id,
            "name": modifier_id.capitalize(),
            "description": ""
        }
        
        var id_lower = modifier_id.to_lower()
        
        # 1. Check our known file modifiers dictionary first
        if FILE_MODIFIERS.has(id_lower):
            var fm = FILE_MODIFIERS[id_lower]
            meta.name = fm.get("name", modifier_id.capitalize())
            meta.icon = fm.get("icon", "")
            # Try to get translated description from guides
            var desc_key = fm.get("description_key", "")
            if desc_key != "":
                var translated = tr(desc_key)
                # Only use if translation exists (doesn't return the key itself)
                if translated != desc_key:
                    meta.description = translated
            return meta
        
        # 2. Check Data.resources (for resources that might be modifiers)
        if Data.resources.has(modifier_id):
            var res = Data.resources[modifier_id]
            if res is Dictionary:
                meta.name = tr(res.get("name", modifier_id))
                meta.description = tr(res.get("description", ""))
                if res.has("icon"):
                    meta.icon = res.get("icon", "")
            return meta
        
        # 3. Check Data.items (if it exists)
        if "items" in Data and Data.items.has(modifier_id):
            var item = Data.items[modifier_id]
            if item is Dictionary:
                meta.name = tr(item.get("name", modifier_id))
                meta.description = tr(item.get("description", ""))
                if item.has("icon"):
                    meta.icon = item.get("icon", "")
            return meta
        
        # 4. Fallback: try guide translation key pattern
        var guide_key = "guide_file_modifiers_" + id_lower
        var translated = tr(guide_key)
        if translated != guide_key:
            meta.description = translated
        
        return meta
    
    func _convert_filter_port(filter_port: Dictionary) -> Dictionary:
        return {
            "shape": filter_port.get("shape", "?"),
            "color": filter_port.get("color", "white"),
            "label": filter_port.get("name", "Port"),
            "count": 1,
            "resource_id": filter_port.get("resource_id", "")
        }

    func _add_port_to_list(list: Array, port: Dictionary) -> void:
        for existing in list:
            if existing.shape == port.shape and existing.color == port.color and existing.label == port.label:
                existing.count += 1
                return
        list.append(port)

    func _get_unlock_info(node_id: String, data: Dictionary) -> Dictionary:
        var info = {"status": "Available"}
        
        # Check 'requirement' field (format: "research.X", "upgrade.X", "perk.X", "")
        var requirement = data.get("requirement", "")
        if requirement != "":
            if requirement.begins_with("research."):
                var rid = requirement.replace("research.", "")
                info.status = "Research Required"
                info.research_id = rid
                if "research" in Data and Data.research.has(rid):
                    var res = Data.research[rid]
                    info.research_name = res.get("name", rid)
                    # Calculate research cost: cost × 10^cost_e
                    var base_cost = res.get("cost", 0)
                    var cost_exp = res.get("cost_e", 0)
                    info.research_cost = base_cost * pow(10, cost_exp)
                    info.research_currency = res.get("currency", "research")
                return info
            elif requirement.begins_with("upgrade."):
                var uid = requirement.replace("upgrade.", "")
                info.status = "Shop Purchase"
                info.upgrade_id = uid
                if "upgrades" in Data and Data.upgrades.has(uid):
                    var upg = Data.upgrades[uid]
                    info.upgrade_name = upg.get("name", uid)
                    # Calculate actual cost: cost × 10^cost_e
                    var base_cost = upg.get("cost", 0)
                    var cost_exp = upg.get("cost_e", 0)
                    info.price = base_cost * pow(10, cost_exp)
                return info
            elif requirement.begins_with("perk."):
                var pid = requirement.replace("perk.", "")
                info.status = "Perk Required"
                info.perk_id = pid
                if "perks" in Data and Data.perks.has(pid):
                    info.perk_name = Data.perks[pid].get("name", pid)
                return info
        
        return info


func _init_node_metadata_service() -> void:
    # Instantiate inner class directly - foolproof!
    # Pass node_filter for reliable parsing
    node_metadata_service = NodeMetadataService.new(node_filter)
    ModLoaderLog.info("Node metadata service initialized (Inner Class)", LOG_NAME)


## Get the node metadata service
func get_node_metadata_service() -> RefCounted:
    return node_metadata_service


## Clear metadata cache (used when wire colors change)
func clear_metadata_cache() -> void:
    if node_metadata_service:
        node_metadata_service.clear_cache()


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
                # Only toggle palette if enabled
                if _palette_enabled:
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
        
    # Ensure metadata service is initialized (recovery)
    if not node_metadata_service:
        _init_node_metadata_service()
        if node_metadata_service:
            overlay.node_metadata_service = node_metadata_service
            
    overlay.toggle_palette()


## Open the palette
func open() -> void:
    if not _initialized or not overlay:
        return
        
    # Ensure metadata service is initialized (recovery for hot-reloads)
    if not node_metadata_service:
        _init_node_metadata_service()
        if node_metadata_service:
            # Update overlay with the new service
            overlay.node_metadata_service = node_metadata_service

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


## Set palette enabled state (middle mouse button toggle)
func set_palette_enabled(enabled: bool) -> void:
    _palette_enabled = enabled
    if mod_config:
        mod_config.set_value("command_palette_enabled", enabled)

## Set tab autocomplete enabled state
func set_tab_autocomplete_enabled(enabled: bool) -> void:
    if palette_config:
        palette_config.set_value("tab_autocomplete", enabled)


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


## Get the node compatibility filter for port-based filtering
func get_node_filter():
    return node_filter
