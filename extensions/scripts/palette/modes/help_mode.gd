# ==============================================================================
# Taj's Mod - Upload Labs
# Help Mode - Command reference and documentation for the palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModHelpMode
extends "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/modes/mode_base.gd"

const PaletteTheme = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_theme.gd")

# State
var _query: String = ""
var _detail_mode: bool = false
var _detail_command_id: String = ""
var _items: Array[Dictionary] = []

# References (set by overlay)
var registry = null
var context = null
var _command_cache: Array = []
var _command_meta_cache: Dictionary = {}


func enter() -> void:
	super.enter()
	_query = ""
	_detail_mode = false
	_detail_command_id = ""


func exit() -> void:
	super.exit()
	_query = ""
	_detail_mode = false
	_detail_command_id = ""


func get_breadcrumb() -> String:
	if _detail_mode and not _detail_command_id.is_empty():
		var meta = _command_meta_cache.get(_detail_command_id, {})
		return "Help: " + str(meta.get("display_name", ""))
	if _query.is_empty():
		return "Help"
	return "Help: " + _query


func filter(query: String) -> void:
	_query = query
	if _detail_mode:
		_detail_mode = false
		_detail_command_id = ""
	_build_items()
	items_updated.emit(_items)


func get_items() -> Array[Dictionary]:
	return _items


func execute_selection(item: Dictionary) -> bool:
	if item.get("_is_help_category", false):
		return true # Categories aren't selectable
	
	if item.get("_help_insert", false):
		var insert_text = str(item.get("_help_insert_text", "")).strip_edges()
		if not insert_text.is_empty():
			action_completed.emit({"action": "insert_text", "text": insert_text + " "})
			Sound.play("click")
		return true
	
	if item.get("_help_entry", false):
		var meta = item.get("_help_meta", {})
		_show_details(meta.get("id", item.get("id", "")))
		Sound.play("click")
		return true
	
	return false


func handle_back() -> bool:
	if _detail_mode:
		_detail_mode = false
		_detail_command_id = ""
		_build_items()
		items_updated.emit(_items)
		breadcrumb_changed.emit(get_breadcrumb())
		return true
	return false


func create_custom_row(item: Dictionary, index: int) -> Control:
	if _detail_mode:
		return _create_detail_row(item, index)
	
	if item.get("_is_help_category", false):
		return _create_category_row(item)
	
	return _create_entry_row(item, index)


func setup_references(reg, ctx, cache: Array, meta_cache: Dictionary) -> void:
	registry = reg
	context = ctx
	_command_cache = cache
	_command_meta_cache = meta_cache


func _build_items() -> void:
	if _detail_mode:
		return
	
	_items.clear()
	var items_by_category: Dictionary = {}
	var query_lower = _query.to_lower()
	
	for cmd in _command_cache:
		if not _is_command_visible(cmd):
			continue
		
		var meta = _command_meta_cache.get(cmd.get("id", ""), {})
		if meta.get("hidden", false):
			continue
		
		var score = 1.0 if query_lower.is_empty() else _match_score(query_lower, meta)
		if score <= 0.0:
			continue
		
		var category = meta.get("category", "Other")
		if not items_by_category.has(category):
			items_by_category[category] = []
		
		items_by_category[category].append({
			"id": meta.get("id", ""),
			"title": meta.get("display_name", ""),
			"hint": meta.get("description", ""),
			"usage": meta.get("usage", ""),
			"_help_entry": true,
			"_help_meta": meta,
			"_help_score": score
		})
	
	var categories = items_by_category.keys()
	categories.sort()
	
	for category in categories:
		var group = items_by_category[category]
		group.sort_custom(func(a, b):
			if a.get("_help_score", 0.0) == b.get("_help_score", 0.0):
				return str(a.get("title", "")) < str(b.get("title", ""))
			return a.get("_help_score", 0.0) > b.get("_help_score", 0.0)
		)
		
		_items.append({
			"id": "_help_cat_" + str(category),
			"title": str(category),
			"_is_help_category": true
		})
		
		for entry in group:
			_items.append(entry)


