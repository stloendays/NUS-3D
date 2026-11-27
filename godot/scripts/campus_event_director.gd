extends Node
class_name NUS3DCampusEventDirector
## Small, scheduled campus micro-events driven by the existing clock, weather and Q-talk action.
## Rewards reuse the account-scoped, atomic coin reward API; no new controls or save files.

const TARGET_TALKERS: int = 2
const RAIN_EVENT_START: float = 810.0
const RAIN_EVENT_END: float = 1320.0
const EVENING_EVENT_START: float = 1080.0
const EVENING_EVENT_END: float = 1200.0
const EVENT_REFRESH_SECONDS: float = 0.5

@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var daily_life: NUS3DCampusDailyLife = $"../CampusDailyLife"
@onready var weather: UTownWeather = $"../Weather"
@onready var activities: NUS3DCampusAmbientActivities = $"../CampusAmbientActivities"
@onready var green_dining: UTownGreenDining = $"../GreenDining"
@onready var coins: UTownCoins = $"../Coins"
@onready var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage

var current_event_id: String = ""
var event_progress: int = 0
var event_complete: bool = false
var event_talkers: Dictionary = {}
var event_anchors: Array[Vector3] = []
var refresh_timer: float = 0.0

func _ready() -> void:
    life.talked_to.connect(_on_npc_talked)
    refresh_event(true)


func _process(delta: float) -> void:
    refresh_timer += delta
    if refresh_timer >= EVENT_REFRESH_SECONDS:
        refresh_timer = 0.0
        refresh_event()


func refresh_event(force: bool = false) -> void:
    var next_id: String = _scheduled_event_id()
    if next_id == current_event_id and not force:
        return

    current_event_id = next_id
    event_progress = 0
    event_complete = false
    event_talkers.clear()
    event_anchors.clear()
    if current_event_id.is_empty():
        return

    _build_event_anchors()
    if event_anchors.is_empty():
        current_event_id = ""
        return

    var reward_id: String = _reward_id()
    if coins.claimed_rewards.has(reward_id):
        event_complete = true
        event_progress = TARGET_TALKERS
        return

    life.message = _event_announcement()
    life.message_time = 5.0


func _scheduled_event_id() -> String:
    var minutes: float = daily_life.game_minutes
    # Lunch remains the primary event during wet weather because the existing
    # Fine Food seating and queue are already covered.
    if daily_life.is_lunch_peak():
        return "lunch_rush"
    if weather.mode >= 3 and minutes >= RAIN_EVENT_START and minutes < RAIN_EVENT_END:
        return "rain_shelter"
    if weather.mode < 3 and minutes >= EVENING_EVENT_START and minutes < EVENING_EVENT_END:
        return "evening_picnic"
    return ""


func _build_event_anchors() -> void:
    match current_event_id:
        "lunch_rush":
            var area: Dictionary = green_dining.dining_areas.get("fine_food", {})
            var food_root: Node3D = area.get("root") as Node3D
            if food_root != null:
                event_anchors.append(food_root.global_position)
        "rain_shelter":
            for spot_value in activities.spots:
                var spot: Dictionary = spot_value
                if str(spot.get("kind", "")) == "shelter":
                    event_anchors.append(spot.get("position", Vector3.ZERO))
        "evening_picnic":
            for group_value in activities.picnic_groups:
                var group: Dictionary = group_value
                for position_value in group.get("positions", []):
                    var position: Vector3 = position_value
                    event_anchors.append(position)


func _on_npc_talked(speaker: String) -> void:
    if current_event_id.is_empty() or event_complete:
        return
    if life.interior_active or life.on_shuttle or life.bicycle_enabled:
        return
    if not _player_in_event_zone():
        return

    # talk_to_nearest emits synchronously after setting talk_remaining, so the
    # nearest actor is still the one whose dialogue just opened.
    var index: int = life._nearest_pedestrian()
    if index < 0 or index >= life.pedestrians.size():
        return
    var state: Dictionary = life.pedestrians[index]
    if str(state.get("name", "")) != speaker or not bool(state.get("ambient", false)):
        return

    var actor_id: String = str(state.get("nav_key", ""))
    if actor_id.is_empty():
        actor_id = str(index)
    if event_talkers.has(actor_id):
        return

    event_talkers[actor_id] = true
    event_progress = event_talkers.size()
    if event_progress >= TARGET_TALKERS:
        _complete_event()
    else:
        life.message = _progress_message()
        life.message_time = 4.0


