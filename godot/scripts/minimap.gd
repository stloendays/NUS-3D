extends Control
class_name UTownMinimap
## North-up, full-extent schematic. Geometry is approximate and is not for real navigation.

@onready var world: UTownWorld = get_parent().get_parent().get_node("World")
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")

const MAP_SIZE: float = 222.0
const EDGE_PADDING: float = 18.0

var map_center_world: Vector2 = Vector2.ZERO
var map_scale: float = 0.25

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rebuild_map_transform()

func _process(_delta: float) -> void:
    queue_redraw()

func building_footprint_points(record: Dictionary, part: Dictionary) -> PackedVector2Array:
    var centre: Vector3 = world.lonlat_to_world(float(record.get("lon", world.origin_lon)),
        float(record.get("lat", world.origin_lat)))
    var angle: float = deg_to_rad(float(record.get("rotation_deg", 0.0)))
    var local_centre: Vector2 = Vector2(float(part.get("dx", 0.0)), -float(part.get("dn", 0.0)))
    var half_width: float = float(part.get("w", 24.0)) * 0.5
    var half_depth: float = float(part.get("d", 24.0)) * 0.5
    var corners: Array[Vector2] = [
        Vector2(-half_width, -half_depth),
        Vector2(half_width, -half_depth),
        Vector2(half_width, half_depth),
        Vector2(-half_width, half_depth),
    ]
    var result: PackedVector2Array = PackedVector2Array()
    for corner in corners:
        var offset: Vector2 = (local_centre + corner).rotated(-angle)
        result.append(Vector2(centre.x, centre.z) + offset)
    return result

func plaza_footprint_points(plaza: Dictionary) -> PackedVector2Array:
    var centre: Vector3 = world.lonlat_to_world(float(plaza.get("lon", world.origin_lon)),
        float(plaza.get("lat", world.origin_lat)))
    var half_width: float = float(plaza.get("width_m", 44.0)) * 0.5
    var half_depth: float = float(plaza.get("depth_m", 31.0)) * 0.5
    var angle: float = -deg_to_rad(float(plaza.get("rotation_deg", 0.0)))
    var result: PackedVector2Array = PackedVector2Array()
    for corner in [
        Vector2(-half_width, -half_depth),
        Vector2(half_width, -half_depth),
        Vector2(half_width, half_depth),
        Vector2(-half_width, half_depth),
    ]:
        var offset: Vector2 = corner.rotated(angle)
        result.append(Vector2(centre.x, centre.z) + offset)
    return result

func _rebuild_map_transform() -> void:
    var points: Array[Vector2] = []
    for record in world.layout.get("buildings", []):
        for part in record.get("parts", []):
            for point in building_footprint_points(record, part):
                points.append(point)

    for coords in world.layout.get("green", {}).get("polygon_lonlat", []):
        var green_point: Vector3 = world.lonlat_to_world(float(coords[0]), float(coords[1]))
        points.append(Vector2(green_point.x, green_point.z))

    var plaza: Dictionary = world.layout.get("plaza", {})
    if not plaza.is_empty():
        for point in plaza_footprint_points(plaza):
            points.append(point)

    for way in world.layout.get("walkways", []):
        for coords in way.get("lonlat", []):
            var path_point: Vector3 = world.lonlat_to_world(float(coords[0]), float(coords[1]))
            points.append(Vector2(path_point.x, path_point.z))

    if points.is_empty():
        map_center_world = Vector2.ZERO
        map_scale = 0.25
        return

    var minimum: Vector2 = points[0]
    var maximum: Vector2 = points[0]
    for point in points:
        minimum.x = minf(minimum.x, point.x)
        minimum.y = minf(minimum.y, point.y)
        maximum.x = maxf(maximum.x, point.x)
        maximum.y = maxf(maximum.y, point.y)

    var extent: Vector2 = maximum - minimum
    map_center_world = (minimum + maximum) * 0.5
    var available: float = MAP_SIZE - EDGE_PADDING * 2.0
    map_scale = minf(available / maxf(extent.x, 1.0), available / maxf(extent.y, 1.0))

func world_to_map(point: Vector3) -> Vector2:
    var offset: Vector2 = Vector2(point.x, point.z) - map_center_world
    return Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5) + offset * map_scale

