extends Control
## Calm, source-anchored, north-up in-game sketch map.
## All geometry remains approximate: not a navigation product.

@onready var world: UTownWorld = get_parent().get_parent().get_node("World")
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")
@onready var tour: UTownTour = get_parent().get_parent().get_node("Tour")
@onready var challenge: UTownChallenge = get_parent().get_parent().get_node("Challenge")
@onready var campus_life: UTownCampusLife = get_parent().get_parent().get_node("CampusLife")
@onready var coursework: UTownCoursework = get_parent().get_parent().get_node("Coursework")
@onready var ddl_story: UTownDDLStory = get_parent().get_parent().get_node_or_null("DDLStory") as UTownDDLStory
@onready var campus_expansion: NUSKentRidgeWorld = get_parent().get_parent().get_node_or_null("KentRidgeExpansion") as NUSKentRidgeWorld

const MAP_SIZE: float = 222.0
const SCALE: float = 0.54
const FOLLOW_START_METRES: float = 180.0
const MAX_NPC_DOTS: int = 14
const C_BACKGROUND: Color = Color("#152B2C")
const C_PANEL: Color = Color("#1C3838")
const C_GRID: Color = Color("#355453")
const C_GREEN: Color = Color("#567F67")
const C_PALE_GREEN: Color = Color("#84AB80")
const C_PAVEMENT: Color = Color("#DED7C5")
const C_DARK_ROAD: Color = Color("#5F7872")
const C_BUILDING: Color = Color("#B5C4BE")
const C_BUILDING_KEY: Color = Color("#E7DCC4")
const C_TEXT: Color = Color("#EDF3E5")
const C_MUTED: Color = Color("#A2BAB1")
const C_GOLD: Color = Color("#FFCF75")
const C_PLAYER: Color = Color("#72D9DD")

var map_focus: Vector3 = Vector3.ZERO

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    # Smooth follow only outside UTown; avoids the jarring old 180m camera jump.
    # _to_map deliberately remains pure so game code/tests can set map_focus.
    var horizontal: Vector2 = Vector2(player.global_position.x, player.global_position.z)
    var target: Vector3 = Vector3.ZERO
    if not campus_life.interior_active and horizontal.length() >= FOLLOW_START_METRES:
        target = player.global_position
    map_focus = map_focus.lerp(target, clampf(delta * 7.0, 0.0, 1.0))
    if map_focus.distance_to(target) < 0.05:
        map_focus = target
    queue_redraw()

func _to_map(p: Vector3) -> Vector2:
    return Vector2(MAP_SIZE * 0.5 + (p.x - map_focus.x) * SCALE,
        MAP_SIZE * 0.5 + (p.z - map_focus.z) * SCALE)

