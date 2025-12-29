# ==============================================================================
# Taj's Mod - Upload Labs
# Disconnected Node Highlighter - Highlights nodes not connected to main graph
# Author: TajemnikTV
# ==============================================================================
class_name DisconnectedNodeHighlighter
extends Node

const LOG_NAME = "TajsModded:DisconnectedHighlighter"

# Configuration
var _config # ConfigManager
var _mod_main # Reference to mod_main for debug logging

# State
var _enabled: bool = true
var _style: String = "pulse" # "pulse" or "outline"
var _intensity: float = 0.5 # 0.0 to 1.0

# Connectivity Data
var _disconnected_windows: Dictionary = {} # window_name -> bool (true if disconnected)
var _cached_windows: Dictionary = {} # window_name -> WindowContainer (cached references)

# Visuals
var _draw_control: Control
var _pulse_tween: Tween
var _pulse_alpha: float = 0.0
var _cached_stylebox: StyleBoxFlat # Reused to avoid allocation
var _last_redraw_time: float = 0.0

# Constants
const PULSE_DURATION = 1.0
const DEBOUNCE_TIME = 0.15
const HIGHLIGHT_COLOR = Color(1.0, 0.0, 0.0) # Red

var _debounce_timer: Timer

func setup(config, tree: SceneTree, mod_main_ref) -> void:
	_config = config
	_mod_main = mod_main_ref
	
	# Load settings
	_enabled = config.get_value("highlight_disconnected_enabled", true)
	_style = config.get_value("highlight_disconnected_style", "pulse")
	_intensity = config.get_value("highlight_disconnected_intensity", 0.5)
	
	# Init Debouncer
	_debounce_timer = Timer.new()
	_debounce_timer.wait_time = DEBOUNCE_TIME
	_debounce_timer.one_shot = true
	_debounce_timer.timeout.connect(recompute_disconnected)
	add_child(_debounce_timer)
	
	# Start Pulse Animation
	_start_pulse_tween()
	
	# Connect Signals
	_connect_signals(tree)
	
	# Defer visual setup until desktop is ready
	call_deferred("_setup_draw_control")
	call_deferred("recompute_disconnected")

func _setup_draw_control() -> void:
	if not is_instance_valid(Globals.desktop):
		return
	
	# Add draw control to desktop (not Windows container to avoid type iteration issues)
	_draw_control = Control.new()
	_draw_control.name = "DisconnectedHighlightOverlay"
	# Large offset to handle panning in any direction
	_draw_control.position = Vector2(-20000, -20000)
	_draw_control.size = Vector2(40000, 40000)
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_control.z_index = 100 # Draw on top of windows
	_draw_control.draw.connect(_on_draw_highlights)
	_draw_control.visible = _enabled
	Globals.desktop.add_child(_draw_control)

func _start_pulse_tween() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	# Pulse alpha from 0.0 to 1.0 and back
	_pulse_tween.tween_property(self, "_pulse_alpha", 1.0, PULSE_DURATION / 2.0).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "_pulse_alpha", 0.0, PULSE_DURATION / 2.0).set_trans(Tween.TRANS_SINE)

func _is_debug_enabled() -> bool:
	if _mod_main:
		return _mod_main._debug_mode
	return false

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _draw_control:
		_draw_control.visible = enabled
		_draw_control.queue_redraw()
	
	if enabled:
		recompute_disconnected()

func set_style(style: String) -> void:
	_style = style
	if _draw_control:
		_draw_control.queue_redraw()

func set_intensity(val: float) -> void:
	_intensity = val
	if _draw_control:
		_draw_control.queue_redraw()

func _connect_signals(tree: SceneTree) -> void:
	if Signals:
		if not Signals.connection_created.is_connected(_on_connection_changed):
			Signals.connection_created.connect(_on_connection_changed)
		if not Signals.connection_deleted.is_connected(_on_connection_changed):
			Signals.connection_deleted.connect(_on_connection_changed)
	
	# Listen for new windows being added (copy/paste, node creation)
	call_deferred("_connect_windows_container_signals")

func _connect_windows_container_signals() -> void:
	if not is_instance_valid(Globals.desktop):
		return
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if windows_container and not windows_container.child_entered_tree.is_connected(_on_window_added):
		windows_container.child_entered_tree.connect(_on_window_added)
		windows_container.child_exiting_tree.connect(_on_window_removed)

func _on_window_added(node: Node) -> void:
	if node is WindowContainer:
		_trigger_recompute()

func _on_window_removed(node: Node) -> void:
	if node is WindowContainer:
		_trigger_recompute()

func _process(delta: float) -> void:
	# Only redraw if pulse mode (outline is static) and limit to ~30 FPS
	if not _enabled or _disconnected_windows.is_empty() or not _draw_control:
		return
	
	# Limit redraw rate
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_redraw_time < 0.033: # ~30 FPS
		return
	_last_redraw_time = now
	
	_draw_control.queue_redraw()

func _on_connection_changed(_a = null, _b = null) -> void:
	_trigger_recompute()

func _trigger_recompute() -> void:
	if _enabled:
		_debounce_timer.start()

# --------------------------------------------------------------------------------
# CORE CONNECTIVITY LOGIC
# --------------------------------------------------------------------------------

