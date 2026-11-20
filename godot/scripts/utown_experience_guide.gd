extends CanvasLayer
class_name UTownExperienceGuide
## Read-only, event-aware UX overlay. No key input, action calls, saves or new physics.
## Built for the standalone UTown gameplay scene; will coexist with account and M6 HUD layers.

const REFRESH_SECONDS: float = 0.22
const ZONE_RADIUS_M: float = 39.0

@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var tour: UTownTour = $"../Tour"
@onready var challenge: UTownChallenge = $"../Challenge"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var indoor_npcs: UTownIndoorNPCs = $"../IndoorNPCs"
@onready var arcade: UTownArcade = $"../Arcade"
@onready var coins: UTownCoins = $"../Coins"
@onready var hud: CanvasLayer = $"../HUD"
@onready var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
const EXPERIENCE_ZH: Dictionary = {
    "ALIGHT SHUTTLE": "下校车",
    "Back to walking before your next class": "下车后走去下一节课",
    "Revisit activity": "再次参加活动",
    "Discover a new indoor activity": "发现新的室内活动",
    "The hallway gossip has lore": "听听校园里的新鲜事",
    "L: change floor  •  I: back outdoors": "L 换楼层 · I 回室外",
    "DELIVER THE LUNCH": "完成送餐",
    "Your food has survived the deadline": "你的午饭幸存了",
    "START LUNCH EXPRESS": "开始送餐挑战",
    "Deliver before the food loses hope": "赶在午饭绝望之前送达",
    "PICK UP CAMPUS COIN": "拾取校园金币",
    "COLLECT FIELD NOTE": "收集探索笔记",
    "A tiny achievement, a huge academic ego": "小小成就，大大满足",
    "Check in and keep exploring UTown": "打卡后继续探索校园",
    "May assign bizarre homework": "可能布置奇怪作业",
    "Campus stories are more fun than DDLs": "校园故事比赶作业有趣",
    "Enter a fictional indoor space": "进入虚构室内空间",
    "BOARD UTOWN SHUTTLE": "乘坐校园校车",
    "A suspiciously convenient commute": "好得可疑的便利交通",
    "Beat the clock  •  Keep moving": "与时间赛跑 · 继续前进",
    "IN RANGE  •  Your next action is ready": "已抵达 · 可以操作了",
    "INTERACT": "互动", "Approach to use": "靠近互动",
    "NEXT OBJECTIVE": "下一个目标", "Schematic direction only": "仅供游戏引导",
    "AREA DISCOVERED": "发现新区域",
    "Your next deadline is already loading.": "新的截止时间正在加载"
}

var screen: Control
var prompt_card: PanelContainer
var prompt_key: Label
var prompt_name: Label
var prompt_detail: Label
var objective_card: PanelContainer
var objective_arrow: Label
var objective_name: Label
var objective_detail: Label
var objective_distance: Label
var zone_card: PanelContainer
var zone_heading: Label
var zone_caption: Label

var _refresh_elapsed: float = 0.0
var _zone_remaining: float = 0.0
# A room transition needs an immediate HUD refresh, not the 220ms polling delay.
var _interior_context_key: String = ""
var _active_zone: String = ""
var _visited_zones: Dictionary = {}
var _active_goal: String = ""
var _active_prompt: String = ""
var _zone_motion: Tween
var _goal_motion: Tween
var _prompt_motion: Tween


func _ready() -> void:
    layer = 2
    _make_screen()
    _make_action_card()
    _make_objective_card()
    _make_zone_card()
    if language != null:
        language.language_changed.connect(_on_language_changed)
    # Let the neighbouring gameplay nodes complete their ready handlers.
    call_deferred("_refresh_feedback")


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en


func _l(text_value: String) -> String:
    if language == null or not language.is_chinese():
        return text_value
    return str(EXPERIENCE_ZH.get(text_value, text_value))


func _place_name(name: String) -> String:
    return language.translate_world_name(name) if language != null else name


func _on_language_changed(_code: String) -> void:
    if zone_heading != null and not _active_zone.is_empty():
        zone_heading.text = _t("进入区域：", "NOW ENTERING: ") + _place_name(_active_zone)
        zone_caption.text = _zone_text(_active_zone)
    _active_prompt = ""
    _active_goal = ""
    call_deferred("_refresh_feedback")


