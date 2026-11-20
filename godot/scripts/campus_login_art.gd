extends Control
class_name NUS3DCampusLoginArt
## Hand-drawn, static, low-overhead 2D canvas: campus, one student, one DDL paper pile.
## Geometry only. No AI texture, imported photo, animation loop, or official branding.

const INK: Color = Color("#30333B")
const SKY: Color = Color("#98C9DE")
const GRASS: Color = Color("#B4D494")
const PAPER: Color = Color("#FFF9ED")
const YELLOW: Color = Color("#F7CA55")
const WINDOW: Color = Color("#B7DAE6")


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)


func _block(rect: Rect2, fill: Color, outline: float = 4.0) -> void:
    draw_rect(rect, fill, true)
    if outline > 0.0:
        draw_rect(rect, INK, false, outline)


func _cloud(origin: Vector2, scale_factor: float) -> void:
    for part in [Vector2(-33, 2), Vector2(0, -10), Vector2(33, 2)]:
        draw_circle(origin + part * scale_factor, 25.0 * scale_factor, PAPER)
    draw_rect(Rect2(origin + Vector2(-42, 0) * scale_factor, Vector2(84, 23) * scale_factor), PAPER)


func _tree(x: float, y: float) -> void:
    _block(Rect2(x - 7, y - 86, 15, 88), Color("#9E7159"), 3)
    for offset in [Vector2(-21, -86), Vector2(16, -104), Vector2(37, -79)]:
        draw_circle(Vector2(x, y) + offset, 36.0, INK)
        draw_circle(Vector2(x, y) + offset, 32.0, GRASS)


func _building(x: float, y: float, width: float, height: float, columns: int) -> void:
    _block(Rect2(x, y, width, height), PAPER)
    var pitch: float = (width - 30.0) / float(columns)
    for col in range(columns):
        for row in range(2):
            _block(
                Rect2(x + 17 + float(col) * pitch, y + 23 + float(row) * 65, pitch - 14, 42),
                WINDOW, 2.5
            )
    _block(Rect2(x - 8, y - 12, width + 16, 12), Color("#DBA27E"))


func _draw() -> void:
    if size.x <= 0 or size.y <= 0:
        return
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 1280.0, size.y / 720.0))
    draw_rect(Rect2(0, 0, 1280, 720), SKY)
    _cloud(Vector2(170, 130), 1.2)
    _cloud(Vector2(490, 85), 0.7)
    _cloud(Vector2(1070, 130), 0.65)

    # Strong silhouettes and a handful of architectural cues; no realistic campus replica.
    _building(48, 295, 292, 235, 4)
    _building(348, 342, 224, 188, 3)
    _building(580, 312, 226, 218, 3)
    draw_rect(Rect2(0, 521, 1280, 199), GRASS)
    draw_colored_polygon(PackedVector2Array([
        Vector2(465, 535), Vector2(705, 535), Vector2(890, 720), Vector2(280, 720)
    ]), Color("#F3D7A7"))
    draw_line(Vector2(0, 521), Vector2(1280, 521), INK, 5.0)
    _tree(44, 535)
    _tree(577, 525)

    # One original cartoon student overwhelmed by a comically large DDL stack.
    # No goose/duck likeness or other franchise assets.
    _block(Rect2(150, 610, 67, 88), Color("#54769A"))  # backpack
    _block(Rect2(195, 612, 92, 85), Color("#F4A95D"))
    _block(Rect2(204, 688, 24, 29), INK, 0.0)
    _block(Rect2(255, 688, 24, 29), INK, 0.0)
    draw_circle(Vector2(239, 574), 59, INK)
    draw_circle(Vector2(239, 574), 55, PAPER)
    draw_colored_polygon(PackedVector2Array([
        Vector2(187, 547), Vector2(191, 522), Vector2(213, 516),
        Vector2(229, 521), Vector2(248, 508), Vector2(283, 531),
        Vector2(290, 544)
    ]), INK)
    draw_circle(Vector2(217, 574), 5.0, INK)
    draw_circle(Vector2(256, 574), 5.0, INK)
    draw_line(Vector2(226, 604), Vector2(252, 607), INK, 4.0)

    # A compact stack of examination pages, not a busy collection of props.
    for index in range(4):
        var page: Rect2 = Rect2(204 + index * 3, 448 + index * 16, 103, 47)
        _block(page, PAPER, 3)
        draw_line(page.position + Vector2(14, 15),
            page.position + Vector2(83, 15), INK, 2.0)
    draw_line(Vector2(280, 636), Vector2(335, 610), INK, 10.0)
    _block(Rect2(333, 582, 40, 48), Color("#F7CA55"), 3)
    draw_line(Vector2(336, 585), Vector2(371, 585), INK, 4.0)

    # Simple badge ties the comedy to coursework/deadline stress.
    _block(Rect2(392, 570, 113, 43), YELLOW, 3)
    var f: Font = ThemeDB.fallback_font
    if f != null:
        draw_string(f, Vector2(405, 598), "DDL?!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
