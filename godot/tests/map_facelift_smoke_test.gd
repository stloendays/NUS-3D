extends SceneTree
## Non-destructive, source-anchored visual facelift regression.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NUS3D map facelift regression: " + message)
    quit(1)

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene could not load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)
    var world: UTownWorld = game.get_node_or_null("World") as UTownWorld
    var styling: NUS3DMapDressing = game.get_node_or_null("MapDressing") as NUS3DMapDressing
    var ridge: NUSKentRidgeWorld = game.get_node_or_null("KentRidgeExpansion") as NUSKentRidgeWorld
    if world == null or styling == null or ridge == null:
        _fail("Map components not attached")
        return
    if styling.path_edge_count != world.generated_path_count:
        _fail("Path edging failed to mirror original 11 walkway segments")
        return
    if styling.meadow_patch_count != world.generated_tree_count or styling.meadow_patch_count > 64:
        _fail("Tree-base details must be bounded, instanced and match canonical tree count")
        return
    if styling.bush_count > styling.MAX_BUSHES or styling.bench_count > styling.MAX_BENCHES:
        _fail("UTown details exceeded shared geometry budgets")
        return
    if styling.district_tree_count > styling.MAX_DISTRICT_TREES:
        _fail("Ridge vegetation exceeds allocated bound")
        return
    if styling.plaza_planter_count != 4:
        _fail("Town Plaza corner planters missing")
        return
    if styling.grove_positions.size() != styling.district_tree_count:
        _fail("District foliage CPU positions inconsistent")
        return
    for point in styling.bush_positions:
        if not world.is_tree_position_clear(Vector2(point.x, point.z), 4.5):
            _fail("Decorative shrub was planted on a building or walkway")
            return
    # All props are decorative: no new collision geometry or changed source data.
    if game.get_node("MapDressing").find_children("*", "CollisionShape3D", true, false).size() > 0:
        _fail("Visual dressing must not add colliders")
        return
    var shrub_batch: MultiMeshInstance3D = styling.get_node_or_null("CampusShrubs_BatchedLowPoly") as MultiMeshInstance3D
    if styling.bush_count > 0 and (shrub_batch == null or shrub_batch.multimesh.instance_count != styling.bush_count):
        _fail("Repeated shrubs were not instanced")
        return
    if world.generated_building_count != 9 or ridge.districts.size() != 10:
        _fail("Canonical campus sites changed while restyling")
        return
    print("PASS: map facelift: %d path edges, %d meadow patches, %d shrubs, %d benches and %d Ridge trees." % [
        styling.path_edge_count, styling.meadow_patch_count, styling.bush_count,
        styling.bench_count, styling.district_tree_count
    ])
    game.queue_free()
    quit(0)
