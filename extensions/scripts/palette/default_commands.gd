# ==============================================================================
# Taj's Mod - Upload Labs
# Default Commands - Initial command set for the palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModDefaultCommands
extends RefCounted

const LOG_NAME = "TajsModded:DefaultCommands"


## Register all default commands
static func register_all(registry, refs: Dictionary) -> void:
    var mod_config = refs.get("mod_config")
    var mod_ui = refs.get("mod_ui")
    var mod_main = refs.get("mod_main")
    var context = refs.get("context")
    var palette_config = refs.get("palette_config")
    var controller = refs.get("controller")
    var reg = refs.get("registry")
    
    # ==========================================
    # ROOT CATEGORIES
    # ==========================================
    
    registry.register({
        "id": "cat_nodes",
        "title": "Nodes",
        "category_path": [],
        "keywords": ["nodes", "windows", "network", "connections"],
        "hint": "Node and connection management",
        "icon_path": "res://textures/icons/connections.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    registry.register({
        "id": "cat_tajs_mod",
        "title": "Taj's Mod",
        "category_path": [],
        "keywords": ["mod", "settings", "tajs", "options"],
        "hint": "Mod settings and features",
        "icon_path": "res://textures/icons/puzzle.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    registry.register({
        "id": "cat_tools",
        "title": "Tools (Opt-in)",
        "category_path": [],
        "keywords": ["tools", "cheats", "gameplay", "dev"],
        "hint": "Gameplay-affecting tools and cheats",
        "icon_path": "res://textures/icons/bug.png",
        "is_category": true,
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled()
    })
    
    registry.register({
        "id": "cat_help",
        "title": "Help & Links",
        "category_path": [],
        "keywords": ["help", "links", "about", "info", "support"],
        "hint": "Help and external links",
        "icon_path": "res://textures/icons/question.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    # ==========================================
    # NODES - MAIN COMMANDS
    # ==========================================
    
    # General commands under Nodes root
    registry.register({
        "id": "cmd_select_all_nodes",
        "title": "Select All Nodes",
        "category_path": ["Nodes"],
        "keywords": ["select", "all", "nodes", "everything"],
        "hint": "Select all nodes on the desktop",
        "icon_path": "res://textures/icons/select_all.png",
        "badge": "SAFE",
        "run": func(ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var typed_windows: Array[WindowContainer] = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            typed_windows.append(child)
                    var typed_connectors: Array[Control] = []
                    Globals.set_selection(typed_windows, typed_connectors, 1)
                    Signals.notify.emit("check", "Selected %d nodes" % typed_windows.size())
    })
    
    registry.register({
        "id": "cmd_deselect_all",
        "title": "Deselect All",
        "category_path": ["Nodes"],
        "keywords": ["deselect", "clear", "selection", "none"],
        "hint": "Clear the current selection",
        "badge": "SAFE",
        "run": func(ctx):
            if Globals:
                var empty_windows: Array[WindowContainer] = []
                var empty_connectors: Array[Control] = []
                Globals.set_selection(empty_windows, empty_connectors, 0)
                Signals.notify.emit("check", "Selection cleared")
    })
    
    registry.register({
        "id": "cmd_center_view",
        "title": "Center View on Selection",
        "category_path": ["Nodes"],
        "keywords": ["center", "focus", "zoom", "view", "camera"],
        "hint": "Center the camera on selected nodes",
        "icon_path": "res://textures/icons/crosshair.png",
        "badge": "SAFE",
        "run": func(ctx):
            if Globals and Globals.selections.size() > 0:
                var center = Vector2.ZERO
                for window in Globals.selections:
                    center += window.position + window.size / 2
                center /= Globals.selections.size()
                # Use the signal to actually move the camera
                Signals.center_camera.emit(center)
                Signals.notify.emit("check", "Centered on %d nodes" % Globals.selections.size())
            else:
                Signals.notify.emit("exclamation", "No nodes selected")
    })
    
    # ==========================================
    # NODES - CATEGORY SUBCATEGORIES
    # ==========================================
    
    # Register each category individually to avoid closure capture issues
    _register_node_category(registry, "network", "Network", "connections")
    _register_node_category(registry, "cpu", "CPU", "bits")
    _register_node_category(registry, "gpu", "GPU", "contrast")
    _register_node_category(registry, "research", "Research", "atom")
    _register_node_category(registry, "factory", "Factory", "box")
    _register_node_category(registry, "hacking", "Hacking", "bug")
    _register_node_category(registry, "coding", "Coding", "code")
    _register_node_category(registry, "utility", "Utility", "cog")
    
    # ==========================================
    # NODES > GROUPS
    # ==========================================
    
    registry.register({
        "id": "cat_nodes_groups",
        "title": "Groups",
        "category_path": ["Nodes"],
        "keywords": ["groups", "organize", "color"],
        "hint": "Node group operations",
        "icon_path": "res://textures/icons/nodes.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    # Upgrade Selected command (in root Nodes)
    registry.register({
        "id": "cmd_upgrade_selected",
        "title": "Upgrade Selected",
        "category_path": ["Nodes"],
        "keywords": ["upgrade", "selected", "level", "up"],
        "hint": "Upgrade all selected nodes (if affordable)",
        "icon_path": "res://textures/icons/up_arrow.png",
        "badge": "SAFE",
        "run": func(ctx):
            _upgrade_nodes(Globals.selections if Globals else [])
    })
    
    # Upgrade All command (in root Nodes)
    registry.register({
        "id": "cmd_upgrade_all",
        "title": "Upgrade All",
        "category_path": ["Nodes"],
        "keywords": ["upgrade", "all", "level", "up", "everything"],
        "hint": "Upgrade all nodes on desktop (if affordable)",
        "icon_path": "res://textures/icons/up_arrow.png",
        "badge": "SAFE",
        "run": func(ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var all_windows: Array = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            all_windows.append(child)
                    _upgrade_nodes(all_windows)
    })
    
    # ==========================================
    # TAJ'S MOD - SETTINGS
    # ==========================================
    
    registry.register({
        "id": "cmd_open_settings",
        "title": "Open Settings",
        "category_path": ["Taj's Mod"],
        "keywords": ["settings", "config", "options", "preferences", "menu"],
        "hint": "Open the mod settings panel",
        "icon_path": "res://textures/icons/cog.png",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_ui:
                mod_ui.set_visible(true)
    })
    
    registry.register({
        "id": "cmd_close_settings",
        "title": "Close Settings",
        "category_path": ["Taj's Mod"],
        "keywords": ["close", "hide", "settings"],
        "hint": "Close the mod settings panel",
        "badge": "SAFE",
        "can_run": func(ctx): return mod_ui and mod_ui.is_visible(),
        "run": func(ctx):
            if mod_ui:
                mod_ui.set_visible(false)
    })
    
    # ==========================================
    # TAJ'S MOD - SETTINGS TOGGLES
    # ==========================================
    
    registry.register({
        "id": "cat_tajs_toggles",
        "title": "Feature Toggles",
        "category_path": ["Taj's Mod"],
        "keywords": ["toggles", "features", "enable", "disable", "settings"],
        "hint": "Quick toggle for mod features",
        "icon_path": "res://textures/icons/switch.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    # Wire Drop Node Menu toggle
    registry.register({
        "id": "cmd_toggle_wire_drop",
        "title": "Wire Drop Menu",
        "get_title": func(): return "Wire Drop Menu " + ("[ON]" if mod_config.get_value("wire_drop_menu_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["wire", "drop", "menu", "toggle", "enable", "disable"],
        "hint": "Toggle wire drop node spawning menu",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and controller:
                var current = mod_config.get_value("wire_drop_menu_enabled", true)
                mod_config.set_value("wire_drop_menu_enabled", !current)
                controller.set_wire_drop_enabled(!current)
                if mod_main: mod_main.sync_settings_toggle("wire_drop_menu_enabled")
                Signals.notify.emit("check", "Wire Drop Menu: " + ("ON" if !current else "OFF"))
    })
    
    # Command Palette toggle
    registry.register({
        "id": "cmd_toggle_palette",
        "title": "Command Palette",
        "get_title": func(): return "Command Palette " + ("[ON]" if mod_config.get_value("command_palette_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["palette", "command", "mmb", "toggle"],
        "hint": "Toggle command palette (MMB)",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and controller:
                var current = mod_config.get_value("command_palette_enabled", true)
                mod_config.set_value("command_palette_enabled", !current)
                controller.set_palette_enabled(!current)
                if mod_main: mod_main.sync_settings_toggle("command_palette_enabled")
                Signals.notify.emit("check", "Command Palette: " + ("ON" if !current else "OFF"))
    })
    
    # Right-click Wire Clear toggle
    registry.register({
        "id": "cmd_toggle_wire_clear",
        "title": "Right-click Wire Clear",
        "get_title": func(): return "Right-click Wire Clear " + ("[ON]" if mod_config.get_value("right_click_clear_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["wire", "clear", "right", "click", "toggle"],
        "hint": "Toggle right-click to clear wires",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main and mod_main.wire_clear_handler:
                var current = mod_config.get_value("right_click_clear_enabled", true)
                mod_config.set_value("right_click_clear_enabled", !current)
                mod_main.wire_clear_handler.set_enabled(!current)
                mod_main.sync_settings_toggle("right_click_clear_enabled")
                Signals.notify.emit("check", "Wire Clear: " + ("ON" if !current else "OFF"))
    })
    
    # Ctrl+A Select All toggle
    registry.register({
        "id": "cmd_toggle_select_all",
        "title": "Ctrl+A Select All",
        "get_title": func(): return "Ctrl+A Select All " + ("[ON]" if mod_config.get_value("select_all_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["select", "all", "ctrl", "keyboard", "toggle"],
        "hint": "Toggle Ctrl+A select all nodes",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main:
                var current = mod_config.get_value("select_all_enabled", true)
                mod_config.set_value("select_all_enabled", !current)
                Globals.select_all_enabled = !current
                mod_main.sync_settings_toggle("select_all_enabled")
                Signals.notify.emit("check", "Select All: " + ("ON" if !current else "OFF"))
    })
    
    # Go To Group Button toggle
    registry.register({
        "id": "cmd_toggle_goto_group",
        "title": "Go To Group Button",
        "get_title": func(): return "Go To Group Button " + ("[ON]" if mod_config.get_value("goto_group_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["goto", "group", "button", "panel", "toggle"],
        "hint": "Toggle Go To Group panel button",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main:
                var current = mod_config.get_value("goto_group_enabled", true)
                mod_config.set_value("goto_group_enabled", !current)
                mod_main._set_goto_group_visible(!current)
                mod_main.sync_settings_toggle("goto_group_enabled")
                Signals.notify.emit("check", "Go To Group: " + ("ON" if !current else "OFF"))
    })
    
    # Buy Max Button toggle
    registry.register({
        "id": "cmd_toggle_buy_max",
        "title": "Buy Max Button",
        "get_title": func(): return "Buy Max Button " + ("[ON]" if mod_config.get_value("buy_max_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["buy", "max", "button", "upgrades", "toggle"],
        "hint": "Toggle Buy Max button in upgrades",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main:
                var current = mod_config.get_value("buy_max_enabled", true)
                mod_config.set_value("buy_max_enabled", !current)
                mod_main._set_buy_max_visible(!current)
                mod_main.sync_settings_toggle("buy_max_enabled")
                Signals.notify.emit("check", "Buy Max: " + ("ON" if !current else "OFF"))
    })
    
    # Z-Order Fix toggle
    registry.register({
        "id": "cmd_toggle_z_order",
        "title": "Group Z-Order Fix",
        "get_title": func(): return "Group Z-Order Fix " + ("[ON]" if mod_config.get_value("z_order_fix_enabled", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["z", "order", "group", "layer", "toggle"],
        "hint": "Toggle z-order fix for nested groups",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main and mod_main.node_group_z_fix:
                var current = mod_config.get_value("z_order_fix_enabled", true)
                mod_config.set_value("z_order_fix_enabled", !current)
                mod_main.node_group_z_fix.set_enabled(!current)
                mod_main.sync_settings_toggle("z_order_fix_enabled")
                Signals.notify.emit("check", "Z-Order Fix: " + ("ON" if !current else "OFF"))
    })
    
    # 6-Input Containers toggle (requires restart)
    registry.register({
        "id": "cmd_toggle_six_inputs",
        "title": "6-Input Containers ⟳",
        "get_title": func(): return "6-Input Containers ⟳ " + ("[ON]" if mod_config.get_value("six_input_containers", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["six", "6", "input", "container", "toggle"],
        "hint": "Toggle 6-input containers (requires restart)",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main:
                var current = mod_config.get_value("six_input_containers", true)
                mod_config.set_value("six_input_containers", !current)
                mod_main.sync_settings_toggle("six_input_containers")
                Signals.notify.emit("exclamation", "6-Input: " + ("ON" if !current else "OFF") + " (restart required)")
    })
    
    # Mute on Focus Loss toggle
    registry.register({
        "id": "cmd_toggle_focus_mute",
        "title": "Mute on Focus Loss",
        "get_title": func(): return "Mute on Focus Loss " + ("[ON]" if mod_config.get_value("mute_on_focus_loss", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["mute", "focus", "background", "audio", "toggle"],
        "hint": "Toggle mute when game loses focus",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main and mod_main.focus_handler:
                var current = mod_config.get_value("mute_on_focus_loss", true)
                mod_main.focus_handler.set_enabled(!current)
                mod_main.sync_settings_toggle("mute_on_focus_loss")
                Signals.notify.emit("check", "Focus Mute: " + ("ON" if !current else "OFF"))
    })
    
    # Custom Boot Screen toggle
    registry.register({
        "id": "cmd_toggle_boot_screen",
        "title": "Custom Boot Screen ⟳",
        "get_title": func(): return "Custom Boot Screen ⟳ " + ("[ON]" if mod_config.get_value("custom_boot_screen", true) else "[OFF]"),
        "category_path": ["Taj's Mod", "Feature Toggles"],
        "keywords": ["boot", "screen", "splash", "startup", "toggle"],
        "hint": "Toggle custom boot screen (restart to see)",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main:
                var current = mod_config.get_value("custom_boot_screen", true)
                mod_config.set_value("custom_boot_screen", !current)
                mod_main.sync_settings_toggle("custom_boot_screen")
                Signals.notify.emit("check", "Boot Screen: " + ("ON" if !current else "OFF") + " (restart to see)")
    })
    
    # ==========================================
    # TAJ'S MOD - VISUALS
    # ==========================================
    
    registry.register({
        "id": "cat_tajs_visuals",
        "title": "Visuals",
        "category_path": ["Taj's Mod"],
        "keywords": ["visuals", "glow", "effects", "graphics"],
        "hint": "Visual settings and effects",
        "icon_path": "res://textures/icons/eye_ball.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    registry.register({
        "id": "cmd_toggle_glow",
        "title": "Toggle Extra Glow",
        "category_path": ["Taj's Mod", "Visuals"],
        "keywords": ["glow", "bloom", "effects", "visuals", "toggle"],
        "hint": "Toggle the extra glow effect",
        "icon_path": "res://textures/icons/contrast.png",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_main and mod_main.has_method("set_extra_glow"):
                var current = mod_config.get_value("extra_glow", false) if mod_config else false
                mod_main.set_extra_glow(!current)
                Signals.notify.emit("check", "Glow " + ("enabled" if !current else "disabled"))
    })
    
    registry.register({
        "id": "cmd_cycle_opacity",
        "title": "Cycle UI Opacity",
        "category_path": ["Taj's Mod", "Visuals"],
        "keywords": ["opacity", "transparency", "ui", "fade"],
        "hint": "Cycle through UI opacity levels: 100% → 75% → 50%",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config and mod_main:
                var current = mod_config.get_value("ui_opacity", 100)
                var next = 100.0
                if current >= 100:
                    next = 75.0
                elif current >= 75:
                    next = 50.0
                else:
                    next = 100.0
                mod_config.set_value("ui_opacity", next)
                mod_main._apply_ui_opacity(next)
                Signals.notify.emit("check", "UI Opacity: %d%%" % int(next))
    })
    
    # ==========================================
    # TAJ'S MOD - SCREENSHOTS
    # ==========================================
    
    registry.register({
        "id": "cat_tajs_screenshots",
        "title": "Screenshots",
        "category_path": ["Taj's Mod"],
        "keywords": ["screenshot", "capture", "photo", "image"],
        "hint": "Screenshot options",
        "icon_path": "res://textures/icons/camera.png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    registry.register({
        "id": "cmd_take_screenshot",
        "title": "Take Screenshot",
        "category_path": ["Taj's Mod", "Screenshots"],
        "keywords": ["screenshot", "capture", "photo", "save", "image"],
        "hint": "Capture a full desktop screenshot",
        "icon_path": "res://textures/icons/camera.png",
        "badge": "SAFE",
        "run": func(ctx):
            # This will be overridden by mod_main
            Signals.notify.emit("check", "Taking screenshot...")
    })
    
    registry.register({
        "id": "cmd_open_screenshots_folder",
        "title": "Open Screenshots Folder",
        "category_path": ["Taj's Mod", "Screenshots"],
        "keywords": ["open", "folder", "directory", "browse"],
        "hint": "Open the screenshots folder in file explorer",
        "badge": "SAFE",
        "run": func(ctx):
            var path = OS.get_user_data_dir() + "/screenshots"
            DirAccess.make_dir_recursive_absolute(path)
            OS.shell_open(path)
    })
    
    # ==========================================
    # TAJ'S MOD - DEBUG
    # ==========================================
    
    registry.register({
        "id": "cmd_reset_settings",
        "title": "Reset All Settings",
        "category_path": ["Taj's Mod"],
        "keywords": ["reset", "defaults", "clear", "restore"],
        "hint": "Reset all mod settings to defaults",
        "icon_path": "res://textures/icons/refresh.png",
        "badge": "SAFE",
        "run": func(ctx):
            if mod_config:
                mod_config.reset_to_defaults()
                Signals.notify.emit("check", "Settings reset!")
    })
    
    # ==========================================
    # TOOLS (OPT-IN) - CHEATS
    # ==========================================
    
    registry.register({
        "id": "cmd_money_add",
        "title": "Money +10%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["money", "cash", "add", "cheat", "currency"],
        "hint": "Increase money by 10%",
        "icon_path": "res://textures/icons/money.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("money", 0.1)
    })
    
    registry.register({
        "id": "cmd_money_add_30",
        "title": "Money +30%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["money", "cash", "add", "cheat"],
        "hint": "Increase money by 30%",
        "icon_path": "res://textures/icons/money.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("money", 0.3)
    })
    
    registry.register({
        "id": "cmd_money_add_50",
        "title": "Money +50%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["money", "cash", "add", "cheat"],
        "hint": "Increase money by 50%",
        "icon_path": "res://textures/icons/money.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("money", 0.5)
    })
    
    registry.register({
        "id": "cmd_money_sub",
        "title": "Money -10%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["money", "cash", "remove", "subtract", "cheat"],
        "hint": "Decrease money by 10%",
        "icon_path": "res://textures/icons/money.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("money", -0.1)
    })
    
    registry.register({
        "id": "cmd_money_zero",
        "title": "Money → 0",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["money", "cash", "zero", "reset", "clear", "cheat"],
        "hint": "Set money to 0",
        "icon_path": "res://textures/icons/money.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main.set_currency_to_zero("money")
    })
    
    registry.register({
        "id": "cmd_research_add",
        "title": "Research +10%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["research", "science", "add", "cheat"],
        "hint": "Increase research by 10%",
        "icon_path": "res://textures/icons/research.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("research", 0.1)
    })
    
    registry.register({
        "id": "cmd_research_add_30",
        "title": "Research +30%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["research", "science", "add", "cheat"],
        "hint": "Increase research by 30%",
        "icon_path": "res://textures/icons/research.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("research", 0.3)
    })
    
    registry.register({
        "id": "cmd_research_add_50",
        "title": "Research +50%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["research", "science", "add", "cheat"],
        "hint": "Increase research by 50%",
        "icon_path": "res://textures/icons/research.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("research", 0.5)
    })
    
    registry.register({
        "id": "cmd_research_sub",
        "title": "Research -10%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["research", "science", "remove", "cheat"],
        "hint": "Decrease research by 10%",
        "icon_path": "res://textures/icons/research.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main._modify_currency("research", -0.1)
    })
    
    registry.register({
        "id": "cmd_research_zero",
        "title": "Research → 0",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["research", "science", "zero", "reset", "clear", "cheat"],
        "hint": "Set research to 0",
        "icon_path": "res://textures/icons/research.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main: mod_main.set_currency_to_zero("research")
    })
    
    registry.register({
        "id": "cmd_node_limit_unlimited",
        "title": "Set Unlimited Nodes",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["nodes", "limit", "unlimited", "infinite", "max"],
        "hint": "Remove the node limit (set to ∞)",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main and mod_main.has_method("set_node_limit"):
                mod_main.set_node_limit(-1)
                Signals.notify.emit("check", "Node limit set to ∞")
    })
    
    registry.register({
        "id": "cmd_node_limit_default",
        "title": "Reset Node Limit",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["nodes", "limit", "reset", "default"],
        "hint": "Reset node limit to default (400)",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            if mod_main and mod_main.has_method("set_node_limit"):
                mod_main.set_node_limit(400)
                Signals.notify.emit("check", "Node limit reset to 400")
    })
    
    # ==========================================
    # HELP & LINKS
    # ==========================================
    
    registry.register({
        "id": "cmd_show_about",
        "title": "About Taj's Mod",
        "category_path": ["Help & Links"],
        "keywords": ["about", "version", "info", "author"],
        "hint": "Show mod version and info",
        "icon_path": "res://textures/icons/question.png",
        "badge": "SAFE",
        "run": func(ctx):
            Signals.notify.emit("check", "Taj's Mod - Made with ❤️")
    })
    
    registry.register({
        "id": "cmd_copy_workshop",
        "title": "Copy Workshop Link",
        "category_path": ["Help & Links"],
        "keywords": ["workshop", "steam", "link", "copy", "share"],
        "hint": "Copy Steam Workshop link to clipboard",
        "badge": "SAFE",
        "run": func(ctx):
            DisplayServer.clipboard_set("https://steamcommunity.com/sharedfiles/filedetails/?id=3628222709")
            Signals.notify.emit("check", "Workshop link copied!")
    })
    
    registry.register({
        "id": "cmd_show_all_commands",
        "title": "Show All Commands",
        "category_path": ["Help & Links"],
        "keywords": ["commands", "list", "all", "help", "reference"],
        "hint": "Display a list of all registered commands",
        "icon_path": "res://textures/icons/list.png",
        "badge": "SAFE",
        "keep_open": true,
        "run": func(ctx):
            if reg:
                var commands = reg.get_all_commands()
                var msg = "Registered Commands: %d\n" % commands.size()
                for cmd in commands:
                    if not cmd.get("is_category", false):
                        var path = " > ".join(cmd.get("category_path", []))
                        msg += "\n• %s (%s) - %s" % [cmd.get("title", "?"), path, cmd.get("hint", "")]
                # Show in console/log since there's no popup system
                ModLoaderLog.info(msg, "TajsModded:Commands")
                Signals.notify.emit("check", "Commands logged to console (check F1 console)")
    })
    
    registry.register({
        "id": "cmd_enable_tools",
        "title": "Enable Tools in Palette",
        "category_path": ["Help & Links"],
        "keywords": ["enable", "tools", "cheats", "unlock"],
        "hint": "Enable opt-in tools and gameplay commands",
        "badge": "SAFE",
        "can_run": func(ctx): return not ctx.are_tools_enabled(),
        "run": func(ctx):
            ctx.set_tools_enabled(true)
            if palette_config:
                palette_config.set_tools_enabled(true)
            Signals.notify.emit("check", "Tools enabled in palette")
    })
    
    registry.register({
        "id": "cmd_disable_tools",
        "title": "Disable Tools in Palette",
        "category_path": ["Help & Links"],
        "keywords": ["disable", "tools", "cheats", "hide"],
        "hint": "Disable opt-in tools and gameplay commands",
        "badge": "SAFE",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            ctx.set_tools_enabled(false)
            if palette_config:
                palette_config.set_tools_enabled(false)
            Signals.notify.emit("check", "Tools disabled in palette")
    })
    
    ModLoaderLog.info("Registered %d default commands" % registry.get_count(), LOG_NAME)


## Helper to modify currency
static func _modify_currency(type: String, percent: float) -> void:
    if not Globals.currencies.has(type):
        return
    
    var current = Globals.currencies[type]
    var amount = current * percent
    
    var mins = {"money": 1000.0, "research": 100.0, "token": 10.0}
    var min_amount = mins.get(type, 100.0)
    
    if percent > 0 and abs(amount) < min_amount:
        amount = min_amount
    
    Globals.currencies[type] += amount
    
    if Globals.currencies[type] < 0:
        Globals.currencies[type] = 0
    
    if type == "money":
        Globals.max_money = max(Globals.max_money, Globals.currencies[type])
    elif type == "research":
        Globals.max_research = max(Globals.max_research, Globals.currencies[type])
    
    if Globals.has_method("process"):
        Globals.process(0)
    
    var sign_str = "+" if percent > 0 else ""
    Signals.notify.emit("check", "%s %s%d%%" % [type.capitalize(), sign_str, int(percent * 100)])
    Sound.play("click")


## Helper to register a node category with select and upgrade commands
static func _register_node_category(registry, cat_id: String, cat_title: String, icon: String) -> void:
    # Register category
    registry.register({
        "id": "cat_nodes_" + cat_id,
        "title": cat_title,
        "category_path": ["Nodes"],
        "keywords": [cat_id, cat_title.to_lower()],
        "hint": cat_title + " nodes",
        "icon_path": "res://textures/icons/" + icon + ".png",
        "is_category": true,
        "badge": "SAFE"
    })
    
    # Register select all for this category
    registry.register({
        "id": "cmd_select_" + cat_id,
        "title": "Select All " + cat_title,
        "category_path": ["Nodes", cat_title],
        "keywords": ["select", "all", cat_id, cat_title.to_lower()],
        "hint": "Select all " + cat_title + " nodes",
        "badge": "SAFE",
        "run": func(ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var typed_windows: Array[WindowContainer] = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            var window_key = ""
                            if "window" in child:
                                window_key = child.window
                            if window_key and window_key in Data.windows:
                                if Data.windows[window_key].category == cat_id:
                                    typed_windows.append(child)
                    var typed_connectors: Array[Control] = []
                    Globals.set_selection(typed_windows, typed_connectors, 1)
                    Signals.notify.emit("check", "Selected %d %s nodes" % [typed_windows.size(), cat_title])
    })
    
    # Register upgrade for this category
    registry.register({
        "id": "cmd_upgrade_" + cat_id,
        "title": "Upgrade " + cat_title,
        "category_path": ["Nodes", cat_title],
        "keywords": ["upgrade", cat_id, cat_title.to_lower(), "level", "up"],
        "hint": "Upgrade all " + cat_title + " nodes (if affordable)",
        "icon_path": "res://textures/icons/up_arrow.png",
        "badge": "SAFE",
        "run": func(ctx):
            if Globals and Globals.desktop:
                var windows_container = Globals.desktop.get_node_or_null("Windows")
                if windows_container:
                    var category_windows: Array = []
                    for child in windows_container.get_children():
                        if child is WindowContainer:
                            var window_key = ""
                            if "window" in child:
                                window_key = child.window
                            if window_key and window_key in Data.windows:
                                if Data.windows[window_key].category == cat_id:
                                    category_windows.append(child)
                    _upgrade_nodes(category_windows)
    })


## Helper to upgrade a list of nodes with cost checking
static func _upgrade_nodes(windows: Array) -> void:
    var upgraded_count = 0
    var skipped_count = 0
    
    for window in windows:
        if window == null:
            continue
        
        # Check if window has upgrade capability
        if not window.has_method("upgrade"):
            continue
        
        # Check if can afford the upgrade
        if window.has_method("can_upgrade"):
            if not window.can_upgrade():
                skipped_count += 1
                continue
            # Windows with can_upgrade() usually handle their own cost deduction
            if window.has_method("_on_upgrade_button_pressed"):
                window._on_upgrade_button_pressed()
                upgraded_count += 1
                continue
        
        # For windows without can_upgrade, check cost manually
        var cost = window.get("cost")
        if cost != null and cost > 0:
            if cost > Globals.currencies.get("money", 0):
                skipped_count += 1
                continue
            Globals.currencies["money"] -= cost
        
        # Call upgrade with appropriate arguments
        var arg_count = _get_method_arg_count(window, "upgrade")
        if arg_count == 0:
            window.upgrade()
        else:
            window.upgrade(1)
        upgraded_count += 1
    
    # Provide feedback
    if upgraded_count > 0:
        Sound.play("upgrade")
        var msg = "Upgraded " + str(upgraded_count) + " nodes"
        if skipped_count > 0:
            msg += " (" + str(skipped_count) + " skipped)"
        Signals.notify.emit("check", msg)
    else:
        Sound.play("error")
        if skipped_count > 0:
            Signals.notify.emit("exclamation", "Can't afford any upgrades (" + str(skipped_count) + " nodes)")
        else:
            Signals.notify.emit("exclamation", "No upgradeable nodes")


## Helper to get method argument count
static func _get_method_arg_count(obj: Object, method_name: String) -> int:
    var script = obj.get_script()
    if script:
        for method in script.get_script_method_list():
            if method.name == method_name:
                return method.args.size()
    return 1
