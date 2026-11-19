extends Node
class_name UTownChallenge
## Optional offline challenges layered on the existing schematic UTown paths.
## Pickup positions are derived from walkway segment references, never new campus coordinates.

const ITEMS_PATH: String = "res://data/explorer_items.json"
const DEFAULT_SAVE_PATH: String = "user://nus3d_explorer.cfg"
const COLLECT_RADIUS_M: float = 4.5
const SPRINT_CHECKPOINT_RADIUS_M: float = 12.0
const GOLD_TIME_S: float = 78.0
const SILVER_TIME_S: float = 100.0
const BRONZE_TIME_S: float = 135.0

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"

var save_path: String = DEFAULT_SAVE_PATH
var items: Array[Dictionary] = []
var item_positions: Array[Vector3] = []
var item_markers: Array[Node3D] = []
var collected_ids: PackedStringArray = PackedStringArray()
var markers_visible: bool = true

var sprint_route: Array[Vector3] = []
var sprint_route_ids: PackedStringArray = PackedStringArray(["GREEN", "ERC", "SRC", "PLAZA", "GREEN"])
var sprint_active: bool = false
var sprint_elapsed: float = 0.0
var sprint_next_index: int = 0
var sprint_last_time: float = -1.0
var sprint_best_time: float = -1.0
var sprint_medal: String = ""

var feedback_message: String = ""
var feedback_remaining: float = 0.0

func _ready() -> void:
    _load_items()
    _build_sprint_route()
    _load_progress()

func _load_items() -> void:
    if not FileAccess.file_exists(ITEMS_PATH):
        push_error("Missing UTown Field Notes data")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("UTown Field Notes JSON is invalid")
        return
    var document: Dictionary = parsed
    if document.get("no_official_affiliation", false) != true:
        push_error("Field Notes must be labelled as unofficial")
        return
    if str(document.get("status", "")).is_empty():
        push_error("Field Notes data must declare its provisional status")
        return

    var walkways: Array = world.layout.get("walkways", [])
    for raw_item in document.get("items", []):
        if typeof(raw_item) != TYPE_DICTIONARY:
            continue
        var row: Dictionary = raw_item
        var item_id: String = str(row.get("id", ""))
        var path_index: int = int(row.get("path_index", -1))
        var segment_index: int = int(row.get("segment_index", -1))
        if item_id.is_empty() or path_index < 0 or path_index >= walkways.size():
            push_warning("Skipping invalid Field Note reference: " + item_id)
            continue
        var walkway: Dictionary = walkways[path_index]
        var coordinates: Array = walkway.get("lonlat", [])
        if segment_index < 0 or segment_index >= coordinates.size() - 1:
            push_warning("Skipping out-of-range Field Note segment: " + item_id)
            continue
        var start_coords: Array = coordinates[segment_index]
        var finish_coords: Array = coordinates[segment_index + 1]
        var start: Vector3 = world.lonlat_to_world(float(start_coords[0]), float(start_coords[1]))
        var finish: Vector3 = world.lonlat_to_world(float(finish_coords[0]), float(finish_coords[1]))
        var fraction: float = clampf(float(row.get("t", 0.5)), 0.0, 1.0)
        var position: Vector3 = start.lerp(finish, fraction)

        var item: Dictionary = row.duplicate()
        item["position"] = position
        items.append(item)
        item_positions.append(position)

        var marker: Node3D = _make_item_marker(item_id)
        marker.position = Vector3(position.x, 1.25, position.z)
        marker.set_meta("base_y", 1.25)
        marker.set_meta("phase", float(items.size()) * 0.73)
        add_child(marker)
        item_markers.append(marker)

func _make_item_marker(item_id: String) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "FieldNote_" + item_id

    var orb: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.38
    sphere.height = 0.76
    orb.mesh = sphere
    var orb_material: StandardMaterial3D = StandardMaterial3D.new()
    orb_material.albedo_color = Color.html("#55d6b5")
    orb_material.emission_enabled = true
    orb_material.emission = Color.html("#25b992")
    orb_material.emission_energy_multiplier = 1.5
    orb_material.roughness = 0.28
    orb.material_override = orb_material
    root.add_child(orb)

    var ring: MeshInstance3D = MeshInstance3D.new()
    var ring_mesh: TorusMesh = TorusMesh.new()
    ring_mesh.inner_radius = 0.55
    ring_mesh.outer_radius = 0.65
    ring.mesh = ring_mesh
    var ring_material: StandardMaterial3D = StandardMaterial3D.new()
    ring_material.albedo_color = Color.html("#f0d28a")
    ring_material.emission_enabled = true
    ring_material.emission = Color.html("#a47a36")
    ring_material.emission_energy_multiplier = 0.8
    ring.material_override = ring_material
    root.add_child(ring)

    return root

