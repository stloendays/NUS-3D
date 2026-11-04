# UTown-first project plan / NUS-3D 开发计划

Date: 2026-11-04 · Status: **M2 ERC/SRC architecture alpha implemented, with M1 survey and on-device acceptance still pending**

## 1. 产品定位

做一个普通 Windows 电脑能流畅运行、可第一人称探索的 NUS University Town 数字场景（未来可扩展为 Three.js 网页）。核心价值是 **熟悉 NUS 的人在正确的空间关系里认出建筑和道路**，而不是一开始追求电影级画质。

**优先顺序**：空间布局准确 > 地面可行走与坡度 > 主要建筑辨识度 > 光照植被 > 小道具 > 可选互动。

### 目标用户

- NUS 学生/校友：漫步、回忆校园、截屏。
- 准新生/访客：提前熟悉 UTown，建筑标签与定点视角。
- 自身学习：积累可复用的 Blender/Godot/Three.js 资产与 GIS 工作流。

### 非目标（第一版）

- 不覆盖整个 NUS；不需要内饰高精度或所有建筑开放。
- 不把官方地图当做准确可量尺的施工图。
- 不用未获许可的谷歌卫星图/街景纹理“贴图复刻”。
- 不引入 AI NPC、真实实时数据、多玩家服务器等高成本功能。

## 2. 场景范围与地标优先级

**P0 可玩闭环**

| 地标 | 第一版建模目标 | 核验重点 |
|---|---|---|
| Town Green | 草坪边界、道路/台阶、树木大体分布 | 面积、坡度与周围视线 |
| Town Plaza | 铺装地面、廊道、入口关系 | 与 Green/ERC/SRC 的连接 |
| Education Resource Centre (ERC) | 可辨识建筑体量、立面与主要入口 | 楼层比例、朝向、楼梯/连廊 |
| Stephen Riady Centre (SRC) | 建筑体量、外立面、出入口 | 对外广场关系、标高、立面 |

**P1 周边轮廓**（先占位，后精修）：Tembusu College、College of Alice & Peter Tan、Residential College 4、Cinnamon College、CREATE、UTown Residence。

**P2 扩区**：College Avenue East/West、College Link 连通主校区的路线及其他住宅/教学区；根据当前地图和名称重新核对。

地标及证据状态统一记录在 [data/utown_landmarks.csv](../data/utown_landmarks.csv)。旧版地图中的学院名称可能与现行使用名称不同，以官方当期来源为准。

## 3. 开发节奏和每阶段交付

### M0 — Geospatial baseline / 地理数据准备

- [ ] 查 UTown 当期官方地图；2024 PDF 只做命名/拓扑参考（其页面标注 not to scale）。
- [ ] 用 OSM 获取建筑轮廓、园路、台阶、树木/草坪等矢量数据；记录 OSM 抓取日期与 ODbL attribution。
- [ ] 以 Town Green 的后续实测/核实中心点作为局部坐标原点；坐标转换遵循技术规范。
- [ ] 创建四大 P0 地标的俯视标注图、立面参考清单、几何质量等级。
- [ ] 查验航拍/街景/360° 图的许可，先保存链接和拍摄角度，不盲目上传照片。
- [ ] 单独核查 Digital Twin 的建筑资产可下载性与再利用许可，不把网页的模型列表当成授权。

**验收**：一个带来源的平面总图；P0 建筑轮廓与关键路径有可复现坐标；从 360° 能辨识关键视角。

### M1 — Greybox / 空间占位模型

**2026-10-24 progress:** [第一版 Godot 灰盒](M1_GREYBOX.md)已经加入 `godot/`：简化 Green/Plaza、ERC/SRC 大体量与周边建筑、基础碰撞、第一人称控制、路径指示、简图和数据来源说明。**还未达到本阶段验收**：路线、坡道与建筑尺度未现场验证，Blender GLB 资产尚未制作，Windows 真机性能未实测。

