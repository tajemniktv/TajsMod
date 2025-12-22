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
            _modify_currency("money", 0.1)
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
            _modify_currency("money", -0.1)
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
            _modify_currency("research", 0.1)
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
            _modify_currency("research", -0.1)
    })
    
    registry.register({
        "id": "cmd_tokens_add",
        "title": "Tokens +10%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["tokens", "coins", "add", "cheat"],
        "hint": "Increase tokens by 10%",
        "icon_path": "res://textures/icons/token.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            _modify_currency("token", 0.1)
    })
    
    registry.register({
        "id": "cmd_tokens_sub",
        "title": "Tokens -10%",
        "category_path": ["Tools (Opt-in)"],
        "keywords": ["tokens", "coins", "remove", "cheat"],
        "hint": "Decrease tokens by 10%",
        "icon_path": "res://textures/icons/token.png",
        "badge": "OPT-IN",
        "can_run": func(ctx): return ctx.are_tools_enabled(),
        "run": func(ctx):
            _modify_currency("token", -0.1)
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


## Helper to register a node category with select command (avoids closure capture)
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
    
    # Register select all for this category - use window property for type
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
                            # Use the 'window' property which contains the window type key
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
