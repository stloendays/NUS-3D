extends SceneTree
## Verifies the new ERC/SRC prop dressing is present, lightweight and non-blocking.

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("INTERIOR_SET_DRESSING_SMOKE: " + message)
    quit(1)


func _has_physics_blocker(node: Node) -> bool:
    if node is StaticBody3D or node is CollisionShape3D or node is CharacterBody3D:
        return true
    for child in node.get_children():
        if _has_physics_blocker(child):
            return true
    return false


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene failed to load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    if game == null:
        _fail("main scene could not instantiate")
        return
    root.add_child(game)
    await process_frame

    var campus: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    if campus == null or not campus.interiors.has("ERC") or not campus.interiors.has("SRC"):
        _fail("existing ERC/SRC interiors are unavailable")
        return

    var erc: Node3D = campus.interiors["ERC"]
    var src: Node3D = campus.interiors["SRC"]
    var study: Node3D = erc.get_node_or_null("StudyLifePropsM24") as Node3D
    var recreation: Node3D = src.get_node_or_null("RecreationLifePropsM24") as Node3D
    if study == null or recreation == null:
        _fail("one of the M24 prop groups was not attached to the live rooms")
        return
    if study.get_child_count() < 100:
        _fail("ERC desk and study dressing count is unexpectedly low")
        return
    if recreation.get_child_count() < 45:
        _fail("SRC sports and social dressing count is unexpectedly low")
        return
    for required in ["ShelfBook_0_0_0", "Desk_00_LaptopBase", "PrintStationCabinet", "StudyWasteBin"]:
        if study.get_node_or_null(required) == null:
            _fail("missing ERC prop: " + required)
            return
    for required in ["SportsBallRackBase", "SportsLocker", "ChessTile_0_0", "CardDeckBox", "SRCClubPoster"]:
        if recreation.get_node_or_null(required) == null:
            _fail("missing SRC prop: " + required)
            return
    if _has_physics_blocker(study) or _has_physics_blocker(recreation):
        _fail("decorative props must not introduce new collision blockers")
        return

    print("NUS3D_INTERIOR_SET_DRESSING_SMOKE_OK")
    game.queue_free()
    quit(0)
