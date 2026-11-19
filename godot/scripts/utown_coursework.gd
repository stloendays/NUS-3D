extends Node
class_name UTownCoursework
## Offline and entirely fictional coursework storyline. No real course codes,
## academic records, actual NUS deadlines, accounts, or network connections.
## Shares only established schematic waypoints and existing campus activity IDs.

const DATA_PATH: String = "res://data/coursework_quests.json"
const SAVE_PATH: String = "user://nus3d_coursework.cfg"
const INTERACT_RADIUS: float = 13.0
const SAVE_INTERVAL: float = 12.0
const STAGE_BRIEF: int = 0
const STAGE_ACTIVITY: int = 1
const STAGE_PARTNER: int = 2
const STAGE_SUBMIT: int = 3
const ACTIVITY_LABELS: Dictionary = {
    "ERC/cafe": "咖啡角",
    "ERC/reading": "阅读区",
    "ERC/mezzanine": "二层学习区",
    "SRC/refill": "饮水站",
    "SRC/warmup": "热身区",
    "SRC/viewing": "观众席"
}

@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"

var save_path: String = SAVE_PATH
var faculty_options: Array[Dictionary] = []
var faculty_by_id: Dictionary = {}
var current_faculty_id: String = ""
var faculty_progress: Dictionary = {}
var total_xp: int = 0
var credits: int = 0
var last_grade: String = ""
var exam_reward_ids: PackedStringArray = PackedStringArray()
var feedback: String = ""
var feedback_left: float = 0.0
var current_time_left: float = 0.0
var active_quest_index: int = 0
var active_stage: int = STAGE_BRIEF
var modal_open: bool = false
var marker_preference: bool = true

var marker: Node3D
var marker_label: Label3D
var marker_ring: MeshInstance3D
var save_clock: float = 0.0

func _ready() -> void:
    _load_data()
    _build_marker()
    _load_progress()
    _refresh_marker()

func _load_data() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Missing original fictional coursework JSON")
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(raw) != TYPE_DICTIONARY:
        push_error("Invalid coursework JSON")
        return
    var data: Dictionary = raw
    if str(data.get("schema", "")) != "nus3d-coursework-v1" or data.get("unofficial", false) != true:
        push_error("Coursework data requires the explicit unofficial-fictional contract")
        return
    for item in data.get("faculty_options", []):
        if typeof(item) != TYPE_DICTIONARY:
            continue
        var faculty: Dictionary = item
        var id: String = str(faculty.get("id", ""))
        var quests: Array = faculty.get("quests", [])
        if id.is_empty() or faculty_by_id.has(id) or quests.size() != 3:
            continue
        var okay: bool = true
        for quest in quests:
            if typeof(quest) != TYPE_DICTIONARY:
                okay = false
                break
            if str(quest.get("activity", "")).is_empty() or str(quest.get("partner", "")).is_empty():
                okay = false
                break
        if okay:
            faculty_options.append(faculty)
            faculty_by_id[id] = faculty

func _blank_state() -> Dictionary:
    return {"quest": 0, "stage": STAGE_BRIEF, "time_left": 0.0, "grades": PackedStringArray()}

func _valid_state(faculty_id: String, raw: Variant) -> Dictionary:
    var state: Dictionary = _blank_state()
    if typeof(raw) != TYPE_DICTIONARY or not faculty_by_id.has(faculty_id):
        return state
    var previous: Dictionary = raw
    var count: int = faculty_by_id[faculty_id]["quests"].size()
    state["quest"] = clampi(int(previous.get("quest", 0)), 0, count)
    state["stage"] = clampi(int(previous.get("stage", 0)), 0, STAGE_SUBMIT)
    state["time_left"] = maxf(0.0, float(previous.get("time_left", 0.0)))
    var grades: PackedStringArray = PackedStringArray()
    for grade in previous.get("grades", PackedStringArray()):
        grades.append(str(grade))
    if grades.size() > count:
        grades.resize(count)
    state["grades"] = grades
    if int(state["quest"]) >= count:
        state["stage"] = STAGE_BRIEF
        state["time_left"] = 0.0
    return state

func _store_active_state() -> void:
    if current_faculty_id.is_empty():
        return
    var state: Dictionary = faculty_progress.get(current_faculty_id, _blank_state())
    state["quest"] = active_quest_index
    state["stage"] = active_stage
    state["time_left"] = maxf(0.0, current_time_left)
    faculty_progress[current_faculty_id] = state