- [ ] Blender 按米建立 Green/Plaza/ERC/SRC 占位几何；确定高度、入口朝向和地形高差的可信来源。
- [ ] 导出 GLB；模型原点、命名、比例一致。
- [ ] Godot 加入第一人称控制、地面碰撞、建筑碰撞、简易路径和起点。
- [ ] 实地核验概念闭环：Green → ERC → SRC → Plaza → Green（现有 JSON 顺序；不可作为实际校园导航）。
- [ ] 提供一张固定视角对比图（实景参考 vs 引擎截图）。

**验收**：能连贯绕行，不穿模，不会因上下台阶而卡死；人物大小和建筑比例看起来合理。

### M1.5 — Data integrity and scene consistency / 数据校验与场景一致性

**2026-11-03 progress:** a standard-library Python validator and regression tests now check the source JSON before Godot imports it. Checks cover WGS84 coordinate ranges, duplicate IDs, Town Green polygon area/self-intersection, positive building dimensions, rotated massing bounds, walkway-to-route endpoint alignment and attribution fields. Godot vegetation placement now tests each rotated building part and conceptual paths instead of relying on a circular distance from building centres. The 64 accepted tree positions are rendered through two MultiMesh batches (trunks and canopies).

- [x] Add `tools/validate_utown_data.py` and regression tests under `tools/`.
- [x] Run data validation and Python unit tests in GitHub Actions alongside the Godot smoke test.
- [x] Expand the provisional ground depth from 720 m to 800 m: the RC4 proxy reaches about 372 m north of the local origin, beyond the old 360 m half-depth.
- [x] Render 64 procedural trees through two MultiMesh batches, reducing the tree scene from 128 individual mesh nodes to two draw batches.
- [ ] Keep all estimated geometry visibly labelled as provisional; automated checks do not replace a field survey.

**验收**：source JSON has zero structural/extent errors, Python tests pass, Godot smoke test passes, and all remaining uncertainty is clearly documented.


### M1.6 — Proxy walkway clearance (not field-georeferenced)

**2026-11-04 engineering progress:** the existing ERC-to-SRC conceptual guide crossed an SRC estimated massing. Two east-side schematic offsets now avoid the in-engine footprint, and a reproducible audit checks all route segments against rotated building parts using **walkway half-width + 0.75 m** clearance. Python regression tests and a CI JSON report cover the check.

- [x] Record the original proxy collision and prevent re-introduction with tests.
- [x] Clear the conceptual route against existing proxy buildings in 2-D.
- [x] Produce CI machine-readable per-segment clearance evidence.
- [ ] Validate actual walkways, ramps, entrances, ground elevations and accessibility in person or with appropriately licensed GIS/photo sources.
- [ ] Check the route in a Godot/Windows graphical walkthrough; 2-D audit does not test vertical circulation.

**No survey claim:** corrected guide points are schematic geometry. Refer to [M1.6 route audit](M1_6_ROUTE_CLEARANCE.md) before using any coordinates outside the prototype.

### M2 — Recognizable architecture / 建筑辨识度

**2026-11-04 progress:** Godot now creates non-colliding, independently toggleable architectural details for ERC (faceted glazing, sunshades, canopy) and SRC (forum disc, layered bridges and glass). Parameters and evidence are recorded in `godot/data/m2_profiles.json` and validated in CI. `blender/build_m2_blockouts.py` generated actual .blend and GLB assets in a Blender 4.0.2 GitHub Actions run; exported model visuals and imported Godot scenes remain uninspected. See [M2 architecture study](M2_ARCHITECTURE.md).

- [x] Research real architectural motifs and keep numeric dimensions marked estimated.
- [x] Implement independent M2 visual layers and F2 greybox comparison.
- [x] Add reproducible Blender 4.x authoring script plus profile validator.
- [ ] Verify building heights, facade geometry, courtyard/Forum placement and true entrances on-site.
- [ ] Generate and visually inspect Blender and GLB assets, then explicitly replace selected in-engine proxies.
- [ ] Validate Windows GUI rendering, sightlines and pedestrian routes.

