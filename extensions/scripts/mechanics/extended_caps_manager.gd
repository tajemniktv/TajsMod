# ==============================================================================
# Taj's Mod - Upload Labs
# Extended Caps Manager - Handles cap overrides and post-cap cost curves
# Author: TajemnikTV
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:ExtendedCaps"

# Cap modes
enum CapMode {VANILLA, EXTENDED, UNLIMITED}

# Cost curve modes
enum CostCurve {OFF, EXPONENTIAL, POLYNOMIAL}

# Max cost to prevent overflow (below GDScript INF)
const MAX_COST: float = 1e300

# Unlimited cap value
const UNLIMITED_CAP: int = 999999

# Vanilla base caps (fallback if runtime detection fails)
const VANILLA_CAPS := {
	"processor": 53,
	"gpu_cluster": 48,
	"network": 112,
	"data_lab": 200,
}

# System config structure
var _systems: Dictionary = {} # system_name -> { enabled, mode, extended_cap, cost_curve, exp_mult, poly_k, poly_p, base_cap, cached_multipliers }

var _config = null # ConfigManager reference
var _mod_main_ref = null # For debug logging

# ==============================================================================
# SETUP
# ==============================================================================

func setup(config, mod_main_ref = null) -> void:
	_config = config
	_mod_main_ref = mod_main_ref
	_init_systems()
	print("[ExtCaps] Manager setup complete!")
	_log("Extended Caps Manager initialized")

func _init_systems() -> void:
	# Initialize each system with defaults
	for system_name in ["processor", "gpu_cluster", "network", "data_lab"]:
		_systems[system_name] = _load_system_config(system_name)
		print("[ExtCaps] Loaded %s: enabled=%s, mode=%s" % [system_name, _systems[system_name].enabled, _systems[system_name].mode])
	_log("Loaded config for %d systems" % _systems.size())

func _load_system_config(system_name: String) -> Dictionary:
	var vanilla_cap = VANILLA_CAPS.get(system_name, 100)
	
	return {
		"enabled": _config.get_value("extended_caps_%s_enabled" % system_name, false),
		"mode": _config.get_value("extended_caps_%s_mode" % system_name, CapMode.VANILLA),
		"extended_cap": _config.get_value("extended_caps_%s_cap" % system_name, vanilla_cap * 2),
		"cost_curve": _config.get_value("extended_caps_%s_curve" % system_name, CostCurve.EXPONENTIAL),
		"exp_mult": _config.get_value("extended_caps_%s_exp_mult" % system_name, 1.10),
		"poly_k": _config.get_value("extended_caps_%s_poly_k" % system_name, 0.05),
		"poly_p": _config.get_value("extended_caps_%s_poly_p" % system_name, 2.0),
		"base_cap": vanilla_cap,
		"cached_multipliers": {}, # level -> multiplier cache
	}

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Get the effective cap for a system
func get_cap(system_name: String) -> int:
	var sys = _get_system(system_name)
	if sys == null or not sys.enabled:
		return sys.base_cap if sys else VANILLA_CAPS.get(system_name, 100)
	
	# Cast mode to int because JSON stores it as float but enum is int
	var mode = int(sys.mode)
	match mode:
		CapMode.VANILLA:
			return sys.base_cap
		CapMode.EXTENDED:
			return sys.extended_cap
		CapMode.UNLIMITED:
			return UNLIMITED_CAP
	
	return sys.base_cap # Fail-soft

## Get the base (vanilla) cap for a system
func get_base_cap(system_name: String) -> int:
	var sys = _get_system(system_name)
	if sys:
		return sys.base_cap
	return VANILLA_CAPS.get(system_name, 100)

## Check if a system is at or past its effective cap
func is_capped(system_name: String, level: int) -> bool:
	return level >= get_cap(system_name)

## Check if extended caps are enabled for a system
func is_enabled(system_name: String) -> bool:
	var sys = _get_system(system_name)
	if sys == null:
		print("[ExtCaps] is_enabled(%s) = false (system not found)" % system_name)
		return false
	# Feature is enabled if toggle is on AND mode is not Vanilla
	# Cast mode to int because JSON stores it as float
	var mode = int(sys.mode)
	var result = sys.enabled and mode != CapMode.VANILLA
	print("[ExtCaps] is_enabled(%s): enabled=%s, mode=%s, result=%s" % [system_name, sys.enabled, mode, result])
	return result

## Calculate cost with post-cap multiplier applied
## Returns: modified cost (clamped to MAX_COST)
func get_cost(system_name: String, base_cost: float, level: int) -> float:
	var sys = _get_system(system_name)
	
	# Fail-soft: if system unknown or disabled, return base cost
	if sys == null or not sys.enabled:
		return minf(base_cost, MAX_COST)
	
	var base_cap = sys.base_cap
	
	# No multiplier if below base cap
	if level < base_cap:
		return minf(base_cost, MAX_COST)
	
	# Get or compute multiplier
	var multiplier = _get_cached_multiplier(sys, level, base_cap)
	var final_cost = base_cost * multiplier
	
	# Clamp to prevent overflow
	final_cost = minf(final_cost, MAX_COST)
	
	_log("Cost calc: %s level %d, base %.2e, mult %.4f, final %.2e" % [
		system_name, level, base_cost, multiplier, final_cost
	])
	
	return final_cost

## Update config for a system (called from settings UI)
func set_system_config(system_name: String, key: String, value) -> void:
	if not _systems.has(system_name):
		_log("WARNING: Unknown system '%s'" % system_name, true)
		return
	
	_systems[system_name][key] = value
	
	# Clear cache when curve params change
	if key in ["cost_curve", "exp_mult", "poly_k", "poly_p"]:
		_systems[system_name].cached_multipliers.clear()
	
	# Refresh windows when enabled/mode changes
	if key in ["enabled", "mode"]:
		_refresh_windows_for_system(system_name)
	
	# Save to config
	_config.set_value("extended_caps_%s_%s" % [system_name, key], value)
	_log("Set %s.%s = %s" % [system_name, key, str(value)])