func recompute_disconnected() -> void:
	if not is_instance_valid(Globals.desktop):
		return
		
	var windows_container = Globals.desktop.get_node_or_null("Windows")
	if not windows_container:
		return

	# 1. Gather all resources and map them to their Windows
	var all_res_ids: Dictionary = {} # id -> ResourceContainer
	var res_to_window: Dictionary = {} # id -> WindowContainer
	
	for window in windows_container.get_children():
		if window is WindowContainer:
			var resources = _get_window_resources(window)
			for res in resources:
				if res.id and not res.id.is_empty():
					all_res_ids[res.id] = res
					res_to_window[res.id] = window
	
	if all_res_ids.is_empty():
		_disconnected_windows.clear()
		if _draw_control:
			_draw_control.queue_redraw()
		return

	# 2. Build Adjacency Graph (Global)
	var adjacency: Dictionary = {} # id -> Array[id]
	
	# Initialize list
	for id in all_res_ids:
		adjacency[id] = []
		
	for id in all_res_ids:
		var res = all_res_ids[id]
		
		# External Connections (Wires)
		for out_id in res.outputs_id:
			if all_res_ids.has(out_id):
				adjacency[id].append(out_id)
				adjacency[out_id].append(id) # Bidirectional

	# Add Internal Connections (Same Shape Only)
	for window in windows_container.get_children():
		if window is WindowContainer:
			var resources = _get_window_resources(window)
			var by_shape = {}
			for res in resources:
				var shape = res.get_connection_shape()
				if not by_shape.has(shape): by_shape[shape] = []
				by_shape[shape].append(res.id)
			
			for shape in by_shape:
				var ids = by_shape[shape]
				for i in range(ids.size()):
					for j in range(i + 1, ids.size()):
						var id1 = ids[i]
						var id2 = ids[j]
						adjacency[id1].append(id2)
						adjacency[id2].append(id1)

	# 3. BFS to find Connected Components
	var visited: Dictionary = {}
	var valid_res_ids: Dictionary = {} # id -> true
	
	var components = []
	
	for start_id in all_res_ids:
		if visited.has(start_id): continue
		
		# Start BFS
		var component = []
		var queue = [start_id]
		visited[start_id] = true
		
		var idx = 0
		while idx < queue.size():
			var curr = queue[idx]
			idx += 1
			component.append(curr)
			
			if adjacency.has(curr):
				for neighbor in adjacency[curr]:
					if not visited.has(neighbor):
						visited[neighbor] = true
						queue.append(neighbor)
		
		components.append(component)
	
	# 4. Validate Components - Must span >= 2 Distinct Windows
	var newly_disconnected_windows: Dictionary = {}
	
	for comp in components:
		var distinct_windows = {}
		for r_id in comp:
			var w = res_to_window[r_id]
			distinct_windows[w.name] = true
			
		if distinct_windows.size() >= 2:
			# Valid - mark all resources
			for r_id in comp:
				valid_res_ids[r_id] = true
		else:
			# Invalid (Isolated) - mark windows
			for r_id in comp:
				var w = res_to_window[r_id]
				newly_disconnected_windows[w.name] = true

	# Update State
	_disconnected_windows = newly_disconnected_windows
	_cached_windows.clear() # Clear cache to avoid stale references
	
	if _is_debug_enabled():
		ModLoaderLog.info("Connectivity Scan: Total Nodes: %d, Components: %d, Highlighted Windows: %d" %
			[all_res_ids.size(), components.size(), _disconnected_windows.size()], LOG_NAME)

	if _draw_control:
		_draw_control.queue_redraw()

func _get_window_resources(node: Node, result: Array = []) -> Array:
	if node is ResourceContainer:
		result.append(node)
	for child in node.get_children():
		_get_window_resources(child, result)
	return result

func _find_window_by_name(name: String) -> WindowContainer:
	if not is_instance_valid(Globals.desktop): return null
	var wc = Globals.desktop.get_node_or_null("Windows")
	if wc:
		return wc.get_node_or_null(name)
	return null

# --------------------------------------------------------------------------------
# DRAWING
# --------------------------------------------------------------------------------

func _on_draw_highlights() -> void:
	if not _enabled or _disconnected_windows.is_empty():
		return
		
	var draw_style = _style
	var intensity_val = _intensity
	
	if draw_style == "pulse":
		# Pulse Alpha: min 0.1 to max (0.3 + 0.5*intensity)
		var max_a = 0.3 + (intensity_val * 0.5)
		var min_a = 0.1
		var cur_a = min_a + (max_a - min_a) * _pulse_alpha
		
		var col = HIGHLIGHT_COLOR
		col.a = cur_a
		
		# Use simple draw_rect instead of StyleBox (StyleBox may cause edge artifacts)
		for win_name in _disconnected_windows:
			var win = _get_cached_window(win_name)
			if win:
				var local_pos = win.global_position - _draw_control.global_position
				var win_size = win.custom_minimum_size if win.custom_minimum_size != Vector2.ZERO else win.size
				var rect = Rect2(local_pos, win_size)
				_draw_control.draw_rect(rect, col, true) # Filled rect
				
	else:
		# Outline
		var col = HIGHLIGHT_COLOR
		col.a = 0.3 + (intensity_val * 0.7)
		var border_width = 4
		
		for win_name in _disconnected_windows:
			var win = _get_cached_window(win_name)
			if win:
				var local_pos = win.global_position - _draw_control.global_position
				var win_size = win.custom_minimum_size if win.custom_minimum_size != Vector2.ZERO else win.size
				var rect = Rect2(local_pos, win_size)
				_draw_control.draw_rect(rect, col, false, border_width)

func _get_cached_window(win_name: String) -> WindowContainer:
	if _cached_windows.has(win_name) and is_instance_valid(_cached_windows[win_name]):
		return _cached_windows[win_name]
	var win = _find_window_by_name(win_name)
	if win:
		_cached_windows[win_name] = win
	return win

func _update_stylebox(col: Color) -> void:
	if not _cached_stylebox:
		_cached_stylebox = StyleBoxFlat.new()
		_cached_stylebox.set_corner_radius_all(10)
		_cached_stylebox.draw_center = true
	_cached_stylebox.bg_color = col