func _map_points(points_world: PackedVector2Array) -> PackedVector2Array:
    var result: PackedVector2Array = PackedVector2Array()
    for point in points_world:
        result.append(Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5) + (point - map_center_world) * map_scale)
    return result

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), Color(0.055, 0.10, 0.12, 0.93), true)
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), Color(0.58, 0.70, 0.68, 0.95), false, 1.2)
    if world.layout.is_empty():
        return

    var font: Font = ThemeDB.fallback_font

    var green_polygon: PackedVector2Array = PackedVector2Array()
    for coords in world.layout.get("green", {}).get("polygon_lonlat", []):
        var point: Vector3 = world.lonlat_to_world(float(coords[0]), float(coords[1]))
        green_polygon.append(world_to_map(point))
    if green_polygon.size() >= 3:
        draw_colored_polygon(green_polygon, Color.html("#739f70"))
        var green_outline: PackedVector2Array = PackedVector2Array(green_polygon)
        green_outline.append(green_polygon[0])
        draw_polyline(green_outline, Color.html("#a9d29a"), 1.1, true)

    var plaza: Dictionary = world.layout.get("plaza", {})
    if not plaza.is_empty():
        var plaza_polygon: PackedVector2Array = _map_points(plaza_footprint_points(plaza))
        draw_colored_polygon(plaza_polygon, Color.html("#b6aa8c"))
        var plaza_outline: PackedVector2Array = PackedVector2Array(plaza_polygon)
        plaza_outline.append(plaza_polygon[0])
        draw_polyline(plaza_outline, Color.html("#e2d4b1"), 1.0, true)

    for record in world.layout.get("buildings", []):
        var is_core: bool = str(record.get("priority", "P1")) == "P0"
        var fill: Color = Color.html("#d9ded8") if is_core else Color.html("#899b9b")
        var outline: Color = Color.html("#f0f1e8") if is_core else Color.html("#aebbb5")
        for part in record.get("parts", []):
            var footprint: PackedVector2Array = _map_points(building_footprint_points(record, part))
            draw_colored_polygon(footprint, fill)
            var closed: PackedVector2Array = PackedVector2Array(footprint)
            closed.append(footprint[0])
            draw_polyline(closed, outline, 1.0, true)
        if is_core:
            var centre: Vector3 = world.lonlat_to_world(float(record.get("lon", world.origin_lon)),
                float(record.get("lat", world.origin_lat)))
            draw_string(font, world_to_map(centre) + Vector2(4.0, -4.0), str(record.get("id", "")),
                HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)

    for way in world.layout.get("walkways", []):
        var coords: Array = way.get("lonlat", [])
        var route_line: PackedVector2Array = PackedVector2Array()
        for coord in coords:
            var route_point: Vector3 = world.lonlat_to_world(float(coord[0]), float(coord[1]))
            route_line.append(world_to_map(route_point))
        if route_line.size() >= 2:
            draw_polyline(route_line, Color.html("#e5bd70"), 1.8, true)
        for detour_index in way.get("schematic_detour_indices", []):
            if int(detour_index) >= 0 and int(detour_index) < route_line.size():
                draw_circle(route_line[int(detour_index)], 2.8, Color.html("#d66d58"))

    for i in range(world.route_points.size()):
        var stop: Vector2 = world_to_map(world.route_points[i])
        draw_circle(stop, 3.1, Color.html("#f2cf72"))
        draw_circle(stop, 3.1, Color.html("#fff3c8"), false, 0.8)
        draw_string(font, stop + Vector2(4.0, -4.0), str(i + 1),
            HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)

    var player_point: Vector2 = world_to_map(player.global_position)
    var front: Vector3 = -player.global_transform.basis.z
    var heading: Vector2 = Vector2(front.x, front.z).normalized()
    draw_circle(player_point, 4.4, Color.html("#4da6e6"))
    draw_circle(player_point, 4.4, Color.WHITE, false, 1.0)
    if heading.length_squared() > 0.5:
        var tip: Vector2 = player_point + heading * 8.0
        var rear: Vector2 = player_point - heading * 4.0
        var side: Vector2 = Vector2(-heading.y, heading.x) * 3.0
        var arrow: PackedVector2Array = PackedVector2Array([tip, rear + side, rear - side])
        draw_colored_polygon(arrow, Color.WHITE)

    draw_string(font, Vector2(8.0, 15.0), "UTOWN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color.WHITE)
    var north_base: Vector2 = Vector2(MAP_SIZE - 18.0, 27.0)
    draw_line(north_base + Vector2(0.0, 7.0), north_base + Vector2(0.0, -7.0), Color.WHITE, 1.4)
    draw_colored_polygon(PackedVector2Array([
        north_base + Vector2(0.0, -11.0),
        north_base + Vector2(-3.5, -4.0),
        north_base + Vector2(3.5, -4.0),
    ]), Color.WHITE)
    draw_string(font, north_base + Vector2(-4.0, -14.0), "N",
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)

    var scale_distance: float = 50.0
    while scale_distance * map_scale > 54.0:
        scale_distance *= 0.5
    while scale_distance * map_scale < 20.0:
        scale_distance *= 2.0
    var scale_length: float = scale_distance * map_scale
    var scale_start: Vector2 = Vector2(10.0, 39.0)
    draw_line(scale_start, scale_start + Vector2(scale_length, 0.0), Color.WHITE, 2.0)
    draw_line(scale_start + Vector2(0.0, -3.0), scale_start + Vector2(0.0, 3.0), Color.WHITE, 1.2)
    draw_line(scale_start + Vector2(scale_length, -3.0), scale_start + Vector2(scale_length, 3.0), Color.WHITE, 1.2)
    draw_string(font, scale_start + Vector2(0.0, 13.0), "%d m" % int(round(scale_distance)),
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)

    var legend_rect: Rect2 = Rect2(7.0, MAP_SIZE - 29.0, MAP_SIZE - 14.0, 22.0)
    draw_rect(legend_rect, Color(0.035, 0.07, 0.08, 0.88), true)
    draw_rect(Rect2(13.0, MAP_SIZE - 22.0, 7.0, 7.0), Color.html("#d9ded8"), true)
    draw_string(font, Vector2(23.0, MAP_SIZE - 15.0), "Core", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
    draw_rect(Rect2(57.0, MAP_SIZE - 22.0, 7.0, 7.0), Color.html("#899b9b"), true)
    draw_string(font, Vector2(67.0, MAP_SIZE - 15.0), "Proxy", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
    draw_line(Vector2(112.0, MAP_SIZE - 18.0), Vector2(123.0, MAP_SIZE - 18.0), Color.html("#e5bd70"), 2.0)
    draw_string(font, Vector2(127.0, MAP_SIZE - 15.0), "Path", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
    draw_circle(Vector2(165.0, MAP_SIZE - 18.0), 3.0, Color.html("#4da6e6"))
    draw_string(font, Vector2(172.0, MAP_SIZE - 15.0), "You", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
