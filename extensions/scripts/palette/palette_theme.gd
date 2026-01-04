# ==============================================================================
# Taj's Mod - Upload Labs
# Palette Theme - Shared colors, dimensions, and style factories
# Author: TajemnikTV
# ==============================================================================
class_name TajsModPaletteTheme
extends RefCounted

# ==============================================================================
# Dimensions
# ==============================================================================

const PANEL_WIDTH = 600
const PANEL_HEIGHT = 500
const ITEM_HEIGHT = 50
const MAX_VISIBLE_ITEMS = 10

# ==============================================================================
# Colors - Background & Panel
# ==============================================================================

const COLOR_BG_DIM = Color(0, 0, 0, 0.6)
const COLOR_BG_PANEL = Color(0.08, 0.1, 0.14, 0.95)
const COLOR_BG_FOOTER = Color(0.06, 0.08, 0.1, 0.8)
const COLOR_BG_INPUT = Color(0.12, 0.14, 0.18, 0.8)
const COLOR_BG_ROW = Color(0.1, 0.12, 0.16, 0.3)
const COLOR_BG_SECTION = Color(0.06, 0.1, 0.15, 0.8)
const COLOR_BG_AUTOCOMPLETE = Color(0.12, 0.18, 0.24, 0.9)

# ==============================================================================
# Colors - Selection & Interaction
# ==============================================================================

const COLOR_SELECTED = Color(0.2, 0.4, 0.6, 0.8)
const COLOR_HOVER = Color(0.15, 0.25, 0.35, 0.5)

# ==============================================================================
# Colors - Borders
# ==============================================================================

const COLOR_BORDER_PANEL = Color(0.3, 0.5, 0.7, 0.6)
const COLOR_BORDER_SELECTED = Color(0.4, 0.6, 0.8, 0.6)
const COLOR_BORDER_SECTION = Color(0.25, 0.4, 0.55, 0.7)
const COLOR_BORDER_AUTOCOMPLETE = Color(0.4, 0.6, 0.8, 0.6)

# ==============================================================================
# Colors - Badges
# ==============================================================================

const COLOR_BADGE_SAFE = Color(0.3, 0.7, 0.4)
const COLOR_BADGE_OPTIN = Color(0.85, 0.65, 0.2)
const COLOR_BADGE_GAMEPLAY = Color(0.8, 0.3, 0.3)

# ==============================================================================
# Colors - Text
# ==============================================================================

const COLOR_TEXT_PRIMARY = Color(0.9, 0.95, 1.0)
const COLOR_TEXT_SECONDARY = Color(0.6, 0.7, 0.8)
const COLOR_TEXT_MUTED = Color(0.5, 0.5, 0.5)
const COLOR_TEXT_HINT = Color(0.4, 0.5, 0.6)
const COLOR_TEXT_BREADCRUMB = Color(0.6, 0.7, 0.8)
const COLOR_TEXT_SHADOW = Color(0, 0, 0, 0.8)
const COLOR_TEXT_GLOW = Color(0.4, 0.65, 1.0, 0.5)

# Calculator-specific colors
const COLOR_CALC_SUCCESS = Color(0.4, 1.0, 0.5)
const COLOR_CALC_ERROR = Color(1.0, 0.5, 0.4)
const COLOR_CALC_SUCCESS_BG = Color(0.1, 0.25, 0.15, 0.8)
const COLOR_CALC_ERROR_BG = Color(0.25, 0.1, 0.1, 0.8)

# Definition panel colors
const COLOR_DEF_BG = Color(0.08, 0.1, 0.14, 0.98)
const COLOR_DEF_BORDER = Color(0.25, 0.4, 0.55, 0.7)
const COLOR_DEF_POSITIVE = Color(0.5, 1.0, 0.6)
const COLOR_DEF_NEGATIVE = Color(1.0, 0.5, 0.4)
const COLOR_DEF_NEUTRAL = Color(0.8, 0.85, 0.9)

# ==============================================================================
# Style Factories
# ==============================================================================

## Create main panel style
static func create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_PANEL
	style.border_color = COLOR_BORDER_PANEL
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	return style


## Create row style for result items
static func create_row_style(selected: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if selected:
		style.bg_color = COLOR_SELECTED
		style.border_color = COLOR_BORDER_SELECTED
		style.set_border_width_all(1)
	else:
		style.bg_color = COLOR_BG_ROW
		style.set_border_width_all(0)
	style.set_corner_radius_all(6)
	return style


## Create footer style
static func create_footer_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_FOOTER
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


## Create input field style
static func create_input_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## Create section panel style
static func create_section_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_SECTION
	style.set_corner_radius_all(6)
	return style


## Create autocomplete row style
static func create_autocomplete_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_AUTOCOMPLETE
	style.border_color = COLOR_BORDER_AUTOCOMPLETE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Create definition panel base style
static func create_definition_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_DEF_BG
	style.border_color = COLOR_DEF_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style


## Create onboarding hint style
static func create_onboarding_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.25, 0.35, 0.95)
	style.border_color = Color(0.4, 0.6, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


## Apply text glow effect to a label
static func apply_text_glow(label: Label, use_glow: bool = true) -> void:
	if use_glow:
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", COLOR_TEXT_GLOW)


## Get badge color by type
static func get_badge_color(badge_type: String) -> Color:
	match badge_type:
		"SAFE":
			return COLOR_BADGE_SAFE
		"OPT-IN":
			return COLOR_BADGE_OPTIN
		"GAMEPLAY":
			return COLOR_BADGE_GAMEPLAY
		_:
			return COLOR_TEXT_SECONDARY