func _make_screen() -> void:
    screen = Control.new()
    screen.name = "ExperienceUI"
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(screen)


func _panel_style(_legacy_background: Color, trim: Color, radius: int = 12, margin: int = 10) -> StyleBoxFlat:
    return NUS3DUISkin.glass(trim.darkened(0.25), maxi(radius, 18), margin)


func _panel(name: String, from_left: float, to_right: float, from_top: float, to_bottom: float, anchor_x: float, anchor_y: float, background: Color, trim: Color) -> PanelContainer:
    var item: PanelContainer = PanelContainer.new()
    item.name = name
    item.anchor_left = anchor_x
    item.anchor_right = anchor_x
    item.anchor_top = anchor_y
    item.anchor_bottom = anchor_y
    item.offset_left = from_left
    item.offset_right = to_right
    item.offset_top = from_top
    item.offset_bottom = to_bottom
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item.add_theme_stylebox_override("panel", _panel_style(background, trim))
    screen.add_child(item)
    return item


func _label(text_value: String, size_value: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size_value)
    label.add_theme_color_override("font_color", NUS3DUISkin.ink_for(color))
    label.clip_text = true
    return label


func _make_action_card() -> void:
    prompt_card = _panel("ActionSuggestion", -220, 220, 30, 96, 0.5, 0.5, Color(0.065, 0.12, 0.16, 0.96), Color("#82dacb"))
    var horizontal: HBoxContainer = HBoxContainer.new()
    horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    horizontal.add_theme_constant_override("separation", 13)
    prompt_card.add_child(horizontal)

    var cap: PanelContainer = PanelContainer.new()
    cap.custom_minimum_size = Vector2(54, 39)
    cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cap.add_theme_stylebox_override("panel", NUS3DUISkin.keycap())
    horizontal.add_child(cap)
    prompt_key = _label("E", 19, Color("#f6fffe"))
    prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cap.add_child(prompt_key)

    var details: VBoxContainer = VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_theme_constant_override("separation", 3)
    horizontal.add_child(details)
    prompt_name = _label(_l("INTERACT"), 16, Color("#f1faf8"))
    prompt_detail = _label(_l("Approach to use"), 12, Color("#abcbd1"))
    details.add_child(prompt_name)
    details.add_child(prompt_detail)
    prompt_card.hide()


func _make_objective_card() -> void:
    objective_card = _panel("ObjectiveCompass", -233, 233, 66, 115, 0.5, 0.0, Color(0.055, 0.115, 0.14, 0.95), Color("#e4c783"))
    var row: HBoxContainer = HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 11)
    objective_card.add_child(row)
    objective_arrow = _label("↑", 27, Color("#f5d98d"))
    objective_arrow.custom_minimum_size.x = 32
    objective_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(objective_arrow)
    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_theme_constant_override("separation", 0)
    row.add_child(content)
    objective_name = _label(_l("NEXT OBJECTIVE"), 14, Color("#f9ead1"))
    objective_detail = _label(_l("Schematic direction only"), 11, Color("#9cb9be"))
    content.add_child(objective_name)
    content.add_child(objective_detail)
    objective_distance = _label("0 m", 16, Color("#f1e0aa"))
    objective_distance.custom_minimum_size.x = 68
    objective_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    objective_distance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(objective_distance)
    objective_card.hide()


func _make_zone_card() -> void:
    zone_card = _panel("DistrictPostcard", 18, 402, 354, 430, 0.0, 0.0, Color(0.07, 0.14, 0.16, 0.96), Color("#b1e4c4"))
    var column: VBoxContainer = VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 5)
    zone_card.add_child(column)
    zone_heading = _label(_l("AREA DISCOVERED"), 16, Color("#e3f9e9"))
    zone_caption = _label(_l("Your next deadline is already loading."), 12, Color("#b3cfd1"))
    zone_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(zone_heading)
    column.add_child(zone_caption)
    zone_card.hide()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _candidate(best: Dictionary, priority: int, key: String, title: String, detail: String, distance: float) -> Dictionary:
    if best.is_empty() or priority > int(best.get("priority", 0)) or (priority == int(best.get("priority", 0)) and distance < float(best.get("distance", 9999.0))):
        return {"priority": priority, "key": key, "title": _l(title), "detail": _l(detail), "distance": distance}
    return best


