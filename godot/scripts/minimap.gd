extends Control
## North-up diagram. The site geometry is approximate and must not be used for navigation.

@onready var world: UTownWorld = get_parent().get_parent().get_node("World")
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")
@onready var tour: UTownTour = get_parent().get_parent().get_node("Tour")
@onready var challenge: UTownChallenge = get_parent().get_parent().get_node("Challenge")
@onready var campus_life: UTownCampusLife = get_parent().get_parent().get_node("CampusLife")
@onready var ddl_story: UTownDDLStory = get_parent().get_parent().get_node_or_null("DDLStory") as UTownDDLStory

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
    if campus_life.interior_active:
        _draw_interior_plan()
        return
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
    # Public OSM outlines are compare-only, never a traversable street overlay.
    if world.osm_reference_visible:
        for source in world.osm_reference_data.get("features", []):
            var polygon: Array = source.get("coordinates_lonlat", [])
            var outline_color: Color = Color.html("#f5bb44") if str(source["id"]) == "ERC" else Color.html("#49d5de")
            for edge in range(polygon.size() - 1):
                var a: Vector3 = world.lonlat_to_world(float(polygon[edge][0]), float(polygon[edge][1]))
                var b: Vector3 = world.lonlat_to_world(float(polygon[edge + 1][0]), float(polygon[edge + 1][1]))
                draw_line(_to_map(a), _to_map(b), outline_color, 1.7)
    for item in world.layout.get("buildings", []):
        var p: Vector2 = _to_map(world.lonlat_to_world(float(item["lon"]), float(item["lat"])))
        var priority: String = str(item.get("priority", "P1"))
        var color: Color = Color.html("#b4a794") if priority == "P1" else Color.html("#e0e1d9")
        draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), color, true)
        if priority == "P0":
            draw_string(ThemeDB.fallback_font, p + Vector2(7, -3), str(item["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)
    # One source for stops: existing conceptual waypoints, not real directions.
    for i in range(tour.stops.size()):
        var item: Dictionary = tour.stops[i]
        var marker: Vector2 = _to_map(tour.stop_world_position(i))
        if tour.has_discovered(str(item["id"])):
            draw_circle(marker, 4.6, Color.html("#70d4ae"))
        elif i == tour.current_index and not tour.completed:
            draw_circle(marker, 8.1, Color.html("#f1ce6a"), false, 2.0)
            draw_circle(marker, 3.6, Color.html("#f1ce6a"))
        else:
            draw_circle(marker, 3.0, Color.html("#a7b2b0"))
    # Optional collectible markers are derived from existing conceptual walkway segments.
    for item_index in range(challenge.items.size()):
        var item_id_value: String = challenge.item_id(item_index)
        if not challenge.is_item_collected(item_id_value):
            draw_circle(_to_map(challenge.item_world_position(item_index)), 3.2, Color.html("#b99aff"))
    if challenge.sprint_active and challenge.sprint_next_index < challenge.sprint_route.size():
        var sprint_target: Vector2 = _to_map(challenge.sprint_route[challenge.sprint_next_index])
        draw_circle(sprint_target, 8.5, Color.html("#f2a8df"), false, 2.0)
    # The current mission is one unobtrusive map focus, never a 3D sign.
    if ddl_story != null and ddl_story.enabled and ddl_story.stage_points.size() == 4 and not ddl_story.completed:
        var goal: Vector2 = _to_map(ddl_story.stage_points[clampi(ddl_story.stage, 0, 3)])
        draw_circle(goal, 6.1, Color.html("#fff0ba"), false, 1.8)
        draw_circle(goal, 2.0, Color.html("#fff0ba"))
    for state in campus_life.pedestrians:
        var npc: Node3D = state["node"]
        draw_circle(_to_map(npc.global_position), 2.2, Color.html("#e8a17c"))
    if campus_life.shuttle != null:
        draw_rect(Rect2(_to_map(campus_life.shuttle.global_position) - Vector2(4.0, 3.0), Vector2(8.0, 6.0)), Color.html("#f2a85d"), true)
    var pp: Vector2 = _to_map(player.global_position)
    draw_circle(pp, 5.0, Color.html("#52a6e0"))
    draw_circle(pp, 5.0, Color.WHITE, false, 1.1)
    var front: Vector3 = -player.global_transform.basis.z
    var arrow: Vector2 = Vector2(front.x, front.z).normalized()
    draw_line(pp, pp + arrow * 14.0, Color.WHITE, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(106, 19), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(9, MAP_SIZE - 12), "SCHEMATIC", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color.html("#a6b8b9"))

func _interior_map(p: Vector3) -> Vector2:
    return Vector2(MAP_SIZE * 0.5 + p.x * 8.0, MAP_SIZE * 0.5 + p.z * 8.0)

func _draw_interior_plan() -> void:
    # Fictional room pocket navigation only. Not a measured floor plan.
    var room: Node3D = campus_life.interiors[campus_life.active_interior]
    var level: int = campus_life.interior_floor
    var heading: String = "%s  |  %s" % [campus_life.active_interior, "MEZZANINE" if level == 1 else "GROUND"]
    draw_string(ThemeDB.fallback_font, Vector2(12, 20), heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.html("#e5f3ee"))
    var outline := Rect2(Vector2(15, 39), Vector2(192, 144))
    draw_rect(outline, Color.html("#324b54"), true)
    draw_rect(outline, Color.html("#9db8b3"), false, 1.5)
    if level == 1:
        draw_rect(Rect2(Vector2(16, 40), Vector2(190, 40)), Color.html("#819d9c"), true)
        draw_line(Vector2(16, 80), Vector2(206, 80), Color.html("#dfc483"), 2.0)
    else:
        draw_rect(Rect2(Vector2(101, 41), Vector2(20, 140)), Color.html("#607e84"), true)
        for bay_x in [46.0, 75.0, 147.0, 175.0]:
            for bay_y in [89.0, 116.0]:
                draw_rect(Rect2(Vector2(bay_x - 7.0, bay_y - 4.0), Vector2(14, 8)), Color.html("#b9a787"), true)
    var stairs := Rect2(_interior_map(Vector3(9.25, 0, -3.9)), Vector2(14, 57))
    draw_rect(stairs, Color.html("#d7bb79"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(169, 165), "STAIRS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color.html("#e7d59d"))
    for activity in campus_life.activity_spots.get(campus_life.active_interior, []):
        var p3: Vector3 = activity["position"]
        if (p3.y > 2.0) != (level == 1):
            continue
        var marker: Vector2 = _interior_map(p3)
        var item_id: String = "%s/%s" % [campus_life.active_interior, str(activity["id"])]
        draw_circle(marker, 4.3, Color.html("#83d2ac") if campus_life.visited_activities.has(item_id) else Color.html("#e8c27a"))
        draw_circle(marker, 4.3, Color.html("#ecf2e9"), false, 1.0)
    var local_player: Vector3 = room.to_local(player.global_position)
    var pos: Vector2 = _interior_map(local_player)
    draw_circle(pos, 5.0, Color.html("#55b2ef"))
    draw_circle(pos, 5.0, Color.WHITE, false, 1.3)
    var forward: Vector3 = -player.global_transform.basis.z
    var arrow := Vector2(forward.x, forward.z).normalized()
    draw_line(pos, pos + arrow * 12.0, Color.WHITE, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(12, 204), "ILLUSTRATIVE / NOT FLOOR PLAN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color.html("#abc2c5"))
