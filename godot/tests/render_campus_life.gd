extends SceneTree
## Render the illustrative campus furniture and day/night lighting. Not survey evidence.

func _capture(output: String, filename: String) -> bool:
    for _frame in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        push_error("Campus-life renderer did not return a valid viewport image")
        return false
    if frame.save_png(output.path_join(filename)) != OK:
        push_error("Could not save campus-life screenshot: " + filename)
        return false
    return true

func _render() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("Could not load main scene for campus-life review")
        quit(1)
        return
    var instance: Node3D = packed.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    var camera: Camera3D = instance.get_node_or_null("Player/Head/Camera3D") as Camera3D
    if world == null or hud == null or camera == null:
        push_error("Campus-life review nodes did not initialize")
        quit(1)
        return
    if DisplayServer.get_name() == "headless":
        push_error("X11 display required for campus-life review screenshots")
        quit(1)
        return
    if world.generated_bench_count != 4 or world.generated_lamp_count != 3 or world.generated_guide_count != 1:
        push_error("Campus-life props did not all generate")
        quit(1)
        return

    hud.visible = false
    camera.top_level = true
    camera.fov = 68.0
    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        push_error("Could not create campus-life review output folder")
        quit(1)
        return

    var green: Vector3 = world.lonlat_to_world(103.77312, 1.30504)
    camera.global_position = green + Vector3(0.0, 8.0, 24.0)
    camera.look_at(green + Vector3(0.0, 1.0, 0.0), Vector3.UP)
    world.set_night_mode(false)
    var day_ok: bool = await _capture(output, "campus_life_town_green_day.png")
    if not day_ok:
        quit(1)
        return
    world.set_night_mode(true)
    var night_ok: bool = await _capture(output, "campus_life_town_green_night.png")
    if not night_ok:
        quit(1)
        return

    var guide: Node3D = world.get_node_or_null("CampusFurniture_Illustrative/GUIDE_TOTEM") as Node3D
    if guide == null:
        push_error("Campus wayfinding totem was not generated")
        quit(1)
        return
    world.set_night_mode(false)
    camera.global_position = guide.global_position + Vector3(5.5, 3.2, 7.0)
    camera.look_at(guide.global_position + Vector3(0.0, 1.45, 0.0), Vector3.UP)
    var guide_ok: bool = await _capture(output, "campus_life_wayfinding_totem.png")
    if not guide_ok:
        quit(1)
        return

    var manifest: Dictionary = {
        "status": "illustrative_campus_life_software_render_not_field_verified",
        "engine": str(Engine.get_version_info().get("string", "")),
        "renderer": RenderingServer.get_current_rendering_driver_name(),
        "benches": world.generated_bench_count,
        "warm_lamps": world.generated_lamp_count,
        "guide_signs": world.generated_guide_count,
        "discovery_points": world.campus_life_data.get("discoveries", []).size(),
        "captures": [
            "campus_life_town_green_day.png",
            "campus_life_town_green_night.png",
            "campus_life_wayfinding_totem.png"
        ],
        "note": "Furniture is illustrative art placement, not a claim about surveyed existing amenities. Night mode is a manual visual preview, not a real-time astronomical simulation."
    }
    var report: FileAccess = FileAccess.open(output.path_join("campus_life_manifest.json"), FileAccess.WRITE)
    if report == null:
        push_error("Could not write campus-life review manifest")
        quit(1)
        return
    report.store_string(JSON.stringify(manifest, "  ") + "\n")
    report.close()
    print("PASS: rendered Town Green day/night and campus guide views")
    camera.top_level = false
    instance.queue_free()
    quit(0)

func _initialize() -> void:
    call_deferred("_render")
