extends Node
class_name NUS3DCampusAmbientActivities
## Lightweight autonomous campus routines for ambient pedestrians only.
## Story-character affinity, player inventory, quests, currency and multiplayer are untouched.

const ARRIVAL_RADIUS: float = 1.05
const WALK_SPEED: float = 1.05
const MAX_ACTIVE_NPCS: int = 6
const MAX_LUNCH_ACTIVE_NPCS: int = 10
const ACTIVITY_DURATION := {
    "sit": 16.0,
    "drink": 8.0,
    "buy": 10.0,
    "eat": 24.0,
    "queue": 6.0,
    "shelter": 28.0,
    "chat": 18.0
}
const PROFILE_ORDER: Array[String] = ["social", "studious", "foodie", "active", "quiet", "commuter"]
const OCCUPANCY_FREE: Color = Color(0.36, 0.68, 0.52, 0.18)
const OCCUPANCY_BUSY: Color = Color(0.94, 0.61, 0.30, 0.92)

@onready var life: UTownCampusLife = $"../CampusLife"
@onready var navigation: NUS3DNPCNavigation = $"../NPCNavigation"
@onready var green_dining: UTownGreenDining = $"../GreenDining"

var spots: Array[Dictionary] = []
var spot_by_id: Dictionary = {}
var picnic_groups: Array[Dictionary] = []
var reserved_spots: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var next_chat_at: float = 0.0
var completed_activities: Dictionary = {}
var cancelled_activities: int = 0
var game_minutes: float = 675.0
var weather_mode: int = 0
var lunch_peak: bool = false
var occupancy_visual: MultiMeshInstance3D
var occupancy_multimesh: MultiMesh
var occupancy_refresh: float = 0.0

func _ready() -> void:
    rng.seed = 2026112206
    _build_facility_spots()
    _build_occupancy_markers()
    var now: float = Time.get_ticks_msec() / 1000.0
    next_chat_at = now + 14.0
    for index in range(life.pedestrians.size()):
        var state: Dictionary = life.pedestrians[index]
        if not bool(state.get("ambient", false)):
            continue
        state["activity_mode"] = "walk"
        state["activity_kind"] = ""
        state["activity_target"] = Vector3.ZERO
        state["activity_facing"] = Vector3.ZERO
        state["activity_spot_id"] = ""
        state["activity_group_id"] = ""
        state["activity_timer"] = 0.0
        state["activity_started_at"] = 0.0
        state["activity_base_y"] = (state["node"] as Node3D).global_position.y
        state["activity_phase"] = rng.randf_range(0.0, TAU)
        state["activity_partner"] = null
        state["activity_prop"] = null
        state["activity_attempts"] = 0
        state["routine_profile"] = PROFILE_ORDER[(index - 6) % PROFILE_ORDER.size()]
        state["activity_area"] = ""
        state["activity_next_at"] = now + 7.0 + float(index % 6) * 3.5

