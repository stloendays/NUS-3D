extends SceneTree
## Main-based outfit preview regression: no shared controller/input-map edits.

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("M13 wardrobe regression: " + why)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene missing")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)
    var wardrobe: CanvasLayer = game.get_node_or_null("Wardrobe") as CanvasLayer
    var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
    var coursework: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    if wardrobe == null or player == null or coursework == null:
        _fail("existing player/coursework or outfit controller missing")
        return
    var panel: PanelContainer = wardrobe.get("panel") as PanelContainer
    var preview: SubViewport = wardrobe.get("preview") as SubViewport
    var character: Node3D = wardrobe.get("character") as Node3D
    if panel == null or preview == null or character == null or character.get_node_or_null("Torso") == null:
        _fail("preview UI or NPC-proportioned character missing")
        return
    if wardrobe.get("is_open") == true or panel.visible:
        _fail("wardrobe unexpectedly active on game start")
        return
    var story_key := InputEventKey.new()
    story_key.keycode = KEY_H
    story_key.pressed = true
    wardrobe.call("_unhandled_input", story_key)
    if wardrobe.get("is_open") == true:
        _fail("wardrobe stole the existing H story key")
        return
    if wardrobe.call("_can_open") != true:
        _fail("main game could not open wardrobe after test-playmode unlock")
        return
    var previous_mouse: int = Input.mouse_mode
    wardrobe.call("_toggle")
    if wardrobe.get("is_open") != true or not panel.visible or not player.movement_locked or not coursework.modal_open:
        _fail("preview did not lock gameplay/enable UI")
        return
    var old_outfit: Dictionary = (wardrobe.get("outfit") as Dictionary).duplicate()
    wardrobe.call("_cycle", "hat", 1, 4)
    if int((wardrobe.get("outfit") as Dictionary)["hat"]) == int(old_outfit["hat"]):
        _fail("hat selection did not update")
        return
    wardrobe.set("outfit", old_outfit)
    wardrobe.call("_toggle")
    if wardrobe.get("is_open") == true or player.movement_locked or coursework.modal_open:
        _fail("wardrobe exit did not restore game control")
        return
    if Input.mouse_mode != previous_mouse:
        _fail("wardrobe exit did not restore original mouse mode")
        return
    var exams: Node = game.get_node_or_null("EnglishExams")
    if exams != null:
        exams.set("is_open", true)
        if wardrobe.call("_can_open") == true:
            _fail("wardrobe overlaps active English exam modal")
            return
        exams.set("is_open", false)
    print("PASS: F6-only outfit preview, no story-key conflict, reversible movement/mouse lock and modal isolation")
    game.queue_free()
    quit(0)
