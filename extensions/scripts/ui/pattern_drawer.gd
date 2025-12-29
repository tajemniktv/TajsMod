# ==============================================================================
# Taj's Mod - Upload Labs
# PatternDrawer - Draws patterns on UI panels (supports 11 patterns)
# Extracted from window_group.gd for reuse
# ==============================================================================
extends Control

var pattern_type: int = 0
var color: Color = Color(0, 0, 0, 0.4)
var spacing: float = 20.0
var thickness: float = 4.0

func _ready() -> void:
    resized.connect(queue_redraw)
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    if pattern_type == 0: return
    
    var s = get_size()
    
    match pattern_type:
        1: _draw_horizontal(s)
        2: _draw_vertical(s)
        3: _draw_diagonal_slash(s)
        4: _draw_diagonal_backslash(s)
        5: _draw_grid(s)
        6: _draw_diamond(s)
        7: _draw_dots(s)
        8: _draw_zigzag(s)
        9: _draw_waves(s)
        10: _draw_brick(s)

func _draw_horizontal(s: Vector2):
    var y = spacing / 2.0
    while y < s.y:
        draw_line(Vector2(0, y), Vector2(s.x, y), color, thickness)
        y += spacing

func _draw_vertical(s: Vector2):
    var x = spacing / 2.0
    while x < s.x:
        draw_line(Vector2(x, 0), Vector2(x, s.y), color, thickness)
        x += spacing

func _draw_diagonal_slash(s: Vector2):
    var x = -s.y
    while x < s.x:
        draw_line(Vector2(x, 0), Vector2(x + s.y, s.y), color, thickness)
        x += spacing

func _draw_diagonal_backslash(s: Vector2):
    var x = 0.0
    while x < s.x + s.y:
        draw_line(Vector2(x, 0), Vector2(x - s.y, s.y), color, thickness)
        x += spacing

func _draw_grid(s: Vector2):
    _draw_horizontal(s)
    _draw_vertical(s)

func _draw_diamond(s: Vector2):
    _draw_diagonal_slash(s)
    _draw_diagonal_backslash(s)

func _draw_dots(s: Vector2):
    var radius = max(thickness * 0.8, 2.0)
    var x = spacing / 2.0
    while x < s.x:
        var y = spacing / 2.0
        while y < s.y:
            draw_circle(Vector2(x, y), radius, color)
            y += spacing
        x += spacing

func _draw_zigzag(s: Vector2):
    var y = spacing / 2.0
    while y < s.y:
        var points = PackedVector2Array()
        var x = 0.0
        var up = true
        while x <= s.x:
            var py = y - spacing * 0.25 if up else y + spacing * 0.25
            points.append(Vector2(x, py))
            x += spacing * 0.5
            up = !up
        if points.size() >= 2:
            draw_polyline(points, color, thickness)
        y += spacing

func _draw_waves(s: Vector2):
    var y = spacing / 2.0
    while y < s.y:
        var points = PackedVector2Array()
        var x = 0.0
        while x <= s.x + spacing:
            var wave_y = y + sin(x / spacing * PI) * spacing * 0.25
            points.append(Vector2(x, wave_y))
            x += 3.0
        if points.size() >= 2:
            draw_polyline(points, color, thickness)
        y += spacing

func _draw_brick(s: Vector2):
    var y = 0.0
    var row = 0
    while y < s.y:
        draw_line(Vector2(0, y), Vector2(s.x, y), color, thickness)
        var offset = (spacing * 0.5) if row % 2 == 1 else 0.0
        var x = offset
        while x < s.x:
            var next_y = min(y + spacing, s.y)
            draw_line(Vector2(x, y), Vector2(x, next_y), color, thickness)
            x += spacing
        y += spacing
        row += 1

func set_pattern(p: int):
    pattern_type = p
    queue_redraw()

func set_style(c: Color, a: float, sp: float, th: float):
    color = Color(c.r, c.g, c.b, a)
    spacing = sp
    thickness = th
    queue_redraw()
