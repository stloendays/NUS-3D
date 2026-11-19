extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var districts: Array[Dictionary] = [
        {"position": Vector3(0, 0, 0), "elevation_m": 0.0},
        {"position": Vector3(180, 0, 0), "elevation_m": 24.0}
    ]
    var mesh_root: Node3D = KentRidgeTerrainMesh.create(districts)
    root.add_child(mesh_root)
    var terrain: MeshInstance3D = mesh_root.get_node_or_null("TerrainSurface")
    if terrain == null or terrain.mesh == null:
        push_error("Terrain mesh generation failed")
        quit(1)
        return
    if terrain.mesh.get_surface_count() != 1:
        push_error("Unexpected terrain surface count")
        quit(1)
        return
    var low: float = KentRidgeTerrainMesh.height_at(Vector2(0, 0), districts)
    var high: float = KentRidgeTerrainMesh.height_at(Vector2(180, 0), districts)
    if high <= low:
        push_error("Terrain height field is not monotonic at control points")
        quit(1)
        return
    print("PASS: continuous terrain mesh and height sampling")
    quit(0)