func _nearest_offer() -> Dictionary:
    if life.on_shuttle:
        return _candidate({}, 150, "X", "ALIGHT SHUTTLE", "Back to walking before your next class", 0.0)
    if player.movement_locked or coins.shop_open:
        return {}

    var best: Dictionary = {}
    if life.interior_active:
        var activity: Dictionary = life.nearest_activity()
        if not activity.is_empty():
            var activity_id: String = "%s/%s" % [life.active_interior, str(activity["id"])]
            var caption: String = "Revisit activity" if life.visited_activities.has(activity_id) else "Discover a new indoor activity"
            best = _candidate(best, 120, "F", _place_name(str(activity.get("name", _t("校园活动", "Campus activity")))), _l(caption), 0.0)
        var person_name: String = indoor_npcs.nearby_name()
        if not person_name.is_empty():
            best = _candidate(best, 108, "Q", _t("与 %s 交谈", "TALK TO %s") % person_name, "The hallway gossip has lore", 0.0)
        best = _candidate(best, 20, "I", _t("离开 %s", "LEAVE %s") % life.active_interior, "L: change floor  •  I: back outdoors", 2.0)
        return best

    if coins.delivery_active and _horizontal_distance(player.global_position, coins.delivery_destination) <= coins.DELIVERY_FINISH_RADIUS:
        best = _candidate(best, 150, "N", "DELIVER THE LUNCH", "Your food has survived the deadline", 0.0)
    elif not coins.delivery_active and coins.delivery_cooldown <= 0.0 and coins.delivery_origin != Vector3.ZERO:
        var start_distance: float = _horizontal_distance(player.global_position, coins.delivery_origin)
        if start_distance <= coins.DELIVERY_START_RADIUS:
            best = _candidate(best, 95, "N", "START LUNCH EXPRESS", "Deliver before the food loses hope", start_distance)

    for pickup in coins.pickups:
        if not bool(pickup.get("active", false)):
            continue
        var coin_distance: float = _horizontal_distance(player.global_position, pickup["base"])
        if coin_distance <= coins.PICKUP_RADIUS:
            best = _candidate(best, 135, "Z", "PICK UP CAMPUS COIN", _t("获得 %d 金币", "+%d C for your questionable spending") % int(pickup["value"]), coin_distance)

    var note_index: int = challenge.nearest_item_index()
    if note_index >= 0:
        best = _candidate(best, 130, "C", "COLLECT FIELD NOTE", "A tiny achievement, a huge academic ego", 0.0)
    if tour.can_check_in():
        var stop: Dictionary = tour.current_stop()
        best = _candidate(best, 125, "E", _place_name(str(stop.get("title", _t("探索打卡点", "DISCOVERY CHECKPOINT")))), "Check in and keep exploring UTown", tour.current_distance_m())

    for professor in arcade.professors:
        var professor_node: Node3D = professor.get("node") as Node3D
        if professor_node == null or not is_instance_valid(professor_node):
            continue
        var professor_distance: float = _horizontal_distance(player.global_position, professor_node.global_position)
        if professor_distance <= 4.5:
            best = _candidate(best, 112, "K", _t("寻找 %s", "MEET %s") % str(professor.get("name", _t("教授", "PROFESSOR"))), "May assign bizarre homework", professor_distance)

    for person in life.pedestrians:
        var node: Node3D = person.get("node") as Node3D
        if node == null or not is_instance_valid(node):
            continue
        var talk_distance: float = _horizontal_distance(player.global_position, node.global_position)
        if talk_distance <= life.TALK_RADIUS:
            best = _candidate(best, 90, "Q", _t("与 %s 交谈", "TALK TO %s") % str(person.get("name", _t("学生", "STUDENT"))), "Campus stories are more fun than DDLs", talk_distance)

    if not life.bicycle_enabled:
        for room_id in ["ERC", "SRC"]:
            if not life.entry_positions.has(room_id):
                continue
            var entry_distance: float = _horizontal_distance(player.global_position, life.entry_positions[room_id])
            if entry_distance <= life.ENTRY_RADIUS:
                best = _candidate(best, 70, "I", _t("探索 %s 室内", "EXPLORE %s INTERIOR") % room_id, "Enter a fictional indoor space", entry_distance)
        if life.shuttle != null:
            var shuttle_distance: float = _horizontal_distance(player.global_position, life.shuttle.global_position)
            if shuttle_distance <= life.BOARD_RADIUS:
                best = _candidate(best, 80, "X", "BOARD UTOWN SHUTTLE", "A suspiciously convenient commute", shuttle_distance)
    return best


