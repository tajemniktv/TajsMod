# ==============================================================================
# Taj's Mod - Upload Labs
# Workspace Bounds Manager - Central source of truth for expanded board limits
# Author: TajemnikTV
# ==============================================================================
class_name WorkspaceBounds
extends RefCounted

const LOG_NAME = "TajsModded:WorkspaceBounds"

# Vanilla board limits (from original game)
const VANILLA_LIMIT: float = 5000.0
const VANILLA_SIZE: float = 10000.0 # Total size = 2 * limit

# Safe range for multiplier
const MIN_MULTIPLIER: float = 1.0
const MAX_MULTIPLIER: float = 10.0

# Static state (shared across all instances)
static var _enabled: bool = false
static var _multiplier: float = 1.0
static var _bounds_changed_callback: Callable

## Enable/disable expanded workspace
static func set_enabled(enabled: bool) -> void:
	if _enabled != enabled:
		_enabled = enabled
		_emit_bounds_changed()

## Get whether expanded workspace is enabled
static func is_enabled() -> bool:
	return _enabled

## Set the workspace multiplier (clamped to safe range)
static func set_multiplier(value: float) -> void:
	var clamped = clampf(value, MIN_MULTIPLIER, MAX_MULTIPLIER)
	if _multiplier != clamped:
		_multiplier = clamped
		_emit_bounds_changed()

## Get the current multiplier
static func get_multiplier() -> float:
	return _multiplier

## Get the effective limit (half of total size, distance from center to edge)
static func get_limit() -> float:
	if _enabled:
		return VANILLA_LIMIT * _multiplier
	return VANILLA_LIMIT

## Get the effective bounds as a Rect2
static func get_bounds() -> Rect2:
	var limit = get_limit()
	return Rect2(-limit, -limit, limit * 2, limit * 2)

## Get the grid range (number of 50px cells in each direction from center)
static func get_grid_range() -> int:
	# Original is -99 to 100 (200 divisions) for 5000 limit
	# Scale proportionally with multiplier
	if _enabled:
		return int(100 * _multiplier)
	return 100

## Clamp a position to the effective bounds (accounting for node size)
static func clamp_position(pos: Vector2, node_size: Vector2 = Vector2.ZERO) -> Vector2:
	var limit = get_limit()
	var min_pos = - limit
	var max_pos_x = limit - node_size.x
	var max_pos_y = limit - node_size.y
	return Vector2(
		clampf(pos.x, min_pos, max_pos_x),
		clampf(pos.y, min_pos, max_pos_y)
	)

## Set a callback to be called when bounds change
static func set_bounds_changed_callback(callback: Callable) -> void:
	_bounds_changed_callback = callback

## Internal: emit bounds changed notification
static func _emit_bounds_changed() -> void:
	if _bounds_changed_callback.is_valid():
		_bounds_changed_callback.call()
	# Also emit via Signals if available
	if Engine.has_singleton("Signals"):
		pass # Signals is not a singleton, it's autoloaded differently

## Initialize from config values
static func initialize(enabled: bool, multiplier: float) -> void:
	_enabled = enabled
	_multiplier = clampf(multiplier, MIN_MULTIPLIER, MAX_MULTIPLIER)

## Get human-readable description of current bounds
static func get_description() -> String:
	if not _enabled:
		return "Vanilla (10000×10000)"
	var size = int(VANILLA_SIZE * _multiplier)
	return "%dx (%d×%d)" % [int(_multiplier), size, size]
