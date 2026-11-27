extends SceneTree
## M28 visual review: genuine Godot viewport captures with the event line visible in the HUD.

func _initialize() -> void:
    call_deferred("_render")


func _fail(reason: String) -> void:
    push_error("M28 campus event visual review: " + reason)
    quit(1)


func _render() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene could not load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)
    var intro: Node = game.get_node_or_null("Intro")
    if intro != null:
        if intro.has_method("finish_intro"):
            intro.call("finish_intro")
        intro.set_process(false)
        intro.set_physics_process(false)
    await process_frame

    var daily: NUS3DCampusDailyLife = game.get_node_or_null("CampusDailyLife") as NUS3DCampusDailyLife
    var events: NUS3DCampusEventDirector = game.get_node_or_null("CampusEvents") as NUS3DCampusEventDirector
    var activities: NUS3DCampusAmbientActivities = game.get_node_or_null("CampusAmbientActivities") as NUS3DCampusAmbientActivities
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    var dining: UTownGreenDining = game.get_node_or_null("GreenDining") as UTownGreenDining
    var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
    var hud: CanvasLayer = game.get_node_or_null("HUD") as CanvasLayer
    var coins: UTownCoins = game.get_node_or_null("Coins") as UTownCoins
    if daily == null or events == null or activities == null or life == null or weather == null or dining == null or player == null or hud == null or coins == null:
        _fail("event or campus scene services are missing")
        return

    player.set_physics_process(false)
    player.visible = false
    hud.visible = true
    for child in game.get_children():
        if child is CanvasLayer and child != hud:
            (child as CanvasLayer).visible = false
    if coins.interface != null:
        coins.interface.visible = false
    coins.save_path = "user://nus3d-m28-render-%d.cfg" % Time.get_ticks_usec()
    coins.load_progress()

    var camera := Camera3D.new()
    camera.name = "M28_ReviewCamera"
    camera.fov = 68.0
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

    var ambient_states: Array[Dictionary] = _ambient_states(life)
    if ambient_states.size() < 3:
        _fail("ambient pedestrians are missing")
        return

    var food_area: Dictionary = dining.dining_areas.get("fine_food", {})
    var food_root: Node3D = food_area.get("root") as Node3D
    if food_root == null:
        _fail("Fine Food root is missing")
        return
    daily.set_game_time(12.0 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    player.global_position = food_root.global_position
    _talk_to(life, player, ambient_states[0])
    if not await _save_capture(camera, food_root.global_position, Vector3(0.0, 58.0, 76.0), output, "M28_LUNCH_EVENT.png"):
        _fail("Lunch Rush event capture failed")
        return

    var shelter_position: Vector3 = Vector3.ZERO
    for spot_value in activities.spots:
        var spot: Dictionary = spot_value
        if str(spot.get("kind", "")) == "shelter" and str(spot.get("area", "")) == "flavours":
            shelter_position = spot.get("position", Vector3.ZERO)
            break
    if shelter_position == Vector3.ZERO:
        for spot_value in activities.spots:
            var spot: Dictionary = spot_value
            if str(spot.get("kind", "")) == "shelter":
                shelter_position = spot.get("position", Vector3.ZERO)
                break
    if shelter_position == Vector3.ZERO:
        _fail("rain shelter anchor is missing")
        return
    daily.set_game_time(15.0 * 60.0)
    weather.set_mode(3)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    player.global_position = shelter_position
    _talk_to(life, player, ambient_states[1])
    if not await _save_capture(camera, shelter_position, Vector3(0.0, 38.0, 52.0), output, "M28_RAIN_EVENT.png"):
        _fail("Rain Shelter event capture failed")
        return

    if activities.picnic_groups.is_empty():
        _fail("Town Green picnic anchors are missing")
        return
    var picnic: Dictionary = activities.picnic_groups[0]
    var positions: Array = picnic.get("positions", [])
    if positions.is_empty():
        _fail("Town Green picnic positions are missing")
        return
    var picnic_position: Vector3 = positions[0]
    daily.set_game_time(18.5 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    player.global_position = picnic_position
    _talk_to(life, player, ambient_states[2])
    if not await _save_capture(camera, picnic_position, Vector3(18.0, 13.0, 20.0), output, "M28_EVENING_EVENT.png"):
        _fail("Evening Picnic event capture failed")
        return

    print("PASS: M28 lunch, rain and evening campus event HUD captures")
    game.queue_free()
    await process_frame
    quit(0)


func _ambient_states(life: UTownCampusLife) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if bool(state.get("ambient", false)):
            result.append(state)
    return result


func _talk_to(life: UTownCampusLife, player: UTownPlayer, target_state: Dictionary) -> void:
    for index in range(life.pedestrians.size()):
        var state: Dictionary = life.pedestrians[index]
        var actor: Node3D = state.get("node") as Node3D
        if actor != null:
            actor.global_position = player.global_position + Vector3(90.0 + float(index) * 3.0, 0.0, 90.0)
    var target: Node3D = target_state.get("node") as Node3D
    if target != null:
        target.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
        life.talk_to_nearest()


func _save_capture(camera: Camera3D, centre: Vector3, offset: Vector3, output: String, filename: String) -> bool:
    camera.global_position = centre + offset
    camera.look_at(centre, Vector3.UP)
    for _frame in range(5):
        await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        return false
    return frame.save_png(output.path_join(filename)) == OK
