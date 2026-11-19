extends SceneTree
## Run: godot --headless --path godot --script res://tests/kent_ridge_expansion_smoke_test.gd
## All bus travel is driven by direct method calls; no keyboard events are injected.

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("NUS-3D Kent Ridge expansion smoke failed: " + reason)
    paused = false
    quit(1)


func _run() -> void:
    var source: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if source == null:
        _fail("Unable to load base UTown scene")
        return
    var scene: Node3D = source.instantiate() as Node3D
    if scene == null:
        _fail("Unable to instantiate base UTown scene")
        return
    root.add_child(scene)
    await process_frame

    var world: UTownWorld = scene.get_node_or_null("World") as UTownWorld
    var extension: NUSKentRidgeWorld = scene.get_node_or_null("KentRidgeExpansion") as NUSKentRidgeWorld
    var bus: NUSCampusBusTravel = scene.get_node_or_null("CampusBusTravel") as NUSCampusBusTravel
    var player: UTownPlayer = scene.get_node_or_null("Player") as UTownPlayer
    var minimap: Control = scene.get_node_or_null("HUD/Minimap") as Control
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if world == null or extension == null or bus == null or player == null or minimap == null or hud == null:
        _fail("Existing world or new travel scene nodes are absent")
        return
    if extension.districts.size() != 11 or extension.stops.size() != 12:
        _fail("Expected 11 extended districts and 11 shuttle stop anchors")
        return
    if extension.shelter_count != 11 or extension.building_count < 24:
        _fail("Shelters and low-poly campus building geometry are missing")
        return
    if extension.bus_states.size() != 2:
        _fail("Visual D1/D2 route buses did not initialize")
        return
    for faculty_id in ["ENGINEERING", "CLB", "COM3", "BIZ2", "MUSEUM", "YIH", "UHC", "PGP", "KR_MRT"]:
        var amenity_root: Node3D = extension.get_node_or_null("KentRidgeDistricts_Schematic/%s/FacultyAmenities" % faculty_id) as Node3D
        if amenity_root == null or amenity_root.get_child_count() < 3:
            _fail("Missing distinct amenity zones in faculty district: " + faculty_id)
            return
    if extension.get_node_or_null("ScienceSportsGround/FootballGrass") == null or extension.get_node_or_null("ScienceSportsGround/TrackBed") == null:
        _fail("Science-side sports pitch and running track are missing")
        return
    if extension.get_node_or_null("FrontierCanteenTerrace/DiningTable") == null:
        _fail("Frontier Canteen tables are missing")
        return
    if extension.get_node_or_null("ScienceSportsGround/PracticeBall") == null:
        _fail("Science sports activity ball is missing")
        return
    var activities: NUSScienceCampusActivities = scene.get_node_or_null("ScienceCampusActivities") as NUSScienceCampusActivities
    if activities == null or activities.panel == null:
        _fail("Mouse-only Science activity UI is missing")
        return
    if extension.get_node_or_null("WoodedCampusBoundary") == null:
        _fail("Natural wooded campus boundary is missing")
        return
    if extension.get_node_or_null("CampusBaseTerrain_Estimated") == null:
        _fail("Large walkable campus terrain is missing")
        return
    if world.layout.get("buildings", []).size() != 9 or world.get_node_or_null("BuildingMassing_Estimated/ERC") == null:
        _fail("Original UTown geometry was overwritten")
        return
    for route in ["D1", "D2"]:
        if not extension.route_serves(route, "UTOWN") or not extension.route_serves(route, "COM3"):
            _fail("Both schematic game lines must include UTown and COM3 interchanges")
            return
    if not extension.route_serves("D1", "CLB") or not extension.route_serves("D2", "KR_MRT"):
        _fail("The two campus route branches are not connected")
        return
    if extension.route_serves("D1", "SCIENCE"):
        _fail("D1 must not claim to directly serve the D2 Science destination")
        return

    var utown_stop: Vector3 = extension.stop_position("UTOWN")
    var science_stop: Vector3 = extension.stop_position("SCIENCE")
    if utown_stop.distance_to(science_stop) < 300.0:
        _fail("Georeferenced expansion is not significantly larger than UTown")
        return
    player.global_position = utown_stop + Vector3(0, 0.18, 0)
    if str(extension.nearest_stop(player.global_position, 17.0).get("id", "")) != "UTOWN":
        _fail("Unable to find the UTown Town Plaza bus stop")
        return
    if bus.map_canvas == null or bus.route_list == null:
        _fail("Visual bus route atlas or destination buttons are missing")
        return

    bus._open_menu()
    if not bus.menu_open or not paused or not player.movement_locked or not bus.menu.visible:
        _fail("Opening a bus stop must pause original game and expose destination picker")
        return
    if bus.selected_route != "D1":
        _fail("UTown must offer default D1 boarding")
        return
    bus._select_route("D2")
    if bus.selected_route != "D2":
        _fail("UTown transfer stop should allow D2 boarding")
        return
    bus._ride_to("SCIENCE")
    if not bus.traveling or not bus.travel_cover.visible or bus.menu_open:
        _fail("Choosing Science must start the D2 express animation")
        return
    bus._process(4.0)
    if bus.traveling or paused or player.movement_locked or bus.travel_cover.visible:
        _fail("Finished bus transition did not restore normal player controls")
        return
    if player.global_position.distance_to(science_stop + Vector3(0, 0.18, 11)) > 0.02:
        _fail("Express shuttle did not reach the selected Science region")
        return
    if not bus.arrival_card.visible or not bus.arrival_label.text.contains("SCIENCE"):
        _fail("No visual feedback was shown after arriving")
        return

    minimap.set("map_focus", player.global_position)
    var on_map: Vector2 = minimap.call("_to_map", player.global_position)
    if on_map.distance_to(Vector2(111, 111)) > 0.05:
        _fail("Off-UTown minimap should center on the player rather than old UTown")
        return

    # A D1-only station cannot silently board D2 or jump to a D2-only target.
    var clb_stop: Vector3 = extension.stop_position("CLB")
    player.global_position = clb_stop + Vector3(0, 0.18, 0)
    bus._open_menu()
    if not bus.menu_open or bus.selected_route != "D1":
        _fail("Central Library should offer D1")
        return
    bus._select_route("D2")
    if bus.selected_route != "D1":
        _fail("Cannot change to an unavailable bus line at Central Library")
        return
    bus._ride_to("KR_MRT")
    if bus.traveling or bus.destination_id != "":
        _fail("A D1-only stop must reject a D2-only direct boarding")
        return
    bus._close_menu()
    if paused or player.movement_locked:
        _fail("Closing the route picker must restore gameplay and unpause")
        return

    hud.visible = false
    bus._process(0.4)
    if bus.offer.visible:
        _fail("F7 photo HUD mode should hide bus prompt")
        return
    hud.visible = true
    print("NUS3D_KENT_RIDGE_EXPANSION_SMOKE_OK")
    quit(0)