func _goal_offer() -> Dictionary:
    # Interior coordinates are deliberately far outside the outdoor world;
    # never point to outdoor objectives while the player is in a room.
    if life.interior_active or life.on_shuttle:
        return {}
    if coins.delivery_active:
        return {
            "id": "lunch",
            "position": coins.delivery_destination,
            "title": _t("送餐任务 | 中央草坪", "LUNCH EXPRESS | TOWN GREEN"),
            "detail": _t("剩余 %d 秒 · 抵达后按 N", "%ds left · Press N at the destination") % ceili(coins.delivery_time)
        }
    if challenge.sprint_active and challenge.sprint_next_index < challenge.sprint_route.size():
        return {
            "id": "sprint:%d" % challenge.sprint_next_index,
            "position": challenge.sprint_route[challenge.sprint_next_index],
            "title": _t("校园竞速 | 打卡点", "CAMPUS SPRINT | CHECKPOINT"),
            "detail": "Beat the clock  •  Keep moving"
        }
    if not tour.completed and not tour.current_stop().is_empty():
        var stop: Dictionary = tour.current_stop()
        return {
            "id": "tour:%d" % tour.current_index,
            "position": tour.stop_world_position(tour.current_index),
            "title": _t("探索 | ", "DISCOVERY | ") + _place_name(str(stop.get("title", _t("下一站", "NEXT STOP")))),
            "detail": _t("打卡点 %d/%d · 游戏示意路线", "Waypoint %d/%d · Illustrative route") % [tour.discovered_ids.size() + 1, tour.stops.size()]
        }
    return {}


func _direction_arrow(point: Vector3) -> String:
    var to_goal: Vector3 = point - player.global_position
    to_goal.y = 0.0
    if to_goal.length_squared() < 0.0001:
        return "●"
    to_goal = to_goal.normalized()
    var front: Vector3 = -player.global_transform.basis.z
    var right: Vector3 = player.global_transform.basis.x
    var angle: float = atan2(right.dot(to_goal), front.dot(to_goal))
    var headings: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
    return headings[posmod(int(round(angle / (PI / 4.0))), headings.size())]


