extends SceneTree
## Render proxy versus OSM-footprint shell views. Not survey validation.

func _initialize() -> void:
    call_deferred("_render")

func _capture_pair(world: UTownWorld, camera: Camera3D, output: String,
        viewpoint_id: String, captures: Array[String]) -> bool:
    for shell_mode in [false, true]:
        world.set_osm_shells_visible(shell_mode)
        for _frame in range(3):
            await process_frame
        await RenderingServer.frame_post_draw
        var frame: Image = root.get_texture().get_image()
        if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
            push_error("OSM shell review did not produce a valid viewport image")
            return false
        var mode: String = "OSM_SHELL" if shell_mode else "PROXY"
        var filename: String = "%s_%s.png" % [viewpoint_id, mode]
        if frame.save_png(output.path_join(filename)) != OK:
            push_error("Could not save OSM shell review image: " + filename)
            return false
        captures.append(filename)
    return true

func _position_isometric_camera(camera: Camera3D, shell: MeshInstance3D) -> void:
    var bounds: AABB = shell.mesh.get_aabb()
    var span: float = maxf(bounds.size.x, bounds.size.z)
    var centre: Vector3 = shell.global_position
    camera.top_level = true
    camera.fov = 65.0
    camera.near = 0.1
    camera.far = 1000.0
    camera.global_position = centre + Vector3(span * 0.95, span * 0.55, span * 0.95)
    camera.look_at(centre + Vector3(0.0, bounds.size.y * 0.35, 0.0), Vector3.UP)

func _render() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("Could not load main scene for OSM shell review")
        quit(1)
        return
    var instance: Node3D = packed.instantiate() as Node3D
    root.add_child(instance)
    await process_frame

    var review: UTownViewReview = instance.get_node_or_null("ViewReview") as UTownViewReview
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    var camera: Camera3D = instance.get_node_or_null("Player/Head/Camera3D") as Camera3D
    if review == null or world == null or hud == null or camera == null or world.osm_shell_count != 2:
        push_error("OSM shell review scene did not initialize")
        quit(1)
        return
    if DisplayServer.get_name() == "headless":
        push_error("X11 display required for OSM shell screenshots")
        quit(1)
        return

    hud.visible = false
    camera.top_level = false
    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        push_error("Could not create OSM shell review output folder")
        quit(1)
        return

    var captures: Array[String] = []
    # The 2026 ERC south-approach camera is outside the OSM outline and provides
    # the closest available source-backed exterior comparison.
    if not review.select_view(2):
        push_error("Could not select the ERC 2026 review camera")
        quit(1)
        return
    if not await _capture_pair(world, camera, output, "ERC_2026_GREEN", captures):
        quit(1)
        return

    # Use a reproducible elevated isometric view for each source footprint.
    # The historical ERC 2014 geotag falls about 1.1 m inside the OSM polygon;
    # the SRC proxy camera is only about 15 m from its OSM outline, so neither
    # is used as the sole shell overview.
    for building_id in ["ERC", "SRC"]:
        var shell: MeshInstance3D = world.get_node_or_null(
            "OSMBuildingShells_Estimated/" + building_id + "_OSMFootprintShell_NotSurveyed"
        ) as MeshInstance3D
        if shell == null:
            push_error("Missing OSM shell for isometric review: " + building_id)
            quit(1)
            return
        _position_isometric_camera(camera, shell)
        if not await _capture_pair(world, camera, output, building_id + "_OSM_ISOMETRIC", captures):
            quit(1)
            return

    camera.top_level = false
    world.set_osm_shells_visible(false)
    var manifest: Dictionary = {
        "status": "software_rendered_proxy_vs_osm_shell_review_not_survey_validation",
        "engine": str(Engine.get_version_info().get("string", "")),
        "renderer": RenderingServer.get_current_rendering_driver_name(),
        "osm_shell_count": world.osm_shell_count,
        "osm_way_ids": world.osm_shell_way_ids,
        "height_estimates_m": {"ERC": 13.8, "SRC": 14.6},
        "viewpoint_ids": ["ERC_2026_GREEN", "ERC_OSM_ISOMETRIC", "SRC_OSM_ISOMETRIC"],
        "captures": captures,
        "excluded_camera_notes": {
            "ERC_2014_SOUTH": "The geotagged point is approximately 1.1 m inside the OSM ERC polygon in the current local projection; geotag and outline uncertainty prevent treating it as a validated exterior view.",
            "SRC_EAST_PROXY": "The synthetic proxy camera is approximately 15.4 m from the OSM SRC polygon and is too close for a full-footprint overview."
        },
        "note": "OSM footprints are community-mapped; heights are estimated from building:levels and estimated storey pitch. The original proxy collision remains active. Images are software renders, not photo matching or survey validation."
    }
    var report: FileAccess = FileAccess.open(output.path_join("osm_shell_manifest.json"), FileAccess.WRITE)
    if report == null:
        push_error("Could not write OSM shell review manifest")
        quit(1)
        return
    report.store_string(JSON.stringify(manifest, "  ") + "\n")
    report.close()
    print("PASS: rendered %d proxy/OSM shell comparison images" % captures.size())
    instance.queue_free()
    quit(0)
