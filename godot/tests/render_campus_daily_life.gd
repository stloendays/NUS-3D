extends SceneTree
## M27 genuine Godot viewport captures for lunch crowd, rain shelter and evening transition.

func _initialize() -> void:
    call_deferred("_render")

func _fail(message: String) -> void:
    push_error("M27 campus daily-life visual review: " + message)
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
    var activities: NUS3DCampusAmbientActivities = game.get_node_or_null("CampusAmbientActivities") as NUS3DCampusAmbientActivities
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    if daily == null or activities == null or life == null or weather == null:
        _fail("campus daily-life systems missing")
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
    camera.name = "M27_ReviewCamera"
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

    daily.set_game_time(12.0 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    var food_root: Node3D = (game.get_node("GreenDining") as UTownGreenDining).dining_areas["fine_food"]["root"] as Node3D
    var queue_spots: Array[Dictionary] = activities._available_spots("queue")
    var eat_spots: Array[Dictionary] = activities._available_spots("eat")
    var ambient_states: Array[Dictionary] = _ambient_states(life)
    for index in range(4):
        var queue_state: Dictionary = ambient_states[index]
        activities._start_single_activity(queue_state, queue_spots[index])
        (queue_state["node"] as Node3D).global_position = queue_spots[index]["position"]
        activities._arrive(queue_state, Time.get_ticks_msec() / 1000.0)
        var eater: Dictionary = ambient_states[index + 4]
        activities._start_single_activity(eater, eat_spots[index])
        (eater["node"] as Node3D).global_position = eat_spots[index]["position"]
        activities._arrive(eater, Time.get_ticks_msec() / 1000.0)
    activities.update_occupancy_markers(true)
    var lunch_centre: Vector3 = food_root.to_global(Vector3(0.0, 0.0, -7.5))
    if not await _capture(camera, lunch_centre, output, "M27_LUNCH_CROWD.png"):
        _fail("lunch crowd capture failed")
        return

    for state in ambient_states:
        if str(state.get("activity_mode", "walk")) != "walk":
            activities._cancel_state(state, Time.get_ticks_msec() / 1000.0 + 1.0)
    daily.set_game_time(15.0 * 60.0)
    weather.set_mode(3)
    daily.refresh_schedule_context(true)
    var shelters: Array[Dictionary] = activities._available_spots("shelter")
    for index in range(3):
        var state: Dictionary = ambient_states[index]
        activities._start_single_activity(state, shelters[index])
        (state["node"] as Node3D).global_position = shelters[index]["position"]
        activities._arrive(state, Time.get_ticks_msec() / 1000.0)
    activities.update_occupancy_markers(true)
    var shelter_centre: Vector3 = (shelters[0]["position"] + shelters[1]["position"] + shelters[2]["position"]) / 3.0
    if not await _capture(camera, shelter_centre, output, "M27_RAIN_SHELTER.png"):
        _fail("rain shelter capture failed")
        return

    daily.set_game_time(20.0 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    if not await _capture(camera, food_root.global_position + Vector3(0.0, 0.0, -8.0), output, "M27_EVENING_CAMPUS.png"):
        _fail("evening lighting capture failed")
        return

    print("PASS: M27 rendered lunch crowd, rain shelter and evening campus views")
    game.queue_free()
    quit(0)

func _ambient_states(life: UTownCampusLife) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if bool(state.get("ambient", false)):
            result.append(state)
    return result

func _capture(camera: Camera3D, centre: Vector3, output: String, filename: String) -> bool:
    camera.global_position = centre + Vector3(0.0, 10.5, 22.0)
    camera.look_at(centre + Vector3.UP * 0.9, Vector3.UP)
    for _frame in range(4):
        await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        return false
    return frame.save_png(output.path_join(filename)) == OK
