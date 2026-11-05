# M2.3 — OSM footprints and terrain contour reference (2026-11-05)

**Status:** versioned public-source GIS snapshots are integrated into the minimap. The 3D building collision model and terrain surface remain provisional; this is not a cadastral survey, a DEM, or an accessibility map.

## OSM campus extract

Snapshot: \`godot/data/osm_utown_snapshot.json\`

- Extracted from OpenStreetMap API v0.6 on 2026-11-05.
- Clipped to the OSM University Town boundary way **92357946**.
- 177 selected features: **38 building footprints, 4 roof structures, 118 path/step/service ways and 17 landcover areas/lines**.
- Each way retains its OSM ID, version, changeset, timestamp, source URL, tags, node IDs and WGS84 geometry.
- Explicit named matches are recorded for ERC (124549217), SRC (125774787), CREATE Tower (125842215), CAPT (124543527), Tembusu Tower (124230878), Acacia Tower/Cinnamon College (124542228), and RC4 Tower (124543999).

A rough anchor check compares the existing seven schematic landmark anchors with the arithmetic mean of each OSM way's vertices. Offsets are approximately 1.7–4.9 m. This is only a coarse consistency check: a vertex mean is not a polygon centroid, and it does not measure footprint overlap, rotation or survey error.

OSM \`building:levels\` tags are preserved as tags, not converted into measured heights. \`layer=*\` indicates relative topological stacking, not a vertical elevation in metres. The snapshot is community-mapped geometry and must retain OSM attribution and ODbL obligations.

## Terrain contour reference

Snapshot: \`godot/data/terrain_contours.json\`

A public Singapore contour layer sourced from Singapore Land Authority (Land Survey) was queried and clipped to the UTown boundary. It exposes a \`Height\` field in metres and five contours intersecting the study area: **5, 10, 15, 20 and 25 m**.

The item description states a **5 m contour interval** and **10 m resolution**. Its acknowledgements identify SLA Land Survey data downloaded 1 May 2019; the service reports data last edited 15 March 2020. The vertical datum is not stated in the service metadata.

This is therefore a planimetric contour reference, not a gridded DEM or a current site survey. The minimap draws these contour lines for slope context only. CI also captures both the decluttered default map and a path-network comparison image. They are not used to assign player elevation, building-floor height, ramp grade or step riser height.

## In-game controls

- **O** toggles OSM building footprints and landcover.
- **P** toggles the denser OSM footway/steps/service network (off by default to keep the minimap legible).
- **T** toggles the 5 m contour overlay.
- The overlays are drawn separately from the existing schematic building collision envelopes and conceptual route.

## Validation

\`tools/validate_geospatial_sources.py\` and its unit tests check:
- OSM contributor attribution and ODbL notice;
- closed, complete building rings and valid WGS84 coordinates;
- consistency between snapshot feature records and summary counts;
- the five contour values, 5 m interval and explicit unknown vertical datum;
- the prohibition on presenting the contour reference as a surveyed DEM.

CI validation proves data structure and provenance fields only. It does not prove the geometry is correct on the ground.

## Next acceptance gates

1. Compare the OSM building polygons with licensed current photographs or on-site observations; verify all P0 entrances and footprint extents.
2. Establish the contour dataset's vertical datum and source accuracy, or obtain an appropriate higher-resolution SLA/NUS survey.
3. Measure the Town Green–ERC–SRC ground levels, ramps, steps and stacked paths before building a height mesh.
4. Replace only selected visual proxy geometry after polygon collision and route-clearance tests support it. Keep a fallback proxy until the new geometry passes GUI review.
