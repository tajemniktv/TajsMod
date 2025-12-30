---
title: Upload Labs - Suggestions
description: Suggestions for Upload Labs modding.
---

## 🔴 Major Pain Points

### 1. Expose Window/Node Metadata in Data.windows

**Problem**: To build the wire-drop node picker, we had to load and instantiate every window scene to discover what connectors it has.

**Current workaround**: Load scene → instantiate → scan for ResourceContainers → get connector info → free instance

**Suggestion**: Pre-compute metadata in `Data.windows`:

```gdscript
Data.windows["compiler"] = {
    "scene": "window_compiler",
    "category": "processing",
    "inputs": [{"shape": "square", "color": "lime", "resource": "code"}],
    "outputs": [{"shape": "circle", "color": "orange", "resource": "file"}],
    "max_count": -1,  # -1 = unlimited
}
```

---

### 2. Add Connection Lifecycle Signals

**Problem**: Had to infer when wire was dropped on empty canvas from `Signals.connection_droppped` and check if connection was actually made.

**Suggestion**: Add explicit signals:

```gdscript
signal connection_drag_started(origin_id: String, connection_type: int)
signal connection_cancelled(origin_id: String, connection_type: int, position: Vector2)  # Wire dropped on empty canvas
signal connection_preview(origin_id: String, target_id: String)  # Hovering over valid target
```

---

### 3. Expose ResourceContainer Connector Type

**Problem**: Had to search for child nodes named "InputConnector"/"OutputConnector" to determine if a pin is input or output.

**Suggestion**: Add direct properties to `ResourceContainer`:

```gdscript
@export var connector_type: int  # Utils.connections_types.INPUT or OUTPUT or BOTH
func is_input() -> bool
func is_output() -> bool
func has_connection() -> bool
```

---

### 4. Window Spawn Helper API

**Problem**: Spawning windows requires: load scene → instantiate → set position → emit signal → await initialization → check validity.

**Suggestion**: Add utility function:

```gdscript
# In Utils or Globals
static func spawn_window(window_id: String, position: Vector2, auto_connect_to: String = "") -> WindowContainer

# Usage
var new_node = Utils.spawn_window("compiler", drop_position)
```

---

## 🟡 Would Significantly Help

### 5. Desktop Selection API

**Problem**: Accessed internals like `Globals.desktop.selected` directly, had to call internal methods.

**Suggestion**: Clean public API on Desktop:

```gdscript
func select_all() -> void
func select_by_category(category: String) -> void
func clear_selection() -> void
func get_selection() -> Array[WindowContainer]
func center_view_on_selection() -> void
func delete_selection() -> void
```

---

### 6. Camera/Viewport Access

**Problem**: Screenshot feature needed to access and manipulate camera for proper rendering.

**Suggestion**: Expose camera controls:

```gdscript
Globals.desktop.get_camera() -> Camera2D
Globals.desktop.get_viewport_rect() -> Rect2
Globals.desktop.capture_viewport(quality: int = 1) -> Image
```

---

### 7. Settings Change Signal

**Problem**: Had to create custom callback chains for settings like opacity, glow.

**Suggestion**: Centralized settings event:

```gdscript
signal setting_changed(key: String, old_value: Variant, new_value: Variant)
```

---

### 8. Node Count/Limit API

**Problem**: Had to dig into `Globals.max_window_count` and `Utils.MAX_WINDOW` to understand limits.

**Suggestion**: Clean API:

```gdscript
func get_node_count() -> int
func get_node_limit() -> int
func set_node_limit(limit: int) -> void
func can_add_node(window_id: String = "") -> bool
```

---

## 🟢 Nice to Have

### 9. Window Container Lifecycle Signals

```gdscript
signal initialized()     # After fully ready with ResourceContainers registered
signal closing()         # Already exists ✓
signal selected()
signal deselected()
signal moved(old_pos: Vector2, new_pos: Vector2)
```

---

### 10. Modding Hook Points

Add virtual methods for modding extension points:

```gdscript
func _mod_pre_delete_window(window: WindowContainer) -> bool  # Return false to cancel
func _mod_post_create_connection(output_id: String, input_id: String)
func _mod_pre_save() -> Dictionary  # Return extra data to save
func _mod_post_load(data: Dictionary)
```

---

### 11. UI Layer Access

**Problem**: Had to navigate scene tree to find HUD → Overlay for placing mod UI.

**Suggestion**: Named access:

```gdscript
Globals.get_ui_layer() -> CanvasLayer  # For overlays like command palette
Globals.get_hud() -> Control  # For HUD buttons
```

---

### 12. Resource/Currency API

**Problem**: Currency modification required understanding internal mechanics.

**Suggestion**:

```gdscript
func get_currency(type: String) -> float  # "money", "research", "token"
func add_currency(type: String, amount: float)
func set_currency(type: String, amount: float)
```

---

## 🐛 Minor Issues

### 13. Typo Fix

`Signals.connection_droppped` has triple 'p' - consider fixing for consistency.

---

## Summary Table

| Suggestion            | Effort | Impact | Feature Affected                |
| --------------------- | ------ | ------ | ------------------------------- |
| Window metadata       | Medium | High   | Wire-drop menu, Command palette |
| Connection signals    | Low    | High   | Wire-drop menu                  |
| Connector type expose | Low    | High   | Wire-drop menu                  |
| Spawn helper          | Medium | High   | Wire-drop menu                  |
| Selection API         | Low    | Medium | Command palette                 |
| Camera access         | Low    | Medium | Screenshot                      |
| Settings signal       | Low    | Medium | All settings                    |
| Node count API        | Low    | Medium | Node limit feature              |
| Lifecycle signals     | Low    | Low    | General modding                 |
| Hook points           | Medium | Medium | General modding                 |
| UI layer access       | Low    | Low    | Settings UI, Palette            |
| Currency API          | Low    | Low    | Cheats tab                      |

---

The main challenge is that many internals aren't designed for external access, requiring mods to reach into private state.
