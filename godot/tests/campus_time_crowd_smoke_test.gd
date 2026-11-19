extends SceneTree
## M12 clock/crowd regression.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M12 time/crowd: " + reason)
    quit(1)

func _run() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene cannot load")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    var clock := game.get_node("CampusClock") as UTownCampusClock
    var crowd := game.get_node("DiningCrowds") as UTownDiningCrowds
    if clock == null or crowd == null:
        _fail("missing clock or crowd")
        return
    clock.set_time(8, 0)
    if clock.dining_intensity() != 0.0 or clock.formatted_time() != "08:00":
        _fail("morning clock should be quiet")
        return
    clock.set_time(12, 30)
    if clock.lunch_intensity() < 0.99:
        _fail("12:30 should be lunch peak")
        return
    clock.set_time(18, 30)
    if clock.dinner_intensity() < 0.7:
        _fail("dinner peak is missing")
        return
    clock.set_time(23, 59)
    clock._process(60.0 / clock.game_minutes_per_real_minute * 60.0)
    if clock.hour() != 0:
        _fail("clock must wrap at midnight")
        return
    if crowd.people.size() != crowd.MAX_PEOPLE:
        _fail("crowd budget mismatch")
        return
    var stack: Array[Node] = [crowd]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        if n is CollisionObject3D:
            _fail("crowd must remain soft and non-trapping")
            return
        for child in n.get_children():
            stack.append(child)
    print("PASS: M12 accelerated clock, lunch/dinner peaks, midnight wrap, bounded soft crowd")
    game.queue_free()
    quit(0)
