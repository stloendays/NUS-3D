extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var districts: Array[Dictionary] = [
        {"position": Vector3(0, 0, 0), "elevation_m": 0.0},
        {"position": Vector3(180, 0, 0), "elevation_m": 24.0}
    ]
    var root_node: Node3D = KentRidgeTerrainMesh.create(districts)
    root.add_child(root_node)
    var surface: MeshInstance3D = root_node.get_node_or_null("TerrainSurface")
    if surface == null:
        push_error("Terrain surface not generated")
        quit(1)
        return
    var script_text: String = FileAccess.get_file_as_string("res://scripts/kent_ridge_world.gd")
    if not script_text.contains("return TERRAIN_MESH.height_at(Vector2(point.x, point.z), districts)"):
        push_error("Bus stop heights must use the shared terrain sampler")
        quit(1)
        return
    for x in [0.0, 45.0, 90.0, 135.0, 180.0]:
        var h: float = KentRidgeTerrainMesh.height_at(Vector2(x, 0), districts)
        if not is_finite(h) or h < -0.01 or h > 24.01:
            push_error("Invalid height sample at x=" + str(x))
            quit(1)
            return
    print("PASS: terrain height samples finite and shared with bus stop logic")
    quit(0)
