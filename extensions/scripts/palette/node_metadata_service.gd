# ==============================================================================
# Taj's Mod - Upload Labs
# Node Metadata Service - Abstraction layer for querying node information
# Author: TajemnikTV
# ==============================================================================
# Node Metadata Service - Abstraction layer for querying node information
# Author: TajemnikTV
# ==============================================================================
extends RefCounted

const LOG_NAME = "TajsModded:NodeMetadataService"
const FuzzySearch = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/fuzzy_search.gd")

# Cache for node metadata
var _node_cache: Array[Dictionary] = []
var _node_details_cache: Dictionary = {}
var _cache_built: bool = false
var _fuzzy_search: RefCounted

func _init() -> void:
    _fuzzy_search = FuzzySearch.new()

## Get all nodes available in the game
## Returns an array of node summaries {id, name, category, icon, score}
func get_all_nodes() -> Array[Dictionary]:
    if not _cache_built:
        _build_cache()
    return _node_cache

## Clear the details cache to force refresh (e.g. when wire colors change)
func clear_cache() -> void:
    _node_details_cache.clear()

## Find nodes matching a query
## Uses fuzzy search to rank results
func find_nodes(query: String) -> Array[Dictionary]:
    if not _cache_built:
        _build_cache()
    
    if query.is_empty():
        return _node_cache
    
    var results: Array[Dictionary] = []
    for node in _node_cache:
        var score = _fuzzy_search.search(query, node.name)
        # Also search description and category for better recall
        var desc_score = _fuzzy_search.search(query, node.get("description", "")) * 0.5
        var cat_score = _fuzzy_search.search(query, node.get("category", "")) * 0.7
        
        # Take the best score
        var final_score = max(score, max(desc_score, cat_score))
        
        if final_score > 0.1: # Threshold to filter noise
            var result = node.duplicate()
            result.score = final_score
            results.append(result)
    
    # Sort by score descending
    results.sort_custom(func(a, b): return a.score > b.score)
    return results

## Get detailed information for a specific node
## Includes inputs/outputs, full description, etc.
func get_node_details(node_id: String) -> Dictionary:
    ModLoaderLog.info("DEBUG: get_node_details called for '%s'" % node_id, LOG_NAME)
    
    # Return cached details if available
    if _node_details_cache.has(node_id):
        ModLoaderLog.info("DEBUG: returning cached details for '%s'" % node_id, LOG_NAME)
        return _node_details_cache[node_id]
    
    # Fetch from Data.windows
    if not Data.windows.has(node_id):
        ModLoaderLog.info("DEBUG: '%s' not found in Data.windows" % node_id, LOG_NAME)
        return {}
    
    var window_data = Data.windows[node_id]
    ModLoaderLog.info("DEBUG: Extracting details for '%s'" % node_id, LOG_NAME)
    var details = _extract_node_details(node_id, window_data)
    
    # Cache it
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
        
        # Skip hidden or invalid nodes if possible (optional check)
        # For now, include everything that has a name
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

## Extract detailed info including ports by instantiating the scene
## This is expensive, so it should be cached
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
        "scene_path": ""
    }
    
    # Try to get scene-based details (ports)
    if data.has("scene"):
        var scene_path = "res://scenes/windows/" + data.scene + ".tscn"
        details.scene_path = scene_path
        
        if ResourceLoader.exists(scene_path):
            var scene = load(scene_path)
            if scene:
                var instance = scene.instantiate()
                if instance:
                    _collect_ports(instance, details)
                    instance.queue_free()
    
    # Add unlock info if available (heuristic-based for now)
    details.unlock_info = _get_unlock_info(node_id, data)
    
    return details

## Helper to recursively collect port info
func _collect_ports(node: Node, details: Dictionary) -> void:
    # DEBUG LOGGING (Unconditional)
    if "Neuron" in node.name:
        ModLoaderLog.info("DEBUG: Visiting node '%s'" % node.name, LOG_NAME)
        ModLoaderLog.info("  - Script: %s" % str(node.get_script()), LOG_NAME)
        ModLoaderLog.info("  - Has default_resource? %s" % str(node.get("default_resource") != null), LOG_NAME)
        if node.get("default_resource") != null:
             ModLoaderLog.info("  - Value: %s" % str(node.get("default_resource")), LOG_NAME)

    # Use duck typing/property check instead of class_name to avoid potential scope issues
    # We check for a property unique enough to ResourceContainer
    if node.get("default_resource") != null:
        var shape = node.get("override_connector")
        if shape == null: shape = "" # Handle potential null
        
        var color = node.get("override_color")
        if color == null or color == "": color = "white"
        
        var default_res = node.get("default_resource")
        
        # DEBUG LOGGING
        if "Neuron" in node.name:
            ModLoaderLog.info("DEBUG: Found node %s" % node.name, LOG_NAME)
            ModLoaderLog.info("  - default_resource: %s" % str(default_res), LOG_NAME)
            ModLoaderLog.info("  - override_connector: %s" % str(shape), LOG_NAME)
            ModLoaderLog.info("  - script: %s" % str(node.get_script()), LOG_NAME)
        

        if shape.is_empty() and default_res != "" and Data.resources.has(default_res):
            var res_data = Data.resources[default_res]
            shape = res_data.get("connection", "")
            if color == "white": # Only override if not set
                color = res_data.get("color", "white")
        
        # Also need to cast to something compatible or just access properties dynamically
        # Since we verified default_resource exists, we can access others dynamically
        var rc_default_resource = default_res
        
        if not shape.is_empty():
            if "Neuron" in node.name:
                 ModLoaderLog.info("DEBUG: Adding port info with ID: %s" % str(rc_default_resource), LOG_NAME)
            var port_info = {
                "shape": shape,
                "color": color,
                "label": node.name, # Usually useful label
                "count": 1, # Can be used for grouping
                "resource_id": rc_default_resource
            }
            
            if node.has_node("InputConnector"):
                _add_port_to_list(details.inputs, port_info)
            if node.has_node("OutputConnector"):
                _add_port_to_list(details.outputs, port_info)
    
    for child in node.get_children():
        _collect_ports(child, details)

## Helper to add port to list or increment count if identical exists
func _add_port_to_list(list: Array, port: Dictionary) -> void:
    # Try to find identical port to group them (e.g. 6x Data Input)
    for existing in list:
        if existing.shape == port.shape and existing.color == port.color and existing.label == port.label:
            existing.count += 1
            return
    list.append(port)

## Try to determine unlock info
func _get_unlock_info(node_id: String, data: Dictionary) -> Dictionary:
    # Heuristic: Check if it's a base node or research locked
    # This part is speculative as we haven't found explicit unlock data in the mod files
    # But we can allow for manual overrides or future expansion
    var info = {
        "status": "Available"
    }
    
    if data.has("research_id"):
        info.status = "Research Required"
        info.research_id = data.research_id
        # Could look up research name if we can access Research data
        if Data.has("research") and Data.research.has(data.research_id):
            info.research_name = Data.research[data.research_id].get("name", data.research_id)
            
    return info
