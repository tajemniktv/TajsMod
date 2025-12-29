# ==============================================================================
# Buy Max Manager - Taj's Mod
# Author: TajemnikTV
# Description: Adds "Buy Max" button to upgrade tabs for batch purchasing
#              with multiple selectable purchase strategies
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:BuyMax"

# Available purchase strategies
enum Strategy {
	ROUND_ROBIN, # Even distribution across all upgrades
	CHEAPEST_FIRST, # Always buy the cheapest available upgrade
	EXPENSIVE_FIRST, # Buy the most expensive you can afford
	TOP_TO_BOTTOM # Buy first upgrade until maxed, then next
}

const STRATEGY_NAMES = {
	Strategy.ROUND_ROBIN: "Round Robin",
	Strategy.CHEAPEST_FIRST: "Cheapest First",
	Strategy.EXPENSIVE_FIRST: "Most Expensive",
	Strategy.TOP_TO_BOTTOM: "Top to Bottom"
}

const STRATEGY_DESCRIPTIONS = {
	Strategy.ROUND_ROBIN: "Even distribution - buys 1 level of each upgrade in rotation",
	Strategy.CHEAPEST_FIRST: "Always buys the cheapest available upgrade first",
	Strategy.EXPENSIVE_FIRST: "Buys the most expensive upgrade you can afford",
	Strategy.TOP_TO_BOTTOM: "Maxes out upgrades in order from top to bottom"
}

# Current selected strategy
var current_strategy: int = Strategy.ROUND_ROBIN

# Reference to the upgrades tab (VBoxContainer containing ButtonsPanel + TabContainer)
var _upgrades_tab: VBoxContainer = null
var _buy_max_container: HBoxContainer = null # Container for split button
var _buy_max_button: Button = null # Main action button
var _strategy_button: MenuButton = null # Small dropdown for strategy
var _initialized := false
var _config = null # Reference to config manager


## Initialize the Buy Max manager after HUD is ready
func setup(tree: SceneTree, config = null) -> void:
	if _initialized:
		return
	
	_config = config
	
	# Load saved strategy from config
	if _config:
		current_strategy = _config.get_value("buy_max_strategy", Strategy.ROUND_ROBIN)
	
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
	ModLoaderLog.info("Buy Max manager initialized with strategy: " + STRATEGY_NAMES[current_strategy], LOG_NAME)


## Set the purchase strategy
func set_strategy(strategy: int) -> void:
	current_strategy = strategy
	if _config:
		_config.set_value("buy_max_strategy", strategy)
	_update_strategy_menu()
	Signals.notify.emit("check", "Strategy: " + STRATEGY_NAMES[strategy])
	ModLoaderLog.info("Buy Max strategy set to: " + STRATEGY_NAMES[strategy], LOG_NAME)


## Get current strategy for external use (e.g., options_bar)
func get_strategy() -> int:
	return current_strategy


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


