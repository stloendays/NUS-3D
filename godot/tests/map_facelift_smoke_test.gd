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
    var map: Control = game.get_node_or_null("HUD/Minimap") as Control
    var language_service: NUS3DGameLanguage = root.get_node_or_null("GameLanguage") as NUS3DGameLanguage
    if map == null or language_service == null or (map.get("map_font") as Font) == null:
        _fail("Minimap requires the installed CJK UI font and language service")
        return
    var previous_locale: String = language_service.locale
    language_service.locale = "zh"
    var chinese_map_label: String = str(map.call("_map_text", "地图", "GAME MAP"))
    language_service.locale = "en"
    var english_map_label: String = str(map.call("_map_text", "地图", "GAME MAP"))
    language_service.locale = previous_locale
    if chinese_map_label != "地图" or english_map_label != "GAME MAP":
        _fail("Minimap labels do not follow the selected login language")
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
    # Kent Ridge JSON landmark offsets are east/north; the Godot world uses
    # east/-north. Check ACTUAL built landmarks, not just the vegetation budget.
    for tree_position in styling.grove_positions:
        var tree_xz: Vector2 = Vector2(tree_position.x, tree_position.z)
        for district in ridge.districts:
            var center: Vector3 = district["position"]
            var local: Vector2 = tree_xz - Vector2(center.x, center.z)
            for landmark in district.get("landmarks", []):
                var offset: Array = landmark.get("offset", [0, 0])
                var size_m: Array = landmark.get("size", [30, 25, 14])
                var footprint_z: float = -float(offset[1])
                if absf(local.x - float(offset[0])) < float(size_m[0]) * 0.5 + 6.0 \
                        and absf(local.y - footprint_z) < float(size_m[1]) * 0.5 + 6.0:
                    _fail("District tree overlaps 6m building clearance at " + str(landmark.get("name", "")))
                    return
        for stop in ridge.stops:
            var at: Vector3 = stop["position"]
            if tree_xz.distance_to(Vector2(at.x, at.z)) < 15.0:
                _fail("District tree overlaps a campus bus stop")
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
    # Validate against the current source data, not a frozen district count:
    # newer main branches legitimately add Science and other campus content.
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ridge.DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        _fail("The canonical Kent Ridge data document is unavailable")
        return
    var record: Dictionary = parsed
    var source_districts: Array = record.get("districts", [])
    var source_buildings: Array = world.layout.get("buildings", [])
    if world.generated_building_count != source_buildings.size() or ridge.districts.size() != source_districts.size():
        _fail("Map dressing modified an existing campus district or building")
        return
    print("PASS: map facelift: %d path edges, %d meadow patches, %d shrubs, %d benches and %d Ridge trees." % [
        styling.path_edge_count, styling.meadow_patch_count, styling.bush_count,
        styling.bench_count, styling.district_tree_count
    ])
    game.queue_free()
    quit(0)
