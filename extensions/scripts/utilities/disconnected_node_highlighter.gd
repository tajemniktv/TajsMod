# ==============================================================================
# Taj's Mod - Upload Labs
# Disconnected Node Highlighter - Highlights nodes not connected to main graph
# Author: TajemnikTV
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:DisconnectedHighlighter"

# Configuration
var _config = null
var _tree: SceneTree = null
var _mod_main = null # Reference to mod_main for debug mode
var _enabled := true
var _style := "pulse" # "pulse" or "outline"
var _intensity := 0.5

# State
var _disconnected_windows: Dictionary = {} # window_name -> original modulate
var _debounce_timer: Timer = null
var _recompute_queued := false
var _highlight_tweens: Dictionary = {} # window_name -> Tween

# Constants
const DEBOUNCE_MS := 150
const HIGHLIGHT_COLOR := Color(1.0, 0.3, 0.3, 1.0) # Red tint
const PULSE_DURATION := 1.0


func _ready() -> void:
	# Create debounce timer
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = DEBOUNCE_MS / 1000.0
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)


## Initialize the highlighter with config and scene tree
func setup(config, tree: SceneTree, mod_main = null) -> void:
	_config = config
	_tree = tree
	_mod_main = mod_main
	
	# Load settings from config
	_enabled = config.get_value("highlight_disconnected_enabled", true)
	_style = config.get_value("highlight_disconnected_style", "pulse")
	_intensity = config.get_value("highlight_disconnected_intensity", 0.5)
	
	# Connect to relevant signals
	Signals.dragged.connect(_on_node_dragged)
	Signals.connection_created.connect(_on_connection_created)
	Signals.connection_deleted.connect(_on_connection_deleted)
	
	# Initial computation after a short delay
	if _enabled:
		await tree.create_timer(0.5).timeout
		_queue_recompute()
	
	ModLoaderLog.info("Disconnected Node Highlighter initialized (enabled=%s)" % str(_enabled), LOG_NAME)


## Set enabled state
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _config:
		_config.set_value("highlight_disconnected_enabled", enabled)
	
	if enabled:
		_queue_recompute()
	else:
		_clear_all_highlights()


## Set highlight style
func set_style(style: String) -> void:
	_style = style
	if _config:
		_config.set_value("highlight_disconnected_style", style)
	
	# Reapply highlights with new style (preserve original modulate values)
	if _enabled and _disconnected_windows.size() > 0:
		# Store original values before clearing
		var original_modulates = _disconnected_windows.duplicate()
		
		# Clear existing highlights (this restores original modulates)
		for window_name in _disconnected_windows:
			var window = _find_window_by_name(window_name)
			if window:
				# Kill tween without restoring modulate yet
				if _highlight_tweens.has(window_name) and is_instance_valid(_highlight_tweens[window_name]):
					_highlight_tweens[window_name].kill()
					_highlight_tweens.erase(window_name)
				# Restore original before reapplying
				window.modulate = original_modulates[window_name]
		
		# Reapply with new style
		for window_name in original_modulates:
			var window = _find_window_by_name(window_name)
			if window:
				_apply_highlight(window)


## Set highlight intensity
func set_intensity(intensity: float) -> void:
	_intensity = clampf(intensity, 0.0, 1.0)
	if _config:
		_config.set_value("highlight_disconnected_intensity", _intensity)
	
	# Update existing highlights
	_update_highlight_intensity()


## Check if debug mode is enabled (uses mod_main's debug mode)
func _is_debug_enabled() -> bool:
	if _mod_main and "_debug_mode" in _mod_main:
		return _mod_main._debug_mode
	return false


## Get current enabled state
func is_enabled() -> bool:
	return _enabled


# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================

func _on_node_dragged(window: WindowContainer) -> void:
	if _enabled:
		_queue_recompute()


func _on_connection_created(output: String, input: String) -> void:
	if _enabled:
		_queue_recompute()


func _on_connection_deleted(output: String, input: String) -> void:
	if _enabled:
		_queue_recompute()


func _on_debounce_timeout() -> void:
	if _recompute_queued:
		_recompute_queued = false
		recompute_disconnected()