func _build_sprint_route() -> void:
    var waypoint_positions: Dictionary = {}
    for raw_waypoint in world.layout.get("loop", []):
        if typeof(raw_waypoint) != TYPE_DICTIONARY:
            continue
        var waypoint: Dictionary = raw_waypoint
        var waypoint_id: String = str(waypoint.get("id", ""))
        waypoint_positions[waypoint_id] = world.lonlat_to_world(
            float(waypoint.get("lon", world.origin_lon)),
            float(waypoint.get("lat", world.origin_lat))
        )

    sprint_route.clear()
    for waypoint_id in ["GREEN", "ERC", "SRC", "PLAZA"]:
        if not waypoint_positions.has(waypoint_id):
            push_error("Campus Sprint is missing conceptual waypoint: " + waypoint_id)
            sprint_route.clear()
            return
        sprint_route.append(waypoint_positions[waypoint_id])
    sprint_route.append(sprint_route[0])

func _process(delta: float) -> void:
    feedback_remaining = maxf(0.0, feedback_remaining - delta)
    var clock_seconds: float = float(Time.get_ticks_msec()) / 1000.0
    for i in range(item_markers.size()):
        var marker: Node3D = item_markers[i]
        if marker.visible:
            var phase: float = float(marker.get_meta("phase", 0.0))
            var base_y: float = float(marker.get_meta("base_y", 1.25))
            marker.position.y = base_y + sin(clock_seconds * 1.7 + phase) * 0.14
            marker.rotation.y += delta * 0.85

    if sprint_active:
        sprint_elapsed += delta
        if sprint_next_index >= 0 and sprint_next_index < sprint_route.size():
            var target: Vector3 = sprint_route[sprint_next_index]
            if _horizontal_distance(player.global_position, target) <= SPRINT_CHECKPOINT_RADIUS_M:
                if sprint_next_index == sprint_route.size() - 1:
                    _finish_sprint()
                else:
                    sprint_next_index += 1
                    feedback_message = "Checkpoint reached: %d / 4" % (sprint_next_index - 1)
                    feedback_remaining = 1.5

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func nearest_item_index() -> int:
    var nearest: int = -1
    var nearest_distance: float = COLLECT_RADIUS_M
    for i in range(items.size()):
        if is_item_collected(str(items[i].get("id", ""))):
            continue
        var distance: float = _horizontal_distance(player.global_position, item_positions[i])
        if distance <= nearest_distance:
            nearest = i
            nearest_distance = distance
    return nearest

func can_collect_nearest() -> bool:
    return nearest_item_index() >= 0

func try_collect_nearest() -> bool:
    var index: int = nearest_item_index()
    if index < 0:
        feedback_message = "No Field Note in reach. Look for a glowing marker."
        feedback_remaining = 2.0
        return false
    var item: Dictionary = items[index]
    var item_id: String = str(item.get("id", ""))
    if collected_ids.has(item_id):
        return false
    collected_ids.append(item_id)
    item_markers[index].visible = false
    feedback_message = "FOUND: %s\n%s" % [
        str(item.get("title", "FIELD NOTE")),
        str(item.get("note", "Field Note collected."))
    ]
    feedback_remaining = 6.0
    _save_progress()
    return true

func item_id(index: int) -> String:
    if index < 0 or index >= items.size():
        return ""
    return str(items[index].get("id", ""))

func item_world_position(index: int) -> Vector3:
    if index < 0 or index >= item_positions.size():
        return Vector3.ZERO
    return item_positions[index]

func is_item_collected(item_id_value: String) -> bool:
    return collected_ids.has(item_id_value)

func set_markers_visible(enabled: bool) -> void:
    markers_visible = enabled
    _refresh_item_markers()

func _refresh_item_markers() -> void:
    for i in range(item_markers.size()):
        item_markers[i].visible = markers_visible and not is_item_collected(item_id(i))

