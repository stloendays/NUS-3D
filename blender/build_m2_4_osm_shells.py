#!/usr/bin/env python3
"""Build editable, site-local ERC/SRC extrusion shells from the dated OSM snapshot.

Run with Blender 4.x:
  blender --background --python blender/build_m2_4_osm_shells.py -- --out build/m2_4_osm_shells

Footprints come from OSM community mapping. Heights are estimates derived from
building:levels multiplied by an estimated storey pitch. No shell is survey-grade
or used for collision. Blender axes are X=east, Y=north, Z=up; GLB export uses
Y-up so Godot receives X=east, -Z=north, Y=up.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
METRES_PER_DEG_LAT = 110574.0
METRES_PER_DEG_LON = 111320.0


def lonlat_to_local(lon: float, lat: float, origin_lon: float, origin_lat: float) -> tuple[float, float]:
    east = (lon - origin_lon) * METRES_PER_DEG_LON * math.cos(math.radians(origin_lat))
    north = (lat - origin_lat) * METRES_PER_DEG_LAT
    return east, north


def signed_area(points: list[tuple[float, float]]) -> float:
    return 0.5 * sum(
        points[index][0] * points[(index + 1) % len(points)][1]
        - points[(index + 1) % len(points)][0] * points[index][1]
        for index in range(len(points))
    )


def shell_mesh(bpy: Any, building_id: str, feature: dict[str, Any], profile: dict[str, Any],
               origin_lon: float, origin_lat: float):
    import bmesh
    from mathutils import Vector
    from mathutils.geometry import tessellate_polygon

    ring = feature.get("coordinates", [])
    if len(ring) >= 2 and ring[0] == ring[-1]:
        ring = ring[:-1]
    if len(ring) < 3:
        raise ValueError(f"{building_id}: OSM polygon has fewer than three unique vertices")

    points = [
        lonlat_to_local(float(pair[0]), float(pair[1]), origin_lon, origin_lat)
        for pair in ring
    ]
    if abs(signed_area(points)) < 0.1:
        raise ValueError(f"{building_id}: OSM polygon has near-zero area")

    polygon_vectors = [Vector((x, y, 0.0)) for x, y in points]
    triangles = tessellate_polygon([polygon_vectors])
    if not triangles:
        raise ValueError(f"{building_id}: Blender could not triangulate the OSM polygon")

    # Blender 4.0.2 returns source-vertex indices from tessellate_polygon.
    top_triangles: list[tuple[int, int, int]] = []
    for triangle in triangles:
        ids = tuple(int(vertex_index) for vertex_index in triangle)
        if len(ids) != 3 or any(index < 0 or index >= len(points) for index in ids):
            raise ValueError(f"{building_id}: triangulator returned an invalid source index")
        if len(set(ids)) == 3:
            top_triangles.append(ids)
    if not top_triangles:
        raise ValueError(f"{building_id}: triangulation returned no usable roof faces")

    height_m = float(profile["height_m"])
    if not math.isfinite(height_m) or height_m <= 0:
        raise ValueError(f"{building_id}: estimated height must be positive")

    count = len(points)
    vertices = [(x, y, 0.0) for x, y in points]
    vertices.extend((x, y, height_m) for x, y in points)
    faces: list[tuple[int, ...]] = []

    # Side quads connect the source footprint ring to the estimated roof level.
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, following + count, index + count))

    # Top cap is triangulated so concave building outlines remain valid.
    for triangle in top_triangles:
        faces.append(tuple(vertex + count for vertex in triangle))

    # Close the underside as well; it is not a ground-elevation measurement.
    for triangle in top_triangles:
        faces.append(tuple(reversed(triangle)))

    mesh = bpy.data.meshes.new(f"{building_id}_OSM_Footprint_Extrusion_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=True)
    mesh.update()

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    side = bpy.data.materials.new(f"{building_id}_OSM_Shell_Sides_Estimated")
    side.diffuse_color = (*tuple(int(profile["side_color"].lstrip("#")[i:i + 2], 16) / 255.0
                                 for i in (0, 2, 4)), 1.0)
    side.use_nodes = True
    side_shader = side.node_tree.nodes.get("Principled BSDF")
    if side_shader is not None:
        side_shader.inputs["Base Color"].default_value = side.diffuse_color
        side_shader.inputs["Roughness"].default_value = 0.72

    roof = bpy.data.materials.new(f"{building_id}_OSM_Shell_Roof_Estimated")
    roof.diffuse_color = (*tuple(int(profile["roof_color"].lstrip("#")[i:i + 2], 16) / 255.0
                                 for i in (0, 2, 4)), 1.0)
    roof.use_nodes = True
    roof_shader = roof.node_tree.nodes.get("Principled BSDF")
    if roof_shader is not None:
        roof_shader.inputs["Base Color"].default_value = roof.diffuse_color
        roof_shader.inputs["Roughness"].default_value = 0.86

    mesh.materials.append(side)
    mesh.materials.append(roof)
    for polygon in mesh.polygons:
        polygon.material_index = 1 if polygon.normal.z > 0.5 else 0

    obj = bpy.data.objects.new(f"UT_{building_id}_OSMFootprintShell_LOD0", mesh)
    bpy.context.collection.objects.link(obj)
    obj["NUS3D_status"] = "ESTIMATED OSM FOOTPRINT EXTRUSION - NOT SURVEYED"
    obj["NUS3D_landmark_id"] = building_id
    obj["NUS3D_source"] = "OpenStreetMap contributors / ODbL"
    obj["NUS3D_osm_way_id"] = int(feature["osm_id"])
    obj["NUS3D_osm_version"] = int(feature.get("version", 0))
    obj["NUS3D_osm_timestamp"] = str(feature.get("timestamp", ""))
    obj["NUS3D_osm_levels"] = int(profile["osm_levels"])
    obj["NUS3D_estimated_storey_pitch_m"] = float(profile["storey_pitch_m"])
    obj["NUS3D_estimated_height_m"] = height_m
    obj["NUS3D_height_confidence"] = str(profile["height_confidence"])
    obj["NUS3D_coordinate_system"] = "site-local metres; X east, Y north, Z up"
    obj["NUS3D_collision"] = "none; keep Godot proxy collision until independently reviewed"
    obj["NUS3D_layer_tag"] = str(profile.get("osm_layer_tag") or "")
    return obj, len(vertices), len(faces), abs(signed_area(points))


def author_one(bpy: Any, building_id: str, feature: dict[str, Any], profile: dict[str, Any],
               origin_lon: float, origin_lat: float, outdir: Path) -> dict[str, Any]:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0

    obj, vertex_count, face_count, area_m2 = shell_mesh(
        bpy, building_id, feature, profile, origin_lon, origin_lat
    )
    scene = bpy.context.scene
    scene["NUS3D_status"] = "M2.4 OSM FOOTPRINT SHELL - ESTIMATED HEIGHT - NOT SURVEYED"
    scene["NUS3D_landmark_id"] = building_id
    scene["NUS3D_osm_way_id"] = int(feature["osm_id"])
    scene["NUS3D_osm_timestamp"] = str(feature.get("timestamp", ""))
    scene["NUS3D_height_method"] = "OSM building:levels x estimated storey pitch"
    scene["NUS3D_vertical_datum"] = "unknown; shell base placed at provisional Godot Y=0"
    scene["NUS3D_license"] = "OpenStreetMap ODbL 1.0; attribution required"

    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    blend_path = outdir / f"{building_id.lower()}_osm_shell.blend"
    glb_path = outdir / f"{building_id.lower()}_osm_shell.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        export_yup=True,
        export_extras=True,
        export_draco_mesh_compression_enable=False,
        use_selection=True,
    )
    return {
        "landmark_id": building_id,
        "osm_way_id": int(feature["osm_id"]),
        "osm_version": int(feature.get("version", 0)),
        "osm_timestamp": str(feature.get("timestamp", "")),
        "vertices": vertex_count,
        "faces": face_count,
        "footprint_area_m2": round(area_m2, 3),
        "estimated_height_m": float(profile["height_m"]),
        "height_confidence": str(profile["height_confidence"]),
        "blend_file": blend_path.name,
        "glb_file": glb_path.name,
    }


def main() -> None:
    try:
        import bpy
    except ImportError as exc:
        raise SystemExit(
            "Run with Blender 4.x: blender --background --python "
            "blender/build_m2_4_osm_shells.py -- --out build/m2_4_osm_shells"
        ) from exc

    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="build/m2_4_osm_shells")
    args = parser.parse_args(argv)
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    layout = json.loads((REPO / "godot/data/utown_core.json").read_text(encoding="utf-8"))
    osm = json.loads((REPO / "godot/data/osm_utown_snapshot.json").read_text(encoding="utf-8"))
    profiles = json.loads((REPO / "godot/data/osm_shell_profiles.json").read_text(encoding="utf-8"))
    spatial = layout["spatial_reference"]
    origin_lon = float(spatial["origin_lon"])
    origin_lat = float(spatial["origin_lat"])
    by_way_id = {int(item["osm_id"]): item for item in osm["features"]}
    manifest = {
        "status": "estimated_osm_footprint_shells_not_surveyed",
        "source": "OpenStreetMap contributors",
        "license": "ODbL 1.0",
        "coordinate_system": "site-local metres; X east, Y north, Z up; GLB export converts to Y-up",
        "height_method": profiles["height_policy"],
        "vertical_datum": "unknown; no terrain elevation applied",
        "collision_policy": profiles["collision_policy"],
        "assets": [],
    }
    for building_id, profile in profiles["buildings"].items():
        way_id = int(profile["osm_way_id"])
        feature = by_way_id.get(way_id)
        if feature is None or feature.get("geometry_status") != "complete":
            raise ValueError(f"{building_id}: complete OSM source way {way_id} is unavailable")
        if feature.get("landmark_id") != building_id:
            raise ValueError(f"{building_id}: OSM landmark ID does not match source feature")
        result = author_one(
            bpy, building_id, feature, profile, origin_lon, origin_lat, outdir
        )
        manifest["assets"].append(result)
        print(
            f"PASS {building_id}: OSM way {way_id}, {result['vertices']} vertices, "
            f"{result['faces']} faces, estimated height {result['estimated_height_m']} m"
        )

    (outdir / "osm_shell_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"M2.4 editable Blender and GLB shells written to {outdir}")


if __name__ == "__main__":
    main()
