# M3.10 — UTown 建筑外观与层数校正（非实测建筑）

本工作修正已核实的层数和部分外形轮廓，不是摄影测量或工程级 BIM。未更改已有交互、地理锚点、通行路线或实体碰撞体。

## 修正清单

| 建筑 | 原版 | 修正与证据 |
|---|---|---|
| ERC | 两个矩形块约 12.5/11.5 m | 4 层；估计 15.2 m；来源轮廓上层折面玻璃、檐线、竖向分格。Meinhardt: https://www.mfacade.com/projects/education-resource-centre-nus/ |
| SRC | 三块矩形主体约 12–13 m | 保留三层、论坛金属圆盘、连廊；用来源轮廓表现上层边界。DP Architects: https://www.dpa.com.sg/projects/stephen-riady-centre/ |
| CREATE Tower | 27 m 单一矮塔 | 16 层约 56.0 m、四面窗格；DP Architects 确认另有 3 栋中层楼，尚未测绘。https://www.dpa.com.sg/projects/createnus-utown/ |
| UTR North/South | 各 42 m | 两塔均为 01–25 层，视觉上估计约 81.25 m，逐层窗带。官方社区资料: https://utr.nus.edu.sg/residential-life/neighbourhood/ |

以上高度和层间距均为游戏比例估计，**不等于建筑实测高度**；其他 Tembusu/CAPT/Cinnamon/RC4 仍保留原有估计，避免凭空修改。

## 外立面与通行安全

- 使用项目已有 OpenStreetMap ERC/SRC 外轮廓（way 124549217、125774787），从 WGS84 投影到现有世界和建筑局部坐标系；轮廓只有平面，缺乏真实立面、庭院洞口、台阶、楼层高度信息。
- 新模型只把轮廓生成**上层玻璃幕墙带、水平檐口和竖向分格**。不将整个外轮廓拉成实心建筑；不在地面生成遮挡通行的墙或任何新增碰撞体。既有实体碰撞、路网、食堂与 NPC 路线完全保留。
- 原 ERC 曲面玻璃、SRC 上层连廊及圆盘保留。新外壳作为 ArchitecturalStudy_NotSurveyed 的子节点，继续随 F2 建筑研究开关切换。
- CREATE/UTR 楼层窗格每栋采用一个 MultiMesh 批次、共享窗户 Mesh/Material；修正层不进行逐帧循环与物理检测，减少节点与渲染提交开销。
- 原有 source OSM 边界和 M2.3 原始碰撞矩形 IoU 不变（ERC 34.95%、SRC 24.19%）。这些指标不代表新立面达到了实景一致性。
- © OpenStreetMap contributors，ODbL 1.0。项目没有内嵌原始第三方摄影、纹理或建筑模型。

## 验证

常规验证命令依次为：

1. python tools/validate_utown_data.py
2. python tools/audit_route_clearance.py --strict
3. python -m unittest discover -s tools -t . -v
4. godot --headless --path godot --import --quit
5. godot --headless --path godot --script res://tests/smoke_test.gd
6. godot --headless --path godot --script res://tests/building_accuracy_smoke_test.gd

专项检查 2 个来源外轮廓、3 个高层外立面、层数与估计高度、原有室外场景、F2、碰撞隔离、原天气材质和金币/食堂/NPC 系统保留。

**尚未做到：** 获取经过授权的建筑实拍、设计 CAD/BIM 以校准尺寸和 CREATE 中层楼群精确位置，以及在真实 Windows PC 上进行 GPU/RAM 与视角比对。此版本是可审计的视觉准确性修复阶段，而非 1:1 实测数字孪生。
