extends RefCounted
class_name NUS3DSoftArchitecture
## Original rounded-prism massing: bevels corners *inward*, so source bounding
## footprints and the original box colliders remain unchanged.
## Used only on large stylized campus building shells and roof caps.
const SEGMENTS_PER_CORNER: int = 5
const MAX_CACHED_MESHES: int = 100
static var _mesh_cache: Dictionary = {}

static func rounded_prism(size_m: Vector3, requested_radius: float = 0.7) -> Mesh:
    if size_m.x <= 0.0 or size_m.y <= 0.0 or size_m.z <= 0.0:
        return BoxMesh.new()
    var radius: float = clampf(requested_radius, 0.05, minf(size_m.x, size_m.z) * 0.24)
    var cache_key: String = "%.3f|%.3f|%.3f|%.3f" % [
        size_m.x, size_m.y, size_m.z, radius
    ]
    if _mesh_cache.has(cache_key):
        return _mesh_cache[cache_key] as Mesh

    var half_width: float = size_m.x * 0.5
    var half_depth: float = size_m.z * 0.5
    var half_height: float = size_m.y * 0.5
    var corners: Array[Vector2] = [
        Vector2(half_width - radius, half_depth - radius),
        Vector2(-half_width + radius, half_depth - radius),
        Vector2(-half_width + radius, -half_depth + radius),
        Vector2(half_width - radius, -half_depth + radius)
    ]
    var footprint: PackedVector2Array = PackedVector2Array()
    for corner_index in range(4):
        for step in range(SEGMENTS_PER_CORNER + 1):
            var angle: float = (float(corner_index) + float(step) /
                float(SEGMENTS_PER_CORNER)) * PI * 0.5
            footprint.append(corners[corner_index] +
                Vector2(cos(angle), sin(angle)) * radius)
    var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(footprint)
    if triangles.size() < 3:
        var fallback: BoxMesh = BoxMesh.new()
        fallback.size = size_m
        return fallback

    var builder: SurfaceTool = SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(0, triangles.size(), 3):
        var a: Vector2 = footprint[triangles[i]]
        var b: Vector2 = footprint[triangles[i + 1]]
        var c: Vector2 = footprint[triangles[i + 2]]
        # Top: reverse the x/z polygon winding so its normal points up.
        for point in [a, c, b]:
            builder.add_vertex(Vector3(point.x, half_height, point.y))
        for point in [a, b, c]:
            builder.add_vertex(Vector3(point.x, -half_height, point.y))
    for index in range(footprint.size()):
        var a: Vector2 = footprint[index]
        var b: Vector2 = footprint[(index + 1) % footprint.size()]
        var a_top: Vector3 = Vector3(a.x, half_height, a.y)
        var b_top: Vector3 = Vector3(b.x, half_height, b.y)
        var a_bottom: Vector3 = Vector3(a.x, -half_height, a.y)
        var b_bottom: Vector3 = Vector3(b.x, -half_height, b.y)
        # The outward wall normal is to the right of the CCW footprint.
        for point in [a_top, b_top, b_bottom, a_top, b_bottom, a_bottom]:
            builder.add_vertex(point)
    builder.generate_normals()
    var output: ArrayMesh = builder.commit()
    if _mesh_cache.size() < MAX_CACHED_MESHES:
        _mesh_cache[cache_key] = output
    return output
