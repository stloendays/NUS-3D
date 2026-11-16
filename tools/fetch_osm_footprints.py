#!/usr/bin/env python3
"""Capture versioned OSM building polygons near ERC/SRC for manual spatial review.

OpenStreetMap contributors (ODbL 1.0). This dataset is neither an as-built
survey nor a replacement for the playable Godot scene.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
from urllib.request import urlopen, Request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
BBOX = (103.77190, 1.30350, 103.77410, 1.30630)
LIMIT = 20_000_000


def xy(lon, lat, lon0, lat0):
    return ((lon - lon0) * 111320.0 * math.cos(math.radians(lat0)),
            (lat - lat0) * 110574.0)


def polygon_area(coords):
    if len(coords) < 4 or coords[0] != coords[-1]:
        return 0.0
    x0, y0 = coords[0]
    points = [xy(x, y, x0, y0) for x, y in coords]
    return abs(sum(points[i][0]*points[i+1][1] - points[i+1][0]*points[i][1]
                   for i in range(len(points)-1))) / 2


def parse_osm_xml(payload):
    if len(payload) > LIMIT:
        raise ValueError("OSM response exceeded size limit")
    root = ET.fromstring(payload)
    if root.tag != "osm":
        raise ValueError("not OSM XML")
    nodes = {n.get("id"): [float(n.get("lon")), float(n.get("lat"))]
             for n in root.findall("node") if n.get("id") and n.get("lon") and n.get("lat")}
    result = []
    for way in root.findall("way"):
        tags = {t.get("k"): t.get("v") for t in way.findall("tag")}
        if not tags.get("building") or tags["building"] == "no":
            continue
        refs = [n.get("ref") for n in way.findall("nd")]
        if len(refs) < 4 or refs[0] != refs[-1] or any(ref not in nodes for ref in refs):
            continue
        coords = [nodes[ref] for ref in refs]
        area = polygon_area(coords)
        if area < 5:
            continue
        lon = sum(p[0] for p in coords[:-1]) / (len(coords)-1)
        lat = sum(p[1] for p in coords[:-1]) / (len(coords)-1)
        wayid = int(way.get("id"))
        result.append({
            "osm_way_id": wayid, "osm_version": int(way.get("version", "0")),
            "osm_timestamp": way.get("timestamp", ""),
            "osm_url": "https://www.openstreetmap.org/way/" + str(wayid),
            "name": tags.get("name", ""), "building": tags.get("building", ""),
            "building_levels": tags.get("building:levels", ""),
            "height": tags.get("height", ""),
            "coordinates_lonlat": coords,
            "mean_node_lonlat": [lon, lat], "area_m2_approx": round(area, 2)
        })
    return result


def make_report(xml, layout, source_url, retrieved_at):
    buildings = parse_osm_xml(xml)
    result = {"schema_version": 1, "status": "OSM-candidate-reference-only-NOT-surveyed",
              "license": "ODbL 1.0", "attribution": "OpenStreetMap contributors",
              "source_url": source_url, "retrieved_at_utc": retrieved_at,
              "bbox_lonlat": list(BBOX), "building_ways_total": len(buildings),
              "caveat": "Not survey-grade. Footprints and entrances/levels need review. No Godot geometry is automatically replaced.",
              "targets": {}}
    for target in ("ERC", "SRC"):
        b = next(item for item in layout["buildings"] if item["id"] == target)
        matches = []
        for entry in buildings:
            dx, dy = xy(*entry["mean_node_lonlat"], b["lon"], b["lat"])
            distance = math.hypot(dx, dy)
            if distance > 110:
                continue
            name_match = ("education resource centre" if target == "ERC"
                          else "stephen riady centre") in entry["name"].lower()
            known = target == "SRC" and entry["osm_way_id"] == 125774787
            matches.append({**entry, "distance_to_model_centre_m": round(distance, 2),
                            "candidate_reason": "known-OSM-ID" if known else
                                                "name-match" if name_match else "nearby"})
        matches.sort(key=lambda e: (e["candidate_reason"] == "nearby",
                                    e["distance_to_model_centre_m"]))
        result["targets"][target] = {
            "model_centre_lonlat": [b["lon"], b["lat"]],
            "candidate_count": len(matches), "candidates": matches[:40],
            "selected_way_id": None, "review_status": "manual-confirmation-required"}
    return result


def fetch_xml(timeout=35):
    bbox = ",".join(map(str, BBOX))
    url = "https://api.openstreetmap.org/api/0.6/map?bbox=" + bbox
    request = Request(url, headers={"User-Agent": "NUS-3D-research-data/0.1 (github.com/stloendays/NUS-3D)",
                                     "Accept": "application/xml"})
    with urlopen(request, timeout=timeout) as result:
        data = result.read(LIMIT+1)
    if len(data) > LIMIT:
        raise ValueError("OSM response exceeded size limit")
    return data, url


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=ROOT / "godot/data/utown_core.json")
    parser.add_argument("--xml", type=Path, help="offline XML fixture or saved OSM response")
    parser.add_argument("--out", type=Path, default=ROOT / "build/osm-utown-candidates.json")
    args = parser.parse_args()
    data, source = ((args.xml.read_bytes(), str(args.xml)) if args.xml else fetch_xml())
    report = make_report(data, json.loads(args.layout.read_text(encoding="utf-8")),
                         source, datetime.now(timezone.utc).isoformat())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Captured {report['building_ways_total']} OSM building polygons.")
    for name, entry in report["targets"].items():
        print(name, "candidate_count", entry["candidate_count"])
        for way in entry["candidates"][:8]:
            print(" ", way["osm_way_id"], way["candidate_reason"],
                  round(way["distance_to_model_centre_m"], 1), way["name"])
    print("No OSM geometry has been applied to the playable world.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
