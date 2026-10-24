# UTown research sources & license register / 素材来源

Date checked: 2026-10-24. Links are research references, **not** statements that media are free to redistribute.

## A. Primary spatial and visual sources

| Resource | Link | Intended role | Access / caveat |
|---|---|---|---|
| NUS interactive campus map | https://map.nus.edu.sg/ | Find buildings, entrances, transport and place names | Official map; use as visual reference, not automatically a survey |
| NUS University Town PDF | https://map.nus.edu.sg/download/9Jan2024/University-Town-Map.pdf | Historical names, layout, road and facility reference | Dated path; **map says NOT TO SCALE**, do not extract exact lengths by pixel |
| NUS official 360° tour | https://www.nus.edu.sg/oam/nus-experience/virtual-tour | Eye-height exterior reference, entrances, facade views | Reference/observation; redistribution of screenshots not presumed licensed |
| NUS UCI UTown facilities | https://uci.nus.edu.sg/campus-life/campus-services/utown/ | ERC, SRC and Town Plaza contextual descriptions | Official descriptive source, confirm updated access and names |
| NUS Digital Twin | https://www.nus-digital-twin.com/ | Building names, footprints, potential geometry references | Some models/layers are listed; **download and reuse permission not verified** |
| OpenStreetMap | https://www.openstreetmap.org/ | Approximate building footprints, roads, lawns, paths | ODbL; attribution and database share-alike rules may apply |
| Overpass Turbo | https://overpass-turbo.eu/ | Extract a UTown OSM area as geospatial input | Query and export results with date/attribution |
| OSM2World | https://osm2world.org/ | Generate first-pass 3D massing from OSM geometry | Verify source data completeness; output is only an approximation |
| Campus3D | https://3d.nus.app/ | Potential reference point-cloud workflow | Site labels CC BY-NC-SA 4.0; not automatically authorized for commercialization |
| Campus3D description | https://3d.nus.app/des/ | Check regional downloadable coverage | Explicitly says **UTown and Faculty of Science datasets to be released later**; verify before relying |
| OSM copyright / licensing | https://www.openstreetmap.org/copyright | Attribution/license review | Keep attribution in published application |

## B. Evidence gathering shot list

For each P0 building, collect **links + photographer/source + date + viewpoint**, not uncontrolled image copies.

| Location | Need | Ideal viewpoints |
|---|---|---|
| Town Green | Grass boundary, slopes, tree types, field of view | 2 elevated, 4 ground-level cardinal/oblique |
| Town Plaza | Surface, canopy, entrances, transitions | 4 pedestrian approaches and 1 elevated overview |
| ERC | Facade, floor rhythm, stairs, doors, exterior walkway | Main entrance, two corner views, side path, far view |
| SRC | Silhouette, roof, columns, glass, entrance | Wide across plaza, near entrance, side/rear overview |
| Linking routes | Walkable continuity and grade | Each junction, staircase and ramp along a full loop |
| Surrounding blocks | Proportions for proxy buildings | One skyline/elevated view + one ground reference each |

Capture record template:

```text
landmark_id:
source_url:
creator_or_copyright_holder:
source_date_or_capture_date:
viewpoint_description:
modeling_observation:
scale_confidence: verified | estimated | unknown
usage_permission: verified | needs-review | reference-only
local_file: none unless authorized
```

## C. Data provenance / measurement workflow

1. Capture the source page URL, access date and source attribution.
2. For OSM, export a bounded UTown dataset, preserve `source_date` and original GeoJSON separately from transformed data.
3. Check footprints against current official mapping and at least one eye-level reference.
4. Record `estimated` for uncertain building heights, floor counts, steps or elevations.
5. Keep Google/satellite imagery as *non-copied* contextual reference unless license explicitly permits re-use.
6. Before including a downloaded 3D model, texture or image, confirm the exact asset license; an accessible URL is not a reuse license.
7. Provide NUS non-affiliation notice and OSM attribution in released demo and project website.

## D. Key open questions

- Where exactly should the Town Green local origin and bounding box be defined using verified GIS points?
- Are there current publicly redistributable exterior photographs of ERC and SRC under suitable Creative Commons terms?
- Does the NUS Digital Twin offer actual accessible building mesh downloads, and under which license?
- How much of UTown is in the currently downloadable Campus3D bundle? The dataset description currently warns its UTown release is pending.
- Which steps, ramps and elevation changes need direct field measurements?
