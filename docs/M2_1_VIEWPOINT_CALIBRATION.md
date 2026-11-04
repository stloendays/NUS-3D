# M2.1 — evidence-linked camera viewpoints and scene review (2026-11-04)

**Engineering stage:** public-source evidence registry, four reusable in-game observation presets, screenshot capture and CI preview generation. **NOT** a surveyed campus reconstruction or visually certified model.

## Public evidence and what it supports

1. [NUS Law Academy UTown map (2025)](https://law.nus.edu.sg/cbfl/wp-content/uploads/sites/5/2025/11/Directions-To-Around-UTown-251204.pdf), page 5. Marked accurate as of 20 November 2025, subject to change. Supports the relative topological arrangement of Education Resource Centre, Town Green, Stephen Riady Centre and Town Plaza, **not building dimensions**. We do not bundle the original map.
2. [NUS UCI Education Resource Centre](https://uci.nus.edu.sg/campus-life/campus-services/utown/education-resource-centre/). A learning cafe at the **lower ground** overlooks Town Green; Computer Commons are at level 1, study zones at levels 2 and 3. Supports real vertical program, but no numerical elevations or surveyed entrances.
3. [DP Architects Stephen Riady Centre](https://www.dpa.com.sg/projects/stephen-riady-centre/). Describes a three-storey mixed-use complex, uphill south-to-north site slope, **stacked pedestrian circulation**, converging routes and a high-level Forum disc. Confirms vertical complexity but no measured grade, floor levels, or usable route cross-section.
4. [NUS UCI Stephen Riady Centre](https://uci.nus.edu.sg/campus-life/campus-services/utown/stephen-riady-centre/). Lists educational, sports and performance areas, plus management on level one. No validated accessible approach or ramp placement is included.
5. [OpenStreetMap SRC way 125774787](https://www.openstreetmap.org/way/125774787) is reported by [Mapcarta](https://mapcarta.com/W125774787) at approximately 1.30462 N, 103.77252 E. **Individual OSM polygon nodes, age, accuracy and licenses have not yet been programmatically imported**; current massing remains estimated. Credit: OpenStreetMap contributors (ODbL).

## The four reference camera presets

The complete versioned source/permission/precision record is in godot/data/viewpoints.json. Wikimedia photographs themselves are not shipped.

| ID | Location and bearing | Reference | Provenance and limitation |
|---|---|---|---|
| ERC_2014_SOUTH | 1.305528 N, 103.772750 E; 6.97 degrees **magnetic** | [Wikimedia Commons, 20 Sep 2014](https://commons.wikimedia.org/wiki/File:Education_Resource_Centre,_University_Town,_National_University_of_Singapore_-_20140920-03.jpg) | Smuconlaw; **CC BY-SA 3.0**; EXIF heading, GPS and focal framing unverified |
| UTOWN_2020_OVERVIEW | 1.305661 N, 103.772500 E; 131.60 degrees **true** | [Wikimedia Commons, 15 Feb 2020](https://commons.wikimedia.org/wiki/File:University_Town_at_sunrise,_National_University_of_Singapore,_February_2020.jpg) | Joshua Rommel Hayag Vargas; **CC BY-SA 4.0**; overview of ERC/UTR/CREATE/SRC, imperfect GPS/lens matching |
| ERC_2026_GREEN | 1.305125 N, 103.772919 E; 14.83 degrees **unknown compass datum** | [Wikimedia Commons, 6 Jul 2026](https://commons.wikimedia.org/wiki/File:National_University_of_Singapore_-_Education_Research_Centre_6Jul2026.jpg) | RFNirmala; **CC BY 4.0**; source photo title spelling retained; not a surveyed standing point |
| SRC_EAST_PROXY | 1.304580 N, 103.773180 E; 273.5 degrees **synthetic** | No matching source photo | Game inspection position on the **schematic Town Green side** of SRC, offset away from its proxy east facade for a legible perspective; no real camera claim |

### Keyboard workflow

- **F3** cycles the 4 inspection positions, then returns to free roam. Location is converted using the exact provisional Godot scene origin and metre convention. Stored heading rotates the viewer around Y; pitch/FOV are **tunable estimates**, not photogrammetric results.
- **F2** toggles estimated M2 architectural details on and off from that identical camera position, so differences can be documented independently of game movement.
- **F4** records an original model PNG and a JSON sidecar in the application user data folder, under user://review_captures. The sidecar includes camera XYZ, viewpoint ID, source URL/license/creator and whether M2 is active.
- **Mouse / WASD** can adjust the view afterward; the original photographs are only linked, never embedded.

**Absolute height warning:** the game assumes a flat ground and eye height around 1.84 metres. GPS altitude is not the building-floor datum; the photos' real vantage elevation and FOV are still unknown. Magnetic and unknown EXIF headings are not corrected automatically.

### CI graphical preview

The pipeline validates viewpoints against WGS84 bounds and the **existing estimated building collision envelopes**, checks author/license/uncertainty metadata, and smoke-tests the Godot camera switch. An Ubuntu Xvfb + software OpenGL job renders four viewpoints with both M1 and M2 layers, yielding **8 original PNG previews and a machine-readable manifest** in the GitHub Actions artifact called utown-m2-1-view-review.

To run on an X11-capable Linux computer with Godot 4.4.1:

    python tools/validate_viewpoints.py
    python -m unittest discover -s tools -t . -v
    godot --headless --path godot --import --quit
    godot --headless --path godot --script res://tests/smoke_test.gd
    xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 godot --path godot --rendering-driver opengl3 --script res://tests/render_viewpoints.gd

Automated PNG capture proves that **the provisional scene renders** in Linux software OpenGL. It does not establish accuracy against the source photo, work on Windows, or benchmark frame rate.

## M1/M2 real-world calibration still required

- Reproducible OSM extraction: ERC/SRC exact way geometry, contributor credit, data timestamp, coordinate pipeline, comparison against existing bounding envelopes.
- Standing-point inspection for 2 photos: compare camera heading, subject visibility, actual point elevation and lens FoV, with rights and dates recorded.
- ERC: real curved facade, courtyard, teaching levels, learning-cafe lower-ground connection, outdoor slope, primary approaches.
- SRC: realistic stacked routes, entrances, Forum, transition between levels, ramps/stairs, differences between accessible and nonaccessible routes.
- Real-time visual comparison and full collision walk on a Windows machine, 1080p performance log and error notes. **Do not treat current F3 presets as a real navigation guide.**

## First visual QA of actual CI-produced frames (2026-11-04)

The first software-rendered artifact was downloaded and individual PNGs inspected, not merely checked for file existence.

- **ERC_2014_SOUTH M2**: geometry, sunlight and glazing render. Large procedurally placed trees block part of the multiwing facade; actual camera framing, courtyard and terrace heights are not reproduced. Treat these as model discrepancies, not source-camera errors.
- **ERC_2026_GREEN M2**: simplified horizontal sunshades/greybox wings appear, but the real curved ERC silhouette and lower-ground cafe/terrace relationship remain poorly represented. Building scale and multiple levels are unverified.
- **UTOWN_2020_OVERVIEW M2**: wide view currently dominated by rectilinear residential proxies; does not reproduce recognisable panoramic rooflines yet.
- **SRC_EAST_PROXY M2**: initial view at the east forecourt path point was just metres from the proxy east wall and hid the Forum shape. Moved the **synthetic only** review camera farther east, toward the schematic Town Green side for whole-building comparison; real GPS/photo evidence is unaffected.
- These are visual diagnosis notes, not validated photogrammetric error measurements. See Issue #5 for acceptance criteria.

