extends SceneTree
## M11 regression: ecology is bounded, decorative, weather-sensitive and isolated.

func _initialize() -> void:
    call_deferred("_test")

func _fail(message: String) -> void:
    push_error("M11 ambient ecology regression: " + message)
    quit(1)

func _test() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("Main scene unavailable")
        return
    var game: Node3D = scene.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)
    var ambient: UTownAmbientEcology = game.get_node_or_null("AmbientEcology") as UTownAmbientEcology
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
    if ambient == null or weather == null or life == null or player == null:
        _fail("A required scene node is missing")
        return
    if ambient.birds.size() != 10 or ambient.butterflies.size() != 12 or ambient.cats.size() != 2:
        _fail("Normal detail wildlife budgets are wrong")
        return
    if ambient.leaf_batch == null or ambient.leaf_batch.multimesh.instance_count != 40:
        _fail("Near-field leaves must share a bounded MultiMesh")
        return
    if ambient.sound_clips.size() != 4:
        _fail("Original procedural ambience clips are missing")
        return
    for kind in ["grass", "paving", "interior", "chirp"]:
        var clip: AudioStreamWAV = ambient.sound_clips.get(kind) as AudioStreamWAV
        if clip == null or clip.data.size() < 500:
            _fail("Audio clip missing or empty: " + kind)
            return
    var stack: Array[Node] = [ambient]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is CollisionObject3D or node is CollisionShape3D:
            _fail("Decorative ecology unexpectedly changes collision/navigation")
            return
        for child in node.get_children():
            stack.append(child)
    player.global_position = ambient.butterflies[0]["base"]
    weather.set_mode(0)
    ambient._process(0.25)
    var butterfly: Node3D = ambient.butterflies[0]["node"]
    if not butterfly.visible:
        _fail("Butterflies must appear nearby in dry daytime weather")
        return
    weather.set_mode(3)
    ambient._process(0.25)
    if butterfly.visible:
        _fail("Butterflies must shelter during heavy rain")
        return
    weather.set_mode(0)
    ambient._process(0.25)
    if not butterfly.visible:
        _fail("Butterflies did not return after rain")
        return
    life.interior_active = true
    ambient._process(0.25)
    if butterfly.visible or ambient.leaf_batch.visible:
        _fail("Outdoor ecology leaked into indoor mode")
        return
    life.interior_active = false
    var old_steps: int = ambient.footstep_count
    player.movement_locked = true
    player.global_position += Vector3(0.2, 0, 0)
    ambient._advance_footsteps()
    if ambient.footstep_count != old_steps:
        _fail("Movement lock must prevent footstep playback")
        return
    player.movement_locked = false
    var settings: Dictionary = ambient.budgets()
    if int(settings["birds"]) > ambient.MAX_BIRDS or int(settings["leaves"]) > ambient.MAX_LEAVES:
        _fail("Performance budgets exceeded")
        return
    print("PASS: M11 bounded tropical wildlife, weather/day-night/indoor gating, spatial original sound, no new collision or hotkeys")
    game.queue_free()
    quit(0)
