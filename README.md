# NUS-3D — University Town (UTown)

> A community-made, exploratory 3D reconstruction of the National University of Singapore campus. **Start with University Town; expand only after a playable vertical slice works.**
>
> Status: **Planning / source collection (2026-10-24)**. No 3D model, terrain survey, or playable build has been completed yet.

[中文项目计划](docs/PROJECT_PLAN.md) · [建模与技术规范](docs/TECHNICAL_DESIGN.md) · [参考资料与版权](docs/REFERENCE_SOURCES.md) · [地标清单](data/utown_landmarks.csv) · [任务 Issues](https://github.com/stloendays/NUS-3D/issues)

## Goal / 项目目标

重建可自由探索的 NUS University Town (UTown)：真实的道路/建筑空间关系、适当简化的建筑外观、热带植被、可行走的连廊与坡道。先保证**整体位置准确、比例可信、行走流畅**，再增加细节和互动。

- **第一版核心区**：Town Green + Town Plaza + Education Resource Centre (ERC) + Stephen Riady Centre (SRC)。
- **周边占位模型**：Tembusu College、College of Alice & Peter Tan (CAPT)、Residential College 4 (RC4)、Cinnamon College、UTown Residence、CREATE；待核实后按批次完善。
- **暂不做**：整个 Kent Ridge 校区、所有室内、精细 BIM、联网多人、自动真实校车仿真。
- **原则**：不是 NUS 官方项目；不要将尚未验证的点云、建筑高度或模型授权表述为已取得。

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

**入口：Town Green 草坪边 → Town Plaza → ERC → SRC → 返回 Town Green。**

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
└── tools/               # future GIS/asset verification scripts
```

Only documented directories/files are created now; the others are **planned**, not implemented.

## Attribution & use / 使用和授权

- 本仓库是独立学习与创作项目，**非 NUS 官方发布**。
- NUS 地图、全景与第三方照片用于观察参考；未确认可再分发前，不把原图/截图上传为仓库资产。
- OSM 数据遵循 [ODbL](https://www.openstreetmap.org/copyright) 并需适当署名。
- Campus3D 的公开站点标注 CC BY-NC-SA 4.0（非商业）；即使能下载，也应先核对适用范围。
- 对外发布模型/截图/安装包前，逐项复查来源、NUS 标识使用权与第三方授权。

## Immediate next action

打开 [Issues](https://github.com/stloendays/NUS-3D/issues)，从 **M0: UTown geospatial baseline** 开始：确定 Town Green 原点、研究 OSM building footprint、测量核心区尺度，录入地标清单。**不要在地理基准确认前批量精细建模。**
