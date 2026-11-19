extends SceneTree
## Original M1/M2 review renders on a virtual X11 display; not a photo or survey.

func _initialize() -> void:
    call_deferred("_render")

func _render() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("Could not load project scene")
        quit(1)
        return
    var instance: Node3D = packed.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    var review: UTownViewReview = instance.get_node_or_null("ViewReview") as UTownViewReview
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    if review == null or world == null or hud == null or review.viewpoint_count() != 4:
        push_error("Photo-review scene did not initialize")
        quit(1)
        return
    if DisplayServer.get_name() == "headless":
        push_error("X11 display required for rendered previews")
        quit(1)
        return
    hud.visible = false
    world.set_navigation_markers_visible(false)
    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        push_error("Could not create review_previews folder")
        quit(1)
        return
    var count: int = 0
    for index in range(review.viewpoint_count()):
        if not review.select_view(index):
            push_error("Could not select camera preset")
            quit(1)
            return
        for with_details in [true, false]:
            world.set_m2_details_visible(with_details)
            await process_frame
            await process_frame
            await RenderingServer.frame_post_draw
            var frame: Image = root.get_texture().get_image()
            if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
                push_error("Graphical viewport did not return a valid PNG frame")
                quit(1)
                return
            var suffix: String = "M2" if with_details else "M1"
            var filename: String = "%s_%s.png" % [str(review.viewpoints[index]["id"]), suffix]
            if frame.save_png(output.path_join(filename)) != OK:
                push_error("Cannot write preview: " + filename)
                quit(1)
                return
            count += 1
    # Two additional source-outline frames make the proxy-to-OSM mismatch inspectable.
    world.set_m2_details_visible(true)
    world.set_osm_reference_visible(true)
    for index in [2, 3]:
        if not review.select_view(index):
            push_error("Cannot select OSM comparison view")
            quit(1)
            return
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var compare: Image = root.get_texture().get_image()
        if compare == null or compare.is_empty():
            push_error("Cannot capture OSM comparison")
            quit(1)
            return
        if compare.save_png(output.path_join("%s_OSM.png" % str(review.viewpoints[index]["id"]))) != OK:
            push_error("Cannot save OSM comparison frame")
            quit(1)
            return
        count += 1
    world.set_osm_reference_visible(false)
    # Two additional original twilight/evening renders, without HUD.
    world.set_m2_details_visible(true)
    if not review.select_view(3):
        push_error("Cannot select evening preview view")
        quit(1)
        return
    for mode in [1, 3]:
        if not world.set_lighting_mode(mode):
            push_error("Cannot set lighting preset for screenshot")
            quit(1)
            return
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        var atmosphere_frame: Image = root.get_texture().get_image()
        if atmosphere_frame == null or atmosphere_frame.is_empty():
            push_error("Cannot capture weather-independent atmosphere frame")
            quit(1)
            return
        var filename: String = "SRC_EAST_PROXY_%s.png" % ("GOLDEN" if mode == 1 else "EVENING")
        if atmosphere_frame.save_png(output.path_join(filename)) != OK:
            push_error("Cannot save atmosphere preview")
            quit(1)
            return
        count += 1
    # Capture a real windowed screenshot of the diagnostic card + F6 outline.
    world.set_lighting_mode(0)
    world.set_osm_reference_visible(true)
    hud.visible = true
    if not review.select_view(3):
        push_error("Cannot select map/metric comparison overview")
        quit(1)
        return
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var gis_frame: Image = root.get_texture().get_image()
    if gis_frame == null or gis_frame.is_empty():
        push_error("Cannot render GIS comparison HUD")
        quit(1)
        return
    if gis_frame.save_png(output.path_join("SRC_GIS_F6_SCORECARD.png")) != OK:
        push_error("Cannot save GIS comparison HUD preview")
        quit(1)
        return
    count += 1
    # M3.3 gameplay showcase: original Godot renders of weather, pedestrians,
    # isolated interior concepts, bicycle mode and the procedural shuttle.
    var player: UTownPlayer = instance.get_node_or_null("Player") as UTownPlayer
    var weather: UTownWeather = instance.get_node_or_null("Weather") as UTownWeather
    var campus_life: UTownCampusLife = instance.get_node_or_null("CampusLife") as UTownCampusLife
    if player == null or weather == null or campus_life == null:
        push_error("M3.3 showcase controllers did not load")
        quit(1)
        return
    hud.visible = true
    world.set_osm_reference_visible(false)
    world.set_m2_details_visible(true)
    world.set_lighting_mode(0)
    review.select_view(3)
    weather.set_mode(3)
    weather.rain.restart()
    for rain_frame in range(60):
        await process_frame
    if not await _capture_frame(output, "M3_3_WEATHER_RAIN.png"):
        push_error("Could not capture the rain and puddle showcase")
        quit(1)
        return
    count += 1

    weather.set_mode(4)
    weather.flash_wait = 60.0
    weather.flash_time = 0.14
    for storm_frame in range(8):
        await process_frame
    if not await _capture_frame(output, "M3_3_WEATHER_THUNDERSTORM.png"):
        push_error("Could not capture the thunderstorm showcase")
        quit(1)
        return
    count += 1

    weather.set_mode(0)
    var featured_npc: Node3D = campus_life.pedestrians[0]["node"]
    player.global_position = featured_npc.global_position + Vector3(0.0, 0.18, 6.5)
    player.head.rotation = Vector3.ZERO
    player.look_at(featured_npc.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
    if not await _capture_frame(output, "M3_3_CAMPUS_NPCS_AND_HUD.png"):
        push_error("Could not capture the campus-life HUD showcase")
        quit(1)
        return
    count += 1

    if not campus_life.enter_interior("ERC"):
        push_error("Could not enter ERC interior for screenshot")
        quit(1)
        return
    if not await _capture_frame(output, "M3_3_ERC_INTERIOR_GROUND.png"):
        push_error("Could not capture ERC interior ground floor")
        quit(1)
        return
    count += 1
    campus_life.toggle_interior_floor()
    if not await _capture_frame(output, "M3_3_ERC_INTERIOR_MEZZANINE.png"):
        push_error("Could not capture ERC interior mezzanine")
        quit(1)
        return
    count += 1
    campus_life.exit_interior()

    if not campus_life.enter_interior("SRC"):
        push_error("Could not enter SRC interior for screenshot")
        quit(1)
        return
    if not await _capture_frame(output, "M3_3_SRC_INTERIOR.png"):
        push_error("Could not capture SRC interior")
        quit(1)
        return
    count += 1
    campus_life.exit_interior()

    review.select_view(3)
    if not campus_life.set_bicycle(true):
        push_error("Could not enable bicycle for screenshot")
        quit(1)
        return
    for frame_index in range(12):
        await process_frame
    if not await _capture_frame(output, "M3_3_BICYCLE_RIDE.png"):
        push_error("Could not capture bicycle mode")
        quit(1)
        return
    count += 1
    campus_life.set_bicycle(false)

    var bus: Node3D = campus_life.shuttle
    player.global_position = bus.global_position + Vector3(5.0, 0.18, 5.0)
    player.head.rotation = Vector3.ZERO
    player.look_at(bus.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
    if not await _capture_frame(output, "M3_3_UTOWN_SHUTTLE.png"):
        push_error("Could not capture the shuttle showcase")
        quit(1)
        return
    count += 1

    # M3.4 visual QA: roof-shadowed, furnished indoor spaces and wet pavements.
    # Capture the project's real Godot viewport, never a generated concept image.
    hud.visible = false
    world.set_lighting_mode(0)
    weather.set_mode(0)
    var erc_room: Node3D = campus_life.interiors["ERC"]
    if not campus_life.enter_interior("ERC"):
        push_error("Could not enter ERC for M3.4 interior review")
        quit(1)
        return
    player.global_position = erc_room.to_global(Vector3(-2.8, 0.18, 5.5))
    player.rotation = Vector3(0.0, PI * 0.5, 0.0)
    player.head.rotation = Vector3.ZERO
    if not await _capture_frame(output, "M3_4_ERC_CAFE_CORNER.png"):
        push_error("Cannot capture new ERC cafe corner")
        quit(1)
        return
    count += 1
    hud.visible = true
    if not await _capture_frame(output, "M3_4_INDOOR_MAP_AND_ACTIVITY_HUD.png"):
        push_error("Cannot capture room-local activity minimap")
        quit(1)
        return
    count += 1
    hud.visible = false
    if not campus_life.toggle_interior_floor():
        push_error("Cannot access the ERC mezzanine")
        quit(1)
        return
    player.rotation = Vector3(0.0, PI, 0.0)
    player.head.rotation = Vector3(-0.1, 0.0, 0.0)
    if not await _capture_frame(output, "M3_4_ERC_MEZZANINE_ATRIUM.png"):
        push_error("Cannot capture ERC mezzanine atrium")
        quit(1)
        return
    count += 1
    campus_life.exit_interior()
    var src_room: Node3D = campus_life.interiors["SRC"]
    if not campus_life.enter_interior("SRC"):
        push_error("Could not enter SRC for M3.4 interior review")
        quit(1)
        return
    player.global_position = src_room.to_global(Vector3(-3.5, 0.18, -0.5))
    var src_aim: Vector3 = src_room.to_global(Vector3(-9.0, 0.18, -5.5))
    player.look_at(src_aim, Vector3.UP)
    player.head.rotation = Vector3.ZERO
    if not await _capture_frame(output, "M3_4_SRC_EQUIPMENT_AND_HALL.png"):
        push_error("Cannot capture new SRC activity corner")
        quit(1)
        return
    count += 1
    campus_life.exit_interior()

    if not review.select_view(3):
        push_error("Cannot select wet-weather overview")
        quit(1)
        return
    weather.set_mode(3)
    for wet_frame in range(85):
        await process_frame
    if not await _capture_frame(output, "M3_4_RAIN_DARKENED_WALKWAYS.png"):
        push_error("Cannot capture wet paving scene")
        quit(1)
        return
    count += 1
    # Move to the water itself; the distant facade camera cannot show puddle height.
    var water_at: Vector3 = weather.puddle_nodes[0].global_position
    player.global_position = water_at + Vector3(2.0, 0.035, 4.4)
    var aim_point := Vector3(water_at.x, player.global_position.y, water_at.z)
    player.look_at(aim_point, Vector3.UP)
    player.head.rotation = Vector3(-0.36, 0.0, 0.0)
    if not await _capture_frame(output, "M3_4_RAIN_PUDDLE_CLOSEUP.png"):
        push_error("Cannot capture above-paving puddle visual")
        quit(1)
        return
    count += 1
    weather.set_mode(0)
    for clearing_frame in range(18):
        await process_frame
    if not await _capture_frame(output, "M3_4_AFTER_RAIN_DRYING.png"):
        push_error("Cannot capture gradual rain-to-clear transition")
        quit(1)
        return
    count += 1

    # M3.5 architectural materials, adaptive interior lighting and lived-in rooms.
    var indoor_npcs: UTownIndoorNPCs = instance.get_node_or_null("IndoorNPCs") as UTownIndoorNPCs
    var polish: UTownVisualPolish = instance.get_node_or_null("VisualPolish") as UTownVisualPolish
    if indoor_npcs == null or polish == null or polish.facade_groups.size() != 2:
        push_error("M3.5 gameplay/finish systems are unavailable during screenshot review")
        quit(1)
        return
    hud.visible = false
    world.set_lighting_mode(0)
    weather.set_mode(0)
    if not campus_life.enter_interior("ERC"):
        push_error("M3.5 ERC study-lounge could not open")
        quit(1)
        return
    var erc_lounge: Node3D = campus_life.interiors["ERC"]
    player.global_position = erc_lounge.to_global(Vector3(-2.2, 0.18, 5.6))
    player.rotation = Vector3(0, PI * 0.5, 0)
    player.head.rotation = Vector3.ZERO
    for occupied_frame in range(16):
        await process_frame
    if not await _capture_frame(output, "M3_5_ERC_CAFE_OCCUPANTS.png"):
        push_error("Cannot capture populated ERC cafe")
        quit(1)
        return
    count += 1
    var barista: Node3D = indoor_npcs.actors[0]["node"]
    player.global_position = barista.global_position + Vector3(0.0, 0.18, -1.8)
    if not campus_life.talk_to_nearest():
        push_error("Cannot capture indoor NPC dialogue scenario")
        quit(1)
        return
    hud.visible = true
    if not await _capture_frame(output, "M3_5_ERC_DIALOGUE_HUD.png"):
        push_error("Cannot capture actual indoor NPC dialogue HUD")
        quit(1)
        return
    count += 1
    hud.visible = false
    world.set_lighting_mode(3)
    for light_frame in range(28):
        await process_frame
    player.global_position = erc_lounge.to_global(Vector3(-2.2, 0.18, 5.6))
    player.rotation = Vector3(0, PI * 0.5, 0)
    player.head.rotation = Vector3.ZERO
    if not await _capture_frame(output, "M3_5_ERC_EVENING_INTERIOR.png"):
        push_error("Cannot capture evening room with adaptive accent lighting")
        quit(1)
        return
    count += 1
    campus_life.exit_interior()
    world.set_lighting_mode(0)
    if not campus_life.enter_interior("SRC"):
        push_error("M3.5 SRC recreation hall could not open")
        quit(1)
        return
    var src_hall: Node3D = campus_life.interiors["SRC"]
    player.global_position = src_hall.to_global(Vector3(3.3, 0.18, 5.0))
    var athlete_position: Vector3 = src_hall.to_global(Vector3(1.2, 1.3, -2.2))
    player.look_at(athlete_position, Vector3.UP)
    player.head.rotation = Vector3.ZERO
    for athlete_frame in range(12):
        await process_frame
    if not await _capture_frame(output, "M3_5_SRC_ACTIVE_CHARACTERS.png"):
        push_error("Cannot capture active SRC indoor characters")
        quit(1)
        return
    count += 1
    campus_life.exit_interior()
    weather.set_mode(0)
    world.set_m2_details_visible(true)
    world.set_lighting_mode(0)
    if not review.select_view(2):
        push_error("Could not select ERC facade review")
        quit(1)
        return
    if not await _capture_frame(output, "M3_5_ERC_FACADE_FINISH_DAY.png"):
        push_error("Cannot capture facade material enhancements")
        quit(1)
        return
    count += 1
    world.set_lighting_mode(3)
    for evening_frame in range(40):
        await process_frame
    if not await _capture_frame(output, "M3_5_ERC_FACADE_FINISH_EVENING.png"):
        push_error("Cannot capture facade evening accent lighting")
        quit(1)
        return
    count += 1

    hud.visible = false
    world.set_osm_reference_visible(false)
    var report: FileAccess = FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
    if report == null:
        push_error("Cannot write preview manifest")
        quit(1)
        return
    report.store_string(JSON.stringify({
        "status": "software-rendered-provisional-scene-NOT-survey-or-photo-validated",
        "renderer": RenderingServer.get_current_rendering_driver_name(),
        "engine": str(Engine.get_version_info().get("string", "")),
        "viewpoints": review.viewpoints,
        "image_count": count,
        "m3_showcase": ["rain", "thunderstorm", "campus_npcs_hud", "erc_ground", "erc_mezzanine", "src_interior", "bicycle", "shuttle"],
        "m34_showcase": ["erc_cafe", "room_map", "erc_atrium", "src_equipment", "wet_walkways", "puddle_closeup", "rain_drying"],
        "m35_showcase": ["erc_cafe_occupants", "erc_dialogue", "erc_evening", "src_active_characters", "erc_facade_day", "erc_facade_evening"],
        "note": "Original Godot software renders, not real reference photos or surveyed geometry. No Windows GPU performance claim."
    }, "  ") + "\n")
    report.close()
    print("PASS: generated %d original Godot view comparison PNGs" % count)
    instance.queue_free()
    quit(0)

func _capture_frame(output: String, filename: String) -> bool:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        return false
    return frame.save_png(output.path_join(filename)) == OK