# ==============================================================================
# CORE LOGIC
# ==============================================================================

## Queue a recomputation (debounced)
func _queue_recompute() -> void:
	_recompute_queued = true
	_debounce_timer.start()


## Main connectivity computation
func recompute_disconnected() -> void:
	if not is_instance_valid(Globals.desktop):
		return
	
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if not windows_container:
		return
	
	# Step 1: Collect all ResourceContainers and their connection info
	var all_resources: Array[ResourceContainer] = []
	var resource_to_window: Dictionary = {} # resource_id -> window
	
	for window in windows_container.get_children():
		if window is WindowContainer:
			var resources = _get_window_resources(window)
			for res in resources:
				if res.id and not res.id.is_empty():
					all_resources.append(res)
					resource_to_window[res.id] = window
	
	if all_resources.is_empty():
		_clear_all_highlights()
		return
	
	# Step 2: Group resources by SHAPE only
	# We will handle color separation logically during BFS
	var shape_groups: Dictionary = {} # "shape" -> Array[ResourceContainer]
	
	for res in all_resources:
		var shape = res.get_connection_shape()
		if shape.is_empty():
			continue
			
		if not shape_groups.has(shape):
			shape_groups[shape] = []
		shape_groups[shape].append(res)
	
	# Step 3: Build adjacency map for all resources
	var adjacency: Dictionary = {} # resource_id -> Array of connected resource_ids
	
	# Initialize adjacency for all
	for res in all_resources:
		adjacency[res.id] = []
	
	# Add external connections (Wires)
	for res in all_resources:
		# Add outputs
		for output_id in res.outputs_id:
			adjacency[res.id].append(output_id)
		# Add input (bidirectional for connectivity check)
		if not res.input_id.is_empty():
			adjacency[res.id].append(res.input_id)
			
	# Add internal connections (Same shape resources on same window are connected)
	for window in windows_container.get_children():
		if window is WindowContainer:
			var resources = _get_window_resources(window)
			var resources_by_shape = {}
			
			for res in resources:
				if res.id.is_empty(): continue
				var shape = res.get_connection_shape()
				if shape.is_empty(): continue
				
				if not resources_by_shape.has(shape):
					resources_by_shape[shape] = []
				resources_by_shape[shape].append(res.id)
			
			# Fully connect all resources of same shape on this window
			for shape in resources_by_shape:
				var ids = resources_by_shape[shape]
				if ids.size() > 1:
					for i in range(ids.size()):
						for j in range(i + 1, ids.size()):
							var id1 = ids[i]
							var id2 = ids[j]
							# Add bidirectional internal edge
							if adjacency.has(id1): adjacency[id1].append(id2)
							if adjacency.has(id2): adjacency[id2].append(id1)
			
	# Step 4: For each shape, analyze components per color
	var disconnected_windows: Dictionary = {} # window -> true
	var valid_resource_ids: Dictionary = {} # resource_id -> true (marked as connected)
	
	for shape in shape_groups:
		var group_resources = shape_groups[shape]
		
		# Identify all distinct colors in this shape group (excluding white/wildcard)
		var distinct_colors: Dictionary = {}
		var white_resources: Array[String] = []
		var resources_by_color: Dictionary = {} # color -> Array[String ids]
		
		for res in group_resources:
			var color = res.get_connector_color()
			if color == "white" or color == "universal": # treat universal as white
				white_resources.append(res.id)
			else:
				distinct_colors[color] = true
				if not resources_by_color.has(color):
					resources_by_color[color] = []
				resources_by_color[color].append(res.id)
		
		# If no distinct colors (only white), treat 'white' as the color
		var colors_to_process = distinct_colors.keys()
		if colors_to_process.is_empty() and not white_resources.is_empty():
			colors_to_process.append("white")
			resources_by_color["white"] = white_resources # White only pass
			white_resources = [] # Clear white list so we don't double add
			
		# Run BFS for each color
		for color in colors_to_process:
			# The graph nodes for this pass are: Specific Color Nodes + White Nodes
			var pass_nodes: Dictionary = {}
			for id in resources_by_color.get(color, []):
				pass_nodes[id] = true
			for id in white_resources:
				pass_nodes[id] = true
				
			if pass_nodes.is_empty():
				continue
				
			# Find connected components within pass_nodes
			var visited: Dictionary = {}
			var components: Array = []
			
			for start_node in pass_nodes:
				if visited.has(start_node):
					continue
				
				var component: Array = []
				var queue: Array = [start_node]
				visited[start_node] = true
				
				var queue_idx = 0
				while queue_idx < queue.size():
					var current = queue[queue_idx]
					queue_idx += 1
					component.append(current)
					
					if adjacency.has(current):
						for neighbor in adjacency[current]:
							# Traverse ONLY if neighbor is also in this pass (Color or White)
							if pass_nodes.has(neighbor) and not visited.has(neighbor):
								visited[neighbor] = true
								queue.append(neighbor)
				
				if not component.is_empty():
					components.append(component)
					
			# Identify valid components
			# Heuristic: A component is valid if it involves at least 2 distinct windows.
			# This implies it has an external connection.
			# Single-window components (isolated nodes or internal loops) are disconnected.
			
			if components.size() > 0:
				for component_nodes in components:
					var distinct_windows = {}
					var is_valid = false
					
					for res_id in component_nodes:
						if resource_to_window.has(res_id):
							var win = resource_to_window[res_id]
							distinct_windows[win.name] = true
						if distinct_windows.size() >= 2:
							is_valid = true
							break
					
					# Removed unsafe 'size > 4' check
					
					if is_valid:
						for id in component_nodes:
							valid_resource_ids[id] = true
					
				# Debug stats per color pass
				if _is_debug_enabled():
					var invalid_count = 0
					for id in pass_nodes:
						if not valid_resource_ids.has(id):
							invalid_count += 1
							
					ModLoaderLog.info("  [%s:%s] Total Nodes: %d, Components: %d, Disconnected: %d" %
						[shape, color, pass_nodes.size(), components.size(), invalid_count], LOG_NAME)

	# Step 5: Identify windows that have ANY resource that remained invalid
	# A window is disconnected if it has a resource that:
	# 1. Was part of a checked shape/color group
	# 2. Was NOT marked valid by ANY color pass
	
	# We re-iterate all resources to see who was left behind
	for res in all_resources:
		var shape = res.get_connection_shape()
		if shape.is_empty(): continue
		
		# If a resource was part of the analysis but not validated, it's disconnected
		# Note: We track checks implicitly. If it wasn't valid, it's disconnected.
		# Exception: Single nodes forming a component of size 1?
		# Our logic above: Largest component is valid. Component of size 1 is valid if it's the largest.
		# If there are multiple components, smaller ones are invalid.
		
		if not valid_resource_ids.has(res.id):
			# Just to be safe, check if it was actually processed (avoid untracked types)
			# But we processed all shapes.
			if resource_to_window.has(res.id):
				var window = resource_to_window[res.id]
				disconnected_windows[window.name] = true

	# Apply/remove highlights
	_update_highlights(disconnected_windows)


