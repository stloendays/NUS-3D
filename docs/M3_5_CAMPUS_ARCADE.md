# M3.5 — Campus Arcade / 校园搞笑对决

本功能是虚构的非致命卡通玩法，独立于 NUS-3D 的建筑、天气、校园生活、导览和账号系统，不代表真实 NUS 人员或校园事件。

## 游戏机制

- 复用现有六名学生 NPC 行人（不再生成另一组）。他们保留原来的巡逻和 Q 对话能力。
- 学生有 3 点 Focus；达到零值会进入约 16 秒的 Snack Break，之后恢复。每次成功进入休息状态获得 30 XP，休息期间不能重复领取。
- 三种玩具：1 纸飞机（Lv 1；1 Focus）；2 粉笔发射器（Lv 2；2 Focus）；3 橡皮鸡（Lv 3；3 Focus，射程短）。鼠标左键或 J 投掷，不是真正武器。
- 两位虚构老师：Prof. Deadline 和 Dr. Plot Twist。靠近按 K 听恶搞作业并领取每人一次性的 20 XP。无法对老师造成伤害。
- 升级所需经验为 80 + (当前等级 - 1) × 45。游戏等级只保存在独立文件 user://nus3d_arcade_progress.cfg，不写入 Explorer、活动或账号系统存档。
- 骑自行车、乘接驳车、室内探索或 F7 隐藏 HUD 时不能投掷。不修改既有按键和玩法。

## 内存与性能

- 学生模型沿用 UTownCampusLife.pedestrians 的节点引用；不复制人物模型，也不创建第二个 NPC 巡逻循环。
- 老师使用低面数几何体，共享 BoxMesh 和 StandardMaterial3D；共享资源缓存按形状、颜色分组。
- 初始仅预分配 8 个投射物 MeshInstance3D、共享一个 SphereMesh，使用固定长度循环对象池，不随连续发射而新增节点。
- 命中目标候选仅为 6 名学生与 2 名老师，在发射时才检测遮挡；日常不执行全场物理扫描。
- 学生标签只在 Focus 改变或休息倒计时的整数秒变动时更新，状态面板每 0.25 秒刷新一次，避免逐帧创建 HUD 字符串。

## 代码隔离与验收

核心逻辑：godot/scripts/utown_arcade.gd，主场景注册一个 Arcade 节点。既有校园生活/天气/导航脚本均保持原样。新分支 feature/m3-5-campus-slapstick-20261119 基于未合并的 M3.4 功能分支创建，建议使用 stacked PR 评审，不直接重置或覆盖其他进程。

在 Godot 4.4.1+ 环境执行：

    godot --headless --path godot --import --quit
    godot --headless --path godot --script res://tests/smoke_test.gd
    godot --headless --path godot --script res://tests/arcade_smoke_test.gd

新增自动测试包含 NPC 引用复用、老师奖励、升级/装备解锁、重复经验限制、休息恢复、独立存档、交通/室内禁用、照片模式以及连续 40 次投掷的内存上界。实际内存峰值（RSS / VRAM）与 GPU 帧率需在目标 Windows 设备上测量，不能只由对象池测试代替。