func _build_facility_spots() -> void:
    # Existing UTown furniture anchors: benches, refill stations and vending machines.
    for anchor_id in ["GREEN", "ERC", "SRC", "PLAZA"]:
        if not life.entry_positions.has(anchor_id):
            continue
        var anchor: Vector3 = life.entry_positions[anchor_id]
        for seat_index in range(2):
            var seat_x: float = 6.0 + float(seat_index) * 2.4
            _add_spot({
                "id": "bench_%s_%d" % [anchor_id, seat_index],
                "kind": "sit",
                "position": anchor + Vector3(seat_x, 0.0, 5.0),
                "facing": Vector3(0.0, 0.0, -1.0)
            })
        if anchor_id in ["SRC", "PLAZA"]:
            _add_spot({
                "id": "vending_%s" % anchor_id,
                "kind": "buy",
                "position": anchor + Vector3(10.0, 0.0, 6.6),
                "facing": Vector3(0.0, 0.0, 1.0)
            })

    # Discover the actual map-dressing refill stations; stand in front of each dispenser.
    var map_dressing: Node3D = get_parent().get_node_or_null("MapDressing") as Node3D
    var refill_root: Node3D = map_dressing.get_node_or_null("CampusRefillStations_NoCollision") as Node3D if map_dressing != null else null
    if refill_root != null:
        for station in refill_root.get_children():
            if not station is Node3D:
                continue
            var station_node: Node3D = station as Node3D
            var front: Vector3 = station_node.global_transform.basis * Vector3(0.0, 0.0, -1.0)
            front.y = 0.0
            if front.length_squared() < 0.0001:
                continue
            front = front.normalized()
            var target: Vector3 = station_node.global_position + front * 1.55
            _add_spot({
                "id": "refill_%s" % station_node.name,
                "kind": "drink",
                "position": Vector3(target.x, 0.0, target.z),
                "facing": -front
            })

    # Dining positions are derived from the actual low-poly tables/stools already built
    # by UTownGreenDining. No extra food-court geometry or guessed campus coordinates.
    var fine_food: Dictionary = green_dining.dining_areas.get("fine_food", {})
    var food_root: Node3D = fine_food.get("root") as Node3D
    if food_root != null:
        var table_xs: Array[float] = [-14.0, -7.0, 9.0, 16.0]
        var table_zs: Array[float] = [-1.8, 5.1]
        var seat_index: int = 0
        for table_x in table_xs:
            for table_z in table_zs:
                var table_centre := Vector3(table_x, 0.0, table_z)
                var table_world: Vector3 = food_root.to_global(table_centre)
                for side in [-1.0, 1.0]:
                    var seat_local := table_centre + Vector3(float(side) * 1.08, 0.0, 0.0)
                    var seat_world: Vector3 = food_root.to_global(seat_local)
                    var facing: Vector3 = table_world - seat_world
                    facing.y = 0.0
                    _add_spot({
                        "id": "food_seat_%02d" % seat_index,
                        "kind": "eat",
                        "area": "fine_food",
                        "position": seat_world,
                        "facing": facing.normalized()
                    })
                    seat_index += 1

        var stall_xs: Array[float] = [-11.0, -1.0, 9.0]
        var queue_index: int = 0
        for stall_x in stall_xs:
            for queue_depth in range(3):
                var queue_local := Vector3(stall_x, 0.0, -6.7 - float(queue_depth) * 1.25)
                var queue_world: Vector3 = food_root.to_global(queue_local)
                var queue_front: Vector3 = food_root.to_global(queue_local + Vector3(0.0, 0.0, -1.0)) - queue_world
                queue_front.y = 0.0
                _add_spot({
                    "id": "food_queue_%02d" % queue_index,
                    "kind": "queue",
                    "area": "fine_food",
                    "position": queue_world,
                    "facing": queue_front.normalized()
                })
                queue_index += 1

        for shelter_index in range(2):
            var shelter_local := Vector3(-18.0 if shelter_index == 0 else 18.0, 0.0, -9.0)
            var shelter_world: Vector3 = food_root.to_global(shelter_local)
            var shelter_facing: Vector3 = food_root.to_global(shelter_local + Vector3(0.0, 0.0, 1.0)) - shelter_world
            shelter_facing.y = 0.0
            _add_spot({
                "id": "food_shelter_%02d" % shelter_index,
                "kind": "shelter",
                "area": "fine_food",
                "position": shelter_world,
                "facing": shelter_facing.normalized()
            })

    # The SRC awning already exists in the M3.7 facade dressing; use its footprint
    # as a second covered waiting area during rain.
    var flavours: Dictionary = green_dining.dining_areas.get("flavours", {})
    var flavours_root: Node3D = flavours.get("root") as Node3D
    if flavours_root != null:
        var src_record: Dictionary = {}
        for record in life.world.layout.get("buildings", []):
            if str(record.get("id", "")) == "SRC":
                src_record = record
                break
        var parts: Array = src_record.get("parts", [])
        if parts.size() >= 3:
            var facade_x: float = float(parts[2].get("dx", 0.0)) + float(parts[2].get("w", 0.0)) * 0.5
            var middle_z: float = -float(parts[2].get("dn", 0.0))
            for shelter_index in range(3):
                var local_shelter := Vector3(facade_x + 1.5, 0.0, middle_z - 3.2 + float(shelter_index) * 3.2)
                var shelter_world: Vector3 = flavours_root.to_global(local_shelter)
                var shelter_facing: Vector3 = flavours_root.to_global(local_shelter + Vector3(1.0, 0.0, 0.0)) - shelter_world
                shelter_facing.y = 0.0
                _add_spot({
                    "id": "src_shelter_%02d" % shelter_index,
                    "kind": "shelter",
                    "area": "flavours",
                    "position": shelter_world,
                    "facing": shelter_facing.normalized()
                })

    # Use the real generated Town Green picnic patches for paired conversations.
    var patch_root: Node3D = green_dining.get_node_or_null("TownGreenPicnicPatches_NoCollisions") as Node3D
    if patch_root == null:
        return
    for patch in patch_root.get_children():
        if not patch is Node3D:
            continue
        var patch_node: Node3D = patch as Node3D
        var left_position: Vector3 = patch_node.to_global(Vector3(-0.82, 0.0, 0.52))
        var right_position: Vector3 = patch_node.to_global(Vector3(0.82, 0.0, 0.52))
        var group_id: String = str(patch_node.name)
        picnic_groups.append({
            "id": group_id,
            "reservation": "picnic:" + group_id,
            "positions": [left_position, right_position]
        })

