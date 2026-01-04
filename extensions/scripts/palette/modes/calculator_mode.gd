# ==============================================================================
# Taj's Mod - Upload Labs
# Calculator Mode - Inline math expression evaluation for the palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModCalculatorMode
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/mode_base.gd"

const Calculator = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/calculator.gd")
const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

# State
var _expression: String = ""
var _result: String = ""
var _error: String = ""
var _history: Array = [] # Array of {"expr": String, "result": String}
const MAX_HISTORY = 5

# Displayed items
var _items: Array[Dictionary] = []


func enter() -> void:
	super.enter()
	_expression = ""
	_result = ""
	_error = ""


func exit() -> void:
	super.exit()
	# Keep history across mode switches


func get_breadcrumb() -> String:
	return "🧮 Calculator"


func filter(query: String) -> void:
	_expression = query
	_build_items()
	items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
	return _items


func execute_selection(item: Dictionary) -> bool:
	# Handle history item click - fill in the expression
	if item.get("_is_calc_history", false):
		var expr = item.get("_calc_expr", "")
		if not expr.is_empty():
			action_completed.emit({"action": "fill_expression", "text": "= " + expr})
			Sound.play("click")
		return true
	
	# Only copy if we have a valid result
	if not item.get("_is_calc_result", false) or _result.is_empty():
		Sound.play("error")
		return true
	
	# Add to history (most recent first)
	var expr = item.get("_calc_expr", "")
	if not expr.is_empty():
		# Remove duplicate if exists
		for i in range(_history.size() - 1, -1, -1):
			if _history[i].expr == expr:
				_history.remove_at(i)
		
		# Add to front
		_history.insert(0, {"expr": expr, "result": _result})
		
		# Limit history size
		while _history.size() > MAX_HISTORY:
			_history.pop_back()
	
	# Copy to clipboard
	DisplayServer.clipboard_set(_result)
	
	# Show notification
	Signals.notify.emit("check", "Copied: " + _result)
	
	Sound.play("click")
	request_close.emit()
	return true


func handle_back() -> bool:
	# Calculator mode can exit immediately
	return false


func create_custom_row(item: Dictionary, index: int) -> Control:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, PaletteTheme.ITEM_HEIGHT + 10)
	
	var row_style = StyleBoxFlat.new()
	
	# Different styling based on result type
	if item.get("_is_calc_result", false):
		row_style.bg_color = PaletteTheme.COLOR_CALC_SUCCESS_BG
	elif item.badge == "ERROR":
		row_style.bg_color = PaletteTheme.COLOR_CALC_ERROR_BG
	else:
		row_style.bg_color = Color(0.1, 0.12, 0.16, 0.5) # Default
	
	row_style.set_corner_radius_all(8)
	row.add_theme_stylebox_override("panel", row_style)
	
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
		title.add_theme_color_override("font_color", PaletteTheme.COLOR_CALC_SUCCESS)
	elif item.badge == "ERROR":
		title.add_theme_color_override("font_color", PaletteTheme.COLOR_CALC_ERROR)
	
	PaletteTheme.apply_text_glow(title, true)
	hbox.add_child(title)
	
	# Hint (action or error message)
	var hint = Label.new()
	hint.text = item.get("hint", "")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", PaletteTheme.COLOR_TEXT_SECONDARY)
	vbox.add_child(hint)
	
	return row


func _build_items() -> void:
	_items.clear()
	
	if _expression.is_empty():
		# Show hint for empty expression
		_items.append({
			"id": "_calc_hint",
			"title": "Type an expression",
			"hint": "e.g. = 2+2, = sqrt(144), = pi * 2^3",
			"icon_path": "res://textures/icons/info.png",
			"is_category": false,
			"badge": "HINT",
			"_is_calc_result": false
		})
		_result = ""
		_error = ""
		
		# Add recent expressions from history
		for i in range(_history.size()):
			var hist = _history[i]
			_items.append({
				"id": "_calc_history_%d" % i,
				"title": hist.expr,
				"hint": "= " + hist.result,
				"icon_path": "res://textures/icons/time.png",
				"is_category": false,
				"badge": "RECENT",
				"_is_calc_result": false,
				"_is_calc_history": true,
				"_calc_expr": hist.expr
			})
	else:
		# Evaluate expression
		var result = Calculator.evaluate(_expression)
		
		if result.success:
			_result = Calculator.format_result(result.value)
			_error = ""
			_items.append({
				"id": "_calc_result",
				"title": "Result: " + _result,
				"hint": "Enter = copy to clipboard",
				"icon_path": "res://textures/icons/check.png",
				"is_category": false,
				"badge": "SAFE",
				"_is_calc_result": true,
				"_calc_expr": _expression
			})
		else:
			_result = ""
			_error = result.error
			_items.append({
				"id": "_calc_error",
				"title": "Invalid expression",
				"hint": result.error,
				"icon_path": "res://textures/icons/exclamation.png",
				"is_category": false,
				"badge": "ERROR",
				"_is_calc_result": false
			})