func _player_in_event_zone() -> bool:
    var radius: float = _event_radius()
    for anchor in event_anchors:
        var distance: float = Vector2(player.global_position.x, player.global_position.z).distance_to(
            Vector2(anchor.x, anchor.z))
        if distance <= radius:
            return true
    return false


func _event_radius() -> float:
    match current_event_id:
        "lunch_rush":
            return 34.0
        "rain_shelter":
            return 12.5
        "evening_picnic":
            return 15.0
    return 0.0


func _complete_event() -> void:
    var reward_id: String = _reward_id()
    if coins.claimed_rewards.has(reward_id):
        event_complete = true
        event_progress = TARGET_TALKERS
        return
    if coins.balance >= coins.MAX_BALANCE:
        event_complete = true
        event_progress = TARGET_TALKERS
        life.message = _t("活动完成！金币钱包已满。", "Event complete! Your coin wallet is full.")
        life.message_time = 5.0
        return

    if coins.reward_once(reward_id, _reward_amount(), _reward_reason()):
        event_complete = true
        life.message = _t("校园活动完成！获得 %d 金币。", "Campus event cleared! You earned %d coins.") % _reward_amount()
        life.message_time = 5.0
        return

    # A failed disk write must not silently consume the reward. Let the player
    # retry the short event instead of recording a false completion.
    event_progress = 0
    event_talkers.clear()
    life.message = _t("活动奖励暂时无法保存，请再与两位同学交谈。",
        "The event reward could not be saved. Please talk to two students again.")
    life.message_time = 5.0


func status_text() -> String:
    if current_event_id.is_empty():
        return ""
    var title: String = _event_title()
    if event_complete:
        return _t("校园活动：%s · 已完成", "CAMPUS EVENT: %s · CLEARED") % title
    return _t("校园活动：%s · [Q] 与不同同学交谈 %d/%d",
        "CAMPUS EVENT: %s · [Q] talk to different students %d/%d") % [
        title, event_progress, TARGET_TALKERS
    ]


func _event_announcement() -> String:
    match current_event_id:
        "lunch_rush":
            return _t("午餐高峰活动：在 Fine Food 附近与两位不同同学交谈。",
                "LUNCH RUSH: Talk to two different students near Fine Food.")
        "rain_shelter":
            return _t("雨天互助活动：在食堂或 SRC 雨棚附近与两位不同同学交谈。",
                "RAIN CHECK: Talk to two different students near a covered campus shelter.")
        "evening_picnic":
            return _t("傍晚野餐活动：在 Town Green 与两位不同同学交谈。",
                "EVENING PICNIC: Talk to two different students around Town Green.")
    return ""


func _progress_message() -> String:
    return _t("已交谈 %d/%d 位不同同学。", "Talked to %d/%d different students.") % [
        event_progress, TARGET_TALKERS
    ]


func _event_title() -> String:
    match current_event_id:
        "lunch_rush":
            return _t("午餐高峰", "Lunch Rush")
        "rain_shelter":
            return _t("雨天互助", "Rain Shelter")
        "evening_picnic":
            return _t("傍晚野餐", "Evening Picnic")
    return _t("校园活动", "Campus Event")


func _reward_id() -> String:
    return "campus_event:" + current_event_id


func _reward_amount() -> int:
    match current_event_id:
        "lunch_rush":
            return 15
        "rain_shelter":
            return 18
        "evening_picnic":
            return 20
    return 0


func _reward_reason() -> String:
    match current_event_id:
        "lunch_rush":
            return "Campus Event: Lunch Rush"
        "rain_shelter":
            return "Campus Event: Rain Shelter"
        "evening_picnic":
            return "Campus Event: Evening Picnic"
    return "Campus Event"


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en
