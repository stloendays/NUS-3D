extends SceneTree
## Capture the actual HUD/minimap with OSM and contour overlays enabled.

func _initialize() -> void:
    call_deferred("_render")

func _render() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("Could not load main scene for minimap review")
        quit(1)
        return
    var instance: Node3D = packed.instantiate() as Node3D
    root.add_child(instance)
    await process_frame

    var review: UTownViewReview = instance.get_node_or_null("ViewReview") as UTownViewReview
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    var minimap: UTownMinimap = instance.get_node_or_null("HUD/Minimap") as UTownMinimap
    if review == null or hud == null or minimap == null:
        push_error("HUD/minimap review nodes failed to initialize")
        quit(1)
        return
    if minimap.osm_features.size() < 170 or minimap.terrain_contours.size() != 5:
        push_error("OSM or contour overlays did not load for graphical review")
        quit(1)
        return
    if not review.select_view(1):
        push_error("Could not select UTown overview camera")
        quit(1)
        return

    hud.visible = true
    minimap.visible = true
    minimap.set_osm_reference_visible(true)
    minimap.set_osm_paths_visible(false)
    minimap.set_terrain_contours_visible(true)
    for _frame in range(4):
        await process_frame
    await RenderingServer.frame_post_draw

    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        push_error("Minimap review did not produce a valid viewport image")
        quit(1)
        return

    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        push_error("Could not create minimap review output folder")
        quit(1)
        return
    var image_path: String = output.path_join("minimap_m2_3_osm_contours.png")
    if frame.save_png(image_path) != OK:
        push_error("Could not save decluttered minimap review PNG")
        quit(1)
        return

    minimap.set_osm_paths_visible(true)
    for _frame in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var path_frame: Image = root.get_texture().get_image()
    if path_frame == null or path_frame.is_empty() or path_frame.save_png(output.path_join("minimap_m2_3_with_paths.png")) != OK:
        push_error("Could not save OSM pedestrian path overlay comparison")
        quit(1)
        return

    var manifest: Dictionary = {
        "status": "software-rendered-HUD-map-review-not-survey-validation",
        "engine": str(Engine.get_version_info().get("string", "")),
        "renderer": RenderingServer.get_current_rendering_driver_name(),
        "viewpoint": "UTOWN_2020_OVERVIEW",
        "osm_feature_count": minimap.osm_features.size(),
        "campus_boundary_node_count": minimap.osm_boundary.size(),
        "contour_heights_m": [5, 10, 15, 20, 25],
        "osm_overlay_visible": minimap.show_osm_reference,
        "path_overlay_visible_in_comparison": minimap.show_osm_paths,
        "contour_overlay_visible": minimap.show_terrain_contours,
        "map_scale_px_per_m": minimap.map_scale,
        "map_center_local_m": [minimap.map_center_world.x, minimap.map_center_world.y],
        "image": "minimap_m2_3_osm_contours.png",
        "path_comparison_image": "minimap_m2_3_with_paths.png",
        "note": "This verifies the software-rendered HUD/minimap and overlay visibility only. It does not certify geographic accuracy or vertical datum."
    }
    var report: FileAccess = FileAccess.open(output.path_join("minimap_manifest.json"), FileAccess.WRITE)
    if report == null:
        push_error("Could not write minimap review manifest")
        quit(1)
        return
    report.store_string(JSON.stringify(manifest, "  ") + "\n")
    report.close()
    print("PASS: rendered HUD minimap with %d OSM features and five contour levels" % minimap.osm_features.size())
    instance.queue_free()
    quit(0)