func _load_progress() -> void:
    current_faculty_id = ""
    faculty_progress.clear()
    total_xp = 0
    credits = 0
    last_grade = ""
    exam_reward_ids.clear()
    active_quest_index = 0
    active_stage = STAGE_BRIEF
    current_time_left = 0.0
    var save := ConfigFile.new()
    if save.load(save_path) != OK:
        return
    total_xp = clampi(int(save.get_value("player", "xp", 0)), 0, 100000000)
    credits = clampi(int(save.get_value("player", "credits", 0)), 0, 100000000)
    var past_exams: Variant = save.get_value("player", "exam_reward_ids", PackedStringArray())
    if typeof(past_exams) == TYPE_ARRAY or typeof(past_exams) == TYPE_PACKED_STRING_ARRAY:
        for raw in past_exams:
            var reward_key: String = str(raw)
            if reward_key.begins_with("exam:") and reward_key.length() <= 100 and not exam_reward_ids.has(reward_key):
                exam_reward_ids.append(reward_key)
    var state_data: Variant = save.get_value("coursework", "progress", {})
    if typeof(state_data) == TYPE_DICTIONARY:
        var records: Dictionary = state_data
        for faculty_id in records:
            if faculty_by_id.has(str(faculty_id)):
                faculty_progress[str(faculty_id)] = _valid_state(str(faculty_id), records[faculty_id])
    var saved_id: String = str(save.get_value("player", "faculty", ""))
    if faculty_by_id.has(saved_id):
        current_faculty_id = saved_id
        _restore_active_state()
    last_grade = str(save.get_value("player", "last_grade", ""))

func _save_progress() -> bool:
    _store_active_state()
    var save := ConfigFile.new()
    save.set_value("player", "faculty", current_faculty_id)
    save.set_value("player", "xp", total_xp)
    save.set_value("player", "credits", credits)
    save.set_value("player", "exam_reward_ids", exam_reward_ids)
    save.set_value("player", "last_grade", last_grade)
    save.set_value("coursework", "progress", faculty_progress)
    var err: Error = save.save(save_path)
    if err != OK:
        push_warning("Local coursework progress could not be saved")
        return false
    return true

## English practice rewards are isolated to the current local account.
func claim_exam_reward_once(paper_id: String, gained_xp: int, gained_credits: int) -> bool:
    if paper_id.is_empty() or paper_id.length() > 90 or gained_xp < 0 or gained_credits < 0:
        return false
    if not paper_id.is_valid_identifier():
        return false
    var reward_id: String = "exam:" + paper_id
    if exam_reward_ids.has(reward_id):
        return false
    var previous_xp: int = total_xp
    var previous_credits: int = credits
    exam_reward_ids.append(reward_id)
    total_xp = mini(100000000, total_xp + gained_xp)
    credits = mini(100000000, credits + gained_credits)
    if _save_progress():
        return true
    exam_reward_ids.remove_at(exam_reward_ids.size() - 1)
    total_xp = previous_xp
    credits = previous_credits
    return false


func _restore_active_state() -> void:
    var state: Dictionary = _valid_state(current_faculty_id, faculty_progress.get(current_faculty_id, {}))
    faculty_progress[current_faculty_id] = state
    active_quest_index = int(state["quest"])
    active_stage = int(state["stage"])
    current_time_left = float(state["time_left"])

func select_faculty(id: String) -> bool:
    if not faculty_by_id.has(id):
        return false
    _store_active_state()
    current_faculty_id = id
    _restore_active_state()
    _save_progress()
    feedback = "欢迎来到 %s！三道课程任务，DDL 正在热身。" % faculty_name()
    feedback_left = 5.5
    _refresh_marker()
    return true

func faculty_name() -> String:
    if not faculty_by_id.has(current_faculty_id):
        return "未选择学院"
    return str(faculty_by_id[current_faculty_id]["zh"])

func current_quest() -> Dictionary:
    if not faculty_by_id.has(current_faculty_id):
        return {}
    var quests: Array = faculty_by_id[current_faculty_id]["quests"]
    if active_quest_index < 0 or active_quest_index >= quests.size():
        return {}
    return quests[active_quest_index]

func is_graduated() -> bool:
    return not current_faculty_id.is_empty() and current_quest().is_empty()

func level() -> int:
    var xp_remaining: int = total_xp
    var lvl: int = 1
    while lvl < 60 and xp_remaining >= lvl * 180:
        xp_remaining -= lvl * 180
        lvl += 1
    return lvl

func total_completed() -> int:
    var count: int = 0
    for state in faculty_progress.values():
        if typeof(state) == TYPE_DICTIONARY:
            var grades: PackedStringArray = state.get("grades", PackedStringArray())
            count += grades.size()
    return count

func _quest_location(id: String) -> Vector3:
    for waypoint in world.layout.get("loop", []):
        if str(waypoint.get("id", "")) == id:
            return world.lonlat_to_world(float(waypoint.get("lon", 0.0)), float(waypoint.get("lat", 0.0)))
    return player.global_position

