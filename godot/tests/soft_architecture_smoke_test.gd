extends SceneTree
## The rounded 3D visual shell may never modify collision sizes or the
## source-informed footprint. Headless QA does not claim real-GPU quality.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("NUS3D soft architecture QA: " + reason)
    quit(1)

func _run() -> void:
    var specimen: Mesh = NUS3DSoftArchitecture.rounded_prism(Vector3(12.0, 8.0, 9.0), 0.72)
    if not (specimen is ArrayMesh) or specimen.get_surface_count() != 1:
        _fail("rounded-prism mesh was not built")
        return
    var bounds: AABB = specimen.get_aabb()
    if (bounds.size - Vector3(12.0, 8.0, 9.0)).length() > 0.04:
        _fail("rounded shell changed the original building bounds")
        return
    if specimen != NUS3DSoftArchitecture.rounded_prism(Vector3(12.0, 8.0, 9.0), 0.72):
        _fail("rounded facade mesh is not cached")
        return
    var values: Array = specimen.surface_get_arrays(0)
    var vertices: PackedVector3Array = values[Mesh.ARRAY_VERTEX]
    if vertices.size() < 100 or vertices.size() > 500:
        _fail("rounded mesh tessellation grew beyond intended budget")
        return

    var graphics: NUS3DGraphicsSettings = NUS3DGraphicsSettings.new()
    if graphics.profile_msaa("low") != Viewport.MSAA_DISABLED or graphics.profile_msaa("balanced") != Viewport.MSAA_2X:
        _fail("low/balanced graphics MSAA profiles missing")
        return
    if graphics.profile_msaa("high") != Viewport.MSAA_4X or graphics.profile_msaa("ultra") != Viewport.MSAA_4X:
        _fail("high/ultra quality anti-aliasing missing")
        return
    # GraphicsSettings is a Node constructed outside the SceneTree. Unlike a
    # RefCounted resource it must be explicitly freed before the process exits;
    # otherwise its GDScript stays referenced and Godot reports leaked objects.
    graphics.free()

    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene failed to load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)
    var world: UTownWorld = game.get_node_or_null("World") as UTownWorld
    var ridge: NUSKentRidgeWorld = game.get_node_or_null("KentRidgeExpansion") as NUSKentRidgeWorld
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    if world == null or ridge == null or weather == null:
        _fail("Visual world or weather is missing")
        return
    if world.sunlight.shadow_blur < 1.10 or world.sunlight.directional_shadow_fade_start > 0.70:
        _fail("daylight soft shadows were not configured")
        return
    if weather.target_fog <= 0.0 or weather.target_fog > 0.002:
        _fail("daylight haze is missing or too heavy")
        return
    # Software-rendered screenshots detected clipped mint grass after a
    # broad +15% ambient increase. Keep daytime reflectance in a usable range.
    if weather.ambient_energy_by_time[0] > 0.64 or weather.sun_energy_by_time[0] > 0.83:
        _fail("daylight exposure exceeds pastel-map readability budget")
        return
    var base: Node3D = world.get_node("BuildingMassing_Estimated") as Node3D
    var source_count: int = 0
    var collision_count: int = 0
    for building in base.get_children():
        for part in building.get_children():
            if part.name != "SoftCampusVolume":
                continue
            source_count += 1
            var visual: MeshInstance3D = part.get_child(0) as MeshInstance3D
            if visual == null or not (visual.mesh is ArrayMesh):
                _fail("UTown facade reverted to hard box mesh")
                return
            for child in part.get_children():
                if child is StaticBody3D:
                    var collider: CollisionShape3D = child.get_child(0) as CollisionShape3D
                    if collider == null or not (collider.shape is BoxShape3D):
                        _fail("rounded mass lost original box collision")
                        return
                    collision_count += 1
    if source_count < world.generated_building_count or collision_count < world.generated_building_count:
        _fail("not all buildings have rounded shells and existing box colliders")
        return
    var ridge_masses: Array[Node] = ridge.find_children("OriginalMass", "MeshInstance3D", true, false)
    if ridge_masses.is_empty():
        _fail("Kent Ridge building masses missing")
        return
    for building_mesh in ridge_masses:
        var model: MeshInstance3D = building_mesh as MeshInstance3D
        if not (model.mesh is ArrayMesh):
            _fail("Kent Ridge original mass remained a hard box")
            return
        var ridge_collider: CollisionShape3D = model.get_node_or_null(
            "SchematicCollision/CollisionShape3D") as CollisionShape3D
        if ridge_collider == null or not (ridge_collider.shape is BoxShape3D):
            _fail("Kent Ridge rounded mass lost its original box collider")
            return
        var original_size: Vector3 = (ridge_collider.shape as BoxShape3D).size
        if (model.mesh.get_aabb().size - original_size).length() > 0.04:
            _fail("Kent Ridge rounded mesh changed the original collision footprint")
            return
    print("PASS: cached original rounded mesh, bounds, %d UTown shells, %d ridge masses, low-spec MSAA and atmospheric falloff" % [
        source_count, ridge_masses.size()
    ])
    game.queue_free()
    quit(0)