func _show_details(command_id: String) -> void:
	var meta = _command_meta_cache.get(command_id, {})
	if meta.is_empty():
		return
	
	_detail_mode = true
	_detail_command_id = command_id
	
	_items.clear()
	
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
	
	_items.append({"id": "_help_desc", "title": tr("Description"), "value": desc_text})
	_items.append({"id": "_help_usage", "title": tr("Usage"), "value": usage_text})
	_items.append({"id": "_help_aliases", "title": tr("Aliases"), "value": alias_text})
	_items.append({"id": "_help_examples", "title": tr("Examples"), "value": example_text})
	
	var insert_text = meta.get("command_text", "")
	if insert_text.is_empty():
		insert_text = meta.get("display_name", "")
	
	_items.append({
		"id": "_help_insert",
		"title": tr("Insert into input"),
		"value": insert_text + " ",
		"hint": tr("Press Enter to insert"),
		"_help_action": true,
		"_help_insert": true,
		"_help_insert_text": insert_text
	})
	
	items_updated.emit(_items)
	breadcrumb_changed.emit(get_breadcrumb())


func _is_command_visible(cmd: Dictionary) -> bool:
	var badge = cmd.get("badge", "SAFE")
	if badge in ["OPT-IN", "GAMEPLAY"]:
		if context and not context.are_tools_enabled():
			return false
	
	var can_run_func = cmd.get("can_run", Callable())
	if can_run_func.is_valid() and context:
		return can_run_func.call(context)
	
	return true


func _match_score(query: String, meta: Dictionary) -> float:
	var score = 0.0
	
	score = max(score, _score_text(query, str(meta.get("display_name", ""))) * 1.2)
	
	for alias in meta.get("aliases", []):
		score = max(score, _score_text(query, str(alias)) * 1.0)
	
	for tag in meta.get("tags", []):
		score = max(score, _score_text(query, str(tag)) * 0.7)
	
	var desc = str(meta.get("description", "")).to_lower()
	if not desc.is_empty() and query in desc:
		score = max(score, 30.0)
	
	if score > 0.0:
		score += 10.0 / (str(meta.get("display_name", "")).length() + 1)
	return score


func _score_text(query: String, text: String) -> float:
	var q = query.to_lower()
	var t = text.to_lower()
	
	if t == q:
		return 120.0
	if t.begins_with(q):
		return 100.0
	if q in t:
		return 70.0
	if _fuzzy_match(q, t):
		return 45.0
	return 0.0


func _fuzzy_match(query: String, text: String) -> bool:
	var query_idx = 0
	var text_idx = 0
	
	while query_idx < query.length() and text_idx < text.length():
		if query[query_idx] == text[text_idx]:
			query_idx += 1
		text_idx += 1
	
	return query_idx == query.length()


func _create_category_row(item: Dictionary) -> Control:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, PaletteTheme.ITEM_HEIGHT - 10)
	
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


func _create_entry_row(item: Dictionary, index: int) -> Control:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, PaletteTheme.ITEM_HEIGHT + 6)
	
	var row_style = PaletteTheme.create_row_style(false)
	row.add_theme_stylebox_override("panel", row_style)
	
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
	PaletteTheme.apply_text_glow(title, true)
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
	desc.add_theme_color_override("font_color", PaletteTheme.COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	return row


func _create_detail_row(item: Dictionary, index: int) -> Control:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, PaletteTheme.ITEM_HEIGHT)
	
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.1, 0.12, 0.16, 0.35)
	row_style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", row_style)
	
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
	value.add_theme_color_override("default_color", PaletteTheme.COLOR_TEXT_PRIMARY)
	value.text = item.get("value", "")
	vbox.add_child(value)
	
	if item.get("_help_action", false):
		var hint = Label.new()
		hint.text = item.get("hint", "")
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", PaletteTheme.COLOR_TEXT_SECONDARY)
		vbox.add_child(hint)
	
	return row
