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

    var minimap: UTownMinimap = instance.get_node_or_null("HUD/Minimap") as UTownMinimap
    if minimap == null or minimap.map_scale <= 0.0:
        push_error("full-extent schematic minimap failed to initialize")
        quit(1)
        return

    if minimap.osm_features.size() < 170 or minimap.osm_boundary.size() < 30:
        push_error("campus-filtered OSM reference geometry failed to load")
        quit(1)
        return
    if minimap.terrain_contours.size() != 5:
        push_error("five-metre terrain contour reference failed to load")
        quit(1)
        return
    var osm_buildings: int = 0
    var osm_paths: int = 0
    for feature in minimap.osm_features:
        if str(feature.get("feature_type", "")) == "building":
            osm_buildings += 1
        elif str(feature.get("feature_type", "")) == "path":
            osm_paths += 1
    if osm_buildings != 38 or osm_paths != 118:
        push_error("OSM feature counts do not match the versioned campus extract")
        quit(1)
        return
    var contour_heights: Array[int] = []
    for contour in minimap.terrain_contours:
        contour_heights.append(int(contour.get("height_m", 0)))
    contour_heights.sort()
    if contour_heights != [5, 10, 15, 20, 25]:
        push_error("terrain contour elevations are missing or incorrectly ordered")
        quit(1)
        return
    for coordinate in minimap.osm_boundary:
        var boundary_world: Vector3 = world.lonlat_to_world(float(coordinate[0]), float(coordinate[1]))
        var boundary_map: Vector2 = minimap.world_to_map(boundary_world)
        if boundary_map.x < 17.0 or boundary_map.x > 233.0 or boundary_map.y < 17.0 or boundary_map.y > 233.0:
            push_error("OSM campus boundary is clipped by the minimap")
            quit(1)
            return
    if minimap.show_osm_paths:
        push_error("OSM footpath network should default to a decluttered state")
        quit(1)
        return
    minimap.set_osm_reference_visible(false)
    minimap.set_osm_paths_visible(true)
    minimap.set_terrain_contours_visible(false)
    if minimap.show_osm_reference or not minimap.show_osm_paths or minimap.show_terrain_contours:
        push_error("OSM building, path and contour overlay toggles failed")
        quit(1)
        return
    minimap.set_osm_reference_visible(true)
    minimap.set_osm_paths_visible(false)
    minimap.set_terrain_contours_visible(true)
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
    if world.route_points.size() != 4 or world.generated_path_count < 8:
        push_error("the conceptual walkway loop was not constructed")
        quit(1)
        return
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

    for record in world.layout.get("buildings", []):
        for part in record.get("parts", []):
            var footprint: PackedVector2Array = minimap.building_footprint_points(record, part)
            if footprint.size() != 4:
                push_error("minimap footprint must contain four corners")
                quit(1)
                return
            for corner in footprint:
                var map_corner: Vector2 = minimap.world_to_map(Vector3(corner.x, 0.0, corner.y))
                if map_corner.x < 17.0 or map_corner.x > 233.0 or map_corner.y < 17.0 or map_corner.y > 233.0:
                    push_error("minimap clipped a building footprint: %s" % str(record.get("id", "")))
                    quit(1)
                    return
    var plaza_record: Dictionary = world.layout.get("plaza", {})
    var plaza_world: Vector3 = world.lonlat_to_world(float(plaza_record.get("lon", world.origin_lon)), float(plaza_record.get("lat", world.origin_lat)))
    if str(world.nearest_landmark(plaza_world).get("id", "")) != "TOWN_PLAZA":
        push_error("Town Plaza nearest-landmark identity failed")
        quit(1)
        return
    if str(world.nearest_landmark(erc).get("id", "")) != "ERC":
        push_error("ERC nearest-landmark identity failed")
        quit(1)
        return
    if str(world.m2_profiles.get("ERC", {}).get("hud_summary", "")).is_empty() or str(world.m2_profiles.get("SRC", {}).get("hud_summary", "")).is_empty():
        push_error("source-backed landmark summaries are missing")
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