func _add_spot(spot: Dictionary) -> void:
    spot["area"] = str(spot.get("area", ""))
    spots.append(spot)
    spot_by_id[str(spot["id"])] = spot

func _build_occupancy_markers() -> void:
    if spots.is_empty():
        return
    var scene_root: Node3D = get_parent() as Node3D
    if scene_root == null:
        return
    var disc := CylinderMesh.new()
    disc.top_radius = 0.16
    disc.bottom_radius = 0.16
    disc.height = 0.018
    disc.radial_segments = 12
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = disc
    multi.instance_count = spots.size()
    occupancy_visual = MultiMeshInstance3D.new()
    occupancy_visual.name = "CampusFacilityOccupancy_MultiMesh"
    occupancy_visual.multimesh = multi
    occupancy_visual.material_override = material
    occupancy_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene_root.call_deferred("add_child", occupancy_visual)
    occupancy_multimesh = multi
    for index in range(spots.size()):
        var spot: Dictionary = spots[index]
        var spot_position: Vector3 = spot["position"]
        var marker_position: Vector3 = scene_root.to_local(spot_position) + Vector3(0.0, 0.035, 0.0)
        multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, marker_position))
        multi.set_instance_color(index, OCCUPANCY_FREE)

func update_occupancy_markers(force: bool = false) -> void:
    if occupancy_multimesh == null:
        return
    if not force:
        occupancy_refresh += get_process_delta_time()
        if occupancy_refresh < 0.4:
            return
    occupancy_refresh = 0.0
    for index in range(spots.size()):
        var spot_id: String = str(spots[index]["id"])
        occupancy_multimesh.set_instance_color(index,
            OCCUPANCY_BUSY if reserved_spots.has(spot_id) else OCCUPANCY_FREE)

func configure_schedule(minutes: float, weather_value: int, force: bool = false) -> void:
    var next_minutes: float = fposmod(minutes, 1440.0)
    var next_lunch: bool = next_minutes >= 690.0 and next_minutes < 810.0
    var next_rain: bool = weather_value >= 3
    var context_changed: bool = force or next_lunch != lunch_peak or next_rain != (weather_mode >= 3)
    game_minutes = next_minutes
    weather_mode = weather_value
    if not context_changed:
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    lunch_peak = next_lunch
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if not bool(state.get("ambient", false)):
            continue
        var mode: String = str(state.get("activity_mode", "walk"))
        var kind: String = str(state.get("activity_kind", ""))
        var cancel: bool = false
        if next_rain and next_lunch:
            cancel = mode != "walk" and kind not in ["eat", "queue"]
        elif next_rain:
            cancel = mode != "walk" and kind != "shelter"
        elif next_lunch:
            cancel = mode != "walk" and kind not in ["eat", "queue"]
        if cancel:
            _cancel_state(state, now + 0.45)
        elif mode == "walk":
            state["activity_next_at"] = minf(float(state.get("activity_next_at", now + 10.0)), now + 0.8)
    update_occupancy_markers(true)

