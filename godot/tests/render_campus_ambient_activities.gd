extends SceneTree
## M26 genuine Godot viewport captures of NPCs using existing campus facilities.

func _initialize() -> void:
    call_deferred("_render")

func _fail(message: String) -> void:
    push_error("M26 campus activity visual review: " + message)
    quit(1)

func _render() -> void:
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
    if life == null or activities == null:
        _fail("campus life or activity controller missing")
        return
    var player: Node3D = game.get_node_or_null("Player") as Node3D
    if player != null:
        player.visible = false
        player.set_process(false)
        player.set_physics_process(false)
    for child in game.get_children():
        if child is CanvasLayer:
            (child as CanvasLayer).visible = false

    var camera := Camera3D.new()
    camera.name = "M26_ReviewCamera"
    camera.fov = 66.0
    camera.far = 1200.0
    game.add_child(camera)
    camera.make_current()
    if DisplayServer.get_name() == "headless":
        _fail("visual review requires an X11 display")
        return
    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        _fail("could not create review output directory")
        return

    var bench: Dictionary = activities._available_spots("sit")[0]
    var sitter: Dictionary = _ambient_state(life, 0)
    activities._start_single_activity(sitter, bench)
    (sitter["node"] as Node3D).global_position = bench["position"]
    activities._process(0.016)
    if not await _capture_activity(camera, sitter, output, "M26_BENCH_REST.png"):
        _fail("bench activity capture failed")
        return

    activities._finish_single(sitter, Time.get_ticks_msec() / 1000.0)
    var water: Dictionary = activities._available_spots("drink")[0]
    var drinker: Dictionary = _ambient_state(life, 1)
    activities._start_single_activity(drinker, water)
    (drinker["node"] as Node3D).global_position = water["position"]
    activities._process(0.016)
    if not await _capture_activity(camera, drinker, output, "M26_WATER_BREAK.png"):
        _fail("water break capture failed")
        return

    activities._finish_single(drinker, Time.get_ticks_msec() / 1000.0)
    var vending: Dictionary = activities._available_spots("buy")[0]
    var buyer: Dictionary = _ambient_state(life, 2)
    activities._start_single_activity(buyer, vending)
    (buyer["node"] as Node3D).global_position = vending["position"]
    activities._process(0.016)
    if not await _capture_activity(camera, buyer, output, "M26_VENDING_PURCHASE.png"):
        _fail("vending purchase capture failed")
        return

    activities._finish_single(buyer, Time.get_ticks_msec() / 1000.0)
    if not activities._start_chat_pair_for_test():
        _fail("picnic chat pair could not start")
        return
    var group_id: String = ""
    var pair: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if str(state.get("activity_kind", "")) == "chat":
            group_id = str(state.get("activity_group_id", ""))
            pair.append(state)
    if pair.size() != 2:
        _fail("picnic chat pair missing")
        return
    for state in pair:
        (state["node"] as Node3D).global_position = state["activity_target"]
    activities._process(0.016)
    if not await _capture_activity(camera, pair[0], output, "M26_PICNIC_CHAT.png"):
        _fail("picnic chat capture failed")
        return

    print("PASS: M26 rendered four genuine campus activity close-ups")
    game.queue_free()
    quit(0)

func _ambient_state(life: UTownCampusLife, index: int) -> Dictionary:
    var found: int = 0
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if not bool(state.get("ambient", false)):
            continue
        if found == index:
            return state
        found += 1
    return {}

func _capture_activity(camera: Camera3D, state: Dictionary, output: String, filename: String) -> bool:
    var npc: Node3D = state["node"]
    camera.global_position = npc.global_position + Vector3(3.2, 2.1, 3.4)
    camera.look_at(npc.global_position + Vector3.UP * 1.0, Vector3.UP)
    for _frame in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        return false
    return frame.save_png(output.path_join(filename)) == OK
