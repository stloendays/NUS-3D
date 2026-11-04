#!/usr/bin/env python3
"""Blender 4.x procedural source authoring for NUS-3D M2 architecture studies.

Run with Blender's Python; files are deliberately NOT committed as validated
campus models. Every measurement comes from estimated JSON proxy geometry.
Coordinates: Blender X=east, Y=north, Z=up. GLB export converts Z-up to Y-up,
so Godot X=east, -Z=north, Y=up. Objects use a common building-local origin.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def colour(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def new_material(bpy, name, hex_color, roughness=0.75, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.diffuse_color = (*colour(hex_color), 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = (*colour(hex_color), 1.0)
        shader.inputs["Roughness"].default_value = roughness
        shader.inputs["Metallic"].default_value = metallic
    return mat


def cube(bpy, name, position, size, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def cylinder(bpy, name, position, radius, height, material, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=height, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def base_massing(bpy, record, materials):
    parts = record["parts"]
    for number, part in enumerate(parts):
        x = float(part.get("dx", 0.0))
        y = float(part.get("dn", 0.0))
        w, d, h = (float(part[key]) for key in ("w", "d", "h"))
        cube(bpy, f"Mass_{number:02d}", (x, y, h / 2), (w, d, h), materials["wall"])
        cube(bpy, f"Roof_{number:02d}", (x, y, h + 0.24), (w + 0.65, d + 0.65, 0.48), materials["white"])


def decorate_erc(bpy, record, estimates, materials):
    pitch = float(estimates["storey_pitch"])
    spacing = float(estimates["mullion_spacing"])
    projection = float(estimates["canopy_projection"])
    for wing, part in enumerate(record["parts"]):
        x = float(part.get("dx", 0.0))
        y = float(part.get("dn", 0.0))
        w, d, h = (float(part[k]) for k in ("w", "d", "h"))
        for floor in range(1, 4):
            z = float(floor) * pitch
            if z + 0.95 >= h:
                break
            cube(bpy, f"ERC_Glass_{wing}_{floor}", (x, y - d / 2 - 0.11, z + 0.12),
                 (w - 1.5, 0.17, 1.95), materials["glass"])
            cube(bpy, f"ERC_Sunshade_{wing}_{floor}", (x, y - d / 2 - projection * 0.32, z + 1.20),
                 (w + 0.8, projection, 0.25), materials["white"])
        count = max(4, int(w / spacing))
        for index in range(1, count):
            px = x - w / 2 + w * index / count
            cube(bpy, f"ERC_Mullion_{wing}_{index}", (px, y - d / 2 - 0.24, h * 0.52),
                 (0.13, 0.18, h * 0.71), materials["metal"])
        cube(bpy, f"ERC_Canopy_{wing}", (x, y - d / 2 - projection * 0.53, 3.28),
             (min(w * 0.55, 21.0), projection * 2.0, 0.27), materials["white"])
        if wing == 0:
            radius = float(estimates["arc_radius"])
            mid_x = x + w * 0.20
            mid_y = y - d / 2 + 1.45
            for step in range(12):
                angle = math.pi * (step + 0.5) / 12.0
                # Blender northing Y increases opposite the Godot southward Z axis.
                p = (mid_x + radius * math.cos(angle), mid_y - radius * math.sin(angle), min(h * 0.52, 6.5))
                panel = cube(bpy, f"ERC_FacetedBay_{step:02d}", p,
                             (2 * math.pi * radius / 12 * 0.97, 0.16, min(h * 0.58, 7.1)),
                             materials["glass"])
                panel.rotation_euler[2] = angle - math.pi / 2


def decorate_src(bpy, record, estimates, materials):
    pitch = float(estimates["storey_pitch"])
    spacing = float(estimates["mullion_spacing"])
    for wing, part in enumerate(record["parts"]):
        x = float(part.get("dx", 0.0))
        y = float(part.get("dn", 0.0))
        w, d, h = (float(part[k]) for k in ("w", "d", "h"))
        for level in range(1, 4):
            z = level * pitch
            if z + 1.0 >= h:
                break
            cube(bpy, f"SRC_Glass_E_{wing}_{level}", (x + w / 2 + 0.10, y, z + 0.10),
                 (0.19, d - 1.6, 1.95), materials["glass"])
            cube(bpy, f"SRC_Glass_S_{wing}_{level}", (x, y - d / 2 - 0.10, z + 0.10),
                 (w - 1.6, 0.19, 1.95), materials["glass"])
            cube(bpy, f"SRC_Balcony_{wing}_{level}", (x + w / 2 + 0.67, y, z + 1.15),
                 (1.45, d + 1.0, 0.27), materials["white"])
        count = max(3, int(d / spacing))
        for index in range(1, count):
            py = y - d / 2 + d * index / count
            cube(bpy, f"SRC_Mullion_{wing}_{index}", (x + w / 2 + 0.23, py, h * 0.52),
                 (0.16, 0.13, h * 0.65), materials["metal"])

    radius = float(estimates["disc_radius"])
    height = float(estimates["disc_elevation"])
    cylinder(bpy, "SRC_ForumDisc_Estimated", (0.0, 0.0, height), radius, 0.55, materials["metal"])
    for index in range(8):
        angle = 2 * math.pi * index / 8
        cylinder(bpy, f"SRC_ForumColumn_{index}", (radius * 0.72 * math.cos(angle),
                 radius * 0.72 * math.sin(angle), height * 0.5 - 0.20),
                 0.18, height - 0.65, materials["white"], vertices=12)

    if len(record["parts"]) >= 2:
        a, b = record["parts"][:2]
        ax, ay = float(a["dx"]), float(a["dn"])
        bx, by = float(b["dx"]), float(b["dn"])
        dx, dy = bx - ax, by - ay
        link = cube(bpy, "SRC_StackedLink_Estimated", ((ax + bx) / 2, (ay + by) / 2, 7.65),
                    (float(estimates["linkway_width"]), math.hypot(dx, dy), 0.40), materials["metal"])
        link.rotation_euler[2] = math.atan2(-dx, dy)


def author_one(bpy, record, profile, outdir):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    mats = {
        "wall": new_material(bpy, "PROXY_Wall", "#e3e5df" if record["id"] == "ERC" else "#c3ccd0"),
        "white": new_material(bpy, "Study_White", "#e5e9e7"),
        "glass": new_material(bpy, "Study_Glazing", "#65919e", 0.23, 0.12),
        "metal": new_material(bpy, "Study_Aluminium", "#aab6b8", 0.38, 0.40),
    }
    base_massing(bpy, record, mats)
    if record["id"] == "ERC":
        decorate_erc(bpy, record, profile["estimates_m"], mats)
    elif record["id"] == "SRC":
        decorate_src(bpy, record, profile["estimates_m"], mats)

    bpy.context.scene["NUS3D_status"] = "ESTIMATED PROXY - NOT SURVEYED"
    bpy.context.scene["NUS3D_id"] = record["id"]
    bpy.context.scene["NUS3D_license_policy"] = "Original procedural geometry; reference links only"
    bpy.ops.wm.save_as_mainfile(filepath=str(outdir / f"{record['id'].lower()}_study.blend"))
    bpy.ops.export_scene.gltf(filepath=str(outdir / f"{record['id'].lower()}_study.glb"),
                              export_format="GLB", export_yup=True)


def main():
    try:
        import bpy
    except ImportError as exc:
        raise SystemExit("Run with Blender 4.x: blender --background --python blender/build_m2_blockouts.py -- --out build/m2_assets") from exc

    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="build/m2_assets", help="output .blend and .glb folder")
    args = parser.parse_args(argv)
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    layout = json.loads((REPO / "godot/data/utown_core.json").read_text(encoding="utf-8"))
    profile_doc = json.loads((REPO / "godot/data/m2_profiles.json").read_text(encoding="utf-8"))
    by_id = {record["id"]: record for record in layout["buildings"]}
    for building_id in ("ERC", "SRC"):
        author_one(bpy, by_id[building_id], profile_doc["profiles"][building_id], outdir)
        print(f"NUS-3D wrote {building_id}: {outdir / (building_id.lower() + '_study.glb')}")
    print("Provisional Blender and GLB assets generated; verify axis, scale, collision, licenses and visuals before import.")


if __name__ == "__main__":
    main()
