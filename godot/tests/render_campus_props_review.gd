extends SceneTree
## M25 visual QA: genuine Godot viewport captures of the new campus amenities.

func _initialize() -> void:
    call_deferred("_render")

func _fail(message: String) -> void:
    push_error("M25 campus prop visual review: " + message)
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
    if intro != null and intro.has_method("finish_intro"):
        intro.call("finish_intro")
    for child in game.get_children():
        if child is CanvasLayer:
            (child as CanvasLayer).visible = false

    var dressing: Node3D = game.get_node_or_null("MapDressing") as Node3D
    var scatter: Node3D = dressing.get_node_or_null("KentRidgeScatteredEverydayProps_M25") if dressing != null else null
    var camera: Camera3D = game.get_node_or_null("Player/Head/Camera3D") as Camera3D
    if scatter == null or camera == null:
        _fail("campus scatter or player camera is missing")
        return

    var vending: MultiMeshInstance3D = scatter.get_node_or_null("Scattered_vending_machine_MultiMesh") as MultiMeshInstance3D
    var picnic: MultiMeshInstance3D = scatter.get_node_or_null("Scattered_picnic_table_MultiMesh") as MultiMeshInstance3D
    var water: MultiMeshInstance3D = scatter.get_node_or_null("Scattered_water_dispenser_MultiMesh") as MultiMeshInstance3D
    if vending == null or picnic == null or water == null:
        _fail("one or more amenity batches are missing")
        return
    if vending.multimesh.instance_count < 1 or picnic.multimesh.instance_count < 1 or water.multimesh.instance_count < 1:
        _fail("amenity batches contain no instances")
        return

    if DisplayServer.get_name() == "headless":
        _fail("an X11 display is required for genuine viewport captures")
        return
    var output: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(output) != OK:
        _fail("could not create review_previews")
        return

    camera.make_current()
    camera.fov = 68.0
    camera.far = 1400.0

    var vending_transform: Transform3D = vending.global_transform * vending.multimesh.get_instance_transform(0)
    var vending_target: Vector3 = vending_transform.origin + Vector3.UP * 0.92
    camera.global_position = vending_transform.origin + vending_transform.basis * Vector3(2.8, 1.8, -4.5)
    camera.look_at(vending_target, Vector3.UP)
    if not await _capture(output, "M25_VENDING_MACHINE.png"):
        _fail("could not capture vending machine")
        return

    var picnic_transform: Transform3D = picnic.global_transform * picnic.multimesh.get_instance_transform(0)
    var picnic_target: Vector3 = picnic_transform.origin + Vector3.UP * 1.2
    camera.global_position = picnic_transform.origin + picnic_transform.basis * Vector3(4.8, 3.0, 5.6)
    camera.look_at(picnic_target, Vector3.UP)
    if not await _capture(output, "M25_SHADED_PICNIC.png"):
        _fail("could not capture shaded picnic table")
        return

    var water_transform: Transform3D = water.global_transform * water.multimesh.get_instance_transform(0)
    var water_target: Vector3 = water_transform.origin + Vector3.UP * 0.75
    camera.global_position = water_transform.origin + water_transform.basis * Vector3(2.7, 1.7, -4.0)
    camera.look_at(water_target, Vector3.UP)
    if not await _capture(output, "M25_WATER_REFILL.png"):
        _fail("could not capture water refill station")
        return

    print("PASS: M25 rendered three genuine Godot campus amenity close-ups")
    game.queue_free()
    quit(0)

func _capture(output: String, filename: String) -> bool:
    for _frame in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame == null or frame.is_empty() or frame.get_width() < 400 or frame.get_height() < 300:
        return false
    return frame.save_png(output.path_join(filename)) == OK
