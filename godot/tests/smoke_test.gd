extends SceneTree
## Run via: godot --headless --path godot --script res://tests/smoke_test.gd

func _initialize() -> void:
    call_deferred("_smoke")

func _smoke() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        push_error("main scene failed to load")
        quit(1)
        return
    var instance: Node3D = scene.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    # Each CI process may inherit an anonymous Coursework save created by an
    # earlier integration test. Isolate BEFORE checking the first-run selector.
    var first_run_coursework: UTownCoursework = instance.get_node("Coursework") as UTownCoursework
    first_run_coursework.save_path = "user://nus3d_coursework_smoke_temp.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(first_run_coursework.save_path))
    first_run_coursework._load_progress()
    first_run_coursework._refresh_marker()
    var intro: UTownIntro = instance.get_node_or_null("Intro") as UTownIntro
    var opening_ui: UTownCourseworkUI = instance.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if intro == null or opening_ui == null or not intro.playing or intro.key_frames.size() != 6:
        push_error("M3.7 animated intro or first-run UI could not initialize")
        quit(1)
        return
    if not intro.cinematic_camera.current or not opening_ui.intro_blocked:
        push_error("The flyover did not take camera control or pause faculty selection")
        quit(1)
        return
    intro.seek_preview(7.8)
    if intro.current_beat != 2 or intro.cinematic_camera.global_position.length() < 1.0:
        push_error("Intro keyframe motion or third story beat did not work")
        quit(1)
        return
    intro.finish_intro()
    if intro.playing or not intro.opening_completed or intro.overlay.visible or not intro.player.camera.current:
        push_error("Intro did not restore the normal first-person camera")
        quit(1)
        return
    if opening_ui.intro_blocked or not opening_ui.modal_visible:
        push_error("The first-run faculty selector did not open after the flyover")
        quit(1)
        return
    if intro.skip_button == null or intro.progress == null or intro.progress.max_value != intro.DURATION_S:
        push_error("Intro skip/timeline controls were not constructed")
        quit(1)
        return
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var player: CharacterBody3D = instance.get_node_or_null("Player") as CharacterBody3D
    if world == null or player == null:
        push_error("required scene nodes absent")
        quit(1)
        return
    if world.layout.is_empty():
        push_error("failed to parse site metadata")
        quit(1)
        return
    var exported_test: Node = instance.get_node_or_null("ExportSelfTest")
    if exported_test == null or not exported_test.has_method("collect_issues"):
        push_error("M4 exported runtime test node is missing")
        quit(1)
        return
    var runtime_issues: Array = exported_test.call("collect_issues")
    if not runtime_issues.is_empty():
        push_error("Export runtime contract failed in editor smoke: " + str(runtime_issues))
        quit(1)
        return
    if world.generated_building_count < 8 or world.generated_tree_count < 20:
        push_error("missing procedural buildings or vegetation")
        quit(1)
        return
    if world.generated_facade_count != 2 or world.m2_detail_nodes.size() != 2:
        push_error("ERC and SRC both require a separate M2 architectural study layer")
        quit(1)
        return
    var erc_details: Node3D = world.get_node_or_null("BuildingMassing_Estimated/ERC/ArchitecturalStudy_NotSurveyed") as Node3D
    var src_details: Node3D = world.get_node_or_null("BuildingMassing_Estimated/SRC/ArchitecturalStudy_NotSurveyed") as Node3D
    if erc_details == null or src_details == null:
        push_error("missing ERC or SRC architectural layers")
        quit(1)
        return
    if erc_details.get_node_or_null("StudyWing_00/ERC_CurvedGlazing_Study") == null:
        push_error("ERC curved glass study was not created")
        quit(1)
        return
    if src_details.get_node_or_null("SRC_ForumDisc_Study/ElevatedMetalDisc_Estimated") == null:
        push_error("SRC forum disc study was not created")
        quit(1)
        return
    if src_details.get_node_or_null("SRC_StackedLink_Study") == null:
        push_error("SRC stacked circulation study was not created")
        quit(1)
        return
    world.set_m2_details_visible(false)
    if erc_details.visible or src_details.visible:
        push_error("F2 architectural comparison toggle does not hide detail layers")
        quit(1)
        return
    world.set_m2_details_visible(true)
    if not erc_details.visible or not src_details.visible:
        push_error("F2 architectural comparison toggle does not restore detail layers")
        quit(1)
        return
    var review: UTownViewReview = instance.get_node_or_null("ViewReview") as UTownViewReview
    if review == null or review.viewpoint_count() != 4:
        push_error("Photo/synthetic camera registry failed to load")
        quit(1)
        return
    if not review.select_view(0):
        push_error("ERC review view could not be selected")
        quit(1)
        return
    var observed: Dictionary = review.viewpoints[0]
    var expected_eye: Vector3 = world.lonlat_to_world(float(observed["lon"]), float(observed["lat"])) + Vector3(0.0, 0.18, 0.0)
    if player.global_position.distance_to(expected_eye) > 0.01:
        push_error("Camera geographic to local conversion failed")
        quit(1)
        return
    if absf(player.rotation.y + deg_to_rad(float(observed["heading_deg"]))) > 0.001:
        push_error("Compass heading is not converted to Godot negative Y yaw")
        quit(1)
        return
    review.current_index = review.viewpoint_count() - 1
    review.cycle_view()
    if review.current_index != -1 or player.global_position.distance_to(Vector3(0.0, 0.18, 0.0)) > 0.01:
        push_error("Free-roam reset after reviewing viewpoints failed")
        quit(1)
        return
    var osm: UTownOSMReference = world.get_node_or_null("OSMFootprints_ReferenceOnly") as UTownOSMReference
    if osm == null or osm.feature_count != 2 or osm.edge_count < 100:
        push_error("OSM ERC/SRC debug-only footprint geometry was not built")
        quit(1)
        return
    if world.osm_reference_visible or osm.visible:
        push_error("OSM outline should start invisible, not replace gameplay")
        quit(1)
        return
    var panel: PanelContainer = instance.get_node_or_null("HUD/GISCard") as PanelContainer
    var fit_text: Label = instance.get_node_or_null("HUD/GISCard/Summary") as Label
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    if panel == null or fit_text == null or hud == null:
        push_error("M2.3 GIS comparison card is missing from HUD")
        quit(1)
        return
    if not fit_text.text.contains("ERC") or not fit_text.text.contains("SRC"):
        push_error("GIS card did not populate source-derived building metrics")
        quit(1)
        return
    if panel.visible:
        push_error("GIS card must start hidden while OSM reference layer is off")
        quit(1)
        return
    world.set_osm_reference_visible(true)
    hud.call("_process", 0.0)
    if not panel.visible:
        push_error("GIS card did not appear with F6 OSM overlay")
        quit(1)
        return
    if not osm.visible or not world.osm_reference_visible:
        push_error("F6 reference outline visibility toggle failed")
        quit(1)
        return
    world.set_osm_reference_visible(false)
    hud.call("_process", 0.0)
    if panel.visible:
        push_error("GIS card remained on screen after OSM overlay hidden")
        quit(1)
        return
    if osm.visible:
        push_error("F6 reference outline does not hide")
        quit(1)
        return
    if world.generated_lamp_count < 2 or world.lamp_lights.size() != world.generated_lamp_count:
        push_error("missing the low-cost illustrative path lanterns")
        quit(1)
        return
    if not world.set_lighting_mode(3) or world.lighting_name() != "Evening":
        push_error("night scene lighting preset failed")
        quit(1)
        return
    for lamp in world.lamp_lights:
        if not lamp.visible or lamp.light_energy <= 0.0 or lamp.shadow_enabled:
            push_error("night lamps are not set to cheap, nonshadowed lighting")
            quit(1)
            return
    if not world.set_lighting_mode(0) or world.lighting_name() != "Daylight":
        push_error("lighting reset to default daytime failed")
        quit(1)
        return
    if world.set_lighting_mode(99):
        push_error("invalid lighting preset was accepted")
        quit(1)
        return
    if world.route_marker_root == null:
        push_error("Missing route marker visibility controller for clean photo mode")
        quit(1)
        return
    world.set_navigation_markers_visible(false)
    for label in world.navigation_labels:
        if label.visible:
            push_error("F7 clean photo mode did not hide world labels")
            quit(1)
            return
    if world.route_marker_root.visible:
        push_error("F7 clean photo mode did not hide route spheres")
        quit(1)
        return
    world.set_navigation_markers_visible(true)
    if world.route_marker_root.visible:
        push_error("Removed sky-high route labels reappeared after F7 photo mode")
        quit(1)
        return
    if world.route_points.size() != 4 or world.generated_path_count < 8:
        push_error("the conceptual walkway loop was not constructed")
        quit(1)
        return
    var tour: UTownTour = instance.get_node_or_null("Tour") as UTownTour
    var card: PanelContainer = instance.get_node_or_null("HUD/TourCard") as PanelContainer
    if tour == null or tour.stops.size() != 4 or card == null:
        push_error("four-stop discovery task or its story card is missing")
        quit(1)
        return
    if not tour.can_check_in():
        push_error("starting at Town Green should expose the first discovery stop")
        quit(1)
        return
    hud.call("_process", 0.0)
    if not card.visible or not tour.card_text().contains("Press E"):
        push_error("nearby checkpoint should display an interactive prompt")
        quit(1)
        return
    player.global_position = Vector3(200.0, 0.18, 200.0)
    if tour.can_check_in() or tour.try_check_in():
        push_error("discovery check-in must reject distant interaction")
        quit(1)
        return
    for stop_index in range(tour.stops.size()):
        var stop: Dictionary = tour.current_stop()
        if str(stop["id"]) != str(world.layout["loop"][stop_index]["id"]):
            push_error("tour stops must use the existing conceptual loop ordering")
            quit(1)
            return
        player.global_position = tour.stop_world_position(stop_index) + Vector3(0.0, 0.18, 0.0)
        if not tour.can_check_in() or not tour.try_check_in():
            push_error("nearby discovery did not advance at stop %d" % stop_index)
            quit(1)
            return
        if not tour.has_discovered(str(stop["id"])):
            push_error("unlocked checkpoint ID was not recorded")
            quit(1)
            return
        if tour.try_check_in():
            push_error("duplicate discovery interaction advanced without reaching a new stop")
            quit(1)
            return
    if not tour.completed or tour.discovered_ids.size() != 4 or not tour.card_text().contains("EXPLORER COMPLETE"):
        push_error("four discoveries must unlock completion and the original Explorer card")
        quit(1)
        return
    tour.restart()
    if tour.completed or tour.discovered_ids.size() != 0 or tour.current_index != 0:
        push_error("replaying the exploration did not reset mission state")
        quit(1)
        return
    player.call("reset_player")
    var challenge: UTownChallenge = instance.get_node_or_null("Challenge") as UTownChallenge
    if challenge == null or challenge.items.size() != 8 or challenge.item_markers.size() != 8:
        push_error("eight collectible Field Notes or their visual markers are missing")
        quit(1)
        return
    if challenge.sprint_route.size() != 5:
        push_error("Campus Sprint must resolve the four existing stops and return to Town Green")
        quit(1)
        return
    # Use an isolated per-run save file so local smoke tests never overwrite player progress.
    challenge.save_path = "user://nus3d-smoke-%d.cfg" % Time.get_ticks_msec()
    challenge.load_progress()
    var first_item_id: String = challenge.item_id(0)
    player.global_position = challenge.item_world_position(0) + Vector3(0.0, 0.18, 0.0)
    if not challenge.can_collect_nearest() or not challenge.try_collect_nearest():
        push_error("nearby Field Note could not be collected with the C interaction")
        quit(1)
        return
    if not challenge.is_item_collected(first_item_id) or challenge.try_collect_nearest():
        push_error("collected Field Note was not hidden or could be collected twice")
        quit(1)
        return
    var progress_file: ConfigFile = ConfigFile.new()
    if progress_file.load(challenge.save_path) != OK:
        push_error("Field Note progress was not written to the local save file")
        quit(1)
        return
    var saved_ids: Variant = progress_file.get_value("progress", "collected_ids", [])
    if typeof(saved_ids) != TYPE_PACKED_STRING_ARRAY or not saved_ids.has(first_item_id):
        push_error("local save did not preserve the collected Field Note ID")
        quit(1)
        return
    challenge.load_progress()
    if not challenge.is_item_collected(first_item_id) or challenge.item_markers[0].visible:
        push_error("reloading local progress did not restore the collected Field Note")
        quit(1)
        return
    player.global_position = Vector3(200.0, 0.18, 200.0)
    if challenge.start_sprint():
        push_error("Campus Sprint must only start near the Town Green start point")
        quit(1)
        return
    player.global_position = challenge.sprint_route[0] + Vector3(0.0, 0.18, 0.0)
    if not challenge.start_sprint() or not challenge.sprint_active:
        push_error("Campus Sprint did not start from Town Green")
        quit(1)
        return
    for route_index in range(1, challenge.sprint_route.size()):
        player.global_position = challenge.sprint_route[route_index] + Vector3(0.0, 0.18, 0.0)
        challenge.call("_process", 0.1)
    if challenge.sprint_active or challenge.sprint_last_time < 0.0 or challenge.sprint_medal != "GOLD":
        push_error("Campus Sprint did not complete the ordered loop or award its expected test medal")
        quit(1)
        return
    if challenge.sprint_best_time < 0.0:
        push_error("Campus Sprint personal best was not recorded")
        quit(1)
        return
    challenge.load_progress()
    if challenge.sprint_best_time < 0.0 or not challenge.is_item_collected(first_item_id):
        push_error("local save did not restore both challenge progress and sprint best time")
        quit(1)
        return
    challenge.set_markers_visible(false)
    for marker in challenge.item_markers:
        if marker.visible:
            push_error("photo mode did not hide Field Note markers")
            quit(1)
            return
    challenge.set_markers_visible(true)
    if challenge.item_markers[0].visible:
        push_error("photo mode restored an already-collected Field Note")
        quit(1)
        return
    player.call("reset_player")
    var weather: UTownWeather = instance.get_node_or_null("Weather") as UTownWeather
    var campus_life: UTownCampusLife = instance.get_node_or_null("CampusLife") as UTownCampusLife
    if weather == null or weather.mode_count() != 5:
        push_error("five-mode weather controller is missing")
        quit(1)
        return
    if world.weather_reactive_materials.size() != 2 or world.weather_reactive_grass.size() != 2:
        push_error("paving and original vegetation materials are not weather-responsive")
        quit(1)
        return
    var path_material: StandardMaterial3D = world.weather_reactive_materials[1]
    var dry_roughness: float = path_material.roughness
    if weather.puddle_nodes.size() < 8 or weather.rain_streaks == null or weather.rain_multimesh.instance_count != 220:
        push_error("weather puddles or the deterministic rain-streak MultiMesh were not generated")
        quit(1)
        return
    if not weather.set_mode(3) or not weather.rain.emitting or not weather.puddle_root.visible:
        push_error("rain weather did not activate rain particles and wet-ground puddles")
        quit(1)
        return
    weather._process(1.0)
    if weather.wetness < 0.5 or path_material.roughness >= dry_roughness or weather.target_fog <= 0.0:
        push_error("rain did not wet shared pavement materials or target storm fog")
        quit(1)
        return
    if not weather.set_mode(4):
        push_error("thunderstorm weather preset could not be selected")
        quit(1)
        return
    if not weather.set_mode(0) or weather.rain.emitting:
        push_error("clear weather did not stop rain")
        quit(1)
        return
    if not weather.puddle_root.visible:
        push_error("puddles should persist briefly after rain stops")
        quit(1)
        return
    weather._process(6.0)
    if weather.wetness > 0.01 or weather.puddle_root.visible or not is_equal_approx(path_material.roughness, dry_roughness):
        push_error("wet surfaces did not dry and restore original materials")
        quit(1)
        return
    if campus_life == null or campus_life.pedestrians.size() != 6:
        push_error("six procedural campus pedestrians did not spawn")
        quit(1)
        return
    var first_npc: Node3D = campus_life.pedestrians[0]["node"]
    if first_npc.get_node_or_null("LeftArmPivot") == null or first_npc.get_node_or_null("RightLegPivot") == null:
        push_error("pedestrian limb pivots for procedural walk animation are missing")
        quit(1)
        return
        quit(1)
        return
    if campus_life.interiors.size() != 2 or campus_life.shuttle == null:
        push_error("ERC/SRC interior concepts or campus shuttle did not load")
        quit(1)
        return
    for interior_id in ["ERC", "SRC"]:
        var room: Node3D = campus_life.interiors[interior_id]
        if room.get_node_or_null("InteriorFinishM34/OpaqueRoofShadow") == null:
            push_error("interior roof and daylight shelter missing from " + interior_id)
            quit(1)
            return
        if room.get_node_or_null("WalkableStairSlope") == null:
            push_error("continuous, walkable mezzanine stair collider missing from " + interior_id)
            quit(1)
            return
        if not campus_life.activity_spots.has(interior_id) or campus_life.activity_spots[interior_id].size() != 3:
            push_error("three visitable indoor activity areas missing from " + interior_id)
            quit(1)
            return
    if campus_life.bicycle_wheels.size() != 2 or campus_life.bicycle_handlebar == null or campus_life.bicycle_crank == null or campus_life.bicycle.get_node_or_null("RiderTorso") == null or campus_life.bicycle.get_node_or_null("RiderHead") == null:
        push_error("bicycle wheels, steering, pedals or rider model are missing")
        quit(1)
        return
    if campus_life.shuttle_wheels.size() != 4 or campus_life.shuttle_passengers.size() != 3:
        push_error("shuttle wheel animation or passenger silhouettes are missing")
        quit(1)
        return
        quit(1)
        return
    var exterior_before: Vector3 = player.global_position
    if not campus_life.enter_interior("ERC") or not campus_life.interior_active or not weather.indoor:
        push_error("ERC illustrative interior could not be entered")
        quit(1)
        return
    if player.global_position.x < 800.0:
        push_error("interior pocket was not isolated from the outdoor proxy")
        quit(1)
        return
    var cafe: Dictionary = campus_life.activity_spots["ERC"][0]
    var erc_room: Node3D = campus_life.interiors["ERC"]
    player.global_position = erc_room.to_global(cafe["position"])
    if not campus_life.interact_nearby() or not campus_life.visited_activities.has("ERC/cafe"):
        push_error("ERC indoor activity discovery did not work")
        quit(1)
        return
    if not campus_life.toggle_interior_floor() or campus_life.interior_floor != 1 or player.global_position.y < 3.0:
        push_error("ERC mezzanine lift did not move the player to the upper floor")
        quit(1)
        return
    if not campus_life.toggle_interior_floor() or campus_life.interior_floor != 0 or player.global_position.y > 1.0:
        push_error("ERC mezzanine lift did not return the player to the ground floor")
        quit(1)
        return
    campus_life.exit_interior()
    if campus_life.interior_active or weather.indoor or player.global_position.distance_to(exterior_before) > 0.01:
        push_error("interior exit did not restore the player's outdoor position")
        quit(1)
        return
    if not campus_life.set_bicycle(true) or not player.bicycle_mode or not campus_life.bicycle.visible:
        push_error("bicycle mode did not enable player speed and bicycle visual")
        quit(1)
        return
    if not is_equal_approx(player.camera_target_fov, 84.0):
        push_error("bicycle camera did not switch to the smooth follow-view target")
        quit(1)
        return
    if not campus_life.set_bicycle(false) or player.bicycle_mode or campus_life.bicycle.visible:
        push_error("bicycle mode did not return to walking")
        quit(1)
        return
    var npc_node: Node3D = campus_life.pedestrians[0]["node"]
    player.global_position = npc_node.global_position
    if not campus_life.talk_to_nearest() or campus_life.message.is_empty():
        push_error("nearby campus NPC dialogue did not respond")
        quit(1)
        return
    player.global_position = campus_life.shuttle.global_position
    if not campus_life.board_or_alight() or not campus_life.on_shuttle or not player.movement_locked:
        push_error("player could not board the nearby shuttle")
        quit(1)
        return
    campus_life.alight_shuttle()
    if campus_life.on_shuttle or player.movement_locked:
        push_error("player could not leave the shuttle")
        quit(1)
        return
    if not campus_life.enter_interior("SRC"):
        push_error("SRC interior failed during reset-state regression")
        quit(1)
        return
    player.call("reset_player")
    if campus_life.interior_active or weather.indoor:
        push_error("reset left the room or indoor-weather flag active")
        quit(1)
        return
    campus_life.set_bicycle(true)
    player.call("reset_player")
    if campus_life.bicycle_enabled or player.bicycle_mode:
        push_error("reset did not clean up bicycle mode")
        quit(1)
        return
    var indoor_npcs: UTownIndoorNPCs = instance.get_node_or_null("IndoorNPCs") as UTownIndoorNPCs
    var polish: UTownVisualPolish = instance.get_node_or_null("VisualPolish") as UTownVisualPolish
    if indoor_npcs == null or indoor_npcs.indoor_count != 6 or indoor_npcs.actors.size() != 6:
        push_error("six fictional room-life NPCs did not spawn")
        quit(1)
        return
    if polish == null or polish.facade_groups.size() != 2 or polish.facade_panes < 40:
        push_error("ERC and SRC material-detail facades were not generated")
        quit(1)
        return
    if polish.indoor_finish_groups.size() != 2 or polish.material_panel_count < 100:
        push_error("two room material finishes and floor-wall cladding are missing")
        quit(1)
        return
    if polish.indoor_lamps.size() != 2 or polish.facade_lamps.size() != 2:
        push_error("responsive indoor/exterior accent lighting registry incomplete")
        quit(1)
        return
    if not campus_life.enter_interior("ERC"):
        push_error("ERC NPC smoke scenario could not enter the study room")
        quit(1)
        return
    indoor_npcs._process(0.016)
    if indoor_npcs.active_count() != 3:
        push_error("three active ERC room NPCs were not visible")
        quit(1)
        return
    var indoor_guest: Node3D = indoor_npcs.actors[0]["node"]
    if not indoor_guest.visible:
        push_error("active room actor was not rendered")
        quit(1)
        return
    var erc_room_lights: Array = polish.indoor_lamps["ERC"]
    var src_room_lights: Array = polish.indoor_lamps["SRC"]
    polish._process(0.25)
    if not erc_room_lights[0].visible or src_room_lights[0].visible:
        push_error("adaptive light fixtures did not isolate the active room")
        quit(1)
        return
    var daytime_energy: float = erc_room_lights[0].light_energy
    world.set_lighting_mode(3)
    polish._process(1.0)
    if erc_room_lights[0].light_energy <= daytime_energy:
        push_error("interior accents did not brighten in artistic evening mode")
        quit(1)
        return
    world.set_lighting_mode(0)
    player.global_position = indoor_guest.global_position + Vector3(0.0, 0.18, 1.6)
    if not campus_life.talk_to_nearest() or indoor_npcs.last_spoken.is_empty():
        push_error("Q did not redirect dialogue to indoor room NPC")
        quit(1)
        return
    campus_life.exit_interior()
    indoor_npcs._process(0.016)
    if indoor_npcs.active_count() != 0 or indoor_guest.visible:
        push_error("room NPCs remained active after the player exited")
        quit(1)
        return
    polish._process(0.25)
    if polish.facade_lamps[0].light_energy < 0.0:
        push_error("building entrance accent lighting became invalid")
        quit(1)
        return
    player.call("reset_player")
    # M3.6 must not overwrite the user's actual local progress during smoke tests.
    var coursework: UTownCoursework = instance.get_node_or_null("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = instance.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if coursework == null or course_ui == null:
        push_error("Coursework faculty controller or selection UI missing")
        quit(1)
        return
    if coursework.faculty_options.size() != 13 or course_ui.faculty_picker.item_count != 13:
        push_error("Thirteen fictional campus faculty choices were not loaded")
        quit(1)
        return
    if coursework.current_quest().size() > 0 and coursework.current_faculty_id.is_empty():
        push_error("Mission started before faculty selection")
        quit(1)
        return
    coursework.save_path = "user://nus3d_coursework_smoke_temp.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(coursework.save_path))
    coursework._load_progress()
    course_ui.show_selector()
    if not course_ui.modal_visible or not coursework.modal_open or not player.movement_locked:
        push_error("Faculty picker did not capture input and freeze walking")
        quit(1)
        return
    course_ui._confirm_faculty()
    if coursework.current_faculty_id != "science" or coursework.active_stage != 0 or course_ui.modal_visible or player.movement_locked:
        push_error("Science faculty selection did not start a clean playable profile")
        quit(1)
        return
    var other_choice: bool = coursework.select_faculty("nonexistent")
    if other_choice:
        push_error("An invalid faculty selection was accepted")
        quit(1)
        return
    if coursework.current_quest().is_empty() or coursework.marker == null or coursework.total_xp != 0:
        push_error("First fictional coursework mission/marker did not initialize")
        quit(1)
        return
    player.global_position = coursework.objective_position() + Vector3(65.0, 0.18, 0.0)
    if coursework.interact_nearby() or coursework.active_stage != 0:
        push_error("Coursework brief could be taken outside the proximity radius")
        quit(1)
        return
    player.global_position = coursework.objective_position() + Vector3(0.0, 0.18, 0.0)
    if not coursework.interact_nearby() or coursework.active_stage != 1 or coursework.current_time_left < 150.0:
        push_error("Coursework brief pickup or DDL start failed")
        quit(1)
        return
    var before_pause: float = coursework.current_time_left
    course_ui.show_journal()
    coursework._process(0.9)
    if not coursework.modal_open or coursework.current_time_left < before_pause - 0.001:
        push_error("DDL countdown did not pause during the journal")
        quit(1)
        return
    course_ui.hide_modal()
    coursework._process(1.0)
    if coursework.current_time_left >= before_pause:
        push_error("DDL countdown failed to resume during actual play")
        quit(1)
        return
    if not campus_life.enter_interior("ERC"):
        push_error("ERC indoor coursework objective unavailable")
        quit(1)
        return
    var science_activity: Dictionary = campus_life.activity_spots["ERC"][1]
    player.global_position = (campus_life.interiors["ERC"] as Node3D).to_global(science_activity["position"])
    if not campus_life.interact_nearby() or coursework.active_stage != 2:
        push_error("Real ERC activity interaction did not advance the coursework mission")
        quit(1)
        return
    var partner_npc: Node3D = indoor_npcs.actors[1]["node"]
    player.global_position = partner_npc.global_position + Vector3(0.0, 0.18, 1.0)
    if not campus_life.talk_to_nearest() or coursework.active_stage != 3:
        push_error("Actual indoor Q dialogue did not advance the coursework partner step")
        quit(1)
        return
    campus_life.exit_interior()
    player.global_position = coursework.objective_position() + Vector3(0.0, 0.18, 0.0)
    if not coursework.interact_nearby() or coursework.active_quest_index != 1 or coursework.total_xp <= 0 or coursework.credits <= 0:
        push_error("Coursework submission did not reward XP/credits and unlock chapter two")
        quit(1)
        return
    var xp_after_science: int = coursework.total_xp
    if not coursework.select_faculty("computing") or coursework.active_quest_index != 0:
        push_error("Switching to a different faculty did not load its own questline")
        quit(1)
        return
    player.global_position = coursework.objective_position() + Vector3(0.0, 0.18, 0.0)
    if not coursework.interact_nearby():
        push_error("Second faculty brief could not start")
        quit(1)
        return
    coursework.current_time_left = 0.0
    if not coursework.notify_activity("ERC/mezzanine") or not coursework.notify_dialogue("ERC/Mei"):
        push_error("Computer Science mission's activity and partner chain did not advance")
        quit(1)
        return
    player.global_position = coursework.objective_position() + Vector3(0.0, 0.18, 0.0)
    if not coursework.interact_nearby() or coursework.last_grade != "C (Late)" or coursework.total_xp <= xp_after_science:
        push_error("Late coursework submission must still complete with reduced reward")
        quit(1)
        return
    var after_both: int = coursework.total_xp
    coursework._load_progress()
    if coursework.current_faculty_id != "computing" or coursework.active_quest_index != 1 or coursework.total_xp != after_both:
        push_error("Saved coursework faculty, XP or completion progress did not survive reload")
        quit(1)
        return
    if not coursework.select_faculty("science") or coursework.active_quest_index != 1 or coursework.total_xp != after_both:
        push_error("Per-faculty quest progress was lost on switching back")
        quit(1)
        return
    player.call("reset_player")
    # M3.8 checks run with isolated leisure and Coursework saves, never the user's progress.
    var leisure: UTownLeisure = instance.get_node_or_null("Leisure") as UTownLeisure
    var leisure_ui: UTownLeisureUI = instance.get_node_or_null("LeisureUI") as UTownLeisureUI
    if leisure == null or leisure_ui == null or leisure.chess_board.size() != 81 or leisure_ui.cells.size() != 81:
        push_error("Post-course games or the 9x9 chess board could not initialize")
        quit(1)
        return
    leisure.save_path = "user://nus3d_leisure_smoke_temp.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(leisure.save_path))
    leisure.chess_wins = 0
    leisure.chess_games = 0
    leisure.card_wins = 0
    leisure.card_games = 0
    leisure.social_visits = 0
    if leisure.unlocked() or leisure_ui.open_lounge():
        push_error("Leisure must remain locked until 3 faculty coursework chapters complete")
        quit(1)
        return
    coursework.active_quest_index = 3
    coursework._store_active_state()
    if not leisure.unlocked() or leisure.grand_master_unlocked():
        push_error("Passing one faculty did not unlock leisure, or awarded 39-chapter bonus too soon")
        quit(1)
        return
    if leisure.lounge_root == null or leisure.lounge_root.name != "PostCourseClub_Illustrative":
        push_error("The SRC post-course club was not built")
        quit(1)
        return
    if leisure.seat_actors.size() != 3 or leisure.station_highlights.size() != 3 or leisure.stone_models == null:
        push_error("Three seated opponents, walk-up interaction halos or live chess scene are missing")
        quit(1)
        return
    if leisure_ui.sound == null or leisure_ui.sound.players.size() != 7 or leisure_ui.fx_sparkles.size() != 19:
        push_error("Six original procedural sounds and local win celebration UI must load")
        quit(1)
        return
    var cheer_stream: AudioStreamWAV = leisure_ui.sound.players["cheer"].stream
    if cheer_stream == null or cheer_stream.data.size() < 1000:
        push_error("Original game-win sound has no generated PCM data")
        quit(1)
        return
    leisure_ui._toggle_sound()
    if leisure_ui.sound.enabled:
        push_error("Accessibility toggle did not mute post-course SFX")
        quit(1)
        return
    leisure_ui._toggle_sound()
    if not leisure_ui.sound.enabled:
        push_error("Post-course SFX could not be re-enabled")
        quit(1)
        return
    if leisure_ui.open_lounge():
        push_error("Unlocked club should require physically walking into SRC")
        quit(1)
        return
    if campus_life.interior_active:
        campus_life.exit_interior()
    if not campus_life.enter_interior("SRC"):
        push_error("Could not enter SRC to approach physical club stations")
        quit(1)
        return
    player.global_position = leisure.station_global_position("chess")
    campus_life.interior_floor = 1
    if not leisure.nearest_station().is_empty():
        push_error("Leisure interaction should be unavailable on the mezzanine")
        quit(1)
        return
    campus_life.interior_floor = 0
    var press_p := InputEventKey.new()
    press_p.keycode = KEY_P
    press_p.pressed = true
    leisure_ui._input(press_p)
    if leisure.nearest_station() != "chess" or not leisure_ui.is_open or leisure_ui.active_tab != "chess":
        push_error("P-key near the Gomoku table did not open the matching game")
        quit(1)
        return
    if not coursework.modal_open or not player.movement_locked:
        push_error("Opening the club did not pause first-person movement")
        quit(1)
        return
    leisure_ui.switch_tab("cards")
    if leisure_ui.active_tab != "chess" or not leisure_ui.tab_cards.disabled:
        push_error("A player can change to a distant table without walking over")
        quit(1)
        return
    leisure_ui.close_lounge()
    if leisure_ui.is_open or coursework.modal_open or player.movement_locked:
        push_error("Closing the club did not restore first-person controls")
        quit(1)
        return
    player.global_position = leisure.station_global_position("cards")
    if leisure.nearest_station() != "cards" or not leisure_ui.open_lounge() or leisure_ui.active_tab != "cards":
        push_error("Approaching the card table did not select card gameplay")
        quit(1)
        return
    leisure_ui.close_lounge()
    player.global_position = leisure.station_global_position("social")
    if leisure.nearest_station() != "social" or not leisure_ui.open_lounge() or leisure_ui.active_tab != "social":
        push_error("Approaching the social counter did not select the party scene")
        quit(1)
        return
    leisure_ui.close_lounge()
    leisure.reset_chess()
    for col in range(4):
        leisure.chess_board[col] = 1
        leisure.chess_moves += 1
    if not leisure.play_chess(4, 0) or not leisure.chess_over or leisure.chess_winner != 1 or leisure.chess_wins != 1:
        push_error("Human five-in-a-row victory did not score correctly")
        quit(1)
        return
    if leisure.stone_models.get_child_count() != 5 or leisure.reaction_left <= 0.0:
        push_error("Completed board was not represented by five live 3D stones or a seated-NPC reaction")
        quit(1)
        return
    leisure.reset_chess()
    for col in range(4):
        leisure.chess_board[2 * 9 + col] = 2
    if leisure._ai_move() != Vector2i(4, 2):
        push_error("Gomoku NPC does not recognize an immediate winning move")
        quit(1)
        return
    leisure.start_cards()
    for card_round in range(5):
        if not leisure.play_card(0):
            push_error("Valid card selection did not complete a round")
            quit(1)
            return
    if not leisure.card_over or leisure.card_games != 1 or leisure.card_round != 5 or leisure.play_card(0):
        push_error("Five-round card game end state is incorrect")
        quit(1)
        return
    if leisure.celebrate("adult") or not leisure.celebrate("mocktail") or not leisure.safe_to_ride():
        push_error("Optional adult toast not gated, or alcohol-free drink restricted travel")
        quit(1)
        return
    if not leisure.celebrate("adult", true) or leisure.safe_to_ride():
        push_error("Adult social option did not begin temporary no-travel cooldown")
        quit(1)
        return
    # Leaving the interior is necessary to reach the vehicle-specific guard:
    # the ordinary campus code rejects vehicle controls indoors first.
    campus_life.exit_interior()
    if campus_life.set_bicycle(true) or campus_life.board_or_alight():
        push_error("Post-toast bike/bus safety rule was bypassed")
        quit(1)
        return
    if not campus_life.message.contains("cooldown"):
        push_error("Alcohol-choice travel guard did not explain its decision")
        quit(1)
        return
    leisure._process(leisure.SOCIAL_COOLDOWN + 0.1)
    if not leisure.safe_to_ride() or not campus_life.set_bicycle(true):
        push_error("Post-toast temporary travel restriction failed to clear")
        quit(1)
        return
    campus_life.set_bicycle(false)
    # An original, replayable hidden story appears after repeat game victories.
    if leisure.secret_unlocked():
        push_error("A hidden ending was unlocked without sufficient wins")
        quit(1)
        return
    leisure.chess_wins = 2
    leisure.card_wins = 1
    if not leisure.secret_unlocked() or not leisure.reveal_secret().contains("SRC"):
        push_error("The cross-minigame epilogue did not unlock at 2 chess/1 card win and a visit")
        quit(1)
        return
    if not leisure.ending_seen or leisure.ending_line_index != 1:
        push_error("The first secret story scene did not persist its chapter")
        quit(1)
        return
    leisure.ending_seen = false
    leisure.ending_line_index = 0
    leisure._load_stats()
    if not leisure.ending_seen or leisure.ending_line_index != 1:
        push_error("Secret ending progress was not restored from a local save")
        quit(1)
        return
    if not coursework.select_faculty("computing") or not leisure.unlocked():
        push_error("Earned leisure access was lost after switching faculty")
        quit(1)
        return
    if leisure.social_visits != 2 or leisure.chess_games != 1 or leisure.card_games != 1:
        push_error("Leisure replay and visit stats are incorrect")
        quit(1)
        return
    leisure.chess_wins = 0
    leisure.chess_games = 0
    leisure.card_games = 0
    leisure.social_visits = 0
    leisure._load_stats()
    if leisure.chess_wins != 2 or leisure.chess_games != 1 or leisure.card_wins != 1 or leisure.card_games != 1 or leisure.social_visits != 2:
        push_error("Leisure and hidden story progress did not persist in the isolated save")
        quit(1)
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(leisure.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(coursework.save_path))
    var trunks: MultiMeshInstance3D = world.get_node_or_null("Vegetation_Procedural/TreeTrunks_MultiMesh") as MultiMeshInstance3D
    var canopies: MultiMeshInstance3D = world.get_node_or_null("Vegetation_Procedural/TreeCanopies_MultiMesh") as MultiMeshInstance3D
    if trunks == null or canopies == null or trunks.multimesh == null or canopies.multimesh == null:
        push_error("the two vegetation MultiMesh batches are missing")
        quit(1)
        return
    if trunks.multimesh.instance_count != world.generated_tree_count or canopies.multimesh.instance_count != world.generated_tree_count:
        push_error("vegetation batch instance counts do not match the generated tree count")
        quit(1)
        return
    if world.generated_tree_positions.size() != world.generated_tree_count:
        push_error("generated tree position registry is incomplete")
        quit(1)
        return
    # Headless CI validates source positions and batch counts; visual transform/culling checks require a GUI run.
    for i in range(world.generated_tree_positions.size()):
        var expected: Vector3 = world.generated_tree_positions[i]
        if not world.is_tree_position_clear(Vector2(expected.x, expected.z)):
            push_error("generated tree %d failed clearance at x=%.2f z=%.2f" % [i, expected.x, expected.z])
            quit(1)
            return
    var erc: Vector3 = world.lonlat_to_world(103.77291, 1.30598)
    var src: Vector3 = world.lonlat_to_world(103.77252, 1.30462)
    if not (erc.x < 0.0 and erc.z < 0.0 and src.x < 0.0 and src.z > 0.0):
        push_error("east/north orientation is inconsistent")
        quit(1)
        return
    var data: Dictionary = world.layout.get("spatial_reference", {})
    if str(data.get("precision", "")).find("NOT survey") < 0:
        push_error("the provisional geography must remain clearly labelled")
        quit(1)
        return
    print("PASS: scene, %d buildings, %d M2 facades, %d trees in 2 MultiMesh batches, %d paths, axes and provenance." % [world.generated_building_count, world.generated_facade_count, world.generated_tree_count, world.generated_path_count])
    instance.queue_free()
    quit(0)