func _visible(p: Vector2, margin: float = 5.0) -> bool:
    return p.x >= margin and p.y >= 31.0 and p.x <= MAP_SIZE - margin and p.y <= MAP_SIZE - 29.0

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * MAP_SIZE), C_BACKGROUND, true)
    for i in range(1, 7):
        var px: float = float(i) * 32.0
        draw_line(Vector2(px, 29), Vector2(px, 196), Color(C_GRID, 0.22), 1.0)
        draw_line(Vector2(0, px + 12), Vector2(MAP_SIZE, px + 12), Color(C_GRID, 0.22), 1.0)

    if campus_life.interior_active:
        _draw_interior_plan()
    elif not world.layout.is_empty():
        _draw_districts()
        _draw_green_and_footpaths()
        _draw_building_footprints()
        _draw_osm_reference()
        _draw_quiet_markers()
        _draw_player(_to_map(player.global_position))

    # Top/bottom editorial strips act as occlusion masks for crowded map detail.
    draw_rect(Rect2(0, 0, MAP_SIZE, 29), Color("#203B3B"), true)
    draw_line(Vector2(0, 29), Vector2(MAP_SIZE, 29), Color("#66877C"), 1.0)
    var zone: String = "UTOWN"
    if campus_life.interior_active:
        zone = str(campus_life.active_interior).to_upper()
    elif Vector2(player.global_position.x, player.global_position.z).length() >= FOLLOW_START_METRES:
        zone = "KENT RIDGE"
    draw_string(ThemeDB.fallback_font, Vector2(12, 20), "NUS-3D  /  " + zone,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, C_TEXT)
    draw_circle(Vector2(201, 14), 9.0, Color("#345754"), true)
    draw_string(ThemeDB.fallback_font, Vector2(197, 19), "N",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_GOLD)
    draw_rect(Rect2(0, MAP_SIZE - 26, MAP_SIZE, 26), Color("#203B3B"), true)
    draw_line(Vector2(0, MAP_SIZE - 26), Vector2(MAP_SIZE, MAP_SIZE - 26), Color("#66877C"), 1.0)
    draw_circle(Vector2(13, MAP_SIZE - 13), 3.3, C_PLAYER)
    draw_string(ThemeDB.fallback_font, Vector2(23, MAP_SIZE - 9),
        "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, C_TEXT)
    draw_circle(Vector2(77, MAP_SIZE - 13), 3.3, C_GOLD)
    draw_string(ThemeDB.fallback_font, Vector2(87, MAP_SIZE - 9),
        "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, C_TEXT)
    draw_string(ThemeDB.fallback_font, Vector2(148, MAP_SIZE - 9),
        "GAME MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, C_MUTED)
    draw_rect(Rect2(0.5, 0.5, MAP_SIZE - 1.0, MAP_SIZE - 1.0),
        Color("#9CB6A8"), false, 1.0)

func _draw_districts() -> void:
    if campus_expansion == null:
        return
    # Wide translucent districts, rather than saturated, blocky aerial squares.
    for district in campus_expansion.districts:
        var center: Vector2 = _to_map(district["position"])
        if center.x < -120 or center.x > MAP_SIZE + 120 or center.y < -120 or center.y > MAP_SIZE + 120:
            continue
        var dims: Array = district.get("size", [120, 120])
        var extent: Vector2 = Vector2(float(dims[0]), float(dims[1])) * SCALE
        draw_rect(Rect2(center - extent * 0.5, extent), Color("#60836F", 0.38), true)
        draw_rect(Rect2(center - extent * 0.5, extent), Color("#A8C3A0", 0.17), false, 1.0)
        for landmark in district.get("landmarks", []):
            var offset: Array = landmark.get("offset", [0, 0])
            var size_values: Array = landmark.get("size", [30, 25, 14])
            var at: Vector2 = _to_map(district["position"] + Vector3(
                float(offset[0]), 0.0, -float(offset[1])))
            var dims2: Vector2 = Vector2(float(size_values[0]), float(size_values[1])) * SCALE
            draw_rect(Rect2(at - dims2 * 0.5, dims2), Color(C_BUILDING, 0.79), true)
            draw_rect(Rect2(at - dims2 * 0.5, dims2), Color("#466565"), false, 1.0)
    # Paths are visual-only schematic links, not real walking or bus directions.
    for connection in campus_expansion.walk_connections:
        if connection.size() < 2:
            continue
        var start: Dictionary = campus_expansion.stop_record(str(connection[0]))
        var end: Dictionary = campus_expansion.stop_record(str(connection[1]))
        if start.is_empty() or end.is_empty():
            continue
        var a: Vector2 = _to_map(start["position"])
        var b: Vector2 = _to_map(end["position"])
        draw_line(a, b, C_DARK_ROAD, 5.5, true)
        draw_line(a, b, Color("#C1CBB9"), 2.8, true)

func _draw_green_and_footpaths() -> void:
    var polygon: PackedVector2Array = PackedVector2Array()
    for coords in world.layout.get("green", {}).get("polygon_lonlat", []):
        polygon.append(_to_map(world.lonlat_to_world(float(coords[0]), float(coords[1]))))
    if polygon.size() >= 3:
        draw_colored_polygon(polygon, C_GREEN)
        polygon.append(polygon[0])
        draw_polyline(polygon, Color(C_PALE_GREEN, 0.65), 1.25, true)
    for way in world.layout.get("walkways", []):
        var coords: Array = way.get("lonlat", [])
        var width: float = maxf(2.8, float(way.get("width_m", 3.5)) * SCALE)
        for i in range(coords.size() - 1):
            var a: Vector2 = _to_map(world.lonlat_to_world(float(coords[i][0]), float(coords[i][1])))
            var b: Vector2 = _to_map(world.lonlat_to_world(float(coords[i + 1][0]), float(coords[i + 1][1])))
            draw_line(a, b, C_DARK_ROAD, width + 2.8, true)
            draw_line(a, b, C_PAVEMENT, width, true)

func _draw_building_footprints() -> void:
    # Actual schematic massing PARTS and rotation: no more generic 10x10 pins.
    for record in world.layout.get("buildings", []):
        var origin: Vector3 = world.lonlat_to_world(float(record["lon"]), float(record["lat"]))
        var theta: float = deg_to_rad(float(record.get("rotation_deg", 0.0)))
        var co: float = cos(theta)
        var si: float = sin(theta)
        var main: bool = str(record.get("priority", "P1")) == "P0"
        for part in record.get("parts", []):
            var px: float = float(part.get("dx", 0.0))
            var pz: float = -float(part.get("dn", 0.0))
            var hx: float = float(part.get("w", 24.0)) * 0.5
            var hz: float = float(part.get("d", 24.0)) * 0.5
            var outline: PackedVector2Array = PackedVector2Array()
            for local in [Vector2(-hx, -hz), Vector2(hx, -hz),
                    Vector2(hx, hz), Vector2(-hx, hz)]:
                var x: float = px + local.x
                var z: float = pz + local.y
                outline.append(_to_map(origin + Vector3(co * x + si * z,
                    0.0, -si * x + co * z)))
            draw_colored_polygon(outline, C_BUILDING_KEY if main else C_BUILDING)
            outline.append(outline[0])
            draw_polyline(outline, Color("#526D68"), 1.25, true)
        if main:
            var label_at: Vector2 = _to_map(origin)
            if _visible(label_at, 18.0):
                draw_string(ThemeDB.fallback_font, label_at + Vector2(8, -6),
                    str(record.get("id", "")).substr(0, 10), HORIZONTAL_ALIGNMENT_LEFT,
                    68.0, 10, C_TEXT)

func _draw_osm_reference() -> void:
    # Orange/cyan source outlines display only on explicit F6 comparison.
    if not world.osm_reference_visible:
        return
    for source in world.osm_reference_data.get("features", []):
        var coords: Array = source.get("coordinates_lonlat", [])
        var poly: PackedVector2Array = PackedVector2Array()
        for pair in coords:
            poly.append(_to_map(world.lonlat_to_world(float(pair[0]), float(pair[1]))))
        if poly.size() > 1:
            draw_polyline(poly, C_GOLD if str(source.get("id", "")) == "ERC" else C_PLAYER, 1.8, true)

func _draw_quiet_markers() -> void:
    if campus_expansion != null:
        for bus in campus_expansion.bus_states:
            var vehicle: Node3D = bus["node"]
            var loc: Vector2 = _to_map(vehicle.position)
            if _visible(loc):
                draw_rect(Rect2(loc - Vector2(3.5, 2.5), Vector2(7, 5)), C_PLAYER, true)
        var nearest_name: String = ""
        var nearest_pos: Vector2 = Vector2.ZERO
        var smallest: float = 55.0
        for stop in campus_expansion.stops:
            var p: Vector2 = _to_map(stop["position"])
            if not _visible(p):
                continue
            draw_circle(p, 4.1, C_DARK_ROAD)
            draw_circle(p, 2.2, C_GOLD)
            var distance: float = p.distance_to(_to_map(player.global_position))
            if distance < smallest:
                smallest = distance
                nearest_pos = p
                nearest_name = str(stop["id"]).replace("_", " ")
        if not nearest_name.is_empty() and _visible(nearest_pos + Vector2(15, 0)):
            draw_string(ThemeDB.fallback_font, nearest_pos + Vector2(8, -6),
                nearest_name, HORIZONTAL_ALIGNMENT_LEFT, 62, 10, C_TEXT)
    # Quiet collectibles, restrained world pins, obvious task priority.
    for i in range(tour.stops.size()):
        var stop: Dictionary = tour.stops[i]
        var p: Vector2 = _to_map(tour.stop_world_position(i))
        if not _visible(p):
            continue
        if tour.has_discovered(str(stop["id"])):
            draw_circle(p, 3.4, Color("#8ED0A6"))
        elif i == tour.current_index and not tour.completed:
            _target_pin(p, C_GOLD, 7.0)
        else:
            draw_circle(p, 2.0, C_MUTED)
    for i in range(challenge.items.size()):
        var id: String = challenge.item_id(i)
        var point: Vector2 = _to_map(challenge.item_world_position(i))
        if not challenge.is_item_collected(id) and _visible(point):
            draw_circle(point, 2.3, Color("#D3B7F2"))
    if challenge.sprint_active and challenge.sprint_next_index < challenge.sprint_route.size():
        _target_pin(_to_map(challenge.sprint_route[challenge.sprint_next_index]), Color("#EAB4D9"), 8.0)
    if ddl_story != null and ddl_story.enabled and ddl_story.stage_points.size() == 4 and not ddl_story.completed:
        _target_pin(_to_map(ddl_story.stage_points[clampi(ddl_story.stage, 0, 3)]), C_GOLD, 7.0)
    var count: int = 0
    for state in campus_life.pedestrians:
        if count >= MAX_NPC_DOTS:
            break
        var npc: Node3D = state["node"]
        var dot: Vector2 = _to_map(npc.global_position)
        if _visible(dot) and dot.distance_to(_to_map(player.global_position)) <= 39.0:
            draw_circle(dot, 1.8, Color("#D8A895", 0.82))
            count += 1
    if campus_life.shuttle != null:
        var shuttle_pos: Vector2 = _to_map(campus_life.shuttle.global_position)
        if _visible(shuttle_pos):
            draw_rect(Rect2(shuttle_pos - Vector2(3.5, 2.5), Vector2(7, 5)), C_GOLD, true)
    if not coursework.current_quest().is_empty() and coursework.marker_preference:
        _target_pin(_to_map(coursework.objective_position()), C_GOLD, 9.0)

func _target_pin(p: Vector2, tint: Color, radius: float) -> void:
    if not _visible(p):
        return
    draw_circle(p, radius, Color(tint, 0.18))
    draw_arc(p, radius, 0.0, TAU, 28, tint, 1.5, true)
    draw_circle(p, 3.0, tint)

func _draw_player(p: Vector2) -> void:
    if not _visible(p):
        return
    var front: Vector3 = -player.global_transform.basis.z
    var facing: Vector2 = Vector2(front.x, front.z)
    if facing.length_squared() < 0.0001:
        facing = Vector2(0, -1)
    facing = facing.normalized()
    var side: Vector2 = Vector2(-facing.y, facing.x)
    draw_circle(p, 10.5, Color(C_PLAYER, 0.16))
    draw_circle(p, 6.3, Color("#1C4245"))
    draw_colored_polygon(PackedVector2Array([
        p + facing * 9.0, p - facing * 4.2 + side * 4.5,
        p - facing * 4.2 - side * 4.5
    ]), C_PLAYER)
    draw_circle(p, 2.0, C_TEXT)

func _interior_map(p: Vector3) -> Vector2:
    return Vector2(MAP_SIZE * 0.5 + p.x * 8.0, MAP_SIZE * 0.5 + p.z * 8.0)

func _draw_interior_plan() -> void:
    # Fictional classroom pocket; not a measured internal floor.
    var room: Node3D = campus_life.interiors[campus_life.active_interior]
    var level: int = campus_life.interior_floor
    var outline: Rect2 = Rect2(Vector2(15, 42), Vector2(192, 137))
    draw_rect(outline, Color("#294744"), true)
    draw_rect(outline, Color("#8FAEA3"), false, 1.3)
    if level == 1:
        draw_rect(Rect2(17, 44, 188, 39), Color("#66897D"), true)
        draw_line(Vector2(18, 82), Vector2(203, 82), C_PAVEMENT, 1.8)
    else:
        draw_rect(Rect2(102, 44, 18, 133), Color("#557A75"), true)
        for x in [45.0, 74.0, 147.0, 175.0]:
            for y in [95.0, 122.0]:
                draw_rect(Rect2(x - 7.0, y - 4.0, 14, 8), Color("#C7BDA5"), true)
    draw_rect(Rect2(_interior_map(Vector3(9.25, 0, -3.9)), Vector2(12, 48)),
        C_GOLD, false, 1.8)
    for activity in campus_life.activity_spots.get(campus_life.active_interior, []):
        var point: Vector3 = activity["position"]
        if (point.y > 2.0) != (level == 1):
            continue
        var map_at: Vector2 = _interior_map(point)
        var item: String = "%s/%s" % [campus_life.active_interior, str(activity["id"])]
        draw_circle(map_at, 3.6, Color("#8FD4AC") if campus_life.visited_activities.has(item) else C_GOLD)
        if coursework.active_stage == coursework.STAGE_ACTIVITY and not coursework.current_quest().is_empty():
            if str(coursework.current_quest()["activity"]) == item:
                _target_pin(map_at, C_GOLD, 8.0)
    if coursework.active_stage == coursework.STAGE_PARTNER and not coursework.current_quest().is_empty():
        var name: String = str(coursework.current_quest()["partner"])
        var indoor_npcs: UTownIndoorNPCs = get_parent().get_parent().get_node("IndoorNPCs") as UTownIndoorNPCs
        for actor in indoor_npcs.actors:
            if str(actor["id"]) == name:
                var actor_node: Node3D = actor["node"]
                _target_pin(_interior_map(room.to_local(actor_node.global_position)), C_GOLD, 8.0)
                break
    _draw_player(_interior_map(room.to_local(player.global_position)))
    draw_string(ThemeDB.fallback_font, Vector2(12, 190),
        "MEZZANINE" if level == 1 else "GROUND FLOOR",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_MUTED)
