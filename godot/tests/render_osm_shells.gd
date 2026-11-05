extends SceneTree
## Render side-by-side proxy versus OSM-footprint shell views. Not survey validation.

func _initialize() -> void:
    call_deferred("_render")

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
    if review == null or world == null or hud == null or world.osm_shell_count != 2:
        push_error("OSM shell review scene did not initialize")
        quit(1)
        return
    if DisplayServer.get_name() == "headless":
        push_error("X11 display required for OSM shell screenshots")
        quit(1)
        return

    hud.visible = false
    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        push_error("Could not create OSM shell review output folder")
        quit(1)
        return

    var captures: Array[String] = []
    for index in [0, 2, 3]:
        if not review.select_view(index):
            push_error("Could not select camera preset for OSM shell review")
            quit(1)
            return
        for shell_mode in [false, true]:
            world.set_osm_shells_visible(shell_mode)
            for _frame in range(3):
                await process_frame
            await RenderingServer.frame_post_draw
            var frame: Image = root.get_texture().get_image()
            if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
                push_error("OSM shell review did not produce a valid viewport image")
                quit(1)
                return
            var mode: String = "OSM_SHELL" if shell_mode else "PROXY"
            var viewpoint_id: String = str(review.viewpoints[index]["id"])
            var filename: String = "%s_%s.png" % [viewpoint_id, mode]
            if frame.save_png(output.path_join(filename)) != OK:
                push_error("Could not save OSM shell review image: " + filename)
                quit(1)
                return
            captures.append(filename)

    world.set_osm_shells_visible(false)
    var manifest: Dictionary = {
        "status": "software_rendered_proxy_vs_osm_shell_review_not_survey_validation",
        "engine": str(Engine.get_version_info().get("string", "")),
        "renderer": RenderingServer.get_current_rendering_driver_name(),
        "osm_shell_count": world.osm_shell_count,
        "osm_way_ids": world.osm_shell_way_ids,
        "height_estimates_m": {"ERC": 13.8, "SRC": 14.6},
        "viewpoint_ids": ["ERC_2014_SOUTH", "ERC_2026_GREEN", "SRC_EAST_PROXY"],
        "captures": captures,
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
