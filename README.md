<div align="center">

# NUS-3D

### Campus chaos, one deadline at a time.

**一款以新加坡国立大学校园为灵感的低多边形、搞笑解压 3D 探索游戏。**

Explore campus. Survive coursework. Miss the bus. Repeat.

[![Godot](https://img.shields.io/badge/Godot-4.4.1%2B-478CBF?logo=godot-engine&logoColor=white)](godot/project.godot)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Godot-30343B)](docs/M4_WINDOWS_BUILD.md)
[![Status](https://img.shields.io/badge/Status-Experimental%20prototype-F2B94B)](docs/INTEGRATION_QA_2026-11-19.md)
[![Build](https://github.com/stloendays/NUS-3D/actions/workflows/windows_build.yml/badge.svg)](https://github.com/stloendays/NUS-3D/actions/workflows/windows_build.yml)

**[Get the Windows preview](https://github.com/stloendays/NUS-3D/actions/workflows/windows_build.yml)** · **[Run in Godot](#-quick-start--快速开始)** · **[Gameplay](#-gameplay--玩法)** · **[Roadmap](#-roadmap--开发路线)** · **[Contribute](#-development--参与开发)**

</div>

---

## 🎮 Gameplay / 玩法

| Explore / 校园探索 | Survive / 校园生存 | Unwind / 解压玩法 |
| :--- | :--- | :--- |
| Low-poly UTown, stylized buildings, day/night, weather and campus NPCs | Coursework, presentations, DDL satire, faculty choice and comic campus events | Coins, shops, bicycles, casual challenges, leisure activities and post-course unlocks |
| Walk, discover interiors, photograph campus and follow a minimap | Build progression through missions rather than endless grinding | Find absurd encounters and revisit the campus after the main tasks |

**The tone:** playful, exaggerated, colorful and approachable — recognizable NUS-inspired spaces, not a serious campus simulator.

> **Development status (19 November 2026):** The experimental `main` build includes UTown and a **schematic** Kent Ridge/Science expansion, Frontier canteen, a sports ground, selectable D1/D2 game shuttle travel, an MD1 landmark, bilingual oral-presentation tasks, a redesigned minimap and an optional F11 Campus AI/links panel. Real-world scale, routes, building geometry and performance on physical Windows GPUs remain unverified. More interiors, terrain, NPCs and cosmetics are under active development.

## 🚀 Quick start / 快速开始

**Option A — Windows portable preview**

1. Open [Windows portable preview workflow](https://github.com/stloendays/NUS-3D/actions/workflows/windows_build.yml).
2. Choose a **successful** workflow run and download its Windows artifact.
3. Extract the ZIP and keep the `.exe` and `.pck` together; launch the EXE.

The preview is unsigned and experimental. A successful CI export is **not** a guarantee of performance on every GPU. See [Windows build notes](docs/M4_WINDOWS_BUILD.md).

**Option B — Godot editor**

```bash
git clone https://github.com/stloendays/NUS-3D.git
cd NUS-3D
godot --editor --path godot
```

Use **Godot 4.4.1 or newer**. Import the project, open the main scene, and press **F5**. The core controls are **WASD** to move, mouse to look, **Shift** to run, **M** for minimap, **P** for coursework, **F5** for the in-game cosmetic wardrobe, **F6** for the GIS geometry overlay, **F11** for optional Campus AI, and **Esc** to release the mouse. See the [full control guide](docs/M1_GREYBOX.md) and in-game prompts for context-sensitive actions.

## 🗺️ World / 游戏世界

**Available on `main`:** UTown Town Green, Town Plaza, ERC and SRC; schematic Kent Ridge districts including Science/Frontier, sports facilities, MD1, campus game buses, time/weather, course challenges, an F5 cosmetic character wardrobe preview and optional F11 Campus AI links.

**In draft / pending verification:** more detailed faculty-specific facilities, optimized 3D props, advanced terrain elevations, richer NPC interactions and a verified Windows auto-update path. All campus geometry and game transit links are stylized interpretations, **not surveyed buildings or official shuttle navigation**.

[Official campus map reference](https://map.nus.edu.sg/) · [Science / Frontier integration #48](https://github.com/stloendays/NUS-3D/pull/48) · [MD1 #49](https://github.com/stloendays/NUS-3D/pull/49) · [Map art #50](https://github.com/stloendays/NUS-3D/pull/50) · [Campus AI #66](https://github.com/stloendays/NUS-3D/pull/66)

## 🧭 Roadmap / 开发路线

| Area | Direction |
| :--- | :--- |
| Campus fidelity | Recognizable buildings, landscape, covered walkways, lighting and natural map edges |
| Player experience | Tactile menus, 3D UI depth, sound design, contextual prompts and better onboarding |
| Campus comedy | DDL story arcs, coursework, presentation challenges, distinct NPC personalities |
| Open-world systems | More districts, transit, canteens, sports and optional minigames |
| Reliability | Stable input ownership, low-memory assets, graphics scalability, save compatibility |
| Multiplayer readiness | Modular network-friendly systems; multiplayer is **planned**, not a released feature |

## 🛠️ Development / 参与开发

Built primarily with **Godot 4 / GDScript**, procedural low-poly geometry, structured campus data and GitHub Actions. New features should be scoped to independent branches/PRs, preserve existing input and save systems, and include focused smoke tests.

- [Issues & tasks](https://github.com/stloendays/NUS-3D/issues)
- [Open pull requests](https://github.com/stloendays/NUS-3D/pulls)
- [Project plan](docs/PROJECT_PLAN.md) · [Technical design](docs/TECHNICAL_DESIGN.md)
- [Reference sources and licensing](docs/REFERENCE_SOURCES.md)
- [Integration QA](docs/INTEGRATION_QA_2026-11-19.md)

## ℹ️ Disclaimer

NUS-3D is an **independent fan-made, unofficial project**. It is not affiliated with, endorsed by, or operated by the National University of Singapore. Campus names and layouts are used for creative reference. No Google Maps/Street View imagery or proprietary 3D assets are redistributed as game content. Any external assets must have verifiable usage rights.

---

<details>
<summary><strong>Historical technical README / 早期技术说明（展开查看；旧版本状态不代表当前 main）</strong></summary>

# NUS-3D — University Town (UTown)

> A community-made, exploratory 3D reconstruction of the National University of Singapore campus. **Start with University Town; expand only after a playable vertical slice works.**
>
> Status: **M2/M3 source-informed UTown + Coursework/cinematic + comic DDL/landscaping/arcade/coins/leisure + M5 local accounts and mailbox + M6 tactile HUD/audio + M7 bilingual NPCs + M4 experimental Windows build (2026-11-19)**. Source-driven detail layers are playable in Godot, but building scale, pedestrian routes, terrain and Windows performance have not been verified.

[登录单语言规范（M18）](docs/M18_SINGLE_LANGUAGE_LOGIN.md) · [Windows 便携版构建与使用](docs/M4_WINDOWS_BUILD.md) · [启动 Godot 原型](docs/M1_GREYBOX.md) · [M2 ERC/SRC 建筑模型](docs/M2_ARCHITECTURE.md) · [M2.1 实景视角核验](docs/M2_1_VIEWPOINT_CALIBRATION.md) · [M2.2 OSM 轮廓对比](docs/M2_2_OSM_REFERENCE.md) · [M2.3 轮廓误差量化](docs/M2_3_FOOTPRINT_FIT.md) · [M3 氛围/拍照模式](docs/M3_ATMOSPHERE.md) · [M3.1 UTown Explorer 互动探索](docs/M3_1_CAMPUS_DISCOVERY.md) · [M3.2 可玩挑战](docs/M3_2_PLAYABLE_CHALLENGES.md) · [M3.3 校园生活与天气](docs/M3_3_CAMPUS_LIFE_WEATHER.md) · [M3.4 室内与雨天升级](docs/M3_4_INTERIOR_WEATHER_POLISH.md) · [M3.5 材质灯光与室内 NPC](docs/M3_5_MATERIALS_INDOOR_LIFE.md) · [M3.6 选择学院与 Coursework 任务](docs/M3_6_COURSEWORK_FACULTY.md) · [M3.7 入场动画](docs/M3_7_CINEMATIC_INTRO.md) · [M1.5 数据验证](docs/M1_5_DATA_VALIDATION.md) · [M1.6 步行路径碰撞审计](docs/M1_6_ROUTE_CLEARANCE.md) · [中文项目计划](docs/PROJECT_PLAN.md) · [建模与技术规范](docs/TECHNICAL_DESIGN.md) · [参考资料与版权](docs/REFERENCE_SOURCES.md) · [地标清单](data/utown_landmarks.csv) · [任务 Issues](https://github.com/stloendays/NUS-3D/issues)

## Goal / 项目目标

重建可自由探索的 NUS University Town (UTown)：真实的道路/建筑空间关系、适当简化的建筑外观、热带植被、可行走的连廊与坡道。先保证**整体位置准确、比例可信、行走流畅**，再增加细节和互动。

- **第一版核心区**：Town Green + Town Plaza + Education Resource Centre (ERC) + Stephen Riady Centre (SRC)。
- **周边占位模型**：Tembusu College、College of Alice & Peter Tan (CAPT)、Residential College 4 (RC4)、Cinnamon College、UTown Residence、CREATE；待核实后按批次完善。
- **暂不做**：整个 Kent Ridge 校区、完整楼层级室内复刻、精细 BIM、联网多人和真实校车时刻/路径仿真。当前室内和交通仅是独立的玩法原型。
- **原则**：不是 NUS 官方项目；不要将尚未验证的点云、建筑高度或模型授权表述为已取得。

## Integrated playable game (PR #20)

The integration branch combines formerly separate arcade, coursework, campus-life, comic DDL story, food courts, coins and delivery, contextual guide, offline profile/messaging and bilingual HUD features. The merge is gated by actual CI and GUI review; do not assume the draft branch is release-ready.

**Controls:** P = Coursework journal; Shift+P = faculty; K = accept/submit tasks; J = Campus Post; Tab = Post-Course Club after completing one faculty; U = professor; left mouse = cartoon toy; 1–3 = choose unlocked toy; H = fictional DDL step or direction pulse; Z = coin pickup; O = shop; N = food delivery; F9 = UI sound; **F10 = choose Chinese/English on the login screen only**. During play, every game-authored text uses the language chosen at sign-in. Existing WASD/E/C/V/Q/I/L/F/B/X/T/Y/M/F1/F7 controls remain.

Per-account feature saves are separated for Coursework, arcade, outdoor/indoor activities, coins, DDL and leisure. XP is imported into the account level once per cumulative source; no repeated level grants. Older single-device saves are copied (not erased) only into the first newly registered profile. This is not real NUS SSO, cloud email or financial money.

**QA:** [Integration controls, automatic checks and manual GPU checklist](docs/INTEGRATION_QA_2026-11-19.md). The source-informed high-rises and facades are still provisional; no accurate field survey or full Kent Ridge campus model is claimed.

## Single-language player experience (M18)

At the login screen, choose **English** or **中文**. All authored gameplay interfaces and dialogue use only that selection for the entire signed-in session; the game no longer mixes Chinese and English labels or permits F10 to switch languages mid-game. Logging out makes the language picker editable again. The selected login language is remembered in the local player profile without changing XP, coursework, email, settings or saved exploration progress.

The login language controls **all 39 fictional Coursework chapter stories**, menus, the cinematic intro, club chess/cards/social dialogue, original DDL stories, arcade, coins/delivery, directional HUD, LAN controls and exam interface. Original English exam questions remain in English by design, and user-written mail and usernames are never altered. Unmerged feature branches must adopt the same language API when integrated.

Details, save boundaries and QA checklist: [M18 Single Language at Login](docs/M18_SINGLE_LANGUAGE_LOGIN.md).

## Play the first prototype / 运行第一版

Download the repository, install **Godot 4.4.1+**, import `godot/project.godot`, then press **F5**. Walk using **WASD**, turn with mouse, **Shift** to run, **R** to reset, **M** to toggle the map, **F2** to compare the original greybox against provisional ERC/SRC architectural layers, **T** to cycle daylight/golden-hour/blue-hour/evening, **E** to discover a nearby tour stop, **G** to replay the completed tour, **C** to collect Field Notes, **V** to start/cancel Campus Sprint, **Y** to cycle weather, **Q** to talk to fictional NPCs, **I** to enter/exit illustrative ERC/SRC interiors, **L** to use the interior mezzanine lift, **F** to discover six indoor activity spots, **Shift+P** to choose/change faculty, **P** to inspect the Coursework journal, **K** to accept/submit a mission at a glowing coursework marker, **B** to ride a bicycle, **X** to board/alight the moving shuttle, **F7** to hide the HUD for photos, **F6** to show/hide ODbL-attributed ERC/SRC outlines and their IoU/coverage card, **F3** to cycle public-geotag camera viewpoints, **F4** to save original screenshot and JSON provenance, **Esc** to release mouse. See [M1_GREYBOX.md](docs/M1_GREYBOX.md) for limitations, validation and licensing.

The prototype has procedural low-poly buildings, a ground plane, an approximate Town Green, a conceptual walking loop, lighting, trees and HUD. **It is not a precise site survey, a completed M1/M2 milestone, or a Windows installer.**

The source-data validator checks coordinate ranges, polygon integrity, rotated building bounds, route continuity and attribution fields. Procedural trees avoid building footprints and conceptual walking paths, and 64 trees are rendered in two MultiMesh batches rather than 128 separate mesh nodes. These checks improve data and rendering efficiency; they do not establish real-world accuracy. M1.6 also generates an original top-down SVG spatial-audit plan (GitHub Actions artifact, not a true campus map) and audits conceptual route corridor widths against the estimated, rotated building footprints: one ERC-to-SRC leg was offset to avoid a proxy collision; the current 11-segment route passes the 2-D clearance check, **not a real-world accessible-path survey**.

## M4 alpha: Windows executable without installing Godot / Windows 便携试玩包

An **experimental, unsigned** x86_64 Windows build can be generated by [GitHub Actions (Windows portable preview)](https://github.com/stloendays/NUS-3D/actions/workflows/windows_build.yml). From a successful run, download the `NUS3D-UTown-Windows-Experimental` artifact, extract the inner ZIP and keep `NUS3D-UTown.exe` plus `NUS3D-UTown.pck` together. The ZIP contains a source-commit/SHA-256 manifest and an attribution and usage guide. Godot 4.4.1 is **not required** on the playback computer. A second job checks the actual exported EXE **headlessly on a Windows runner**; that is not Windows GUI/GPU performance certification, code signing or proof of real-world campus geometry. See [M4 build, acceptance and limitations](docs/M4_WINDOWS_BUILD.md).

## M16 — Windows 自动版本更新（官方 GitHub Releases）

Windows 便携版启动时会异步检查 `stloendays/NUS-3D` 的**稳定版 Release**。发现较新的 `vMAJOR.MINOR.PATCH` 后自动下载到本地缓存、校验 SHA-256，并显示 **RESTART & INSTALL / LATER**；只有玩家确认重启才会关闭游戏并安装。更新助手先验证 ZIP 与 EXE/PCK 清单、运行新版本自检、备份旧版本，再尝试替换；失败时不修改账号存档，尽力回滚。联网失败可以继续离线玩，编辑器/Linux/macOS 不启动 Windows 安装器。完整说明见 [Windows 自动更新与发版](docs/M16_WINDOWS_AUTO_UPDATES.md)。

**发版流程：** 更改 `godot/data/app_version.json` 的版本号并合并至 `main`，由维护者推送对应的 `vX.Y.Z` 标签。GitHub Actions 仅在稳定标签、Windows 构建、自检、SHA 校验均通过后发布正式更新包。目前没有发布过 GitHub Release，所以客户端暂时没有可以下载的新版。普通 PR/CI 构建不算正式更新源。

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
| M3 — Atmosphere & play | 有生命感且可互动的校园 | 天气、NPC、示意室内、自行车、循环穿梭巴士和可重复挑战均可运行；图形界面验收另行完成 |
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

## M2.2 geographical reference overlay

A source-frozen, dated OSM vector snapshot for ERC (way 124549217, v18) and SRC (way 125774787, v15) is provided in godot/data/osm_p0_reference.json with individual polygon nodes and ODbL attribution. Press **F6** to overlay bright ERC/SRC outlines in the 3D world and minimap, or use the CI-generated utown-osm-comparison.svg top-down drawing. The independent overlay has NO collisions and is hidden by default: it deliberately shows mismatches rather than making unsurveyed geometry look accurate. [Provenance and limits](docs/M2_2_OSM_REFERENCE.md).

## M3 alpha: time-of-day and photo controls

Press **T** for four hand-authored day/lighting states, **F7** to hide the HUD, **F4** to capture an original in-game PNG with metadata. Procedural unshadowed path lanterns illuminate blue-hour/evening views, without claiming real NUS lighting locations. CI compares the Daylight and Evening scene on Linux; Windows GPU performance and the real campus light schedule are unverified. [M3 guide](docs/M3_ATMOSPHERE.md).

## M3.1: four-stop offline campus discovery

The playable scene now includes an original, optional **UTown Explorer** check-in activity across the four existing schematic stops. Get within 12 m in-game and press **E** to unlock a short model-aware description. The HUD tracks 0/4 through 4/4, and the minimap distinguishes visited, active and upcoming checkpoints. **G** restarts the completed exploration. No GPS, real directions, online service, account or third-party content is involved; the game references the existing waypoint IDs rather than duplicating latitude/longitude. Python/Godot and exported-Windows-runtime tests check the four-stop contract. See [M3.1 usage, validation and limits](docs/M3_1_CAMPUS_DISCOVERY.md).

## M2.3 P0 footprint coverage scorecard

M2.3 now computes reproducible, exact-in-local-projection plan-view IoU, two-sided area differences and centroid offset between the current ERC/SRC multi-part box massing and independently archived OpenStreetMap outer-ring polygons. CI publishes both `build/osm-proxy-fit.json` and an original SVG scorecard in `utown-route-clearance-audit`. **These are dataset agreement statistics, not validated true building dimensions, roads or accessibility.** See [M2.3 methodology and caveats](docs/M2_3_FOOTPRINT_FIT.md).


## M3.2: Field Notes and Campus Sprint

Eight glowing Field Notes are interpolated along existing schematic walkway segments; press **C** nearby to collect one. Press **V** near Town Green to start the four-stop Campus Sprint (ERC → SRC → Town Plaza → return to Green). The timer awards a game-design medal, and collected-note IDs plus the best Sprint time persist in a local save file. See [M3.2 usage and save contract](docs/M3_2_PLAYABLE_CHALLENGES.md).

## M3.3: weather, campus life, interiors and transport

- **Weather:** press **Y** to cycle Clear, Cloudy, Overcast, Rain and Thunderstorm. Procedural clouds, rain particles and deterministic rain-streak MultiMesh, wet-ground puddles, ripple rings, fog and occasional lightning are local effects, not a live forecast.
- **Pedestrians:** six fictional low-poly student NPCs walk, pause at path ends and animate arms/legs. Press **Q** nearby for a short original dialogue line.
- **Interiors:** press **I** near the ERC or SRC conceptual approach to enter an original two-level study-lounge or recreation-atrium pocket; use **L** to switch between the ground floor and mezzanine, and **I** again to return. These are standalone illustrative rooms, not actual NUS floor plans or connected building interiors.
- **Bicycle:** press **B** to switch between walking and a faster bicycle mode. The follow camera eases into place, while wheels, pedals and handlebars animate.
- **Shuttle:** a procedural bus loops between the four existing conceptual waypoints. Press **X** near it to board and **X** again to alight. It is a gameplay vehicle, not a real NUS service or route.
- The minimap shows pedestrian and shuttle positions. All NPCs, interiors, vehicle geometry, weather and dialogue are offline and procedurally generated. No accounts, telemetry or network services are used.

See [M3.3 implementation and limitations](docs/M3_3_CAMPUS_LIFE_WEATHER.md). The current rooms and shuttle use isolated/estimated game-space positions; visual GUI testing and route/placement review remain necessary.


## M3.4: sheltered rooms, activities and wet-weather response

This original gameplay extension builds on M3.3 without claiming measured NUS interiors or real meteorology:

- ERC and SRC gain opaque sheltering roofs, warm/cool soffit lighting, ceiling diffusers, planters, room zoning, furniture and signs. ERC includes a cafe corner and reading nook; SRC includes a water refill counter, sports equipment wall and spectator lounge.
- A continuous sloped collision ramp now supports visible mezzanine stair treads; **L** remains a convenient lift shortcut. The indoor minimap shows an illustrative plan for each floor.
- Discover three fictional activity stations in each room using **F** at close range. Local progress persists in user://nus3d_campus_activities.cfg (no cloud accounts or telemetry).
- The conceptual plaza and pedestrian paths share two registered materials with rain-responsive roughness, metallic and darkening; grass darkens separately during rain. Puddles are now visibly above the walkway surface, with a pair per path entry. After rain, materials dry gradually while pools temporarily remain. Clouds, sun and fog also transition.
- Linux CI captures original in-engine M3.4 indoor and rain-state screenshots, not measurements or performance benchmarks.

See [M3.4 guide and QA limits](docs/M3_4_INTERIOR_WEATHER_POLISH.md). These are separate teleport-accessible game pockets, not reconstructed building floors. Stairs, collision feel and frame rate require a manual 3D GUI playtest.


## M3.5: original material finishing and occupied interiors

The two priority-0 conceptual ERC/SRC facade studies now contain a separate, **F2-toggleable** M3.5 visual finish: aluminum mullions, layered reflective-tinted glass, entrance canopy undersides, window sills, roof parapets and warm entrance lights. These are deliberately not measured facade reconstructions.

The illustrative ERC/SRC interior pockets receive tiled floors, transition grout, ribbed wall strips, mezzanine acoustic panels, glass accents and three additional room-local lights (including one shadow-capable light per room). Lighting adapts to the game's existing artistic time-of-day and rain mode; there are **no imported HDRI, textures, commercial 3D assets or real architectural plans**.

Six fictional interior characters are distributed across two rooms. Their simple looping routines depict cafe service, reading, upper-floor study movement, warm-up, spectating and a water-refill volunteer. Press **Q** near an indoor character to display original dialogue; outside, **Q** still talks to existing walking NPCs. Characters are non-colliding and spawn inside independent fictional room pockets rather than in real NUS spaces.

See [M3.5 gameplay and QA contract](docs/M3_5_MATERIALS_INDOOR_LIFE.md); this remains a low-poly Godot compatibility-renderer prototype, not photorealistic PBR validation or a completed campus digital twin.


## M3.6: Choose your Faculty + Coursework: The DDL Apocalypse

At first run, choose from **13 fictional gameplay faculty/academic-unit affiliations** based on public NUS academic names. Options include Science, Design & Engineering, Computing, Business, FASS, CHS, Medicine, Law, Dentistry, Music, NUS College, Public Health and Public Policy. The selector is a game-only roleplaying option, not real student affiliation or admissions data. Press **O** later to change it; each faculty's incomplete coursework progress is preserved.

Each faculty has an original, discipline-specific **3-chapter DDL comedy storyline** — 39 playable coursework chapters total. Follow the golden homework marker, press **K** to accept an assignment, use **F** at the relevant interior learning/recreation activity and **Q** with the right fictional groupmate, then rush back and submit with **K**. The clock starts on accepting a chapter. Missing the game deadline is **not a hard failure**: late submissions complete with a smaller reward. Grades, Coursework XP, levels and campus credits are in-game only, and existing exploration and traffic do not reset.

- **O**: choose/change faculty; **J**: journal and story; **K**: collect brief / submit.
- Coursework progress is stored locally in `user://nus3d_coursework.cfg`; it contains no player email, real transcript, academic schedule, network service or telemetry.
- Windows native-runtime validation includes the JSON, all 13 picker options and 39 quest chapters. Godot CI additionally captures real in-engine screenshots of the faculty picker, DDL HUD and mission journal.

See the [M3.6 coursework guide](docs/M3_6_COURSEWORK_FACULTY.md) for detailed gameplay, save rules and manual test limitations.


## M3.7 — Skippable 3D entrance cinematic

A **12-second Godot-rendered opening** now plays when launching the UTown game: a camera flies along the established conceptual Town Green → ERC → SRC → Plaza route while an original comedy storyline announces the looming Coursework DDL. Animated lettering, cinematic letterboxes, smoothly eased camera movement, four changing story captions, a progress bar and a skip control complete the intro. No pre-rendered footage or imported copyrighted assets are required.

- Skip with **Space**, **Esc**, **Enter** or a mouse click / top-right skip button.
- On first run, the cinematic ends on the faculty selector; on later runs it restores the saved faculty profile and normal first-person gameplay.
- The intro never changes spawn, route progress, grades, weather or saved work. DDL timer and player movement are paused during playback.
- Godot CI includes four actual viewport frames from the animated opening, plus tests for camera takeover, scripted beats, skipping and UI handoff.

Read [M3.7 intro documentation](docs/M3_7_CINEMATIC_INTRO.md). This original intro is artistic/fictional and does not show surveyed campus navigation or actual NUS coursework.


</details>
