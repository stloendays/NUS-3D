extends SceneTree
## Isolated M3.6 regression, separate from the long-lived M3.4 smoke test.

func _initialize() -> void:
    call_deferred("_smoke")

func _fail(reason: String) -> void:
    push_error("M3.6 regression: " + reason)
    quit(1)

func _smoke() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("main scene failed to load")
        return
    var instance: Node3D = scene.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    NUS3DServices.enter_test_playmode(instance)
    var arcade: UTownArcade = instance.get_node_or_null("Arcade") as UTownArcade
    var campus: UTownCampusLife = instance.get_node_or_null("CampusLife") as UTownCampusLife
    var player: UTownPlayer = instance.get_node_or_null("Player") as UTownPlayer
    var hud: CanvasLayer = instance.get_node_or_null("HUD") as CanvasLayer
    if arcade == null or campus == null or player == null or hud == null:
        _fail("missing arcade or existing scene nodes")
        return
    if arcade.students.size() != 6 or arcade.professors.size() != 2:
        _fail("six reused students and two fictional professors required")
        return
    if arcade.students[0]["node"] != campus.pedestrians[0]["node"]:
        _fail("student reuse is broken")
        return
    if arcade.projectiles.size() != arcade.PROJECTILE_CAPACITY:
        _fail("bounded projectile pool missing")
        return
    # The weather/campus card can grow with indoor status. Arcade HUD must
    # never cover it or the zone postcard (starts at y=354).
    var arcade_card: PanelContainer = arcade.status_card
    var weather_card: PanelContainer = hud.get_node("CampusCard") as PanelContainer
    if arcade_card == null or weather_card == null:
        _fail("compact arcade or campus status card missing")
        return
    weather_card.visible = true
    weather_card.custom_minimum_size = Vector2(0, 140)
    arcade.call("_layout_status_card")
    var weather_bottom: float = weather_card.position.y + maxf(
        weather_card.size.y, weather_card.get_combined_minimum_size().y)
    if arcade_card.visible and (arcade_card.offset_top < weather_bottom + 9.0
            or arcade_card.offset_bottom > 344.0):
        _fail("Arcade summary overlaps expanded indoor/weather status or zone postcard")
        return
    weather_card.custom_minimum_size = Vector2.ZERO
    arcade.call("_layout_status_card")
    if not arcade_card.visible or arcade_card.offset_bottom > 344.0:
        _fail("Compact arcade summary did not restore after weather card collapsed")
        return
    if arcade.status_label.text.contains("\n"):
        _fail("Arcade summary reverted to a four-line permanent overlay")
        return
    # At 720p the indoor/weather panel can expand; Arcade must not cover
    # either it or the area-discovery postcard.
    var weather_card: PanelContainer = hud.get_node_or_null("CampusCard") as PanelContainer
    var arcade_card: PanelContainer = arcade.status_card
    var guide: UTownExperienceGuide = instance.get_node_or_null("ExperienceGuide") as UTownExperienceGuide
    if weather_card == null or arcade_card == null or guide == null or guide.zone_card == null:
        _fail("HUD clearance card references missing")
        return
    var starting_weather_minimum: Vector2 = weather_card.custom_minimum_size
    weather_card.custom_minimum_size = Vector2(starting_weather_minimum.x, 125.0)
    await process_frame
    arcade._refresh_status()
    if arcade_card.visible and arcade_card.get_global_rect().intersects(weather_card.get_global_rect()):
        _fail("Arcade status overlaps expanded indoor/weather panel")
        return
    if arcade_card.visible and arcade_card.get_global_rect().intersects(guide.zone_card.get_global_rect()):
        _fail("Arcade status overlaps the district postcard")
        return
    if arcade.status_label.text.contains("\\n") or arcade.status_label.text.length() < 20:
        _fail("Arcade summary was not compacted to one readable line")
        return
    weather_card.custom_minimum_size = starting_weather_minimum
    await process_frame
    arcade._refresh_status()
    if not arcade_card.visible:
        _fail("Arcade summary did not return after weather panel contracted")
        return
    arcade.save_path = "user://arcade-test-%d.cfg" % Time.get_ticks_usec()
    arcade.load_progress()
    if arcade.level != 1 or arcade.xp != 0 or arcade.choose_weapon(1):
        _fail("starting weapon should be Paper Plane")
        return
    if arcade.hit_student(-1, 1) or arcade.hit_student(999, 1) or arcade.hit_student(0, 0):
        _fail("invalid hits should fail")
        return
    for i in range(3):
        if not arcade.hit_student(0, 1):
            _fail("three focus hits should register")
            return
    if arcade.student_wins != 1 or arcade.lifetime_xp != 30 or arcade.xp != 30:
        _fail("cartoon duel must award 30 XP once")
        return
    if arcade.hit_student(0, 3) or arcade.lifetime_xp != 30:
        _fail("snack break allowed duplicate XP")
        return
    arcade._process(arcade.BREAK_DURATION + 0.1)
    if int(arcade.students[0]["focus"]) != arcade.STUDENT_FOCUS:
        _fail("student did not recover after break")
        return
    player.global_position = arcade.professors[0]["node"].global_position + Vector3(0.9, 0.18, 0.0)
    if not arcade.talk_to_professor() or arcade.lifetime_xp != 50:
        _fail("teacher did not award first 20 XP")
        return
    if not arcade.talk_to_professor() or arcade.lifetime_xp != 50:
        _fail("teacher bonus was awarded twice")
        return
    arcade.load_progress()
    if arcade.student_wins != 1 or arcade.lifetime_xp != 50 or arcade.met_professors.size() != 1:
        _fail("save restore lost arcade progress")
        return
    arcade._award_xp(30)
    if arcade.level != 2 or arcade.xp != 0 or not arcade.choose_weapon(1) or arcade.choose_weapon(2):
        _fail("level 2 unlock incorrect")
        return
    arcade._award_xp(125)
    if arcade.level != 3 or not arcade.choose_weapon(2):
        _fail("level 3 unlock incorrect")
        return
    if arcade.choose_weapon(-1) or arcade.choose_weapon(3):
        _fail("out-of-range weapons accepted")
        return
    campus.interior_active = true
    if arcade.try_fire():
        _fail("throws allowed indoors")
        return
    campus.interior_active = false
    campus.on_shuttle = true
    if arcade.try_fire():
        _fail("throws allowed on shuttle")
        return
    campus.on_shuttle = false
    player.bicycle_mode = true
    if arcade.try_fire():
        _fail("throws allowed while cycling")
        return
    player.bicycle_mode = false
    hud.visible = false
    if arcade.try_fire():
        _fail("throws allowed in photo mode")
        return
    arcade._process(0.3)
    if arcade.status_layer.visible or arcade.held_toy.visible:
        _fail("F7 photo mode failed to hide arcade")
        return
    hud.visible = true
    arcade._process(0.3)
    if not arcade.status_layer.visible or not arcade.held_toy.visible:
        _fail("arcade failed to return after F7")
        return
    var mesh_count: int = arcade.mesh_cache.size()
    var spawn: Vector3 = player.camera.global_position
    for i in range(40):
        arcade._show_pooled_projectile(spawn, spawn + Vector3(0, 0, -8), str(arcade.WEAPONS[i % 3]["color"]))
    if arcade.projectiles.size() != arcade.PROJECTILE_CAPACITY or arcade.mesh_cache.size() != mesh_count:
        _fail("projectile pool caused dynamic mesh growth")
        return
    if arcade.material_cache.size() > 14:
        _fail("shared material cache grew unexpectedly")
        return
    arcade._process(5.0)
    for state in arcade.projectiles:
        if bool(state["active"]) or state["node"].visible:
            _fail("projectile did not return to pool")
            return
    print("PASS: M3.6 recycled student actors, 2 teachers, XP progression, separate save, blocked modes and pooled projectiles")
    instance.queue_free()
    quit(0)
