extends SceneTree
## Isolated regression for static SVG sky / textured scenery / fictional DDL mission.
func _initialize() -> void:
    call_deferred("_smoke")

func _fail(reason: String) -> void:
    push_error("M3.7 DDL/sky regression: " + reason)
    quit(1)

func _smoke() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene did not load")
        return
    var scene: Node3D = packed.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    var sky: UTownWeather = scene.get_node_or_null("Weather") as UTownWeather
    var decor: UTownStreetscape = scene.get_node_or_null("Streetscape") as UTownStreetscape
    var story: UTownDDLStory = scene.get_node_or_null("DDLStory") as UTownDDLStory
    var arcade: UTownArcade = scene.get_node_or_null("Arcade") as UTownArcade
    var player: UTownPlayer = scene.get_node_or_null("Player") as UTownPlayer
    var campus: UTownCampusLife = scene.get_node_or_null("CampusLife") as UTownCampusLife
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if sky == null or decor == null or story == null or arcade == null or player == null or campus == null or hud == null:
        _fail("required existing and new modules are not all present")
        return
    if sky.clouds == null or sky.clouds.get_child_count() != 3:
        _fail("missing static cloud weather layers")
        return
    for layer_idx in range(3):
        var layer: Node3D = sky.clouds.get_child(layer_idx) as Node3D
        if layer.get_child_count() != 11:
            _fail("layer must contain exactly 11 static cloud sprites")
            return
        for visual in layer.get_children():
            var sprite: Sprite3D = visual as Sprite3D
            if sprite == null or sprite.texture == null or sprite.pixel_size < 0.35:
                _fail("cloud sprite missing texture or is too small to read behind buildings")
                return
    var thin_layer: Node3D = sky.clouds.get_child(0) as Node3D
    var full_layer: Node3D = sky.clouds.get_child(1) as Node3D
    var storm_layer: Node3D = sky.clouds.get_child(2) as Node3D
    if not sky.set_mode(0) or not thin_layer.visible or storm_layer.visible:
        _fail("clear sky must show thin fixed clouds")
        return
    if not sky.set_mode(2) or thin_layer.visible or not full_layer.visible:
        _fail("overcast failed to select illustrated mid-layer")
        return
    if not sky.set_mode(4) or not storm_layer.visible:
        _fail("thunderstorm failed to show illustrated storm clouds")
        return
    sky.set_indoor(true)
    if sky.clouds.visible:
        _fail("sky decals should hide indoors")
        return
    sky.set_indoor(false)
    sky.set_mode(0)
    var world: UTownWorld = scene.get_node_or_null("World") as UTownWorld
    if world == null or world.weather_reactive_grass.size() != 2 or world.weather_reactive_materials.size() != 2:
        _fail("original weather-linked lawn and path material lists changed")
        return
    for grass_material in world.weather_reactive_grass:
        if grass_material.albedo_texture == null:
            _fail("untextured grass surface; authored lawn SVG must load")
            return
    for paving_material in world.weather_reactive_materials:
        if paving_material.albedo_texture == null or not paving_material.uv1_triplanar:
            _fail("paving should use original repeated world-space tiles")
            return
    if decor.texture_cache.size() != 4 or decor.cluster_count < 6 or decor.cluster_count > decor.MAX_CLUSTERS:
        _fail("four reusable textures or expected bounded props missing")
        return
    if decor.backdrop_count != decor.BACKDROP_CAPACITY or decor.placard_count != 0:
        _fail("skyline missing or legacy guide banners were reintroduced")
        return
    if decor.scrap_count > decor.SCRAP_CAPACITY or decor.scrap_count <= 0:
        _fail("decorative paper batching is not bounded")
        return
    if decor.shrub_count < 12 or decor.shrub_count > decor.SHRUB_CAPACITY:
        _fail("bounded roadside shrub batches were not populated")
        return
    if decor.bloom_count <= 0 or decor.bloom_count > decor.BLOOM_CAPACITY:
        _fail("comic flower accents missing or exceeded the cap")
        return
    var foliage: Node3D = decor.get_node_or_null("RoadsideBushesAndFlowerPops_TwoBatches") as Node3D
    if foliage == null or foliage.get_child_count() != 2:
        _fail("roadside vegetation must use only two shared draw batches")
        return
    if decor.find_children("*", "CollisionShape3D", true, false).size() != 0:
        _fail("decorative streetscape should not block existing paths")
        return
    var old_meshes: int = decor.mesh_cache.size()
    var old_materials: int = decor.material_cache.size()
    sky.set_mode(1)
    sky.set_mode(3)
    if decor.mesh_cache.size() != old_meshes or decor.material_cache.size() != old_materials:
        _fail("cycling weather should not generate new street meshes/materials")
        return
    if story.stage_points.size() != 4 or not story.enabled or story.countdown_label == null:
        _fail("four approximate campus checkpoints or enlarged timer display missing")
        return
    if story.stage_roots.size() != 4:
        _fail("all four DDL checkpoint art groups must exist")
        return
    for idx in range(4):
        var checkpoint: Node3D = story.stage_roots[idx]
        var prop: Node3D = checkpoint.get_node_or_null("ComicTaskProp_%d" % idx) as Node3D
        if prop == null or prop.get_child_count() < 4:
            _fail("missing giant cartoon mission prop at stage " + str(idx))
            return
        if not prop.find_children("*", "Label3D", true, false).is_empty():
            _fail("task props must never include floating 3D text signposts")
            return
        if checkpoint.find_children("*", "CollisionShape3D", true, false).size() > 0:
            _fail("new quest props should never obstruct the shuttle or existing walkway")
            return
    # Isolate a unique temporary save before evaluating any starting-state markers.
    story.save_path = "user://ddl-m37-test-%d.cfg" % Time.get_ticks_usec()
    story.load_progress()
    story._process(0.25)
    if not story.stage_roots[0].visible or not story.stage_roots[1].visible:
        _fail("four stage props should be natural persistent scenery, not hidden markers")
        return
    if story.focus_accents.size() != 4 or story.compass_control == null:
        _fail("context highlights or optional compass pulse missing")
        return
    if not story.request_focus() or story.ping_remaining < 2.9:
        _fail("P must request a short focus ping")
        return
    story._process(0.1)
    if not story.compass_control.visible:
        _fail("direction pulse not displayed")
        return
    story._process(4.0)
    if story.compass_control.visible:
        _fail("direction pulse did not fade out")
        return
    player.global_position = story.stage_points[0] + Vector3(0, 0.18, 0)
    if story.interact() != true or story.stage != 1 or not story.running:
        _fail("Town Green email should start a DDL countdown")
        return
    story._refresh()
    if not story.display_label.text.contains("m") or not story.countdown_label.text.contains("05:00"):
        _fail("mission target distance or legible clock is missing from HUD")
        return
    story._process(0.05)
    if story.near_prompt_panel.visible:
        _fail("H prompt must not show far from the active mission object")
        return
    player.global_position = story.stage_points[1] + Vector3(0.0, 0.18, 0.0)
    story._refresh()
    if not story.near_prompt_panel.visible or not story.near_prompt_label.text.contains("H"):
        _fail("close-range H action should appear only at target")
        return
    var remaining: float = story.deadline_left
    story._process(2.0)
    if story.deadline_left >= remaining:
        _fail("mission countdown did not advance")
        return
    campus.interior_active = true
    player.global_position = story.stage_points[1] + Vector3(0, 0.18, 0)
    if story.interact():
        _fail("mission interaction allowed inside illustrative interiors")
        return
    campus.interior_active = false
    var old_xp: int = arcade.lifetime_xp
    for phase in range(1, 4):
        player.global_position = story.stage_points[phase] + Vector3(0, 0.18, 0)
        if not story.interact():
            _fail("mission stopped at act " + str(phase))
            return
    if not story.completed or story.stage != 4 or arcade.lifetime_xp != old_xp + 80:
        _fail("mission ending failed or one-time reward was not granted")
        return
    story.load_progress()
    if not story.completed or not story.rewarded:
        _fail("save/restore lost mission completion")
        return
    player.global_position = story.stage_points[0] + Vector3(0, 0.18, 0)
    if not story.interact() or story.stage != 1:
        _fail("episode replay from Town Green failed")
        return
    for phase in range(1, 4):
        player.global_position = story.stage_points[phase] + Vector3(0, 0.18, 0)
        if not story.interact():
            _fail("episode replay blocked")
            return
    if arcade.lifetime_xp != old_xp + 80:
        _fail("replaying episode must not farm duplicate completion XP")
        return
    story.reset_episode()
    player.global_position = story.stage_points[0] + Vector3(0, 0.18, 0)
    story.interact()
    story._process(story.DEADLINE_SECONDS + 1.0)
    if story.running or story.stage != 0 or story.fail_count < 1:
        _fail("expiry failed to return mission to start")
        return
    hud.visible = false
    story._process(0.3)
    if story.display_layer.visible:
        _fail("F7 clean-photo mode should hide DDL overlay")
        return
    if not story.stage_roots[0].visible:
        _fail("F7 must hide UI, not delete mission scene objects")
        return
    print("PASS M3.7: 33 readable fixed clouds, 6 textures, %d prop scenes, %d paper scraps, %d shrubs + %d blooms, 4 DDL acts, no duplicate XP" % [decor.cluster_count, decor.scrap_count, decor.shrub_count, decor.bloom_count])
    scene.queue_free()
    quit(0)