func _target_room(quest: Dictionary) -> String:
    if active_stage == STAGE_ACTIVITY:
        return str(quest["activity"]).get_slice("/", 0)
    if active_stage == STAGE_PARTNER:
        return str(quest["partner"]).get_slice("/", 0)
    return ""

func waypoint_target() -> String:
    var quest: Dictionary = current_quest()
    if quest.is_empty():
        return ""
    match active_stage:
        STAGE_BRIEF:
            return str(quest["pickup"])
        STAGE_ACTIVITY, STAGE_PARTNER:
            return _target_room(quest)
        STAGE_SUBMIT:
            return str(quest["submit"])
    return ""

func objective_position() -> Vector3:
    return _quest_location(waypoint_target())

func objective_description() -> String:
    var quest: Dictionary = current_quest()
    if quest.is_empty():
        return "全部 coursework 完成。换个学院，或者继续探索 UTown。"
    match active_stage:
        STAGE_BRIEF:
            return "前往 %s，靠近任务告示按 K 领取作业" % waypoint_target()
        STAGE_ACTIVITY:
            var p: PackedStringArray = str(quest["activity"]).split("/")
            return "进入 %s 室内，在 %s 活动点按 F" % [p[0], str(ACTIVITY_LABELS.get(str(quest["activity"]), p[1]))]
        STAGE_PARTNER:
            var p: PackedStringArray = str(quest["partner"]).split("/")
            return "在 %s 寻找队友 %s，靠近按 Q" % [p[0], p[1]]
        STAGE_SUBMIT:
            return "冲向 %s 的提交终端，按 K 交作业！" % waypoint_target()
    return ""

func format_ddl() -> String:
    if active_stage == STAGE_BRIEF:
        return "尚未开始"
    if current_time_left <= 0.0:
        return "逾期，但还能交！"
    var time_int: int = int(ceil(current_time_left))
    var minutes: int = floori(float(time_int) / 60.0)
    var seconds: int = time_int % 60
    return "%02d:%02d" % [minutes, seconds]

func status_text() -> String:
    if current_faculty_id.is_empty():
        return "COURSEWORK  |  选择自己的学院，开启疯狂 DDL 之旅\n[P] 任务手册  [Shift+P] 学院选择"
    var current: Dictionary = current_quest()
    var header: String = "%s  |  Lv.%d  XP %d  $%d" % [faculty_name(), level(), total_xp, credits]
    if current.is_empty():
        return "COURSEWORK  |  " + header + "\n学院任务完成！[Tab] 五子棋/打牌/聚会  [Shift+P] 切换学院"
    return "COURSEWORK %d/3  |  %s\n%s\nDDL %s  |  %s\n[P] 任务手册  [Shift+P] 切换学院" % [
        active_quest_index + 1, header, str(current["title"]), format_ddl(), objective_description()
    ]

func _build_marker() -> void:
    marker = Node3D.new()
    marker.name = "CourseworkWaypointMarker"
    add_child(marker)
    var gold := StandardMaterial3D.new()
    gold.albedo_color = Color.html("#f4b94a")
    gold.emission_enabled = true
    gold.emission = Color.html("#f4aa32")
    gold.emission_energy_multiplier = 0.65
    var disc := MeshInstance3D.new()
    disc.name = "FloatingCourseworkTerminal"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.48
    cylinder.bottom_radius = 0.48
    cylinder.height = 0.18
    disc.mesh = cylinder
    disc.position = Vector3(0.0, 0.27, 0.0)
    disc.material_override = gold
    marker.add_child(disc)
    marker_ring = MeshInstance3D.new()
    marker_ring.name = "DeadlineRipple"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.95
    torus.outer_radius = 1.10
    marker_ring.mesh = torus
    marker_ring.position.y = 0.08
    marker_ring.material_override = gold
    marker.add_child(marker_ring)
    var book := MeshInstance3D.new()
    book.name = "FloatingHomeworkBook"
    var book_box := BoxMesh.new()
    book_box.size = Vector3(0.85, 0.12, 0.6)
    book.mesh = book_box
    book.position = Vector3(0.0, 1.2, 0.0)
    book.material_override = gold
    marker.add_child(book)
    marker_label = Label3D.new()
    marker_label.name = "DeadlineSign"
    marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    marker_label.pixel_size = 0.013
    marker_label.font_size = 32
    marker_label.outline_size = 6
    marker_label.position.y = 2.08
    marker_label.modulate = Color.html("#fff4c9")
    marker.add_child(marker_label)

func set_markers_visible(enabled: bool) -> void:
    marker_preference = enabled
    _refresh_marker()

