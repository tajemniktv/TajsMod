---
title: Command Palette Dev Guide
description: Guide for adding new commands to the command palette.
---

# Command Palette Dev Guide

## Adding New Commands

Register commands using the registry's `register()` method:

```gdscript
registry.register({
    "id": "my_unique_id",           # Required: Unique identifier
    "title": "My Command",          # Required: Display name
    "category_path": ["Category"],  # Category tree path (empty for root)
    "keywords": ["key1", "key2"],   # Search keywords
    "hint": "What this does",       # Description shown in tooltip
    "badge": "SAFE",                # "SAFE" | "OPT-IN" | "GAMEPLAY"
    "icon_path": "res://...",       # Optional: Icon texture path
    "is_category": false,           # true = navigable category
    "can_run": func(ctx): return true,  # Visibility condition
    "run": func(ctx): do_something(),   # Action to execute
    "keep_open": false              # Keep palette open after execution
})
```

## Badge Types

- **SAFE**: No gameplay impact, always visible
- **OPT-IN**: Gameplay-affecting, hidden until tools enabled
- **GAMEPLAY**: Strong gameplay impact, require confirmation

## Context Object (`ctx`)

Available in `can_run` and `run` callbacks:

```gdscript
ctx.selected_nodes         # Array of selected nodes
ctx.selected_node_count    # Number of selections
ctx.has_selection()        # Returns true if anything selected
ctx.are_tools_enabled()    # True if opt-in tools are enabled
ctx.is_in_menu             # True if in a game menu
```

## Registering from External Scripts

```gdscript
var registry = palette_controller.get_registry()
registry.register({ ... })
```

## File Structure

```
palette/
├── command_registry.gd   # Command storage
├── context_provider.gd   # Game state context
├── palette_config.gd     # Persistence (favorites, recents)
├── palette_overlay.gd    # UI overlay
├── palette_controller.gd # Input & orchestration
├── fuzzy_search.gd       # Search algorithm
└── default_commands.gd   # Built-in commands
```
