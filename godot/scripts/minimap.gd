extends Control
class_name UTownMinimap
## North-up campus reference map. OSM geometry and contour lines are overlays, not surveyed navigation data.

@onready var world: UTownWorld = get_parent().get_parent().get_node("World")
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")

const MAP_SIZE: float = 250.0
const EDGE_PADDING: float = 18.0
const OSM_DATA_PATH: String = "res://data/osm_utown_snapshot.json"
const TERRAIN_DATA_PATH: String = "res://data/terrain_contours.json"

var map_center_world: Vector2 = Vector2.ZERO
var map_scale: float = 0.25
var osm_features: Array = []
var osm_boundary: Array = []
var terrain_contours: Array = []
var show_osm_reference: bool = true
var show_osm_paths: bool = false
var show_terrain_contours: bool = true

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _load_reference_data()
    _rebuild_map_transform()

func _process(_delta: float) -> void:
    queue_redraw()

func _load_reference_data() -> void:
    if FileAccess.file_exists(OSM_DATA_PATH):
        var osm_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(OSM_DATA_PATH))
        if typeof(osm_value) == TYPE_DICTIONARY:
            var osm_document: Dictionary = osm_value
            osm_features = osm_document.get("features", [])
            var boundary: Dictionary = osm_document.get("campus_boundary", {})
            osm_boundary = boundary.get("coordinates", [])
        else:
            push_warning("OSM reference snapshot is invalid; estimated proxy map remains available.")
    if FileAccess.file_exists(TERRAIN_DATA_PATH):
        var terrain_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(TERRAIN_DATA_PATH))
        if typeof(terrain_value) == TYPE_DICTIONARY:
            var terrain_document: Dictionary = terrain_value
            terrain_contours = terrain_document.get("contours", [])
        else:
            push_warning("Terrain contour reference is invalid; contour overlay remains disabled.")

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

func _append_lonlat_extent(points: Array[Vector2], coordinates: Array) -> void:
    for pair in coordinates:
        if pair is Array and pair.size() >= 2:
            var point: Vector3 = world.lonlat_to_world(float(pair[0]), float(pair[1]))
            points.append(Vector2(point.x, point.z))

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
        _append_lonlat_extent(points, way.get("lonlat", []))

    _append_lonlat_extent(points, osm_boundary)
    for feature in osm_features:
        _append_lonlat_extent(points, feature.get("coordinates", []))
    for contour in terrain_contours:
        for path in contour.get("paths", []):
            _append_lonlat_extent(points, path)

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

func _map_lonlat_points(coordinates: Array) -> PackedVector2Array:
    var result: PackedVector2Array = PackedVector2Array()
    for pair in coordinates:
        if pair is Array and pair.size() >= 2:
            var point: Vector3 = world.lonlat_to_world(float(pair[0]), float(pair[1]))
            result.append(world_to_map(point))
    return result

func set_osm_reference_visible(enabled: bool) -> void:
    show_osm_reference = enabled
    queue_redraw()

func set_osm_paths_visible(enabled: bool) -> void:
    show_osm_paths = enabled
    queue_redraw()

func set_terrain_contours_visible(enabled: bool) -> void:
    show_terrain_contours = enabled
    queue_redraw()

func _draw_osm_reference() -> void:
    if not show_osm_reference:
        return
    var boundary_line: PackedVector2Array = _map_lonlat_points(osm_boundary)
    if boundary_line.size() >= 2:
        if boundary_line[0].distance_to(boundary_line[boundary_line.size() - 1]) > 0.1:
            boundary_line.append(boundary_line[0])
        draw_polyline(boundary_line, Color(0.49, 0.75, 0.78, 0.65), 0.8, true)

    for feature in osm_features:
        var feature_type: String = str(feature.get("feature_type", ""))
        var coordinates: Array = feature.get("coordinates", [])
        var points: PackedVector2Array = _map_lonlat_points(coordinates)
        if points.size() < 2:
            continue

        if feature_type == "building" or feature_type == "roof":
            var landmark_id: String = str(feature.get("landmark_id", ""))
            var outline: Color = Color.html("#ffd28a") if landmark_id == "ERC" or landmark_id == "SRC" else Color.html("#65c3d4")
            if points.size() >= 3:
                draw_colored_polygon(points, Color(0.27, 0.69, 0.79, 0.10))
            var closed: PackedVector2Array = PackedVector2Array(points)
            if closed[0].distance_to(closed[closed.size() - 1]) > 0.1:
                closed.append(closed[0])
            draw_polyline(closed, outline, 1.35 if not landmark_id.is_empty() else 0.8, true)
        elif feature_type == "landcover":
            if str(feature.get("geometry_type", "")) == "Polygon" and points.size() >= 3:
                draw_colored_polygon(points, Color(0.36, 0.62, 0.39, 0.12))
                var land_outline: PackedVector2Array = PackedVector2Array(points)
                if land_outline[0].distance_to(land_outline[land_outline.size() - 1]) > 0.1:
                    land_outline.append(land_outline[0])
                draw_polyline(land_outline, Color(0.55, 0.76, 0.54, 0.48), 0.65, true)
        elif feature_type == "path" and show_osm_paths:
            var tags: Dictionary = feature.get("tags", {})
            var highway: String = str(tags.get("highway", ""))
            var path_color: Color = Color.html("#d48eb1") if highway == "steps" else Color.html("#68aebc")
            draw_polyline(points, Color(path_color.r, path_color.g, path_color.b, 0.64), 0.75, true)

func _draw_terrain_contours(font: Font) -> void:
    if not show_terrain_contours:
        return
    for contour in terrain_contours:
        var height_m: int = int(contour.get("height_m", 0))
        var paths: Array = contour.get("paths", [])
        for path_index in range(paths.size()):
            var points: PackedVector2Array = _map_lonlat_points(paths[path_index])
            if points.size() < 2:
                continue
            draw_polyline(points, Color(0.88, 0.78, 0.48, 0.74), 0.9, true)
            if path_index == 0:
                var label_point: Vector2 = points[int(points.size() / 2)]
                draw_string(font, label_point + Vector2(2.0, -2.0), "%d m" % height_m,
                    HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.html("#f3df9b"))

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

    _draw_osm_reference()
    _draw_terrain_contours(font)

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
    draw_string(font, Vector2(8.0, 27.0), "O OSM  P paths  T contours", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.html("#c5d4d1"))
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
    draw_line(Vector2(57.0, MAP_SIZE - 18.0), Vector2(68.0, MAP_SIZE - 18.0), Color.html("#65c3d4"), 1.4)
    draw_string(font, Vector2(72.0, MAP_SIZE - 15.0), "OSM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
    draw_line(Vector2(112.0, MAP_SIZE - 18.0), Vector2(123.0, MAP_SIZE - 18.0), Color.html("#e5bd70"), 2.0)
    draw_string(font, Vector2(127.0, MAP_SIZE - 15.0), "Route", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
    draw_circle(Vector2(174.0, MAP_SIZE - 18.0), 3.0, Color.html("#4da6e6"))
    draw_string(font, Vector2(181.0, MAP_SIZE - 15.0), "You", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
    draw_line(Vector2(209.0, MAP_SIZE - 18.0), Vector2(219.0, MAP_SIZE - 18.0), Color.html("#e0c878"), 1.0)
    draw_string(font, Vector2(223.0, MAP_SIZE - 15.0), "5m", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color.WHITE)
