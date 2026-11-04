#!/usr/bin/env python3
"""Generate an original, schematic UTown top-down SVG for field/GIS review.

No aerial tiles, copyrighted campus map images, or third-party assets are used.
All building massing, walkway and landscaping geometry is provisional.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from xml.sax.saxutils import escape

REPO = Path(__file__).resolve().parents[1]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

from tools.audit_route_clearance import _project, assess_layout, footprint_vertices

SVG_WIDTH = 1200
SVG_HEIGHT = 1120
MAP_X = 105.0
MAP_Y = 95.0
MAP_W = 670.0
MAP_H = 945.0
PANEL_X = 805.0


def render_plan(document: dict) -> str:
    """Draw a transparent, non-georeferenced visual audit from one JSON layout."""
    reference = document["spatial_reference"]
    lon0 = float(reference["origin_lon"])
    lat0 = float(reference["origin_lat"])
    ground_w, ground_d = map(float, document["ground_size_m"])
    scale = min(MAP_W / ground_w, MAP_H / ground_d)
    map_width, map_height = scale * ground_w, scale * ground_d
    left = MAP_X + (MAP_W - map_width) / 2
    top = MAP_Y + (MAP_H - map_height) / 2

    def page(x: float, z: float) -> tuple[float, float]:
        return (left + (x + ground_w / 2) * scale,
                top + (z + ground_d / 2) * scale)

    def pair(point: list[float]) -> tuple[float, float]:
        return page(*_project(point, lon0, lat0))

    def polygon(points) -> str:
        return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)

    assessments = assess_layout(document)
    violations = sum(result.conflict for result in assessments)
    output = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SVG_WIDTH}" height="{SVG_HEIGHT}" viewBox="0 0 {SVG_WIDTH} {SVG_HEIGHT}" role="img" aria-label="Schematic UTown site layout audit">',
              '<style>',
              '.title{font:bold 24px system-ui,sans-serif;fill:#182b3b}',
              '.subtitle{font:13px system-ui,sans-serif;fill:#43566a}',
              '.panel{font:15px system-ui,sans-serif;fill:#21374c}',
              '.small{font:12px system-ui,sans-serif;fill:#465769}',
              '.building-mass{stroke:#516577;stroke-width:1.3;fill:#a5b7c1;fill-opacity:.76}',
              '.building-p0{fill:#718eab;fill-opacity:.86;stroke:#345875;stroke-width:1.7}',
              '.walkway{stroke:#e5a949;stroke-width:4;stroke-linejoin:round;stroke-linecap:round;stroke-dasharray:9 5;fill:none}',
              '.building-label{font:bold 12px system-ui,sans-serif;fill:#102e45;paint-order:stroke;stroke:#edf3f4;stroke-width:3.5}',
              '.waypoint-label{font:11px system-ui,sans-serif;fill:#123d72;paint-order:stroke;stroke:white;stroke-width:3}',
              '</style>',
              '<rect width="100%" height="100%" fill="#f7fafb"/>',
              '<text x="48" y="40" class="title">NUS-3D / University Town — M1.6 spatial audit</text>',
              '<text x="48" y="63" class="subtitle">SCHEMATIC ONLY · not a real walking map, as-built model or accessibility survey</text>',
              f'<rect x="{left:.1f}" y="{top:.1f}" width="{map_width:.1f}" height="{map_height:.1f}" fill="#eef2e6" stroke="#84969a" stroke-width="1.5"/>']

    # Original Green geometry derived from the existing JSON, not from a map image.
    green = [pair(point) for point in document["green"]["polygon_lonlat"]]
    output.append(f'<polygon points="{polygon(green)}" fill="#8fc789" stroke="#5a9a60" stroke-width="2"/>')

    # Plaza is a rotated estimated rectangle, using the same footprint helper.
    plaza = document["plaza"]
    fake = {"lon": plaza["lon"], "lat": plaza["lat"], "rotation_deg": plaza.get("rotation_deg", 0)}
    part = {"dx": 0, "dn": 0, "w": plaza["width_m"], "d": plaza["depth_m"]}
    plaza_points = [page(x, z) for x, z in footprint_vertices(fake, part, lon0, lat0)]
    output.append(f'<polygon points="{polygon(plaza_points)}" fill="#d8d3bb" stroke="#80785e" stroke-width="2"/>')

    for building in document["buildings"]:
        p0 = building.get("priority") == "P0"
        for part in building["parts"]:
            points = [page(x, z) for x, z in footprint_vertices(building, part, lon0, lat0)]
            klass = "building-mass building-p0" if p0 else "building-mass"
            output.append(f'<polygon class="{klass}" points="{polygon(points)}"/>')

    # The line is a centreline overlay, never a guarantee of a traversable surface.
    for index, walkway in enumerate(document["walkways"]):
        points = [pair(ll) for ll in walkway["lonlat"]]
        output.append(f'<polyline class="walkway" points="{polygon(points)}" data-route-index="{index}"/>')
        for point_index in walkway.get("schematic_detour_indices", []):
            if not isinstance(point_index, int) or point_index < 0 or point_index >= len(points):
                raise ValueError("schematic_detour_indices must reference valid route points")
            x, y = points[point_index]
            output.append(f'<circle class="detour" cx="{x:.1f}" cy="{y:.1f}" r="5.8" fill="#b75040" stroke="#fff" stroke-width="1.6"/>')

    for building in document["buildings"]:
        x, z = _project([building["lon"], building["lat"]], lon0, lat0)
        px, py = page(x, z)
        output.append(f'<text class="building-label" x="{px:.1f}" y="{py:.1f}" text-anchor="middle">{escape(str(building["id"]))}</text>')

    for index, stop in enumerate(document["loop"]):
        x, y = pair([stop["lon"], stop["lat"]])
        output.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5.4" fill="#3078ad" stroke="#fff" stroke-width="2"/>')
        output.append(f'<text class="waypoint-label" x="{x + 8:.1f}" y="{y - 8:.1f}">{index + 1}. {escape(str(stop["name"]))}</text>')

    # North points toward negative Z: north is up on this diagram.
    output += [
        f'<rect x="{PANEL_X}" y="95" width="344" height="940" rx="12" fill="#ffffff" stroke="#dce4e8"/>',
        f'<text class="title" x="{PANEL_X + 24}" y="136">Plan review</text>',
        f'<text class="panel" x="{PANEL_X + 24}" y="174">9 estimated building groups</text>',
        f'<text class="panel" x="{PANEL_X + 24}" y="204">{len(assessments)} pedestrian guide segments</text>',
        f'<text class="panel" x="{PANEL_X + 24}" y="234">{violations} proxy footprint conflicts</text>',
        f'<text class="small" x="{PANEL_X + 24}" y="262">Clearance = half path width + 0.75 m</text>',
        f'<rect x="{PANEL_X + 25}" y="303" width="18" height="18" fill="#718eab" stroke="#345875"/>',
        f'<text class="panel" x="{PANEL_X + 56}" y="318">P0: ERC and SRC (estimated)</text>',
        f'<rect x="{PANEL_X + 25}" y="346" width="18" height="18" fill="#a5b7c1" stroke="#516577"/>',
        f'<text class="panel" x="{PANEL_X + 56}" y="361">P1: other building proxies</text>',
        f'<rect x="{PANEL_X + 25}" y="389" width="18" height="18" fill="#8fc789"/>',
        f'<text class="panel" x="{PANEL_X + 56}" y="404">Town Green approximation</text>',
        f'<line x1="{PANEL_X + 25}" y1="444" x2="{PANEL_X + 43}" y2="444" stroke="#e5a949" stroke-width="5" stroke-dasharray="6 3"/>',
        f'<text class="panel" x="{PANEL_X + 56}" y="449">Conceptual footpaths</text>',
        f'<circle cx="{PANEL_X + 34}" cy="485" r="5.8" fill="#b75040"/>',
        f'<text class="panel" x="{PANEL_X + 56}" y="489">SRC schematic detour points</text>',
        f'<text class="title" x="{PANEL_X + 24}" y="551">Survey needed</text>',
    ]
    notes = [
        "Confirm genuine building outlines",
        "Check ERC / SRC main entrances",
        "Trace accessible pavement/ramps",
        "Measure steps and vertical levels",
        "Match photos with standing positions",
        "Log OSM/source IDs + extraction date",
        "Record geometry confidence",
    ]
    for index, note in enumerate(notes):
        output.append(f'<text class="small" x="{PANEL_X + 24}" y="{587 + index * 32}">• {escape(note)}</text>')

    output += [
        f'<line x1="{PANEL_X + 65}" y1="885" x2="{PANEL_X + 65}" y2="824" stroke="#1b4862" stroke-width="3"/>',
        f'<polygon points="{PANEL_X + 65},810 {PANEL_X + 57},828 {PANEL_X + 73},828" fill="#1b4862"/>',
        f'<text class="panel" x="{PANEL_X + 60}" y="801">N</text>',
        f'<text class="small" x="{PANEL_X + 90}" y="866">North = up (negative Z)</text>',
        f'<text class="small" x="{PANEL_X + 24}" y="954">Origin WGS84: {lat0:.6f}°N, {lon0:.6f}°E</text>',
        f'<text class="small" x="{PANEL_X + 24}" y="978">Projection: provisional local metres</text>',
        f'<line x1="{left + 16:.1f}" y1="{top + map_height - 24:.1f}" x2="{left + 16 + 50*scale:.1f}" y2="{top + map_height - 24:.1f}" stroke="#1b3645" stroke-width="4"/>',
        f'<text class="small" x="{left + 16:.1f}" y="{top + map_height - 34:.1f}">50 m (approx. scale)</text>',
        '<text class="small" x="48" y="1092">Original schematic generated from godot/data/utown_core.json. No third-party map tiles, screenshots, imagery or proprietary models included.</text>',
        '</svg>',
    ]
    return "\n".join(output) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=REPO / "godot/data/utown_core.json")
    parser.add_argument("--out", type=Path, default=REPO / "build/utown-audit-plan.svg")
    args = parser.parse_args()
    document = json.loads(args.data.read_text(encoding="utf-8"))
    rendered = render_plan(document)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(rendered, encoding="utf-8")
    print(f"Wrote schematic plan: {args.out} ({len(document['buildings'])} buildings)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
