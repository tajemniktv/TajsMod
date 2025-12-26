# ==============================================================================
# Buy Max Manager - Taj's Mod
# Author: TajemnikTV
# Description: Adds "Buy Max" button to upgrade tabs for batch purchasing
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:BuyMax"

# Reference to the upgrades tab (VBoxContainer containing ButtonsPanel + TabContainer)
var _upgrades_tab: VBoxContainer = null
var _buy_max_button: Button = null
var _initialized := false


## Initialize the Buy Max manager after HUD is ready
func setup(tree: SceneTree) -> void:
	if _initialized:
		return
	
	var main = tree.root.get_node_or_null("Main")
	if not main:
		ModLoaderLog.warning("Main not found, cannot setup Buy Max", LOG_NAME)
		return
	
	var hud = main.get_node_or_null("HUD")
	if not hud:
		ModLoaderLog.warning("HUD not found, cannot setup Buy Max", LOG_NAME)
		return
	
	# Find the upgrades tab by looking for a VBoxContainer that has ButtonsPanel/ButtonsContainer
	# and TabContainer children (this is the upgrades_tab.gd structure)
	_upgrades_tab = _find_upgrades_tab(hud)
	
	if not _upgrades_tab:
		ModLoaderLog.warning("Upgrades tab not found in HUD tree", LOG_NAME)
		return
	
	_inject_buy_max_button()
	_initialized = true
	ModLoaderLog.info("Buy Max manager initialized", LOG_NAME)


## Recursively find the upgrades tab (VBoxContainer with ButtonsPanel/ButtonsContainer + TabContainer)
func _find_upgrades_tab(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		var buttons_container = node.get_node_or_null("ButtonsPanel/ButtonsContainer")
		var tab_container = node.get_node_or_null("TabContainer")
		if buttons_container and tab_container:
			ModLoaderLog.info("Found upgrades tab at: " + str(node.get_path()), LOG_NAME)
			return node
	
	for child in node.get_children():
		var result = _find_upgrades_tab(child)
		if result:
			return result
	
	return null


## Inject the Buy Max button into the ButtonsPanel
func _inject_buy_max_button() -> void:
	# Find the buttons container
	var buttons_container = _upgrades_tab.get_node_or_null("ButtonsPanel/ButtonsContainer")
	if not buttons_container:
		ModLoaderLog.warning("ButtonsContainer not found in upgrades tab", LOG_NAME)
		return
	
	# Check if already injected
	if buttons_container.has_node("BuyMaxButton"):
		_buy_max_button = buttons_container.get_node("BuyMaxButton")
		return
	
	# Create the Buy Max button matching existing button styling
	_buy_max_button = Button.new()
	_buy_max_button.name = "BuyMaxButton"
	_buy_max_button.text = "Buy Max"
	_buy_max_button.tooltip_text = "Buys as many upgrades as possible on this page (excluding Tokens)"
	
	# Match styling of other tab buttons (they use TabButton theme variation)
	_buy_max_button.theme_type_variation = "TabButton"
	_buy_max_button.custom_minimum_size = Vector2(100, 50)
	_buy_max_button.focus_mode = Control.FOCUS_NONE
	
	# Connect the pressed signal
	_buy_max_button.pressed.connect(_on_buy_max_pressed)
	
	# Add to container (at the end, after existing buttons)
	buttons_container.add_child(_buy_max_button)
	
	ModLoaderLog.info("Buy Max button injected into upgrades tab", LOG_NAME)


## Handler for Buy Max button press
func _on_buy_max_pressed() -> void:
	Sound.play("click_toggle2")
	var purchased = _do_buy_max()
	
	if purchased > 0:
		Signals.notify.emit("check", "Bought %d upgrades" % purchased)
	else:
		Signals.notify.emit("exclamation", "Nothing affordable on this page")


## Main purchase algorithm - round-robin distribution per currency
## Returns total number of upgrades purchased
func _do_buy_max() -> int:
	var panels = _get_active_upgrade_panels()
	if panels.is_empty():
		return 0
	
	# Group upgrades by their currency/cost type
	# Key format: "currency:money", "currency:research", "attribute:optimization", etc.
	var by_currency: Dictionary = {}
	
	for panel in panels:
		var currency_key = _get_currency_key(panel)
		
		# Skip token upgrades as per requirement
		if currency_key == "currency:token":
			continue
		
		if not by_currency.has(currency_key):
			by_currency[currency_key] = []
		by_currency[currency_key].append(panel)
	
	var total_purchased = 0
	
	# Process each currency group with round-robin
	for currency_key in by_currency.keys():
		var group = by_currency[currency_key]
		var purchased_this_pass = true
		
		# Round-robin: keep looping while at least one purchase was made
		while purchased_this_pass:
			purchased_this_pass = false
			
			for panel in group:
				# Refresh panel state (cost may have changed)
				panel.update_all()
				
				# Try to buy one level
				if panel.can_purchase():
					panel._on_purchase_pressed()
					purchased_this_pass = true
					total_purchased += 1
		
		# Final pass: try one more time for any remaining affordable upgrades
		for panel in group:
			panel.update_all()
			if panel.can_purchase():
				panel._on_purchase_pressed()
				total_purchased += 1
	
	return total_purchased


## Get all visible upgrade panels from the currently active tab
func _get_active_upgrade_panels() -> Array:
	if not _upgrades_tab:
		return []
	
	var tab_container = _upgrades_tab.get_node_or_null("TabContainer")
	if not tab_container:
		return []
	
	var current_tab_idx = tab_container.current_tab
	var current_tab = tab_container.get_child(current_tab_idx)
	if not current_tab:
		return []
	
	# Find all upgrade panels in the current tab
	# Panels are in various container structures depending on the tab
	var panels: Array = []
	_find_upgrade_panels(current_tab, panels)
	
	return panels


## Recursively find all upgrade_panel instances in a node tree
func _find_upgrade_panels(node: Node, result: Array) -> void:
	# Check if this is an upgrade panel (extends Panel, has can_purchase method)
	if node is Panel and node.has_method("can_purchase") and node.has_method("update_all"):
		# Only include visible panels that aren't maxed
		if node.visible:
			result.append(node)
	
	# Recurse into children
	for child in node.get_children():
		_find_upgrade_panels(child, result)


## Get the currency key for grouping upgrades
## Returns: "currency:money", "currency:research", "attribute:optimization", etc.
func _get_currency_key(panel: Panel) -> String:
	var upgrade_name = panel.name
	
	if not Data.upgrades.has(upgrade_name):
		return "unknown"
	
	var upgrade_data = Data.upgrades[upgrade_name]
	var cost_type = int(upgrade_data.cost_type)
	
	# INCREMENTAL (0) or FIXED (1) use currency
	if cost_type == Utils.COST_TYPES.INCREMENTAL or cost_type == Utils.COST_TYPES.FIXED:
		var currency = upgrade_data.currency
		return "currency:" + currency
	
	# ATTRIBUTE (2) uses attribute_cost
	elif cost_type == Utils.COST_TYPES.ATTRIBUTE:
		var attribute = upgrade_data.attribute_cost
		return "attribute:" + attribute
	
	return "unknown"
