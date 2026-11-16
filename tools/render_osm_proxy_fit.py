#!/usr/bin/env python3
"""Draw original SVG P0 footprint mismatch scorecards from OSM and game models."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.audit_route_clearance import _project, footprint_vertices
from tools.audit_osm_proxy_fit import compare_layout

W = 1280
H = 900


def render_scorecard(layout, osm, report=None):
    report = report or compare_layout(layout, osm)
    origin = layout["spatial_reference"]
    lon0, lat0 = origin["origin_lon"], origin["origin_lat"]
    buildings = {b["id"]: b for b in layout["buildings"]}
    feature_map = {f["id"]: f for f in osm["features"]}
    output = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="UTown ERC SRC OSM and estimated model footprint agreement">',
        '<style>',
        '.big{font:700 27px system-ui,sans-serif;fill:#152b38}',
        '.heading{font:700 21px system-ui,sans-serif;fill:#19384c}',
        '.normal{font:15px system-ui,sans-serif;fill:#304a5a}',
        '.small{font:12px system-ui,sans-serif;fill:#637481}',
        '.number{font:700 28px system-ui,sans-serif;fill:#21455e}',
        '</style>',
        '<rect width="100%" height="100%" fill="#f6f9fa"/>',
        '<text class="big" x="50" y="52">NUS-3D | ERC / SRC footprint delta</text>',
        '<text class="normal" x="50" y="82">Frozen OpenStreetMap outer rings vs estimated in-game rotated box unions · same provisional local metre projection</text>',
    ]
    if len(report["buildings"]) != 2:
        raise ValueError("Scorecard expects exactly two named P0 reference footprints")
    for idx, row in enumerate(report["buildings"]):
        source = feature_map[row["id"]]
        model = buildings[row["id"]]
        ox = 46 + idx * 612
        card_w = 590
        output.append(f'<rect x="{ox}" y="116" width="{card_w}" height="668" rx="17" fill="#fff" stroke="#d6e0e7" stroke-width="1.5"/>')
        title = escape(str(source["name"]))
        output.append(f'<text class="heading" x="{ox + 26}" y="155">{title}</text>')
        output.append(f'<text class="small" x="{ox + 26}" y="180">OSM way/{source["osm_way_id"]} v{source["osm_version"]} · source snapshot, NOT surveyed</text>')
        ring = [_project(p, lon0, lat0) for p in source["coordinates_lonlat"]]
        boxes = [footprint_vertices(model, part, lon0, lat0) for part in model["parts"]]
        all_pts = ring + [p for corners in boxes for p in corners]
        xmin, xmax = min(p[0] for p in all_pts), max(p[0] for p in all_pts)
        zmin, zmax = min(p[1] for p in all_pts), max(p[1] for p in all_pts)
        scale = min(498 / max(1, xmax - xmin), 310 / max(1, zmax - zmin))
        xc, zc = (xmin + xmax) / 2, (zmin + zmax) / 2
        middle_x, middle_y = ox + card_w / 2, 362
        def xy(x, z):
            return middle_x + (x - xc) * scale, middle_y + (z - zc) * scale
        def polygon(points):
            return " ".join(f"{px:.2f},{py:.2f}" for px, py in (xy(*p) for p in points))
        output.append(f'<rect x="{ox + 21}" y="204" width="548" height="318" rx="11" fill="#f1f5ef" stroke="#dfe6e5"/>')
        output.append(f'<polygon points="{polygon(ring)}" stroke="#d8872d" stroke-width="3" stroke-linejoin="round" fill="#e7a14c" fill-opacity=".24"/>')
        for part in boxes:
            output.append(f'<polygon points="{polygon(part)}" stroke="#266f95" stroke-width="2" fill="#5b99b3" fill-opacity=".41"/>')
        sx, sz = row["osm_centroid_local_xz_m"]
        px, pz = row["proxy_centroid_local_xz_m"]
        a, b = xy(sx, sz), xy(px, pz)
        output.append(f'<line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" stroke="#39566e" stroke-width="1.8" stroke-dasharray="3 3"/>')
        output.append(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="4.1" fill="#db8b25" stroke="#fff" stroke-width="1"/>')
        output.append(f'<circle cx="{b[0]:.1f}" cy="{b[1]:.1f}" r="4.1" fill="#266f95" stroke="#fff" stroke-width="1"/>')
        output.append(f'<line x1="{ox+40}" y1="546" x2="{ox+72}" y2="546" stroke="#d8872d" stroke-width="4"/>')
        output.append(f'<text class="normal" x="{ox+82}" y="551">OSM outline (ODbL)</text>')
        output.append(f'<line x1="{ox+320}" y1="546" x2="{ox+352}" y2="546" stroke="#266f95" stroke-width="4"/>')
        output.append(f'<text class="normal" x="{ox+362}" y="551">Game proxy</text>')
        output.append(f'<line x1="{ox + 38}" y1="594" x2="{ox + 552}" y2="594" stroke="#e4ebf0" stroke-width="1.5"/>')
        output.append(f'<text class="small" x="{ox + 30}" y="621">Planar intersection / union</text>')
        output.append(f'<text class="number" x="{ox + 30}" y="655">{row["intersection_over_union"] * 100:.1f}% IoU</text>')
        output.append(f'<text class="normal" x="{ox + 310}" y="624">OSM covered: {row["osm_area_covered_pct"]:.1f}%</text>')
        output.append(f'<text class="normal" x="{ox + 310}" y="650">Proxy within OSM: {row["proxy_area_inside_osm_pct"]:.1f}%</text>')
        output.append(f'<text class="normal" x="{ox + 30}" y="687">OSM area: {row["source_area_m2"]:,.0f} m²</text>')
        output.append(f'<text class="normal" x="{ox + 310}" y="687">Proxy area: {row["proxy_union_area_m2"]:,.0f} m²</text>')
        output.append(f'<text class="normal" x="{ox + 30}" y="718">OSM only: {row["source_only_area_m2"]:,.0f} m²</text>')
        output.append(f'<text class="normal" x="{ox + 310}" y="718">Proxy only: {row["proxy_only_area_m2"]:,.0f} m²</text>')
        output.append(f'<text class="normal" x="{ox + 30}" y="750">Centroid separation: {row["centroid_shift_m"]:.1f} m</text>')
        output.append(f'<text class="small" x="{ox + 310}" y="750">{row["proxy_part_count"]} rotated model part(s)</text>')
        output.append(f'<line x1="{ox+498}" y1="248" x2="{ox+498}" y2="216" stroke="#304a5a" stroke-width="2"/>')
        output.append(f'<polygon points="{ox+498},211 {ox+493},220 {ox+503},220" fill="#304a5a"/>')
        output.append(f'<text class="small" x="{ox + 509}" y="227">N</text>')
    output.extend([
        '<text class="normal" x="49" y="817">Interpretation: these are disagreement metrics between two imperfect representations, not a campus positioning accuracy score.</text>',
        '<text class="small" x="49" y="839">OSM rings may include covered passages, open atria or stacked levels; floor heights, accessible routes and missing holes were not mapped.</text>',
        '<text class="small" x="49" y="857">Projection: local tangent approximation (X east / Z south). OSM snapshot: ' + escape(str(osm["snapshot_retrieved_utc"])) + '</text>',
        '<text class="small" x="49" y="877">© OpenStreetMap contributors · ODbL 1.0 · https://www.openstreetmap.org/copyright · Original model polygons from NUS-3D.</text>',
        '</svg>',
    ])
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=ROOT / "godot/data/utown_core.json")
    parser.add_argument("--osm", type=Path, default=ROOT / "godot/data/osm_p0_reference.json")
    parser.add_argument("--out", type=Path, default=ROOT / "build/utown-p0-fit-scorecard.svg")
    args = parser.parse_args()
    layout = json.loads(args.layout.read_text(encoding="utf-8"))
    osm = json.loads(args.osm.read_text(encoding="utf-8"))
    result = render_scorecard(layout, osm)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(result, encoding="utf-8")
    print(f"Created ODbL-attributed P0 fit scorecard: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
