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
        "note": "Original scene screenshots, not real reference photo files. No Windows GPU performance claim."
    }, "  ") + "\n")
    report.close()
    print("PASS: generated %d original Godot view comparison PNGs" % count)
    instance.queue_free()
    quit(0)
