extends RefCounted
class_name KentRidgeTerrainMesh
## Schematic continuous surface. Heights are game-design estimates, not survey data.
## Mesh is visual-only until road/terrace overlap and spawn points are audited.
const GRID_STEP: float = 32.0
const INFLUENCE_RADIUS: float = 165.0
const MAX_CELLS: int = 3000

static func height_at(point: Vector2, districts: Array[Dictionary]) -> float:
    var height_sum: float = 0.0
    var weight_sum: float = 0.0
    for district in districts:
        var center: Vector3 = district["position"]
        var dist: float = point.distance_to(Vector2(center.x, center.z))
        var influence: float = clampf(1.0 - dist / INFLUENCE_RADIUS, 0.0, 1.0)
        var weight: float = influence * influence * (3.0 - 2.0 * influence)
        height_sum += weight * float(district.get("elevation_m", 0.0))
        weight_sum += weight
    return height_sum / weight_sum if weight_sum > 0.0001 else 0.0

static func create(districts: Array[Dictionary]) -> Node3D:
    var root := Node3D.new()
    root.name = "KentRidgeContinuousTerrain_Visual"
    if districts.is_empty():
        return root
    var min_x: float = INF
    var max_x: float = -INF
    var min_z: float = INF
    var max_z: float = -INF
    for district in districts:
        var p: Vector3 = district["position"]
        min_x = minf(min_x, p.x - INFLUENCE_RADIUS)
        max_x = maxf(max_x, p.x + INFLUENCE_RADIUS)
        min_z = minf(min_z, p.z - INFLUENCE_RADIUS)
        max_z = maxf(max_z, p.z + INFLUENCE_RADIUS)
    var nx: int = maxi(1, ceili((max_x - min_x) / GRID_STEP))
    var nz: int = maxi(1, ceili((max_z - min_z) / GRID_STEP))
    # Avoid generating huge meshes when coordinate conversion changes.
    if nx * nz > MAX_CELLS:
        push_warning("Terrain mesh budget exceeded; skipping visual terrain")
        return root
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for z in range(nz + 1):
        for x in range(nx + 1):
            var px: float = min_x + float(x) * GRID_STEP
            var pz: float = min_z + float(z) * GRID_STEP
            verts.append(Vector3(px, height_at(Vector2(px, pz), districts) - 0.22, pz))
            normals.append(Vector3.UP)
    for z in range(nz):
        for x in range(nx):
            var a: int = z * (nx + 1) + x
            var b: int = a + 1
            var c: int = a + nx + 1
            var d: int = c + 1
            # Winding faces upward in Godot's x/z plane.
            indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
    # Compute smooth normals using central differences.
    for z in range(nz + 1):
        for x in range(nx + 1):
            var idx: int = z * (nx + 1) + x
            var left: int = z * (nx + 1) + maxi(0, x - 1)
            var right: int = z * (nx + 1) + mini(nx, x + 1)
            var down: int = maxi(0, z - 1) * (nx + 1) + x
            var up: int = mini(nz, z + 1) * (nx + 1) + x
            var dx: float = (verts[right].y - verts[left].y) / maxf(GRID_STEP, (right - left) * GRID_STEP)
            var dz: float = (verts[up].y - verts[down].y) / maxf(GRID_STEP, (up - down) * GRID_STEP)
            normals[idx] = Vector3(-dx, 1.0, -dz).normalized()
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#789675")
    material.roughness = 0.94
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var instance := MeshInstance3D.new()
    instance.name = "TerrainSurface"
    instance.mesh = mesh
    instance.material_override = material
    root.add_child(instance)
    return root
