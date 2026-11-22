extends SceneTree
## M25: deterministic scatter, bounded GPU batches and collision-free integration.

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("M25 campus scattered props: " + message)
    quit(1)

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene could not load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)

    var dressing: NUS3DMapDressing = game.get_node_or_null("MapDressing") as NUS3DMapDressing
    if dressing == null:
        _fail("map dressing node is missing")
        return
    var scatter: Node3D = dressing.get_node_or_null("KentRidgeScatteredEverydayProps_M25") as Node3D
    if scatter == null:
        _fail("scatter root was not attached")
        return
    var batches: int = scatter.get_child_count()
    if batches < 17 or batches > 26:
        _fail("expected 17-22 bounded prop and amenity batches, got %d" % batches)
        return

    var total_instances: int = 0
    var seen_kinds: Dictionary = {}
    for child in scatter.get_children():
        if not child is MultiMeshInstance3D:
            _fail("scatter contains a non-instanced renderer")
            return
        var renderer: MultiMeshInstance3D = child as MultiMeshInstance3D
        if renderer.multimesh == null:
            _fail("a scatter batch has no MultiMesh")
            return
        if renderer.multimesh.instance_count <= 0:
            _fail("empty scatter batch was attached")
            return
        total_instances += renderer.multimesh.instance_count
        seen_kinds[renderer.name] = true
    if total_instances < 240 or total_instances > 500:
        _fail("instance count outside the authored 240-500 density budget: %d" % total_instances)
        return
    if not seen_kinds.has("Scattered_paper_MultiMesh") or not seen_kinds.has("Scattered_bottle_MultiMesh"):
        _fail("academic and everyday props were not both generated")
        return
    var required_amenity_batches: Array[String] = [
        "Scattered_vending_machine_MultiMesh",
        "Scattered_vending_display_MultiMesh",
        "Scattered_vending_products_MultiMesh",
        "Scattered_vending_buttons_MultiMesh",
        "Scattered_picnic_table_MultiMesh",
        "Scattered_shade_umbrella_MultiMesh",
        "Scattered_umbrella_pole_MultiMesh",
        "Scattered_water_dispenser_MultiMesh",
        "Scattered_water_bottle_MultiMesh",
        "Scattered_water_tap_MultiMesh",
        "Scattered_water_tray_MultiMesh"
    ]
    for required_batch in required_amenity_batches:
        if not seen_kinds.has(required_batch):
            _fail("campus amenity batch is missing: " + required_batch)
            return
    if not seen_kinds.has("Scattered_bench_MultiMesh") or not seen_kinds.has("Scattered_trash_bin_MultiMesh"):
        _fail("outdoor seating and waste bins were not generated")
        return
    var vending_batch: MultiMeshInstance3D = scatter.get_node("Scattered_vending_machine_MultiMesh") as MultiMeshInstance3D
    var picnic_batch: MultiMeshInstance3D = scatter.get_node("Scattered_picnic_table_MultiMesh") as MultiMeshInstance3D
    var water_batch: MultiMeshInstance3D = scatter.get_node("Scattered_water_dispenser_MultiMesh") as MultiMeshInstance3D
    var vending_products: MultiMeshInstance3D = scatter.get_node("Scattered_vending_products_MultiMesh") as MultiMeshInstance3D
    var vending_buttons: MultiMeshInstance3D = scatter.get_node("Scattered_vending_buttons_MultiMesh") as MultiMeshInstance3D
    var water_bottles: MultiMeshInstance3D = scatter.get_node("Scattered_water_bottle_MultiMesh") as MultiMeshInstance3D
    var water_trays: MultiMeshInstance3D = scatter.get_node("Scattered_water_tray_MultiMesh") as MultiMeshInstance3D
    if vending_batch.multimesh.instance_count < 4 or picnic_batch.multimesh.instance_count < 4 or water_batch.multimesh.instance_count < 2:
        _fail("vending, shaded picnic or water refill amenities are below their minimum counts")
        return
    if vending_products.multimesh.instance_count < 24 or vending_buttons.multimesh.instance_count < 12:
        _fail("vending machine displays need visible products and selection buttons")
        return
    if water_bottles.multimesh.instance_count < 2 or water_trays.multimesh.instance_count < 2:
        _fail("water refill stations need visible bottle and drip-tray details")
        return
    var bench_batch: MultiMeshInstance3D = scatter.get_node("Scattered_bench_MultiMesh") as MultiMeshInstance3D
    var bin_batch: MultiMeshInstance3D = scatter.get_node("Scattered_trash_bin_MultiMesh") as MultiMeshInstance3D
    if bench_batch.multimesh.instance_count < 8 or bin_batch.multimesh.instance_count < 8:
        _fail("Kent Ridge needs a visible minimum of 8 benches and 8 waste bins")
        return
    if dressing.bench_count < 5 or dressing.trash_bin_count < 4:
        _fail("UTown expected at least 5 path benches and 4 adjacent bins; got %d benches and %d bins" % [dressing.bench_count, dressing.trash_bin_count])
        return
    if scatter.find_children("*", "CollisionShape3D", true, false).size() > 0:
        _fail("decorative scatter must not add collision geometry")

    print("PASS: M25 campus dressing: %d instances across %d GPU batches; %d vending machines, %d shaded picnic tables, %d refill stations" % [total_instances, batches, vending_batch.multimesh.instance_count, picnic_batch.multimesh.instance_count, water_batch.multimesh.instance_count])
    game.queue_free()
    quit(0)
