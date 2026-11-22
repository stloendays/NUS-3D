extends SceneTree
## M26 contract: ambient NPCs autonomously use campus facilities without touching story state.

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("M26 campus ambient activities: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene could not load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    await process_frame

    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    var activities: NUS3DCampusAmbientActivities = game.get_node_or_null("CampusAmbientActivities") as NUS3DCampusAmbientActivities
    var navigation: NUS3DNPCNavigation = game.get_node_or_null("NPCNavigation") as NUS3DNPCNavigation
    if life == null or activities == null or navigation == null:
        _fail("campus life, activity controller or navigation service is missing")
        return
    if life.pedestrians.size() != 24:
        _fail("the existing 24-person outdoor roster changed")
        return
    if activities.spots.size() < 12 or activities.picnic_groups.is_empty():
        _fail("bench, refill, vending or picnic anchors are missing; found %d spots and %d drink spots" % [activities.spots.size(), activities._available_spots("drink").size()])
        return
    var map_dressing: Node3D = game.get_node_or_null("MapDressing") as Node3D
    var refill_root: Node3D = map_dressing.get_node_or_null("CampusRefillStations_NoCollision") as Node3D if map_dressing != null else null
    if refill_root == null or refill_root.get_child_count() < 2 or activities._available_spots("drink").size() < 2:
        _fail("actual outdoor refill stations or their NPC approach spots are missing; stations=%d drink_spots=%d" % [0 if refill_root == null else refill_root.get_child_count(), activities._available_spots("drink").size()])
        return
    var green_dining: Node3D = game.get_node_or_null("GreenDining") as Node3D
    var picnic_root: Node3D = green_dining.get_node_or_null("TownGreenPicnicPatches_NoCollisions") as Node3D if green_dining != null else null
    if picnic_root == null or picnic_root.get_child_count() < 1:
        _fail("Town Green picnic patches are missing")
        return
    if (picnic_root.get_child(0) as Node3D).get_node_or_null("PicnicTableTop") == null:
        _fail("picnic patch is missing its low table")
        return

    var ambient_states: Array[Dictionary] = []
    var story_states: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if bool(state.get("ambient", false)):
            ambient_states.append(state)
        else:
            story_states.append(state)
    if ambient_states.size() != 18 or story_states.size() != 6:
        _fail("ambient/story NPC separation changed")
        return

    var npc_relations: Node = game.get_node_or_null("NPCRelations")
    var affinity_before: Dictionary = (npc_relations.get("affinity") as Dictionary).duplicate(true) if npc_relations != null else {}
    var story_relationships: Node = game.get_node_or_null("Relationships")
    var story_scores_before: Dictionary = (story_relationships.get("scores") as Dictionary).duplicate(true) if story_relationships != null else {}

    # Verify that the existing A* service actually moves an ambient pedestrian
    # toward a facility before testing the arrival pose in isolation.
    var route_walker: Dictionary = ambient_states[3]
    var route_spot: Dictionary = activities._available_spots("sit")[0]
    if not activities._start_single_activity(route_walker, route_spot):
        _fail("ambient student could not start a routed walk to a bench")
        return
    var route_npc: Node3D = route_walker["node"]
    var route_start: Vector3 = route_npc.global_position
    var route_now: float = Time.get_ticks_msec() / 1000.0
    var first_waypoint: Vector3 = navigation.next_target(
        str(route_walker.get("nav_key", "")), route_start, route_spot["position"], route_now)
    if first_waypoint == Vector3.ZERO:
        _fail("A* did not produce a waypoint to the reserved bench")
        return
    for step in range(12):
        activities._move_to_activity(route_walker, 0.25, route_now + float(step) * 0.25)
        if str(route_walker.get("activity_mode", "")) != "walk_to":
            break
    var walked_distance: float = Vector2(
        route_npc.global_position.x - route_start.x,
        route_npc.global_position.z - route_start.z
    ).length()
    if walked_distance < 0.20:
        _fail("ambient NPC did not make measurable progress along the A* route")
        return
    activities._finish_single(route_walker, Time.get_ticks_msec() / 1000.0)

    var bench_spot: Dictionary = activities._available_spots("sit")[0]
    var sitter: Dictionary = ambient_states[0]
    if not activities._start_single_activity(sitter, bench_spot):
        _fail("ambient student could not reserve a bench")
        return
    (sitter["node"] as Node3D).global_position = bench_spot["position"]
    activities._process(0.016)
    if str(sitter.get("activity_mode", "")) != "sit":
        _fail("bench arrival did not trigger the seated routine")
        return
    if absf(float((sitter["left_leg"] as Node3D).rotation.x) - PI * 0.5) > 0.01:
        _fail("seated routine did not pose the legs")
        return
    activities._finish_single(sitter, Time.get_ticks_msec() / 1000.0)

    var water_spot: Dictionary = activities._available_spots("drink")[0]
    var drinker: Dictionary = ambient_states[1]
    if not activities._start_single_activity(drinker, water_spot):
        _fail("ambient student could not reserve a refill station")
        return
    (drinker["node"] as Node3D).global_position = water_spot["position"]
    activities._process(0.016)
    if str(drinker.get("activity_mode", "")) != "drink" or drinker.get("activity_prop") == null:
        _fail("refill arrival did not trigger a drinking animation and cup")
        return
    activities._finish_single(drinker, Time.get_ticks_msec() / 1000.0)

    var vending_spot: Dictionary = activities._available_spots("buy")[0]
    var buyer: Dictionary = ambient_states[2]
    if not activities._start_single_activity(buyer, vending_spot):
        _fail("ambient student could not reserve a vending machine")
        return
    (buyer["node"] as Node3D).global_position = vending_spot["position"]
    activities._process(0.016)
    if str(buyer.get("activity_mode", "")) != "buy" or buyer.get("activity_prop") == null:
        _fail("vending arrival did not trigger the purchase animation and bag")
        return
    activities._finish_single(buyer, Time.get_ticks_msec() / 1000.0)

    if not activities._start_chat_pair_for_test():
        _fail("two ambient students could not reserve a picnic patch")
        return
    var group_id: String = ""
    var chat_pair: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if str(state.get("activity_kind", "")) == "chat":
            group_id = str(state.get("activity_group_id", ""))
            chat_pair.append(state)
    if chat_pair.size() != 2 or group_id.is_empty():
        _fail("picnic conversation did not reserve a pair of ambient students")
        return
    for state in chat_pair:
        (state["node"] as Node3D).global_position = state["activity_target"]
    activities._process(0.016)
    for state in chat_pair:
        if str(state.get("activity_mode", "")) != "chat":
            _fail("picnic pair did not enter the shared conversation state")
            return
        if absf(float((state["left_leg"] as Node3D).rotation.x) - PI * 0.5) > 0.01:
            _fail("picnic conversation did not switch to a seated pose")
            return
    activities._finish_group(group_id, Time.get_ticks_msec() / 1000.0)

    for state in story_states:
        if str(state.get("activity_mode", "walk")) != "walk":
            _fail("a named story character was incorrectly assigned an ambient routine")
            return
    if npc_relations != null and (npc_relations.get("affinity") as Dictionary) != affinity_before:
        _fail("ambient routines modified rivalry affinity")
        return
    if story_relationships != null and (story_relationships.get("scores") as Dictionary) != story_scores_before:
        _fail("ambient routines modified story-character affinity")
        return
    if activities.find_children("*", "CollisionShape3D", true, false).size() > 0:
        _fail("ambient activity controller added collision geometry")
        return

    print("PASS: M26 ambient NPCs sit, refill, buy drinks and chat at picnic patches")
    game.queue_free()
    quit(0)