func _fade_in(card: PanelContainer, mode: String) -> void:
    var tween: Tween
    if mode == "prompt":
        if _prompt_motion != null and _prompt_motion.is_running():
            _prompt_motion.kill()
        tween = create_tween()
        _prompt_motion = tween
    elif mode == "goal":
        if _goal_motion != null and _goal_motion.is_running():
            _goal_motion.kill()
        tween = create_tween()
        _goal_motion = tween
    else:
        if _zone_motion != null and _zone_motion.is_running():
            _zone_motion.kill()
        tween = create_tween()
        _zone_motion = tween
    card.modulate.a = 0.0
    card.show()
    tween.tween_property(card, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_prompt(focus: Dictionary) -> void:
    if focus.is_empty():
        prompt_card.hide()
        _active_prompt = ""
        return
    var key_text: String = str(focus["key"])
    var identity: String = key_text + ":" + str(focus["title"])
    prompt_key.text = key_text
    prompt_name.text = str(focus["title"])
    prompt_detail.text = str(focus["detail"])
    if identity != _active_prompt or not prompt_card.visible:
        _active_prompt = identity
        _fade_in(prompt_card, "prompt")


func _update_goal(goal: Dictionary) -> void:
    if goal.is_empty():
        objective_card.hide()
        _active_goal = ""
        return
    var goal_position: Vector3 = goal["position"]
    var distance_m: float = _horizontal_distance(player.global_position, goal_position)
    var id_value: String = str(goal["id"])
    var finish_radius: float = coins.DELIVERY_FINISH_RADIUS if id_value == "lunch" else challenge.SPRINT_CHECKPOINT_RADIUS_M if id_value.begins_with("sprint:") else tour.check_in_radius_m
    var arrived: bool = distance_m <= finish_radius
    var urgent: bool = id_value == "lunch" and coins.delivery_time <= 25.0 and not arrived
    objective_arrow.text = "✓" if arrived else _direction_arrow(goal_position)
    objective_name.text = str(goal["title"])
    if arrived:
        objective_detail.text = "IN RANGE  •  Your next action is ready"
    elif urgent:
        objective_detail.text = _t("快点！午饭还有 %d 秒就凉了", "HURRY! %d seconds before cold lunch") % ceili(coins.delivery_time)
    else:
        objective_detail.text = str(goal["detail"])
    objective_distance.text = "%d m" % roundi(distance_m)
    # Dark, semantic glyphs on the pearly compass surface: never pastel-on-white.
    var indicator_color: Color = NUS3DUISkin.SUCCESS if arrived else NUS3DUISkin.DANGER if urgent else NUS3DUISkin.WARNING
    objective_arrow.add_theme_color_override("font_color", indicator_color)
    objective_distance.add_theme_color_override("font_color", indicator_color)
    if id_value != _active_goal or not objective_card.visible:
        _active_goal = id_value
        _fade_in(objective_card, "goal")


func _zone_text(zone: String) -> String:
    var lowered: String = zone.to_lower()
    if lowered.contains("green"):
        return _t("截止时间恶魔正在草坪跑步。", "Deadline demons are doing cardio on the lawn.")
    if lowered.contains("erc") or lowered.contains("education"):
        return _t("打印机排队，是没人要求的终极挑战。", "Printer queue: a boss fight nobody requested.")
    if lowered.contains("src") or lowered.contains("sport"):
        return _t("虽然跑不过作业，但可以试试。", "You cannot outrun coursework, but you can try.")
    if lowered.contains("plaza"):
        return _t("先攒金币，人生问题饭后再说。", "Coins first. Existential crisis after lunch.")
    return _t("解锁新区域，课程任务也仍然保留。", "New district unlocked. Coursework remains unlocked too.")


func _update_zone() -> void:
    var current_zone: String = ""
    if life.interior_active:
        current_zone = life.active_interior + " INTERIOR"
    else:
        var nearest: Dictionary = world.nearest_landmark(player.global_position)
        if float(nearest.get("distance", 9999.0)) <= ZONE_RADIUS_M:
            current_zone = str(nearest.get("name", ""))
    if current_zone == _active_zone:
        return
    _active_zone = current_zone
    if current_zone.is_empty() or _visited_zones.has(current_zone):
        # Never leave the old building postcard visible in a different room.
        _zone_remaining = 0.0
        zone_card.hide()
        return
    _visited_zones[current_zone] = true
    zone_heading.text = _t("进入区域：", "NOW ENTERING: ") + _place_name(current_zone)
    zone_caption.text = _zone_text(current_zone)
    _zone_remaining = 3.6
    _fade_in(zone_card, "zone")


func _refresh_feedback() -> void:
    if screen == null or player == null or coins == null:
        return
    var is_playing: bool = hud.visible and not coins.shop_open and not get_tree().paused
    screen.visible = is_playing
    if not is_playing:
        return
    _update_prompt(_nearest_offer())
    _update_goal(_goal_offer())
    _update_zone()


func _process(delta: float) -> void:
    # Interior entrances/exits are discrete transitions; refresh on the first
    # simulation tick even when the normal guide polling window has not elapsed.
    var next_interior: String = life.active_interior if life.interior_active else ""
    if next_interior != _interior_context_key:
        _interior_context_key = next_interior
        _refresh_elapsed = 0.0
        _refresh_feedback()
    _refresh_elapsed += delta
    if _zone_remaining > 0.0:
        _zone_remaining = maxf(0.0, _zone_remaining - delta)
        if _zone_remaining <= 0.0 and zone_card != null:
            zone_card.hide()
    if _refresh_elapsed >= REFRESH_SECONDS:
        _refresh_elapsed = fmod(_refresh_elapsed, REFRESH_SECONDS)
        _refresh_feedback()