func active_activity_count() -> int:
    return _active_activity_count()

func activity_limit() -> int:
    return MAX_LUNCH_ACTIVE_NPCS if lunch_peak else MAX_ACTIVE_NPCS

func food_court_crowd_count() -> int:
    var count: int = 0
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if bool(state.get("ambient", false)) and str(state.get("activity_area", "")) == "fine_food" and str(state.get("activity_mode", "walk")) != "walk":
            count += 1
    return count

func _process(delta: float) -> void:
    if life == null or navigation == null or life.interior_active:
        return
    var now: float = Time.get_ticks_msec() / 1000.0

    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if not bool(state.get("ambient", false)):
            continue
        var mode: String = str(state.get("activity_mode", "walk"))
        if bool(state.get("hostile", false)) or float(state.get("talk_remaining", 0.0)) > 0.0:
            if mode != "walk":
                _cancel_state(state, now + 20.0)
            continue

        match mode:
            "walk":
                if now >= float(state.get("activity_next_at", now + 10.0)) and _active_activity_count() < activity_limit():
                    _start_next_single_activity(state, now)
            "walk_to":
                _move_to_activity(state, delta, now)
            "waiting_chat":
                if now - float(state.get("activity_started_at", now)) > 20.0:
                    _finish_group(str(state.get("activity_group_id", "")), now)
            "sit", "drink", "buy", "eat", "queue", "shelter", "chat":
                _update_activity_pose(state, now, delta)
                state["activity_timer"] = maxf(0.0, float(state.get("activity_timer", 0.0)) - delta)
                if float(state["activity_timer"]) <= 0.0:
                    if mode == "queue":
                        _finish_queue_and_eat(state, now)
                    else:
                        var group_id: String = str(state.get("activity_group_id", ""))
                        if not group_id.is_empty():
                            _finish_group(group_id, now)
                        else:
                            _finish_single(state, now)

    update_occupancy_markers()
    if not lunch_peak and weather_mode < 3 and now >= next_chat_at and _active_activity_count() <= activity_limit() - 2:
        _start_chat_pair(now)

func _active_activity_count() -> int:
    var count: int = 0
    for state in life.pedestrians:
        if bool(state.get("ambient", false)) and str(state.get("activity_mode", "walk")) != "walk":
            count += 1
    return count

func _ambient_available() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if not bool(state.get("ambient", false)):
            continue
        if str(state.get("activity_mode", "walk")) != "walk":
            continue
        if bool(state.get("hostile", false)) or float(state.get("talk_remaining", 0.0)) > 0.0:
            continue
        result.append(state)
    return result

func _start_next_single_activity(state: Dictionary, now: float) -> bool:
    var profile: String = str(state.get("routine_profile", "commuter"))
    var preferences: Array[String] = []
    if weather_mode >= 3 and not lunch_peak:
        preferences = ["shelter"]
    elif lunch_peak:
        match profile:
            "foodie", "commuter":
                preferences = ["queue", "eat", "buy"]
            "social":
                preferences = ["queue", "eat", "eat"]
            "studious", "quiet":
                preferences = ["eat", "eat", "drink"]
            "active":
                preferences = ["eat", "drink", "eat"]
            _:
                preferences = ["eat", "queue", "drink"]
    else:
        match profile:
            "social":
                preferences = ["sit", "buy", "drink"]
            "studious":
                preferences = ["sit", "drink", "sit"]
            "foodie":
                preferences = ["buy", "drink", "sit"]
            "active":
                preferences = ["drink", "sit", "drink"]
            "quiet":
                preferences = ["sit", "drink", "sit"]
            _:
                preferences = ["buy", "drink", "sit"]
    var attempt: int = int(state.get("activity_attempts", 0))
    var preferred: String = preferences[attempt % preferences.size()]
    var candidates: Array[Dictionary] = _available_spots(preferred)
    if candidates.is_empty():
        for kind in preferences:
            candidates = _available_spots(kind)
            if not candidates.is_empty():
                break
    if candidates.is_empty():
        state["activity_next_at"] = now + 18.0
        return false
    var chosen: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
    state["activity_attempts"] = attempt + 1
    return _start_single_activity(state, chosen, now)