## Get all ResourceContainer nodes from a window
func _get_window_resources(window: WindowContainer) -> Array[ResourceContainer]:
	var result: Array[ResourceContainer] = []
	_find_resource_containers(window, result)
	return result


func _find_resource_containers(node: Node, result: Array[ResourceContainer]) -> void:
	if node is ResourceContainer:
		result.append(node)
	for child in node.get_children():
		_find_resource_containers(child, result)


## Find window by name
func _find_window_by_name(window_name: String) -> WindowContainer:
	if not is_instance_valid(Globals.desktop):
		return null
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if not windows_container:
		return null
	return windows_container.get_node_or_null(window_name)


# ==============================================================================
# VISUAL HIGHLIGHTING
# ==============================================================================

## Update highlights based on new disconnected set
func _update_highlights(new_disconnected: Dictionary) -> void:
	# Remove highlights from windows no longer disconnected
	var to_remove: Array = []
	for window_name in _disconnected_windows:
		if not new_disconnected.has(window_name):
			to_remove.append(window_name)
	
	for window_name in to_remove:
		var window = _find_window_by_name(window_name)
		if window:
			_remove_highlight(window)
		_disconnected_windows.erase(window_name)
	
	# Add highlights to newly disconnected windows
	for window_name in new_disconnected:
		if not _disconnected_windows.has(window_name):
			var window = _find_window_by_name(window_name)
			if window:
				# Store original modulate
				# Sanity check: If already red-tinted (from previous run/hot reload), assume White
				var current = window.modulate
				# Simple heuristic: High Red, Low Green/Blue = likely tinted
				if current.g < 0.6 and current.b < 0.6 and current.r > 0.8:
					_disconnected_windows[window_name] = Color.WHITE
				else:
					_disconnected_windows[window_name] = current
				
				_apply_highlight(window)