## Inject the Buy Max split button into the ButtonsPanel
func _inject_buy_max_button() -> void:
	var buttons_container = _upgrades_tab.get_node_or_null("ButtonsPanel/ButtonsContainer")
	if not buttons_container:
		ModLoaderLog.warning("ButtonsContainer not found in upgrades tab", LOG_NAME)
		return
	
	# Check if already injected
	if buttons_container.has_node("BuyMaxContainer"):
		_buy_max_container = buttons_container.get_node("BuyMaxContainer")
		return
	
	# Create container for split button layout - match game styling
	_buy_max_container = HBoxContainer.new()
	_buy_max_container.name = "BuyMaxContainer"
	_buy_max_container.size_flags_horizontal = Control.SIZE_FILL
	_buy_max_container.size_flags_vertical = Control.SIZE_FILL
	_buy_max_container.add_theme_constant_override("separation", 0)
	
	# Main "Buy Max" button - matches game's TabButton style exactly
	_buy_max_button = Button.new()
	_buy_max_button.name = "BuyMaxButton"
	_buy_max_button.text = "Buy Max"
	_buy_max_button.size_flags_horizontal = Control.SIZE_FILL
	_buy_max_button.size_flags_vertical = Control.SIZE_FILL
	_buy_max_button.focus_mode = Control.FOCUS_NONE
	_buy_max_button.theme_type_variation = "TabButton"
	_buy_max_button.add_theme_font_size_override("font_size", 28)
	_buy_max_button.pressed.connect(_execute_buy_max)
	_update_main_button_tooltip()
	
	# Small dropdown button for strategy selection - styled to match
	_strategy_button = MenuButton.new()
	_strategy_button.name = "StrategyButton"
	_strategy_button.text = "▼"
	_strategy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_strategy_button.size_flags_vertical = Control.SIZE_FILL
	_strategy_button.focus_mode = Control.FOCUS_NONE
	_strategy_button.theme_type_variation = "TabButton"
	_strategy_button.custom_minimum_size = Vector2(45, 0)
	_strategy_button.tooltip_text = "Select purchase strategy"
	
	# Setup strategy popup menu
	var popup = _strategy_button.get_popup()
	popup.clear()
	for strategy_id in STRATEGY_NAMES.keys():
		popup.add_item(STRATEGY_NAMES[strategy_id], strategy_id)
	popup.id_pressed.connect(_on_strategy_selected)
	_update_strategy_menu()
	
	# Add to container
	_buy_max_container.add_child(_buy_max_button)
	_buy_max_container.add_child(_strategy_button)
	buttons_container.add_child(_buy_max_container)
	
	ModLoaderLog.info("Buy Max split button injected into upgrades tab", LOG_NAME)


## Update main button tooltip to show current strategy
func _update_main_button_tooltip() -> void:
	if _buy_max_button:
		_buy_max_button.tooltip_text = "Buy upgrades using: %s\n%s" % [
			STRATEGY_NAMES[current_strategy],
			STRATEGY_DESCRIPTIONS[current_strategy]
		]


## Update strategy menu checkmarks
func _update_strategy_menu() -> void:
	if not _strategy_button:
		return
	
	var popup = _strategy_button.get_popup()
	if not popup:
		return
	
	for i in range(popup.item_count):
		var item_id = popup.get_item_id(i)
		if item_id in STRATEGY_NAMES:
			var base_text = STRATEGY_NAMES[item_id]
			if item_id == current_strategy:
				popup.set_item_text(i, "✓ " + base_text)
			else:
				popup.set_item_text(i, "   " + base_text)
	
	_update_main_button_tooltip()


## Handle strategy selection from dropdown
func _on_strategy_selected(id: int) -> void:
	if id in STRATEGY_NAMES:
		set_strategy(id)
		Sound.play("click_toggle2")


## Execute the buy max with current strategy
func _execute_buy_max() -> void:
	Sound.play("click_toggle2")
	var purchased = _do_buy_max()
	
	if purchased > 0:
		Signals.notify.emit("check", "Bought %d upgrades (%s)" % [purchased, STRATEGY_NAMES[current_strategy]])
	else:
		Signals.notify.emit("exclamation", "Nothing affordable on this page")


## Main purchase algorithm - dispatches to the selected strategy
## Returns total number of upgrades purchased
func _do_buy_max() -> int:
	var panels = _get_active_upgrade_panels()
	if panels.is_empty():
		return 0
	
	# Filter out token upgrades
	var filtered_panels: Array = []
	for panel in panels:
		var currency_key = _get_currency_key(panel)
		if currency_key != "currency:token":
			filtered_panels.append(panel)
	
	if filtered_panels.is_empty():
		return 0
	
	# Dispatch to appropriate strategy
	match current_strategy:
		Strategy.ROUND_ROBIN:
			return _buy_round_robin(filtered_panels)
		Strategy.CHEAPEST_FIRST:
			return _buy_cheapest_first(filtered_panels)
		Strategy.EXPENSIVE_FIRST:
			return _buy_expensive_first(filtered_panels)
		Strategy.TOP_TO_BOTTOM:
			return _buy_top_to_bottom(filtered_panels)
	
	return 0