func _available_spots(kind: String, area_filter: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for spot_value in spots:
        var spot: Dictionary = spot_value
        var spot_id: String = str(spot["id"])
        if str(spot["kind"]) != kind or reserved_spots.has(spot_id):
            continue
        if not area_filter.is_empty() and str(spot.get("area", "")) != area_filter:
            continue
        result.append(spot)
    return result

func _nearest_available_spot(kind: String, from_position: Vector3, area_filter: String = "") -> Dictionary:
    var best: Dictionary = {}
    var best_distance: float = INF
    for spot in _available_spots(kind, area_filter):
        var position: Vector3 = spot["position"]
        var distance: float = Vector2(position.x, position.z).distance_to(Vector2(from_position.x, from_position.z))
        if distance < best_distance:
            best_distance = distance
            best = spot
    return best

func _start_single_activity(state: Dictionary, spot: Dictionary, now: float = -1.0) -> bool:
    if now < 0.0:
        now = Time.get_ticks_msec() / 1000.0
    var spot_id: String = str(spot.get("id", ""))
    if spot_id.is_empty() or reserved_spots.has(spot_id):
        return false
    var npc: Node3D = state.get("node") as Node3D
    if npc == null:
        return false
    reserved_spots[spot_id] = str(state.get("nav_key", state.get("name", "")))
    state["activity_mode"] = "walk_to"
    state["activity_kind"] = str(spot["kind"])
    state["activity_target"] = spot["position"]
    state["activity_facing"] = spot.get("facing", Vector3.FORWARD)
    state["activity_spot_id"] = spot_id
    state["activity_group_id"] = ""
    state["activity_area"] = str(spot.get("area", ""))
    state["activity_timer"] = 0.0
    state["activity_started_at"] = now
    state["activity_base_y"] = npc.global_position.y
    state["activity_partner"] = null
    state["activity_phase"] = rng.randf_range(0.0, TAU)
    navigation.clear_path(str(state.get("nav_key", state.get("name", ""))))
    return true

func _start_chat_pair(now: float = -1.0) -> bool:
    if now < 0.0:
        now = Time.get_ticks_msec() / 1000.0
    if lunch_peak or weather_mode >= 3:
        next_chat_at = now + 24.0
        return false
    var available: Array[Dictionary] = _ambient_available()
    if available.size() < 2 or picnic_groups.is_empty():
        next_chat_at = now + 24.0
        return false
    var free_groups: Array[Dictionary] = []
    for group_value in picnic_groups:
        var group: Dictionary = group_value
        if not reserved_spots.has(str(group["reservation"])):
            free_groups.append(group)
    if free_groups.is_empty():
        next_chat_at = now + 20.0
        return false

    var group: Dictionary = free_groups[rng.randi_range(0, free_groups.size() - 1)]
    var social_candidates: Array[Dictionary] = []
    for candidate in available:
        if str(candidate.get("routine_profile", "")) in ["social", "commuter"]:
            social_candidates.append(candidate)
    var pair: Array[Dictionary] = []
    if social_candidates.size() >= 2:
        pair.append(social_candidates[0])
        pair.append(social_candidates[1])
    else:
        pair.append(available[0])
        pair.append(available[1])
    var positions: Array = group["positions"]
    var group_id: String = str(group["id"])
    var reservation: String = str(group["reservation"])
    reserved_spots[reservation] = group_id
    for index in range(2):
        var state: Dictionary = pair[index]
        var npc: Node3D = state["node"]
        var target: Vector3 = positions[index]
        var partner: Node3D = pair[1 - index]["node"]
        state["activity_mode"] = "walk_to"
        state["activity_kind"] = "chat"
        state["activity_target"] = target
        state["activity_facing"] = partner.global_position - npc.global_position
        state["activity_spot_id"] = reservation
        state["activity_group_id"] = group_id
        state["activity_area"] = "town_green"
        state["activity_timer"] = 0.0
        state["activity_started_at"] = now
        state["activity_base_y"] = npc.global_position.y
        state["activity_partner"] = partner
        state["activity_phase"] = rng.randf_range(0.0, TAU)
        navigation.clear_path(str(state.get("nav_key", state.get("name", ""))))
    next_chat_at = now + 48.0 + rng.randf_range(0.0, 18.0)
    return true

func _move_to_activity(state: Dictionary, delta: float, now: float) -> void:
    var npc: Node3D = state.get("node") as Node3D
    if npc == null:
        _cancel_state(state, now + 20.0)
        return
    if now - float(state.get("activity_started_at", now)) > 22.0:
        _cancel_state(state, now + 24.0)
        return
    var target: Vector3 = state.get("activity_target", npc.global_position)
    var current: Vector3 = npc.global_position
    var offset: Vector3 = target - current
    offset.y = 0.0
    if offset.length() <= ARRIVAL_RADIUS:
        npc.global_position = Vector3(target.x, current.y, target.z)
        _arrive(state, now)
        return

    var nav_key: String = str(state.get("nav_key", state.get("name", "")))
    var waypoint: Vector3 = navigation.next_target(nav_key, current, target, now)
    var direction: Vector3 = waypoint - current
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        direction = offset
    var forward: Vector3 = direction.normalized()
    var avoidance: Vector3 = navigation.separation_offset(nav_key, current, life.pedestrians, forward, 1.45)
    var steering: Vector3 = (forward + avoidance * 0.5).normalized()
    var desired: Vector3 = current + steering * minf(WALK_SPEED * delta, direction.length())
    var safe_position: Vector3 = navigation.move_safe(current, desired, delta)
    npc.global_position = safe_position
    navigation.report_movement(nav_key, current, safe_position, now)
    if safe_position.distance_squared_to(current) > 0.000001:
        npc.look_at(npc.global_position + steering, Vector3.UP)

func _arrive(state: Dictionary, now: float) -> void:
    var kind: String = str(state.get("activity_kind", ""))
    if kind == "chat":
        state["activity_mode"] = "waiting_chat"
        _activate_chat_if_ready(str(state.get("activity_group_id", "")), now)
        return
    state["activity_mode"] = kind
    state["activity_timer"] = float(ACTIVITY_DURATION.get(kind, 10.0))
    state["activity_started_at"] = now
    _apply_activity_pose(state, now)

func _finish_queue_and_eat(state: Dictionary, now: float) -> void:
    var npc: Node3D = state.get("node") as Node3D
    if npc == null:
        _finish_single(state, now)
        return
    var current_position: Vector3 = npc.global_position
    _release_single_state(state)
    var seat: Dictionary = _nearest_available_spot("eat", current_position, "fine_food")
    if seat.is_empty() or not _start_single_activity(state, seat, now):
        state["activity_next_at"] = now + 24.0

func _release_single_state(state: Dictionary) -> void:
    var spot_id: String = str(state.get("activity_spot_id", ""))
    if not spot_id.is_empty():
        reserved_spots.erase(spot_id)
    _reset_state_pose(state)
    state["activity_mode"] = "walk"
    state["activity_kind"] = ""
    state["activity_spot_id"] = ""
    state["activity_group_id"] = ""
    state["activity_area"] = ""
    state["activity_partner"] = null
    state["activity_timer"] = 0.0
    navigation.clear_path(str(state.get("nav_key", state.get("name", ""))))

func _activate_chat_if_ready(group_id: String, now: float) -> void:
    if group_id.is_empty():
        return
    var pair: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if str(state.get("activity_group_id", "")) == group_id:
            pair.append(state)
    if pair.size() != 2:
        return
    for state in pair:
        if str(state.get("activity_mode", "")) != "waiting_chat":
            return
    for state in pair:
        state["activity_mode"] = "chat"
        state["activity_timer"] = float(ACTIVITY_DURATION["chat"])
        state["activity_started_at"] = now
        _apply_activity_pose(state, now)

func _update_activity_pose(state: Dictionary, now: float, delta: float) -> void:
    var npc: Node3D = state.get("node") as Node3D
    if npc == null:
        return
    var mode: String = str(state.get("activity_mode", ""))
    if mode == "eat":
        var phase: float = now * 2.6 + float(state.get("activity_phase", 0.0))
        (state["left_arm"] as Node3D).rotation.x = 0.28
        (state["right_arm"] as Node3D).rotation.x = 1.15 + sin(phase) * 0.22
        return
    if mode == "queue":
        var queue_phase: float = now * 1.5 + float(state.get("activity_phase", 0.0))
        (state["left_arm"] as Node3D).rotation.x = 0.06 + sin(queue_phase) * 0.04
        (state["right_arm"] as Node3D).rotation.x = 0.08 + cos(queue_phase) * 0.04
        return
    if mode == "shelter":
        var shelter_phase: float = now * 1.1 + float(state.get("activity_phase", 0.0))
        (state["left_arm"] as Node3D).rotation.x = sin(shelter_phase) * 0.035
        (state["right_arm"] as Node3D).rotation.x = cos(shelter_phase) * 0.035
        return
    if mode == "chat":
        var partner: Node3D = state.get("activity_partner") as Node3D
        if partner != null:
            var toward: Vector3 = partner.global_position - npc.global_position
            toward.y = 0.0
            if toward.length_squared() > 0.0001:
                npc.look_at(npc.global_position + toward, Vector3.UP)
        var phase: float = now * 2.4 + float(state.get("activity_phase", 0.0))
        (state["left_arm"] as Node3D).rotation.x = 0.55 + sin(phase) * 0.32
        (state["right_arm"] as Node3D).rotation.x = 0.55 + cos(phase * 0.83) * 0.32
        return
    _apply_activity_pose(state, now)

func _apply_activity_pose(state: Dictionary, now: float) -> void:
    var mode: String = str(state.get("activity_mode", ""))
    var npc: Node3D = state.get("node") as Node3D
    if npc == null:
        return
    var left_arm: Node3D = state["left_arm"]
    var right_arm: Node3D = state["right_arm"]
    var left_leg: Node3D = state["left_leg"]
    var right_leg: Node3D = state["right_leg"]
    match mode:
        "sit":
            left_leg.rotation.x = PI * 0.5
            right_leg.rotation.x = PI * 0.5
            left_arm.rotation.x = 0.22
            right_arm.rotation.x = 0.28
            _face_activity_target(state)
        "drink":
            right_arm.rotation.x = 1.92
            left_arm.rotation.x = 0.18
            _face_activity_target(state)
            _attach_hand_prop(state, "cup")
        "buy":
            right_arm.rotation.x = 1.15
            right_arm.rotation.z = -0.12
            left_arm.rotation.x = 0.15
            _face_activity_target(state)
            _attach_hand_prop(state, "bag")
        "eat":
            left_leg.rotation.x = PI * 0.5
            right_leg.rotation.x = PI * 0.5
            left_arm.rotation.x = 0.24
            right_arm.rotation.x = 1.15
            _face_activity_target(state)
            _attach_hand_prop(state, "tray")
        "queue", "shelter":
            _face_activity_target(state)
        "chat":
            left_leg.rotation.x = PI * 0.5
            right_leg.rotation.x = PI * 0.5
            left_arm.rotation.x = 0.45
            right_arm.rotation.x = 0.45
            _update_activity_pose(state, now, 0.0)
        _:
            return

func _face_activity_target(state: Dictionary) -> void:
    var npc: Node3D = state.get("node") as Node3D
    var facing: Vector3 = state.get("activity_facing", Vector3.ZERO)
    facing.y = 0.0
    if npc != null and facing.length_squared() > 0.0001:
        npc.look_at(npc.global_position + facing, Vector3.UP)

func _attach_hand_prop(state: Dictionary, prop_kind: String) -> void:
    if state.get("activity_prop") != null:
        return
    var hand: Node3D = state["left_arm"] if prop_kind == "tray" else state["right_arm"]
    var prop := MeshInstance3D.new()
    prop.name = "AmbientActivityHandProp"
    if prop_kind == "bag":
        var bag := BoxMesh.new()
        bag.size = Vector3(0.16, 0.18, 0.12)
        prop.mesh = bag
        prop.material_override = _material("#c79b73")
    elif prop_kind == "tray":
        var tray := BoxMesh.new()
        tray.size = Vector3(0.24, 0.035, 0.18)
        prop.mesh = tray
        prop.material_override = _material("#d8c8a8")
    else:
        var cup := CylinderMesh.new()
        cup.top_radius = 0.065
        cup.bottom_radius = 0.07
        cup.height = 0.18
        cup.radial_segments = 8
        prop.mesh = cup
        prop.material_override = _material("#d7e5df")
    prop.position = Vector3(0.0, -0.57, -0.12)
    hand.add_child(prop)
    state["activity_prop"] = prop

func _material(hex: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = 0.88
    return material

func _finish_single(state: Dictionary, now: float) -> void:
    _release_single_state(state)
    state["activity_next_at"] = now + rng.randf_range(26.0, 48.0)
    completed_activities[str(state.get("name", ""))] = int(completed_activities.get(str(state.get("name", "")), 0)) + 1

func _finish_group(group_id: String, now: float) -> void:
    if group_id.is_empty():
        return
    reserved_spots.erase("picnic:" + group_id)
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if str(state.get("activity_group_id", "")) != group_id:
            continue
        _reset_state_pose(state)
        state["activity_mode"] = "walk"
        state["activity_kind"] = ""
        state["activity_spot_id"] = ""
        state["activity_group_id"] = ""
        state["activity_area"] = ""
        state["activity_partner"] = null
        state["activity_timer"] = 0.0
        state["activity_next_at"] = now + rng.randf_range(26.0, 48.0)
        var name: String = str(state.get("name", ""))
        completed_activities[name] = int(completed_activities.get(name, 0)) + 1
        navigation.clear_path(str(state.get("nav_key", name)))

func _cancel_state(state: Dictionary, next_time: float) -> void:
    var group_id: String = str(state.get("activity_group_id", ""))
    cancelled_activities += 1
    if not group_id.is_empty():
        _cancel_group(group_id, next_time)
        return
    _release_single_state(state)
    state["activity_next_at"] = next_time

func _cancel_group(group_id: String, next_time: float) -> void:
    if group_id.is_empty():
        return
    reserved_spots.erase("picnic:" + group_id)
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if str(state.get("activity_group_id", "")) != group_id:
            continue
        _reset_state_pose(state)
        state["activity_mode"] = "walk"
        state["activity_kind"] = ""
        state["activity_spot_id"] = ""
        state["activity_group_id"] = ""
        state["activity_area"] = ""
        state["activity_partner"] = null
        state["activity_timer"] = 0.0
        state["activity_next_at"] = next_time
        navigation.clear_path(str(state.get("nav_key", state.get("name", ""))))

func _reset_state_pose(state: Dictionary) -> void:
    var npc: Node3D = state.get("node") as Node3D
    if npc == null:
        return
    (state["left_arm"] as Node3D).rotation = Vector3.ZERO
    (state["right_arm"] as Node3D).rotation = Vector3.ZERO
    (state["left_leg"] as Node3D).rotation = Vector3.ZERO
    (state["right_leg"] as Node3D).rotation = Vector3.ZERO
    var prop: Node = state.get("activity_prop") as Node
    if prop != null and is_instance_valid(prop):
        prop.queue_free()
    state["activity_prop"] = null
    npc.position.y = float(state.get("activity_base_y", npc.position.y))

func _start_chat_pair_for_test() -> bool:
    return _start_chat_pair()
