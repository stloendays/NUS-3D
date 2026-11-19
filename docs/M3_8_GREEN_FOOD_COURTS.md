# M3.8 — UTown Town Green 与食阁街景

该层为游戏中的**示意性**地景增强。食阁名称与所在设施需以现有地图/公开设施页面核对；下列摊位菜单、家具、布景和具体门口位置均为原创游戏元素，**不是实测建筑尺寸或正式商户名单**。

## 新增

- Town Green：保留源数据的多边形草坪；增加最多 2,000 株打包渲染的三角草叶，最多 4 块野餐布、笔记本、水杯与飞盘。草叶/野餐布与道路及草坪边缘保持距离，不添加碰撞体。
- Fine Food：挂在已有 Town Plaza 节点下，在原有顶棚附近增加 3 组示意摊位与 8 张用餐桌，含批量桌面、桌腿和凳子。
- Flavours @ UTown：以已有 SRC（Stephen Riady Centre）建筑体量生成临街食堂门头，**不在草坪上新增建筑**。
- ERC：新增学习咖啡区的简易指示牌，沿用现有 ERC 建筑节点。
- 所有地标文字可随 F7 照片模式隐藏；草叶材质共享天气系统已有雨天湿润逻辑。

## 内存与兼容

- 草坪细节由 1 个 MultiMesh 渲染，草叶共用 1 个 ArrayMesh、1 套材质。食堂重复家具以 MultiMesh 分组，所有尺寸相同的盒体及同色材质缓存复用。
- 仅运行创建期的空间采样，不进行逐帧全地图搜索；运行时每 0.24 秒检查一次照片模式可见性。
- 新逻辑在 `godot/scripts/utown_green_dining.gd`，`main.tscn` 只新增一个 `GreenDining` 场景节点，不修改原有导览、NPC、雨天、战斗、接驳车及账号存档。
- 只有视觉节点，无新碰撞体；因此不改变默认路径、安全间距和碰撞系统。草坪和食堂确切实景尺寸仍有待现场核验。

验收运行：
```bash
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/smoke_test.gd
godot --headless --path godot --script res://tests/arcade_smoke_test.gd
godot --headless --path godot --script res://tests/green_dining_smoke_test.gd
```
