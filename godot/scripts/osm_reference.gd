extends Node3D
class_name UTownOSMReference
## Independent debug-only OSM 2-D footprints, NOT building collision or navigation.
## © OpenStreetMap contributors, ODbL 1.0: openstreetmap.org/copyright.

const DATA_PATH: String = "res://data/osm_p0_reference.json"
const RIBBON_HALF_WIDTH_M: float = 0.38
const RIBBON_Y_M: float = 0.22

var source_document: Dictionary = {}
var feature_count: int = 0
var edge_count: int = 0

func _ready() -> void:
    visible = false
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Missing attributed OSM vector reference data")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("OSM vector reference JSON is not an object")
        return
    source_document = parsed
    var world: UTownWorld = get_parent() as UTownWorld
    if world == null:
        push_error("OSM debug reference must be child of UTownWorld")
        return
    for entry in source_document.get("features", []):
        var points: Array = entry.get("coordinates_lonlat", [])
        if points.size() < 4:
            continue
        var surface: SurfaceTool = SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(points.size() - 1):
            var a: Vector3 = world.lonlat_to_world(float(points[i][0]), float(points[i][1]))
            var b: Vector3 = world.lonlat_to_world(float(points[i + 1][0]), float(points[i + 1][1]))
            var direction: Vector2 = Vector2(b.x - a.x, b.z - a.z)
            if direction.length_squared() < 0.0001:
                continue
            var sideways: Vector2 = Vector2(-direction.y, direction.x).normalized() * RIBBON_HALF_WIDTH_M
            var a_left: Vector3 = Vector3(a.x - sideways.x, RIBBON_Y_M, a.z - sideways.y)
            var a_right: Vector3 = Vector3(a.x + sideways.x, RIBBON_Y_M, a.z + sideways.y)
            var b_left: Vector3 = Vector3(b.x - sideways.x, RIBBON_Y_M, b.z - sideways.y)
            var b_right: Vector3 = Vector3(b.x + sideways.x, RIBBON_Y_M, b.z + sideways.y)
            surface.set_normal(Vector3.UP)
            for point in [a_left, b_left, b_right, a_left, b_right, a_right]:
                surface.add_vertex(point)
            edge_count += 1
        var mesh: MeshInstance3D = MeshInstance3D.new()
        mesh.name = "%s_OSM_way_%s" % [str(entry["id"]), str(entry["osm_way_id"])]
        mesh.mesh = surface.commit()
        var material: StandardMaterial3D = StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.albedo_color = Color.html("#f5bb44") if str(entry["id"]) == "ERC" else Color.html("#49d5de")
        mesh.material_override = material
        add_child(mesh)
        feature_count += 1