## Get system config for UI
func get_system_config(system_name: String) -> Dictionary:
	return _systems.get(system_name, {}).duplicate()

## Get all system names
func get_system_names() -> Array:
	return _systems.keys()

# ==============================================================================
# INTERNAL
# ==============================================================================

func _get_system(system_name: String):
	if _systems.has(system_name):
		return _systems[system_name]
	_log("WARNING: Unknown system '%s', using fail-soft" % system_name, true)
	return null

## Refresh all windows of a given type to update their UI
func _refresh_windows_for_system(system_name: String) -> void:
	# Map system names to window script names
	var window_types = {
		"processor": "window_processor",
		"gpu_cluster": "window_gpu_cluster",
		"network": "window_network",
		"data_lab": "window_data_lab",
	}
	
	var window_type = window_types.get(system_name, "")
	if window_type.is_empty():
		return
	
	# Find all windows in the scene tree
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return
	
	var root = tree.root
	if not root:
		return
	
	# Search for windows of this type and call update_all
	var windows_refreshed = 0
	for node in _get_all_nodes(root):
		if node.has_method("update_all") and node.get_script():
			var script_path = node.get_script().resource_path
			if window_type in script_path:
				node.update_all()
				windows_refreshed += 1
	
	if windows_refreshed > 0:
		_log("Refreshed %d %s windows" % [windows_refreshed, system_name])

## Get all nodes in the scene tree recursively
func _get_all_nodes(node: Node) -> Array:
	var nodes = [node]
	for child in node.get_children():
		nodes.append_array(_get_all_nodes(child))
	return nodes

func _get_cached_multiplier(sys: Dictionary, level: int, base_cap: int) -> float:
	var levels_past_cap = level - base_cap + 1
	
	# Check cache
	if sys.cached_multipliers.has(levels_past_cap):
		return sys.cached_multipliers[levels_past_cap]
	
	# Compute multiplier based on curve mode
	var multiplier: float = 1.0
	
	match sys.cost_curve:
		CostCurve.OFF:
			multiplier = 1.0
		CostCurve.EXPONENTIAL:
			# cost *= (exp_mult)^(level - BaseCap + 1)
			multiplier = pow(sys.exp_mult, float(levels_past_cap))
		CostCurve.POLYNOMIAL:
			# cost *= 1 + poly_k * (level - BaseCap + 1)^poly_p
			multiplier = 1.0 + sys.poly_k * pow(float(levels_past_cap), sys.poly_p)
	
	# Clamp multiplier to prevent extreme values
	multiplier = clampf(multiplier, 1.0, 1e100)
	
	# Cache it
	sys.cached_multipliers[levels_past_cap] = multiplier
	
	return multiplier

func _log(message: String, force: bool = false) -> void:
	if _mod_main_ref and _mod_main_ref.has_method("_debug_log_wrapper"):
		_mod_main_ref._debug_log_wrapper("[ExtCaps] " + message, force)
	elif force or (_config and _config.get_value("debug_mode", false)):
		ModLoaderLog.info(message, LOG_NAME)

# ==============================================================================
# RESEARCH UPGRADES (Special handling)
# ==============================================================================

## Check if a research upgrade should bypass its vanilla limit
func is_research_extended(upgrade_name: String) -> bool:
	return _config.get_value("extended_caps_research_enabled", false)

## Get the effective limit for a research upgrade
func get_research_limit(upgrade_name: String, vanilla_limit: int) -> int:
	if not is_research_extended(upgrade_name):
		return vanilla_limit
	
	var mode = _config.get_value("extended_caps_research_mode", CapMode.VANILLA)
	match mode:
		CapMode.VANILLA:
			return vanilla_limit
		CapMode.EXTENDED:
			var extended = _config.get_value("extended_caps_research_cap", vanilla_limit * 2)
			return extended
		CapMode.UNLIMITED:
			return UNLIMITED_CAP
	
	return vanilla_limit

## Get post-cap cost for research upgrades
func get_research_cost(upgrade_name: String, base_cost: float, current_level: int, vanilla_limit: int) -> float:
	if not is_research_extended(upgrade_name):
		return minf(base_cost, MAX_COST)
	
	if current_level < vanilla_limit:
		return minf(base_cost, MAX_COST)
	
	var levels_past = current_level - vanilla_limit + 1
	var curve = _config.get_value("extended_caps_research_curve", CostCurve.EXPONENTIAL)
	var multiplier: float = 1.0
	
	match curve:
		CostCurve.OFF:
			multiplier = 1.0
		CostCurve.EXPONENTIAL:
			var exp_mult = _config.get_value("extended_caps_research_exp_mult", 1.10)
			multiplier = pow(exp_mult, float(levels_past))
		CostCurve.POLYNOMIAL:
			var poly_k = _config.get_value("extended_caps_research_poly_k", 0.05)
			var poly_p = _config.get_value("extended_caps_research_poly_p", 2.0)
			multiplier = 1.0 + poly_k * pow(float(levels_past), poly_p)
	
	multiplier = clampf(multiplier, 1.0, 1e100)
	var final_cost = minf(base_cost * multiplier, MAX_COST)
	
	_log("Research cost: %s level %d (past %d), mult %.4f, final %.2e" % [
		upgrade_name, current_level, vanilla_limit, multiplier, final_cost
	])
	
	return final_cost