- [ ] 给四个 P0 地标建外立面：柱子、玻璃幕墙、屋檐/遮雨棚、主要入口。
- [ ] 增加常见道路材料：混凝土、地砖、草坪、玻璃、深浅灰金属。
- [ ] 远处 P1 建筑采用低细节模型，不在尚未测量的内部空间花时间。
- [ ] 给重要场所增加简短建筑标签（可关闭）。

**验收**：没有建筑标签也能从正确路线辨识至少 ERC/SRC/Town Green；资源列表完整。

### M3 — Atmosphere / 环境与交互

- [ ] 热带树木和绿篱使用复用模型及 MultiMesh/实例化。
- [ ] 可调整的时间/日光；可选温和阴雨氛围，避免高成本体积效果。
- [ ] 简单行走音效，照片模式（隐藏 UI + 自由相机）可作为加分项。
- [ ] 支持暂停、图形档位、鼠标灵敏度、重置位置。

**验收**：白天场景观感完整，场景漫步不卡顿，低档图形选项可用。

### M4 — Release / 发布与检查

- [ ] Windows 导出独立可运行版本，并在一台非开发电脑上试运行。
- [ ] 记录 1080p 性能测试结果：帧率分布、加载时间、显存/内存峰值（硬件配置随报告记录）。
- [ ] 逐项清点资产版权、第三方许可、OSM 署名和 NUS 非官方声明。
- [ ] 录制 60–90 秒 walkthrough，并提供用户操作说明。

**验收**：第一次下载也能正常走完整条路线，素材合规说明可追溯。

### M5 — Optional Three.js / 网页版

- [ ] 同一个 GLB 资产包可在 Three.js 中加载、显示建筑标签。
- [ ] 自由漫步/轨道相机（优先其中一种）。
- [ ] 对复杂场景做分块加载和 LOD，避免一次下载完整建筑库。
- [ ] 保持 Godot 与网页使用同一地标 ID 和几何坐标系统。

## 4. MVP 可玩行为定义

- 角色：WASD 行走、鼠标看向、Shift 跑、Esc 释放鼠标；移动速度以现实步行量级设定并可调整。
- 视角：真实比例第一人称；相机高度默认 1.65–1.75 m 区间（最终可配置）。
- 交互：前期无复杂任务系统；最小 UI 只有位置提示、设置和建筑标签。
- 世界：同一套地理基准下摆放所有资产；不要单独手拖模型来“目测对齐”。

## 5. 设计原则与后续创意

**Must-have**：准确体量/路线、低复杂度植被、稳定性能、Windows 打包。

**Nice-to-have**：昼夜循环、雨天、拍照模式、景点说明牌、自由摄影视角。

**Later**：整个 Kent Ridge、地图导航/导览路线、轻量 NPC、多人漫步、小事件。扩区和玩法不能妨碍 UTown 第一版验收。

## 6. 核心风险

| 风险 | 对策 |
|---|---|
| 历史地图不按比例、建筑名变更 | 官方网站核对现名；轮廓采用 GIS；记录原始来源与版本 |
| OSM 建筑层数/高度不准确 | 单独标为 estimate；多视角核验，不冒充测量值 |
| Campus3D 对 UTown 数据未开放 | 基线完全独立于点云，用 OSM + 自建代理模型 |
| 第三方 Digital Twin 模型授权不清 | 只做参考，不直接并入资产仓 |
| GPU/CPU 性能不足 | 控制贴图、分块、实例化、LOD、分档阴影 |
| 双引擎维护成本 | Godot 优先；用 GLB/CSV 解耦，网页版本后置 |
| 过度追求建筑细节 | 每阶段验收后再升精度；优先完成闭环路线 |

## 7. 下一步执行顺序

1. 运行 `python tools/validate_utown_data.py`，确认源数据与 CI 检查通过。
2. 现场核验 Town Green、Town Plaza、ERC、SRC 的步行路线、入口、坡道、楼梯和标高；记录测量来源与置信度。
3. 根据核验结果更新 P0 地标坐标、轮廓和步行路径，再重新运行验证器。
4. 完成固定视角实景/引擎截图对比后，再制作 ERC/SRC 的 Blender 可编辑模型并导出 GLB。
