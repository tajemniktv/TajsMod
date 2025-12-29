# ==============================================================================
# Taj's Mod - Upload Labs
# Upgrade Manager - Handles bulk upgrades via modifier keys
# Author: TajemnikTV
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:UpgradeManager"
# const _BUTTON_PATH = "TitlePanel/TitleContainer/UpgradeButton" # Old path

var _config: Object # Was ConfigFile but Mod uses wrapper
var _debug_mode: bool = false
var _tree: SceneTree

func setup(tree: SceneTree, config: Object) -> void:
    _tree = tree
    _config = config
    
    # Listen for new windows
    if Signals.has_signal("window_created"):
        Signals.window_created.connect(_on_window_created)
        
    # Scan for existing windows (in case mod loaded after windows created)
    _scan_existing_windows()

    ModLoaderLog.info("Upgrade Manager initialized", LOG_NAME)

func _scan_existing_windows() -> void:
    if not _tree: return
    var main = _tree.root.get_node_or_null("Main")
    if not main:
        ModLoaderLog.debug("UpgradeManager: Main node not found during scan", LOG_NAME)
        return
    
    # Path seems to be Main -> HUD -> Main -> MainContainer -> Windows
    # But let's be robust and try a few known paths
    var windows_node = main.get_node_or_null("HUD/Main/MainContainer/Windows")
    
    if not windows_node:
        # Fallback: Look in just Main/MainContainer/Windows
        windows_node = main.get_node_or_null("MainContainer/Windows")
        
    if not windows_node:
        # Fallback: Search recursively for a node named "Windows"
        windows_node = _find_node_by_name(main, "Windows")
        
    if windows_node:
        ModLoaderLog.debug("UpgradeManager: Scanning " + str(windows_node.get_child_count()) + " existing windows in " + str(windows_node.get_path()), LOG_NAME)
        for child in windows_node.get_children():
            _on_window_created(child)
    else:
        ModLoaderLog.debug("UpgradeManager: 'Windows' container not found anywhere in Main", LOG_NAME)

## Helper to find a node by name recursively
func _find_node_by_name(root: Node, target_name: String) -> Node:
    if root.name == target_name:
        return root
    
    for child in root.get_children():
        var res = _find_node_by_name(child, target_name)
        if res: return res
        
    return null


func _on_window_created(window: Node) -> void:
    if not is_instance_valid(window):
        return
        
    # Check if window has an upgrade button
    # It could be in multiple places depending on the window type.
    var upgrade_btn: BaseButton = null
    
    # List of possible paths to check
    var paths = [
        "TitlePanel/TitleContainer/UpgradeButton", # Generic Windows
        "UpgradeButton", # Miner, etc.
        "PanelContainer/MainContainer/UpgradeButton", # Others
        "MainContainer/UpgradeButton",
        "Upgrade/UpgradeButton"
    ]
    
    for path in paths:
        var node = window.get_node_or_null(path)
        if node and node is BaseButton:
            upgrade_btn = node
            ModLoaderLog.info("Found upgrade button at: " + path + " for window: " + window.name, LOG_NAME)
            break
            
    if not upgrade_btn:
        # Debug why not found (sample first few to avoid spam)
        # ModLoaderLog.debug("No upgrade button found for: " + window.name, LOG_NAME)
        return
    
    if upgrade_btn:
        # Avoid duplicate connections
        if not upgrade_btn.pressed.is_connected(_on_upgrade_button_pressed.bind(window)):
            upgrade_btn.pressed.connect(_on_upgrade_button_pressed.bind(window))
            ModLoaderLog.info("Connected modifier upgrade logic to window: " + window.name, LOG_NAME)
            
        # Update tooltip
        _update_upgrade_tooltip(upgrade_btn)

func _update_upgrade_tooltip(btn: BaseButton) -> void:
    var mult = Globals.custom_upgrade_multiplier
    var hint = "\n\nCtrl + Click: +%d\nAlt + Click: +100" % mult
    
    if btn.tooltip_text.is_empty():
        btn.tooltip_text = "Upgrade"
        
    if not hint in btn.tooltip_text:
        btn.tooltip_text += hint

func _on_upgrade_button_pressed(window: Node) -> void:
    if not is_instance_valid(window):
        return
        
    # Determine multiplier
    var extra_upgrades = 0
    if Input.is_key_pressed(KEY_ALT):
        extra_upgrades = 99 # Total 100
    elif Input.is_key_pressed(KEY_CTRL):
        var mult = Globals.custom_upgrade_multiplier
        extra_upgrades = mult - 1
            
    if extra_upgrades <= 0:
        return

    # Check abilities
    if not window.has_method("can_upgrade") or not window.has_method("upgrade"):
        return
        
    # ModLoaderLog.debug("Upgrade Modifier: Extra upgrades requested: " + str(extra_upgrades), LOG_NAME)
    
    # Perform extra upgrades
    var total_extra = 0
    
    for i in range(extra_upgrades):
        # Using loop to upgrade one by one
        # 1. Get cost
        var current_cost = 0.0
        # Try different ways to get cost
        if window.has_method("get_upgrade_cost"):
            # Some windows might take level arg, others don't?
            # Usually get_upgrade_cost takes level.
            if "level" in window:
                current_cost = window.get_upgrade_cost(window.level)
        elif "cost" in window:
            current_cost = window.cost
        
        # ModLoaderLog.debug("Upgrade loop " + str(i) + ": Current cost: " + str(current_cost) + ", Money: " + str(Globals.currencies.get("money", 0)), LOG_NAME)
        
        if current_cost <= 0:
            # ModLoaderLog.debug("Loop break: cost <= 0", LOG_NAME)
            break
            
        # 2. Check affordability
        var money = Globals.currencies.get("money", 0)
        if money < current_cost:
            # ModLoaderLog.debug("Loop break: insufficient money", LOG_NAME)
            break
            
        # 3. Check if window logic allows upgrade (e.g. max level)
        if window.has_method("can_upgrade"):
            if not window.can_upgrade():
                # ModLoaderLog.debug("Loop break: can_upgrade() returned false", LOG_NAME)
                break
                
        # 4. Deduct and Upgrade
        # NOTE: logic in window_miner.gd's _on_upgrade_button_pressed deducted money BEFORE calling upgrade().
        # window.upgrade() usually just increments level and plays animation.
        # So we MUST deduct money here.
        Globals.currencies["money"] -= current_cost
        
        # Call upgrade with or without argument depending on signature
        # window_network.gd has upgrade(levels: int), window_miner.gd has upgrade()
        # Strategy: Check if it's a known class type or just check specific method signature?
        # GDScript objects have `get_method_list()`.
        var methods = window.get_method_list()
        var upgrade_method = null
        for m in methods:
            if m.name == "upgrade":
                upgrade_method = m
                break
        
        if upgrade_method:
            var args = upgrade_method.args.size()
            # method info: {name:..., args:[...], ...}
            if args > 0:
                window.upgrade(1)
            else:
                window.upgrade()
        else:
            # Fallback (shouldn't happen due to check above)
            window.upgrade()
            
        total_extra += 1
        
    if total_extra > 0:
        ModLoaderLog.info("Modifier upgrade: Performed " + str(total_extra) + " extra upgrades.", LOG_NAME)
        pass
    else:
        # ModLoaderLog.debug("Modifier upgrade: No extra upgrades performed.", LOG_NAME)
        pass
