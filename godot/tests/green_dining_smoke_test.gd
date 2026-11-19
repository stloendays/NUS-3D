extends SceneTree
## Dedicated M3.8 environment regression: load existing full gameplay scene unchanged.

func _initialize() -> void:
    call_deferred("_test")

func _fail(message: String) -> void:
    push_error("M3.8 grass/dining regression: " + message)
    quit(1)

func _test() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("could not load main scene")
        return
    var instance: Node3D = scene.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    NUS3DServices.enter_test_playmode(instance)
    var environment: UTownGreenDining = instance.get_node_or_null("GreenDining") as UTownGreenDining
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var weather: UTownWeather = instance.get_node_or_null("Weather") as UTownWeather
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    var campus: UTownCampusLife = instance.get_node_or_null("CampusLife") as UTownCampusLife
    var arcade: UTownArcade = instance.get_node_or_null("Arcade") as UTownArcade
    if environment == null or world == null or weather == null or hud == null or campus == null or arcade == null:
        _fail("a required old or new system node is missing")
        return
    if environment.lawn_polygon.size() < 12 or environment.generated_tuft_count < 300:
        _fail("Town Green polygon or visibly dense turf is missing")
        return
    if environment.generated_tuft_count > environment.TUFT_LIMIT:
        _fail("turf exceeded its bounded instance budget")
        return
    if environment.tuft_batch == null or environment.tuft_batch.multimesh == null:
        _fail("turf is not rendered with one shared MultiMesh")
        return
    var multimesh: MultiMesh = environment.tuft_batch.multimesh
    if multimesh.instance_count != environment.generated_tuft_count:
        _fail("turf instance accounting does not match MultiMesh")
        return
    # Validate the actual CPU source positions. MultiMesh get_instance_transform()
    # can yield identity in headless CI even after set_instance_transform(), so
    # do not use renderer readback as a substitute for construction geometry.
    if environment.tuft_positions.size() != multimesh.instance_count:
        _fail("turf CPU position ledger did not match the GPU instance count")
        return
    for i in range(environment.tuft_positions.size()):
        if not environment.is_clear_lawn_point(environment.tuft_positions[i]):
            _fail("grass tuft %d was selected outside lawn or on a walkway" % i)
            return
    if environment.picnic_count < 2 or environment.picnic_count > environment.PICNIC_LIMIT:
        _fail("lawn picnic details missing or unbounded")
        return
    var picnic_root: Node3D = environment.get_node_or_null("TownGreenPicnicPatches_NoCollisions") as Node3D
    if picnic_root == null or picnic_root.get_child_count() != environment.picnic_count:
        _fail("picnic scene registry is inconsistent")
        return
    for picnic in picnic_root.get_children():
        var point := Vector2(picnic.global_position.x, picnic.global_position.z)
        if not environment.is_clear_lawn_point(point, 3.0):
            _fail("picnic blanket blocks the lawn border or existing footpath")
            return
    if environment.food_stall_count != 3 or environment.dining_table_count != 8:
        _fail("Fine Food is missing the schematic dining stalls or table batches")
        return
    if not environment.dining_areas.has("fine_food") or not environment.dining_areas.has("flavours"):
        _fail("Fine Food/Flavours dining zones are missing")
        return
    var fine: Node3D = environment.dining_areas["fine_food"]["root"]
    var flavours: Node3D = environment.dining_areas["flavours"]["root"]
    var plaza: Node3D = world.get_node_or_null("TownPlaza_approximate") as Node3D
    var src: Node3D = world.get_node_or_null("BuildingMassing_Estimated/SRC") as Node3D
    if plaza == null or src == null or fine.get_parent() != plaza or flavours.get_parent() != src:
        _fail("food outlets must attach to the correct existing campus anchors")
        return
    if flavours.get_node_or_null("FoodCourtAwning") == null:
        _fail("SRC food court facade is not recognizable")
        return
    if environment.get_node_or_null("ERCLearningCafe_IllustrativeSignage") != null:
        _fail("ERC cafe signage must be attached to the existing ERC, not this unrelated root")
        return
    if world.generated_path_count < 8 or campus.pedestrians.size() != 6 or arcade.professors.size() != 2:
        _fail("a prior route or NPC system regressed")
        return
    var stack: Array[Node] = [environment]
    while not stack.is_empty():
        var current: Node = stack.pop_back()
        if current is CollisionObject3D or current is CollisionShape3D:
            _fail("a purely decorative dining/lawn node introduced blocking collision")
            return
        for child in current.get_children():
            stack.append(child)
    var original_color: Color = environment.tuft_batch.material_override.albedo_color
    weather.set_mode(3)
    weather._process(1.2)
    if environment.tuft_batch.material_override.albedo_color.is_equal_approx(original_color):
        _fail("lawn turf is not reactive to the shared rain/wetness simulation")
        return
    weather.set_mode(0)
    weather._process(8.0)
    if not environment.tuft_batch.material_override.albedo_color.is_equal_approx(original_color):
        _fail("turf color did not return to dry after weather clears")
        return
    hud.visible = false
    environment._process(0.26)
    for label in environment.signs:
        if label.visible:
            _fail("F7 photo mode failed to hide dining/location captions")
            return
    hud.visible = true
    environment._process(0.26)
    for label in environment.signs:
        if not label.visible:
            _fail("dining labels did not restore after photo mode")
            return
    if environment.mesh_cache.size() > 45 or environment.material_cache.size() > 24:
        _fail("procedural decorations did not share mesh and material resources")
        return
    print("PASS: M3.8 grass in one MultiMesh, walkway-safe picnic details, two correctly anchored food courts, rain response, HUD isolation, no new colliders.")
    instance.queue_free()
    quit(0)
