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
    if batches < 5 or batches > 8:
        _fail("expected a bounded set of 1-8 object batches, got %d" % batches)
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
    if total_instances < 70 or total_instances > 240:
        _fail("instance count outside the authored 70-240 budget: %d" % total_instances)
        return
    if not seen_kinds.has("Scattered_paper_MultiMesh") or not seen_kinds.has("Scattered_bottle_MultiMesh"):
        _fail("academic and everyday props were not both generated")
        return
    if dressing.find_children("*", "CollisionShape3D", true, false).size() > 0:
        _fail("decorative scatter must not add collision geometry")

    print("PASS: M25 campus scatter: %d props across %d GPU batches" % [total_instances, batches])
    game.queue_free()
    quit(0)