## Apply highlight to a window
func _apply_highlight(window: WindowContainer) -> void:
	if _style == "outline":
		_apply_outline_highlight(window)
	else:
		_apply_pulse_highlight(window)


## Apply pulsing tint highlight
func _apply_pulse_highlight(window: WindowContainer) -> void:
	var window_name = window.name
	
	# Cancel existing tween if any
	if _highlight_tweens.has(window_name) and is_instance_valid(_highlight_tweens[window_name]):
		_highlight_tweens[window_name].kill()
	
	# Calculate highlight color based on intensity
	# Use nearly full range (0.0 to 0.9) to ensure visibility changes are obvious
	var intensity_factor = _intensity * 0.9
	var original = _disconnected_windows.get(window_name, Color.WHITE)
	var pulse_high = original.lerp(HIGHLIGHT_COLOR, intensity_factor)
	var pulse_low = original
	
	# Create looping pulse tween
	# Start from current modulate to allow smooth updates (no forced reset)
	var tween = window.create_tween()
	tween.set_loops()
	tween.tween_property(window, "modulate", pulse_high, PULSE_DURATION / 2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(window, "modulate", pulse_low, PULSE_DURATION / 2).set_trans(Tween.TRANS_SINE)
	
	_highlight_tweens[window_name] = tween


## Apply outline highlight (static tint)
func _apply_outline_highlight(window: WindowContainer) -> void:
	var window_name = window.name
	
	# Ensure any existing tween is killed (e.g. if switching from Pulse)
	if _highlight_tweens.has(window_name):
		if is_instance_valid(_highlight_tweens[window_name]):
			_highlight_tweens[window_name].kill()
		_highlight_tweens.erase(window_name)

	# Apply constant red tint at configured intensity (0.0 to 1.0)
	# Direct linear scaling so 0% is invisible and 100% is full tint
	var intensity_factor = _intensity
	var original = _disconnected_windows.get(window_name, Color.WHITE)
	var tinted = original.lerp(HIGHLIGHT_COLOR, intensity_factor)
	window.modulate = tinted


## Remove highlight from a window
func _remove_highlight(window: WindowContainer) -> void:
	var window_name = window.name
	
	# Stop tween if running
	if _highlight_tweens.has(window_name) and is_instance_valid(_highlight_tweens[window_name]):
		_highlight_tweens[window_name].kill()
		_highlight_tweens.erase(window_name)
	
	# Restore original modulate
	if _disconnected_windows.has(window_name):
		window.modulate = _disconnected_windows[window_name]


## Clear all highlights
func _clear_all_highlights() -> void:
	for window_name in _disconnected_windows:
		var window = _find_window_by_name(window_name)
		if window:
			_remove_highlight(window)
	
	_disconnected_windows.clear()
	
	# Kill all tweens
	for window_name in _highlight_tweens:
		if is_instance_valid(_highlight_tweens[window_name]):
			_highlight_tweens[window_name].kill()
	_highlight_tweens.clear()


## Update intensity on existing highlights
func _update_highlight_intensity() -> void:
	if not _enabled:
		return
	
	# Reapply highlights with new intensity
	for window_name in _disconnected_windows:
		var window = _find_window_by_name(window_name)
		if window:
			_apply_highlight(window)


## Get debug stats for display
func get_debug_stats() -> Dictionary:
	return {
		"enabled": _enabled,
		"style": _style,
		"intensity": _intensity,
		"disconnected_count": _disconnected_windows.size()
	}
