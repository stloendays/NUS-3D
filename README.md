# NUS-3D — University Town (UTown)

> A community-made, exploratory 3D reconstruction of the National University of Singapore campus. **Start with University Town; expand only after a playable vertical slice works.**
>
> Status: **M2.5 campus atmosphere and discovery first pass implemented (2026-11-11)**. Procedural grass/pavers, illustrative campus furniture, day/night lighting and a four-stop discovery passport are in Godot; amenity placements and all elevations remain unverified.

[启动 Godot 原型](docs/M1_GREYBOX.md) · [M2 ERC/SRC 建筑模型](docs/M2_ARCHITECTURE.md) · [M2.1 实景视角核验](docs/M2_1_VIEWPOINT_CALIBRATION.md) · [M2.2 地图与地标信息](docs/M2_2_MAP_NAVIGATION.md) · [M2.3 GIS 数据基线](docs/M2_3_GEOSPATIAL_BASELINE.md) · [M2.4 建筑轮廓外壳](docs/M2_4_OSM_BUILDING_SHELLS.md) · [M2.5 校园氛围与探索](docs/M2_5_CAMPUS_ATMOSPHERE.md) · [M1.5 数据验证](docs/M1_5_DATA_VALIDATION.md) · [M1.6 步行路径碰撞审计](docs/M1_6_ROUTE_CLEARANCE.md) · [中文项目计划](docs/PROJECT_PLAN.md) · [建模与技术规范](docs/TECHNICAL_DESIGN.md) · [参考资料与版权](docs/REFERENCE_SOURCES.md) · [地标清单](data/utown_landmarks.csv) · [任务 Issues](https://github.com/stloendays/NUS-3D/issues)

## Goal / 项目目标

重建可自由探索的 NUS University Town (UTown)：真实的道路/建筑空间关系、适当简化的建筑外观、热带植被、可行走的连廊与坡道。先保证**整体位置准确、比例可信、行走流畅**，再增加细节和互动。

- **第一版核心区**：Town Green + Town Plaza + Education Resource Centre (ERC) + Stephen Riady Centre (SRC)。
- **周边占位模型**：Tembusu College、College of Alice & Peter Tan (CAPT)、Residential College 4 (RC4)、Cinnamon College、UTown Residence、CREATE；待核实后按批次完善。
- **暂不做**：整个 Kent Ridge 校区、所有室内、精细 BIM、联网多人、自动真实校车仿真。
- **原则**：不是 NUS 官方项目；不要将尚未验证的点云、建筑高度或模型授权表述为已取得。

## Play the first prototype / 运行第一版

Download the repository, install **Godot 4.4.1+**, import `godot/project.godot`, then press **F5**. Walk using **WASD**, turn with mouse, **Shift** to run, **R** to reset, **M** to toggle the map, **F2** to compare the original greybox against provisional ERC/SRC architectural layers, **F3** to cycle public-geotag camera viewpoints, **E** to discover Town Green/ERC/SRC/Town Plaza, **N** to toggle the manual day/night preview, **G** to switch proxy visuals versus OSM ERC/SRC footprint shells (proxy collision stays active), **O** to toggle OSM building/landcover outlines, **P** to toggle the detailed pedestrian path network, **T** to toggle 5 m contour lines, **F4** to save original screenshot and JSON provenance, **Esc** to release mouse. See [M1_GREYBOX.md](docs/M1_GREYBOX.md) for limitations, validation and licensing.

The prototype has procedural low-poly buildings, a ground plane, an approximate Town Green, a conceptual walking loop, lighting, trees and HUD. **It is not a precise site survey, a completed M1 milestone, or a Windows installer.**

The source-data validators check coordinate ranges, polygon integrity, rotated building bounds, route continuity, OSM attribution, closed campus building rings and contour provenance. The minimap overlays 38 OSM building footprints, 4 roof structures, 118 path/step/service ways and 5 SLA-derived contour levels; these are reference layers, not replacement collision geometry or a surveyed terrain surface. Procedural trees avoid building footprints and conceptual walking paths, and 64 trees are rendered in two MultiMesh batches rather than 128 separate mesh nodes. These checks improve data and rendering efficiency; they do not establish real-world accuracy. M1.6 also generates an original top-down SVG spatial-audit plan (GitHub Actions artifact, not a true campus map) and audits conceptual route corridor widths against the estimated, rotated building footprints: one ERC-to-SRC leg was offset to avoid a proxy collision; the current 11-segment route passes the 2-D clearance check, **not a real-world accessible-path survey**.

## Preferred workflow / 建议技术路线

```text
NUS official map + OpenStreetMap outlines + reference photographs/360 views
                         |
               local-coordinate survey
                         |
        Blender modeling / OSM2World proxy geometry
                         |
              reusable .glb (glTF 2.0) assets
                         |
          +--------------+--------------+
          |                             |
    Godot 4 (first)              Three.js (later)
  first-person playable           browser viewer
```

**决定**：先做 Godot 4 的第一人称可玩场景，同时将资产保留为引擎无关的 GLB；未来有需要再接入 Three.js。这样能避免双引擎同步开发拖慢进度。

## Milestones / 里程碑

| Stage | Output | Definition of done |
|---|---|---|
| M0 — Evidence | UTown 基础地图与可追踪来源 | 明确边界、坐标基准、建筑清单；每项来源有授权状态 |
| M1 — Greybox | 可行走的 Town Green 核心区 | ERC/SRC/Plaza/Green 位置与比例基本准确，能连续绕行 |
| M2 — Architecture | 第一批实景辨识度模型 | 4 个核心地标外形、入口及连接路径可辨识 |
| M3 — Atmosphere | 有生命感的校园 | 树木/草地、基础光照与日夜变化、行走音效 |
| M4 — Release | Windows 可执行文件 | 普通 Windows 电脑可运行；性能测量与版权清单完成 |
| M5 — Optional | Three.js 在线参观 | 同一 GLB 资产可重用，网页版有自由相机和建筑标签 |

阶段边界和验收细则见 [PROJECT_PLAN](docs/PROJECT_PLAN.md)。

## First development slice / 最小可交付场景

**当前概念步行顺序：Town Green → ERC → SRC → Town Plaza → 返回 Town Green。** 地图路线和高差尚未经现场核验。

第一版仅需要：地形/草地、4 个大体量建筑/区域、主路与台阶、基础植被、碰撞、WASD 移动+鼠标视角、白天固定光照。完成后再制作更细的外立面。

## Source bookmarks / 核心资料

- [NUS interactive campus map](https://map.nus.edu.sg/)
- [NUS University Town map PDF (9 Jan 2024 directory; historical reference)](https://map.nus.edu.sg/download/9Jan2024/University-Town-Map.pdf)
- [NUS official 360° virtual tour](https://www.nus.edu.sg/oam/nus-experience/virtual-tour)
- [NUS UTown facilities introduction](https://uci.nus.edu.sg/campus-life/campus-services/utown/)
- [NUS Digital Twin](https://www.nus-digital-twin.com/) (availability/license of 3D assets **unverified**)
- [OSM2World](https://osm2world.org/) · [OpenStreetMap](https://www.openstreetmap.org/)

**Important**: The Campus3D description says UTown and Faculty of Science data “will be released later”; do **not** treat the UTown point cloud as available until a verified download exists. See [reference notes](docs/REFERENCE_SOURCES.md).

## Proposed repository layout

```text
NUS-3D/
├── README.md
├── docs/
│   ├── PROJECT_PLAN.md
│   ├── TECHNICAL_DESIGN.md
│   └── REFERENCE_SOURCES.md
├── data/
│   └── utown_landmarks.csv
├── assets/              # future own/licensed GLB models and textures
├── blender/             # future editable source scenes
├── godot/               # future Godot 4 project
├── web/                 # optional Three.js viewer
└── tools/               # implemented source-data validator and tests
```

The `godot/` prototype, M2 ERC/SRC procedural detail layers, Python validators and Blender authoring script are implemented. **Blender 4.0.2 CI has generated the separate ERC/SRC .blend and GLB files**, available as a downloadable workflow artifact; GUI import, visual fidelity, Windows binaries and the Three.js viewer remain pending.

## Attribution & use / 使用和授权

- 本仓库是独立学习与创作项目，**非 NUS 官方发布**。
- NUS 地图、全景与第三方照片用于观察参考；未确认可再分发前，不把原图/截图上传为仓库资产。
- OSM 数据遵循 [ODbL](https://www.openstreetmap.org/copyright) 并需适当署名。
- Campus3D 的公开站点标注 CC BY-NC-SA 4.0（非商业）；即使能下载，也应先核对适用范围。
- 对外发布模型/截图/安装包前，逐项复查来源、NUS 标识使用权与第三方授权。

## Immediate next action

Run `python tools/validate_utown_data.py`, `python tools/audit_route_clearance.py --strict` and the Godot smoke test, then verify P0 route/size/elevation against onsite or permitted visual evidence before refining buildings. [Issue #1](https://github.com/stloendays/NUS-3D/issues/1) still tracks geometry provenance and survey work.

## M2 architectural study / 建筑细节开发

ERC now has schematic glazing, mullions, sunshades and a faceted curved bay; SRC has schematic glass, balcony overhangs, an elevated forum disc and a linkway. All are a **visual-only study using estimated geometry**, not real as-built plans or official NUS assets. Toggle the detail layer using **F2**. A reproducible Blender authoring script lives at `blender/build_m2_blockouts.py`, and [Blender M2 CI](https://github.com/stloendays/NUS-3D/actions/workflows/blender_m2.yml) builds **editable .blend plus GLB preview artifacts**. See [M2 architecture documentation](docs/M2_ARCHITECTURE.md) for the export command and acceptance checklist. The generated models remain provisional and have not passed a local GUI visual review.

## M2.1 evidence-linked camera review

Godot now provides four photo-review positions through F3: ERC 2014, UTown 2020, ERC 2026, and one explicitly synthetic SRC position. F2 compares greybox against M2 detail at the same camera; F4 saves a generated PNG and evidence sidecar in user://review_captures. Source photograph images are not bundled. See docs/M2_1_VIEWPOINT_CALIBRATION.md for creator/license attribution, magnetic heading and ground-elevation uncertainty. Automated render previews are a **software-only comparison**, not proof of as-built fidelity or Windows performance.


## M2.2 map and landmark context

The feature branch upgrades the in-game minimap to a full-extent north-up schematic with rotated building-part footprints, route stop numbering, player heading, north arrow, scale bar and legend. The HUD adds source-backed ERC/SRC programme notes and Town Plaza as a nearby landmark. See [M2.2 documentation](docs/M2_2_MAP_NAVIGATION.md). All positions, dimensions and route geometry remain provisional; this is not a real navigation or accessibility map.

## M2.3 OSM and terrain reference baseline

The dated OSM snapshot is campus-filtered by the OSM boundary and retains original, uncut way geometry plus IDs, versions, timestamps, tags and node geometry. The minimap displays OSM buildings and landcover with **O**; **P** independently toggles the denser pedestrian-way network. A public SLA Land Survey-derived contour layer contributes 5 m, 10 m, 15 m, 20 m and 25 m lines; **T** toggles these planimetric references. The contour layer's vertical datum is not specified, so no absolute Y elevation or ramp grade is inferred. See [M2.3 GIS baseline](docs/M2_3_GEOSPATIAL_BASELINE.md).

## M2.4 OSM footprint shells

ERC (OSM way 124549217) and SRC (OSM way 125774787) now have separate, site-local extruded footprint shells in Godot, generated from their original OSM polygon rings. Press **G** to compare them with the existing proxy visuals. Estimated shell heights are 13.8 m (ERC) and 14.6 m (SRC), derived from OSM `building:levels` multiplied by the estimated M2 storey pitch; they are not measured heights. The OSM shells have no collision, and the original proxy collision remains active. Blender CI also generates editable .blend and GLB previews. See [M2.4 documentation](docs/M2_4_OSM_BUILDING_SHELLS.md).

## M2.5 campus atmosphere and exploration

The scene now has original procedural grass and paver textures, varied low-poly tree instances, four illustrative benches, three warm-light poles and a generic wayfinding totem. **N** toggles a manual day/night lighting preview; **E** discovers four source-backed UTown places and tracks progress in the campus passport. The furniture coordinates are art placements inside the approximate Town Green polygon, not claims about real existing amenities. See [M2.5 documentation](docs/M2_5_CAMPUS_ATMOSPHERE.md).
