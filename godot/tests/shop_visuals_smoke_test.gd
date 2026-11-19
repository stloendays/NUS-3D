extends SceneTree
## M14 low-poly shop model integration.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("M14 shop visuals: " + message)
    quit(1)

func _run() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene missing")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    var visuals := game.get_node_or_null("ShopVisuals") as UTownShopVisuals
    if visuals == null or visuals.stand == null:
        _fail("Shop counter not mounted")
        return
    for item in ["coffee", "snack", "umbrella"]:
        if not visuals.previews.has(item):
            _fail("Missing model: " + item)
            return
        var root: Node3D = visuals.previews[item]
        if root.get_child_count() < 3:
            _fail("Incomplete model: " + item)
            return
    var stack: Array[Node] = [visuals]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is CollisionObject3D or node is CollisionShape3D:
            _fail("Shop display must not introduce collision")
            return
        for child in node.get_children():
            stack.append(child)
    print("PASS: M14 shop display, three 3D items, collision isolation")
    game.queue_free()
    quit(0)
