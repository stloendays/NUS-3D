# M2.2 — full-extent map and landmark context (2026-11-05)

**Status:** implementation candidate on `feature/m2-2-map-navigation`; all campus geometry remains provisional and is not a surveyed navigation map.

## In-game map

- Auto-fits the complete provisional site extent using building-part footprints, Town Green, Town Plaza and conceptual walkways.
- Draws rotated building-part footprints, with ERC/SRC distinguished from surrounding proxy buildings.
- Shows conceptual paths, numbered stops, schematic SRC detours and the player's position/heading.
- Adds north arrow, scale bar and legend. The map is north-up and uses the provisional local-metre transform.

## Landmark context

The HUD reports stable landmark IDs and includes Town Plaza in nearest-landmark lookup. ERC and SRC notes are grounded in public programme/design references:
- ERC: lower-ground Learning Cafe facing Town Green, Level 1 Computer Commons, Levels 2–3 study zones (NUS UCI).
- SRC: three-storey mixed-use centre, stacked pedestrian circulation and elevated Forum disc (DP Architects).

These notes do not imply exact floor elevations, ramp positions, accessible routes or measured building geometry.

## Validation

The Godot smoke test checks minimap initialization, rotated footprint construction, padded map bounds, nearest-landmark identity for ERC and Town Plaza, and the presence of source-backed summaries. Existing Python route/data audits and Godot rendering remain in CI.

Passing CI confirms code/data consistency and provisional rendering only. It does not certify geographic accuracy, vertical levels, route accessibility or Windows performance.

## Remaining work

- Import and date-stamp OSM building-way geometries with attribution and per-feature provenance.
- Verify building heights, footprints, courtyard/terrace levels and actual ground elevations.
- Trace real entrances, ramp/stair transitions and stacked SRC paths.
- Review GUI screenshots against permitted photographs and perform a Windows collision/performance walk.
