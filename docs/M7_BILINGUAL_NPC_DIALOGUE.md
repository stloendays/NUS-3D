# M7 — 中文 / English 本地化与校园 NPC 搞笑对话

这是 NUS-3D 非官方离线游戏的双语系统。对话中的学生、老师、学业压力梗和地点事件均为虚构内容，不代表 NUS 官方观点或真实校园成员。

## 操作

登录页面和游戏内账户栏新增“中文 / English”切换按钮；F10 为快捷键。首次启动自动读取系统语言（中文或英文），之后保存选择至 user://nus3d_locale.cfg，与账号/邮件/XP 数据隔离。

中文模式覆盖登录注册、账户等级、邮件控件、系统邮件、六章新手教程、四站探索剧情、八份 Field Notes、挑战和天气 HUD、世界地标、小地图和帮助说明。英文模式恢复英语。游戏不会自动翻译玩家填写的用户名或私人邮件。

接近 NPC 按 Q 交谈，先听到固定的人设开场白，后来会随机吐槽 DDL、课程、实验、咖啡、校车及自习室；雨天偶尔触发额外台词。相邻的随机台词尽量避免相同句子。

## NPC 人设示例

| 角色 | 固定开场白 | 随机吐槽 |
|---|---|---|
| Maya · DDL幸存者 | 我研究如何在 DDL 前一天学完一学期。 | 我的 GPA 每学期都做自由落体。 |
| Ethan · 图书馆流浪者 | 我喜欢图书馆，因为有插座。 | 复习五分钟，调笔记字体一小时。 |
| Aisha · 校车追逐冠军 | 我追校车的速度比赶 DDL 还快。 | 校车已经开到下学期了。 |
| Lucas · 健身与拖延双修 | 我的健身计划自己练出了肌肉。 | 健身房杠铃比课程负担轻。 |
| Mei · 咖啡因工程师 | 咖啡若能算学分，我毕业三次了。 | 第三杯让我能徒手打指数符号。 |
| Daniel · 校园哲学家 | 人生三谜题：DDL、DDL、为什么还是 DDL。 | 地图说你到了截止日期边缘。 |

NPC 数据目前有 14 个人设：6 名室外学生、6 名室内角色和 2 名虚构老师。当前分支已经接入六名室外 NPC 的 Q 对话；室内 NPC 与教师的实体和交互尚在另一玩法分支，它们的双语台词作为兼容资源预留，未声称已经出现在本分支的场景中。

## 文件结构

- godot/data/language_catalog.json：UI 英文原文映射、游戏消息片段、路标和 Field Notes、四站任务剧情。
- godot/scripts/game_language.gd：Autoload GameLanguage，管理语言、设置保存、HUD/教程/系统邮件本地化。
- godot/data/startup_tutorial.json：六章中文与英文内容，英文使用 _en 后缀字段。
- godot/data/npc_dialogue.json：14 个人设的中英成对固定台词、随机台词与天气台词。
- godot/scripts/game_dialogue.gd：Autoload DialogueBank，首见固定介绍、后续随机选择、连续重复抑制，不改变 XP。
- godot/scripts/utown_campus_life.gd：接入原本的六名室外 NPC 的 Q 对话，不改变其巡逻/动作/路线。
- godot/scripts/game_shell.gd、hud.gd、minimap.gd：UI 与动态任务、天气、地图文本显示层。

## 验证

从仓库根目录运行：

    godot --headless --path godot --import --quit
    godot --headless --path godot --script res://tests/language_smoke_test.gd
    godot --headless --path godot --script res://tests/account_smoke_test.gd
    godot --headless --path godot --script res://tests/smoke_test.gd

独立 CI 为 .github/workflows/i18n.yml。Windows 导出完整性测试还检查语言目录和 NPC 对话文件已打包。

## 当前边界

台词是本地审核过的文字池，不是 AI 即时生成、语音配音或联网聊天。英文为无翻译词条时的默认回退。新增玩法分支的字符串要进入语言资源目录，并应在合并后做双语回归。正式发布前仍需手动检查 Windows 简体中文字体、按钮宽度和不同分辨率的显示。