func start_sprint() -> bool:
    if sprint_active:
        return false
    if sprint_route.size() != 5:
        feedback_message = "Campus Sprint is unavailable: route data is incomplete."
        feedback_remaining = 4.0
        return false
    if _horizontal_distance(player.global_position, sprint_route[0]) > SPRINT_CHECKPOINT_RADIUS_M:
        feedback_message = "Return to the Town Green start area, then press V."
        feedback_remaining = 3.0
        return false
    sprint_elapsed = 0.0
    sprint_next_index = 1
    sprint_active = true
    sprint_medal = ""
    feedback_message = "Campus Sprint started. Reach ERC first."
    feedback_remaining = 2.5
    return true

func cancel_sprint() -> void:
    if not sprint_active:
        return
    sprint_active = false
    feedback_message = "Campus Sprint cancelled."
    feedback_remaining = 3.0

func _finish_sprint() -> void:
    sprint_active = false
    sprint_last_time = sprint_elapsed
    sprint_medal = _medal_for(sprint_last_time)
    feedback_message = "SPRINT %s  |  %s" % [sprint_medal, _format_time(sprint_last_time)]
    feedback_remaining = 7.0
    if sprint_best_time < 0.0 or sprint_last_time < sprint_best_time:
        sprint_best_time = sprint_last_time
        _save_progress()

func _medal_for(seconds: float) -> String:
    if seconds <= GOLD_TIME_S:
        return "GOLD"
    if seconds <= SILVER_TIME_S:
        return "SILVER"
    if seconds <= BRONZE_TIME_S:
        return "BRONZE"
    return "FINISH"

func _format_time(seconds: float) -> String:
    if seconds < 0.0:
        return "--"
    return "%.1f s" % seconds

func status_text() -> String:
    var lines: PackedStringArray = PackedStringArray()
    lines.append("UTOWN FIELD NOTES  %d / %d" % [collected_ids.size(), items.size()])
    if sprint_active:
        var target_id: String = str(sprint_route_ids[sprint_next_index])
        lines.append("SPRINT  %s  |  NEXT %s  (%d/4)" % [
            _format_time(sprint_elapsed), target_id, sprint_next_index
        ])
        if feedback_remaining > 0.0 and not feedback_message.is_empty():
            lines.append(feedback_message)
        else:
            lines.append("[V] cancel sprint")
    elif feedback_remaining > 0.0 and not feedback_message.is_empty():
        lines.append(feedback_message)
    else:
        var nearby_index: int = nearest_item_index()
        if nearby_index >= 0:
            lines.append("Nearby: %s  |  press C to collect" % str(items[nearby_index].get("title", "FIELD NOTE")))
        else:
            lines.append("Find the glowing Field Notes along the schematic paths.")
    if not sprint_active:
        if sprint_last_time >= 0.0:
            lines.append("LAST %s %s  |  PB %s" % [
                sprint_medal, _format_time(sprint_last_time), _format_time(sprint_best_time)
            ])
        else:
            lines.append("Campus Sprint: [V] start near Town Green  |  PB %s" % _format_time(sprint_best_time))
    return "\n".join(lines)

func _load_progress() -> void:
    collected_ids.clear()
    sprint_best_time = -1.0
    var config: ConfigFile = ConfigFile.new()
    if config.load(save_path) != OK:
        _refresh_item_markers()
        return
    var stored_ids: Variant = config.get_value("progress", "collected_ids", [])
    if typeof(stored_ids) == TYPE_ARRAY or typeof(stored_ids) == TYPE_PACKED_STRING_ARRAY:
        for candidate in stored_ids:
            var candidate_id: String = str(candidate)
            var known_id: bool = false
            for item in items:
                if str(item.get("id", "")) == candidate_id:
                    known_id = true
                    break
            if known_id and not collected_ids.has(candidate_id):
                collected_ids.append(candidate_id)
    sprint_best_time = float(config.get_value("progress", "sprint_best_time", -1.0))
    if sprint_best_time < 0.0:
        sprint_best_time = -1.0
    _refresh_item_markers()

func load_progress() -> void:
    _load_progress()

func _save_progress() -> void:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("progress", "schema_version", 1)
    config.set_value("progress", "collected_ids", collected_ids)
    config.set_value("progress", "sprint_best_time", sprint_best_time)
    var error: Error = config.save(save_path)
    if error != OK:
        push_warning("Could not save local UTown challenge progress: " + str(error))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            try_collect_nearest()
        elif event.keycode == KEY_V:
            if sprint_active:
                cancel_sprint()
            else:
                start_sprint()