func _refresh_marker() -> void:
    if marker == null:
        return
    var quest: Dictionary = current_quest()
    if quest.is_empty() or not marker_preference:
        marker.visible = false
        return
    var at: Vector3 = objective_position()
    marker.position = at + Vector3(0.0, 0.02, 0.0)
    marker_label.text = "[K] TAKE BRIEF" if active_stage == STAGE_BRIEF else "ENTER ROOM [I]" if active_stage < STAGE_SUBMIT else "[K] SUBMIT DDL"
    marker.visible = not life.interior_active

func _process(delta: float) -> void:
    feedback_left = maxf(0.0, feedback_left - delta)
    save_clock += delta
    if save_clock >= SAVE_INTERVAL:
        save_clock = 0.0
        if not current_faculty_id.is_empty():
            _save_progress()
    if current_faculty_id.is_empty():
        return
    if active_stage > STAGE_BRIEF and not modal_open and current_time_left > 0.0:
        current_time_left = maxf(0.0, current_time_left - delta)
        if current_time_left <= 0.0:
            feedback = "DDL 爆炸了！没关系，逾期也能交，奖励会少一点。"
            feedback_left = 5.0
    if marker != null:
        marker_ring.rotation.y += delta * 0.85
        marker_ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.003))
        var desired: bool = marker_preference and not current_quest().is_empty() and not life.interior_active
        marker.visible = desired

func interact_nearby() -> bool:
    var quest: Dictionary = current_quest()
    if quest.is_empty() or life.interior_active or life.on_shuttle:
        return false
    if active_stage != STAGE_BRIEF and active_stage != STAGE_SUBMIT:
        feedback = "这一关需要先完成室内活动或队友对话。"
        feedback_left = 3.0
        return false
    var distance: float = Vector2(player.global_position.x, player.global_position.z).distance_to(
        Vector2(objective_position().x, objective_position().z))
    if distance > INTERACT_RADIUS:
        feedback = "任务终端距离 %.0f m，跟着金色任务标记走！" % distance
        feedback_left = 3.0
        return false
    if active_stage == STAGE_BRIEF:
        active_stage = STAGE_ACTIVITY
        current_time_left = float(quest["deadline_s"])
        feedback = "接到任务：%s。DDL 怪兽已苏醒！" % str(quest["title"])
        feedback_left = 5.0
        _save_progress()
        _refresh_marker()
        return true
    _complete_quest()
    return true

func notify_activity(id: String) -> bool:
    var quest: Dictionary = current_quest()
    if quest.is_empty() or active_stage != STAGE_ACTIVITY or str(quest["activity"]) != id:
        return false
    active_stage = STAGE_PARTNER
    feedback = "资料到手！队友终于回消息了……还是个表情包。"
    feedback_left = 4.0
    _save_progress()
    _refresh_marker()
    return true

func notify_dialogue(id: String) -> bool:
    var quest: Dictionary = current_quest()
    if quest.is_empty() or active_stage != STAGE_PARTNER or str(quest["partner"]) != id:
        return false
    active_stage = STAGE_SUBMIT
    feedback = "队友说他已经做完了……复制粘贴部分。快去交作业！"
    feedback_left = 4.0
    _save_progress()
    _refresh_marker()
    return true

func _complete_quest() -> void:
    var quest: Dictionary = current_quest()
    if quest.is_empty():
        return
    var overdue: bool = current_time_left <= 0.0
    var grade: String = "C (Late)" if overdue else "S" if current_time_left > float(quest["deadline_s"]) * 0.4 else "A"
    var multiplier: float = 0.55 if overdue else 1.0
    var gained_xp: int = maxi(1, int(round(float(quest["xp"]) * multiplier)))
    var gained_credits: int = maxi(1, int(round(float(quest["credits"]) * multiplier)))
    total_xp += gained_xp
    credits += gained_credits
    var state: Dictionary = faculty_progress.get(current_faculty_id, _blank_state())
    var grades: PackedStringArray = state.get("grades", PackedStringArray())
    grades.append(grade)
    state["grades"] = grades
    faculty_progress[current_faculty_id] = state
    last_grade = grade
    feedback = "已提交！%s  |  +%d XP  +%d 积分。DDL 怪兽暂时退散！" % [grade, gained_xp, gained_credits]
    feedback_left = 7.0
    active_quest_index += 1
    active_stage = STAGE_BRIEF
    current_time_left = 0.0
    var chapters: Array = faculty_by_id[current_faculty_id]["quests"]
    if active_quest_index >= chapters.size():
        feedback += "\n解锁：下课后社团 [Tab] — 五子棋、牌局和聚会！"
        feedback_left = 9.0
    _save_progress()
    _refresh_marker()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_K and not modal_open:
            interact_nearby()