# ==============================================================================
# PURCHASE STRATEGIES
# ==============================================================================

## Round-Robin: Even distribution - buy 1 level of each in rotation
func _buy_round_robin(panels: Array) -> int:
	var total_purchased = 0
	
	# Group by currency for fair distribution per currency type
	var by_currency: Dictionary = {}
	for panel in panels:
		var key = _get_currency_key(panel)
		if not by_currency.has(key):
			by_currency[key] = []
		by_currency[key].append(panel)
	
	# Process each currency group
	for currency_key in by_currency.keys():
		var group = by_currency[currency_key]
		var purchased_this_pass = true
		
		while purchased_this_pass:
			purchased_this_pass = false
			for panel in group:
				panel.update_all()
				if panel.can_purchase():
					panel._on_purchase_pressed()
					purchased_this_pass = true
					total_purchased += 1
		
		# Final pass
		for panel in group:
			panel.update_all()
			if panel.can_purchase():
				panel._on_purchase_pressed()
				total_purchased += 1
	
	return total_purchased


## Cheapest First: Always buy the cheapest available upgrade
func _buy_cheapest_first(panels: Array) -> int:
	var total_purchased = 0
	var purchased_any = true
	
	while purchased_any:
		purchased_any = false
		
		# Refresh all panels and find the cheapest purchasable one
		var cheapest_panel = null
		var cheapest_cost = INF
		
		for panel in panels:
			panel.update_all()
			if panel.can_purchase():
				if panel.cost < cheapest_cost:
					cheapest_cost = panel.cost
					cheapest_panel = panel
		
		# Buy the cheapest one
		if cheapest_panel:
			cheapest_panel._on_purchase_pressed()
			total_purchased += 1
			purchased_any = true
	
	return total_purchased


## Most Expensive First: Buy the most expensive upgrade you can afford
func _buy_expensive_first(panels: Array) -> int:
	var total_purchased = 0
	var purchased_any = true
	
	while purchased_any:
		purchased_any = false
		
		# Refresh all panels and find the most expensive purchasable one
		var expensive_panel = null
		var highest_cost = -1.0
		
		for panel in panels:
			panel.update_all()
			if panel.can_purchase():
				if panel.cost > highest_cost:
					highest_cost = panel.cost
					expensive_panel = panel
		
		# Buy the most expensive one
		if expensive_panel:
			expensive_panel._on_purchase_pressed()
			total_purchased += 1
			purchased_any = true
	
	return total_purchased


## Top-to-Bottom: Max out upgrades in order from top to bottom
func _buy_top_to_bottom(panels: Array) -> int:
	var total_purchased = 0
	
	# Process panels in order (they're already in UI order)
	for panel in panels:
		# Buy as many levels as possible for this upgrade
		var purchased_this_panel = true
		while purchased_this_panel:
			panel.update_all()
			if panel.can_purchase():
				panel._on_purchase_pressed()
				total_purchased += 1
			else:
				purchased_this_panel = false
	
	return total_purchased


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

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
	
	var panels: Array = []
	_find_upgrade_panels(current_tab, panels)
	
	return panels


## Recursively find all upgrade_panel instances in a node tree
func _find_upgrade_panels(node: Node, result: Array) -> void:
	if node is Panel and node.has_method("can_purchase") and node.has_method("update_all"):
		if node.visible:
			result.append(node)
	
	for child in node.get_children():
		_find_upgrade_panels(child, result)


## Get the currency key for grouping upgrades
func _get_currency_key(panel: Panel) -> String:
	var upgrade_name = panel.name
	
	if not Data.upgrades.has(upgrade_name):
		return "unknown"
	
	var upgrade_data = Data.upgrades[upgrade_name]
	var cost_type = int(upgrade_data.cost_type)
	
	if cost_type == Utils.COST_TYPES.INCREMENTAL or cost_type == Utils.COST_TYPES.FIXED:
		return "currency:" + upgrade_data.currency
	elif cost_type == Utils.COST_TYPES.ATTRIBUTE:
		return "attribute:" + upgrade_data.attribute_cost
	
	return "unknown"
