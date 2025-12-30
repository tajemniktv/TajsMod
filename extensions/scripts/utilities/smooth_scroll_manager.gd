extends Node

const LOG_NAME = "TajsModded:SmoothScroll"

var _config = null
var _enabled := false

# Settings
var _scroll_speed := 12.0
var _scroll_step := 120.0

# State
var _scroll_targets: Dictionary = {}

func setup(config) -> void:
	_config = config
	_update_settings()

func set_enabled(v: bool) -> void:
	if _enabled != v:
		_enabled = v
		set_process(v)
		set_process_input(v)
		if !v:
			_scroll_targets.clear()

func _update_settings() -> void:
	pass

func _ready() -> void:
	set_process(false)
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if not _enabled: return
	
	if event is InputEventMouseButton and event.pressed:
		var is_wheel = false
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				is_wheel = true
		
		if is_wheel:
			var mouse_pos = get_viewport().get_mouse_position()
			var container = _find_scroll_container_at_point(get_tree().root, mouse_pos)
			
			if container:
				_handle_scroll_input(container, event)
				get_viewport().set_input_as_handled()

func _handle_scroll_input(container: ScrollContainer, event: InputEventMouseButton) -> void:
	# Initialize target if new
	if not _scroll_targets.has(container):
		_scroll_targets[container] = Vector2(container.scroll_horizontal, container.scroll_vertical)
	
	# Resync if drifted too far (manual drag or code change)
	var current = Vector2(container.scroll_horizontal, container.scroll_vertical)
	var stored = _scroll_targets[container]
	if current.distance_to(stored) > 50.0:
		_scroll_targets[container] = current
	
	var step = _scroll_step * event.factor
	var delta_v = Vector2.ZERO
	
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.shift_pressed: delta_v.x -= step
			else: delta_v.y -= step
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.shift_pressed: delta_v.x += step
			else: delta_v.y += step
		MOUSE_BUTTON_WHEEL_LEFT:
			delta_v.x -= step
		MOUSE_BUTTON_WHEEL_RIGHT:
			delta_v.x += step

	# Calculate Max Scroll using ScrollBars
	var h_bar = container.get_h_scroll_bar()
	var v_bar = container.get_v_scroll_bar()
	var max_h = (h_bar.max_value - h_bar.page) if h_bar else 0.0
	var max_v = (v_bar.max_value - v_bar.page) if v_bar else 0.0
	
	if max_h < 0: max_h = 0
	if max_v < 0: max_v = 0
	
	_scroll_targets[container] += delta_v
	
	# Clamp target
	_scroll_targets[container].x = clamp(_scroll_targets[container].x, 0, max_h)
	_scroll_targets[container].y = clamp(_scroll_targets[container].y, 0, max_v)

func _process(delta: float) -> void:
	var to_remove = []
	
	for container in _scroll_targets:
		if not is_instance_valid(container) or not container.is_visible_in_tree():
			to_remove.append(container)
			continue
			
		var target = _scroll_targets[container]
		var current_h = float(container.scroll_horizontal)
		var current_v = float(container.scroll_vertical)
		
		var new_h = lerp(current_h, target.x, delta * _scroll_speed)
		var new_v = lerp(current_v, target.y, delta * _scroll_speed)
		
		if abs(new_h - target.x) < 1.0: new_h = target.x
		if abs(new_v - target.y) < 1.0: new_v = target.y
		
		# Set
		container.scroll_horizontal = int(new_h)
		container.scroll_vertical = int(new_v)
		
		if new_h == target.x and new_v == target.y:
			pass
		
	for c in to_remove:
		_scroll_targets.erase(c)

func _find_scroll_container_at_point(node: Node, point: Vector2) -> ScrollContainer:
	# Reverse iteration (Front-to-Back) is critical for overlapping UI
	for i in range(node.get_child_count() - 1, -1, -1):
		var child = node.get_child(i)
		
		# Check visibility
		if child is CanvasItem:
			if !child.visible: continue
		
		# Recurse FIRST (Children are drawn on top of parent)
		var res = _find_scroll_container_at_point(child, point)
		if res: return res
		
	# Check Self (after children, meaning if no child captured it)
	if node is ScrollContainer:
		var c = node as ScrollContainer
		if c.is_visible_in_tree() and c.get_global_rect().has_point(point):
			return c
			
	return null
