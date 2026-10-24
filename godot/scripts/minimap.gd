extends Control
## North-up diagram. The site geometry is approximate and must not be used for navigation.

@onready var world: UTownWorld = get_parent().get_parent().get_node("World")
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")

const MAP_SIZE: float = 222.0
const SCALE: float = 0.54

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
    queue_redraw()

func _to_map(p: Vector3) -> Vector2:
    return Vector2(MAP_SIZE * 0.5 + p.x * SCALE, MAP_SIZE * 0.5 + p.z * SCALE)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), Color(0.07, 0.13, 0.15, 0.89), true)
    draw_rect(Rect2(Vector2(0, 0), Vector2(MAP_SIZE - 1, MAP_SIZE - 1)), Color(0.55, 0.68, 0.66, 0.9), false, 1.2)
    if world.layout.is_empty():
        return
    var green_polygon: PackedVector2Array = PackedVector2Array()
    for coords in world.layout.get("green", {}).get("polygon_lonlat", []):
        green_polygon.append(_to_map(world.lonlat_to_world(float(coords[0]), float(coords[1]))))
    if green_polygon.size() > 2:
        draw_colored_polygon(green_polygon, Color.html("#7cb67b"))
    for way in world.layout.get("walkways", []):
        var coords: Array = way.get("lonlat", [])
        for i in range(coords.size() - 1):
            draw_line(_to_map(world.lonlat_to_world(float(coords[i][0]), float(coords[i][1]))),
                _to_map(world.lonlat_to_world(float(coords[i + 1][0]), float(coords[i + 1][1]))),
                Color.html("#c5c8b9"), 2.1)
    for item in world.layout.get("buildings", []):
        var p: Vector2 = _to_map(world.lonlat_to_world(float(item["lon"]), float(item["lat"])))
        var priority: String = str(item.get("priority", "P1"))
        var color: Color = Color.html("#b4a794") if priority == "P1" else Color.html("#e0e1d9")
        draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), color, true)
        if priority == "P0":
            draw_string(ThemeDB.fallback_font, p + Vector2(7, -3), str(item["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)
    for i in range(world.route_points.size()):
        draw_circle(_to_map(world.route_points[i]), 2.8, Color.html("#f1ce6a"))
    var pp: Vector2 = _to_map(player.global_position)
    draw_circle(pp, 5.0, Color.html("#52a6e0"))
    draw_circle(pp, 5.0, Color.WHITE, false, 1.1)
    var front: Vector3 = -player.global_transform.basis.z
    var arrow: Vector2 = Vector2(front.x, front.z).normalized()
    draw_line(pp, pp + arrow * 14.0, Color.WHITE, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(106, 19), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(9, MAP_SIZE - 12), "SCHEMATIC", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color.html("#a6b8b9"))
