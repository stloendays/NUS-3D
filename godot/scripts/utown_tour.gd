extends Node
class_name UTownTour
## Original four-stop discovery activity using the existing conceptual loop.
## Not a campus navigator: stop positions, ground level and walkways are unverified.

const TOUR_PATH: String = "res://data/discovery_tour.json"
const DISCOVERY_TOAST_SECONDS: float = 8.0

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"

var stops: Array[Dictionary] = []
var discovered_ids: PackedStringArray = PackedStringArray()
var current_index: int = 0
var completed: bool = false
var check_in_radius_m: float = 12.0
var last_discovered_index: int = -1
var toast_remaining: float = 0.0

func _ready() -> void:
    if not FileAccess.file_exists(TOUR_PATH):
        push_error("Missing UTown exploratory tour JSON")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOUR_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("UTown exploratory tour JSON is invalid")
        return
    var document: Dictionary = parsed
    if document.get("no_official_affiliation", false) != true:
        push_error("Exploratory tour must clearly be unofficial")
        return
    check_in_radius_m = float(document.get("check_in_radius_m", 12.0))

    # Resolve each stop against one authoritative waypoint record; do not
    # introduce a competing set of coordinates or mistake them for real paths.
    var waypoints: Dictionary = {}
    for item in world.layout.get("loop", []):
        var waypoint: Dictionary = item
        waypoints[str(waypoint.get("id", ""))] = waypoint
    for row in document.get("stops", []):
        if typeof(row) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = row
        var stop_id: String = str(item.get("id", ""))
        if not waypoints.has(stop_id):
            push_error("Exploration checkpoint missing conceptual loop point: " + stop_id)
            continue
        var origin: Dictionary = waypoints[stop_id]
        var stop: Dictionary = item.duplicate()
        stop["position"] = world.lonlat_to_world(float(origin["lon"]), float(origin["lat"]))
        stops.append(stop)

func _process(delta: float) -> void:
    toast_remaining = maxf(0.0, toast_remaining - delta)

func current_stop() -> Dictionary:
    if completed or current_index >= stops.size():
        return {}
    return stops[current_index]

func stop_world_position(index: int) -> Vector3:
    if index < 0 or index >= stops.size():
        return Vector3.ZERO
    var destination: Vector3 = stops[index]["position"]
    return destination

func current_distance_m() -> float:
    if current_stop().is_empty():
        return -1.0
    var target: Vector3 = stop_world_position(current_index)
    return Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(target.x, target.z))

func can_check_in() -> bool:
    return not completed and not stops.is_empty() and current_distance_m() <= check_in_radius_m

func try_check_in() -> bool:
    if not can_check_in():
        return false
    var stop: Dictionary = stops[current_index]
    discovered_ids.append(str(stop["id"]))
    last_discovered_index = current_index
    current_index += 1
    completed = current_index == stops.size()
    toast_remaining = DISCOVERY_TOAST_SECONDS
    return true

func has_discovered(stop_id: String) -> bool:
    return discovered_ids.has(stop_id)

func restart() -> void:
    discovered_ids.clear()
    current_index = 0
    completed = false
    last_discovered_index = -1
    toast_remaining = 0.0

func card_text() -> String:
    if last_discovered_index >= 0 and toast_remaining > 0.0:
        var unlocked: Dictionary = stops[last_discovered_index]
        var heading: String = "UTOWN EXPLORER COMPLETE" if completed else "DISCOVERED  %d / %d" % [discovered_ids.size(), stops.size()]
        var footer: String = "Press G to explore again." if completed else "Continue to your next checkpoint."
        return "%s  —  %s\n%s\n%s" % [heading, str(unlocked["title"]), str(unlocked["discovery"]), footer]
    if completed:
        return "UTOWN EXPLORER  |  ALL %d STOPS FOUND\nOriginal unofficial exploration complete. Press G to replay." % stops.size()
    if can_check_in():
        var target: Dictionary = current_stop()
        return "DISCOVERY STOP  —  %s\n%s\nPress E to check in. Schematic route; not real directions." % [str(target["title"]), str(target["observation"])]
    return ""

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_E:
            try_check_in()
        elif event.keycode == KEY_G and completed:
            restart()
