extends Node
class_name NUS3DCampusDailyLife
## Compressed, offline campus clock and schedule context for the existing ambient NPC roster.
## One complete in-game day lasts 30 real minutes. T still cycles the existing lighting presets.

const REAL_SECONDS_PER_GAME_DAY: float = 1800.0
const GAME_MINUTES_PER_REAL_SECOND: float = 1440.0 / REAL_SECONDS_PER_GAME_DAY
const START_TIME_MINUTES: float = 675.0
const SCHEDULE_REFRESH_SECONDS: float = 0.75

@onready var world: UTownWorld = $"../World"
@onready var weather: UTownWeather = $"../Weather"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var activities: NUS3DCampusAmbientActivities = $"../CampusAmbientActivities"

var game_minutes: float = START_TIME_MINUTES
var last_lighting_mode: int = 0
var schedule_refresh: float = 0.0
var food_court_crowd: int = 0
var active_routines: int = 0

func _ready() -> void:
    life = get_parent().get_node_or_null("CampusLife") as UTownCampusLife
    game_minutes = START_TIME_MINUTES
    last_lighting_mode = world.lighting_mode
    _apply_clock_lighting()
    refresh_schedule_context(true)

func _process(delta: float) -> void:
    # Preserve the existing [T] control: a manual lighting change snaps the
    # in-game clock to a representative time for that lighting preset.
    if world.lighting_mode != last_lighting_mode:
        _sync_clock_to_lighting(world.lighting_mode)
    else:
        game_minutes = fposmod(game_minutes + delta * GAME_MINUTES_PER_REAL_SECOND, 1440.0)
        var target_mode: int = lighting_mode_for_time(game_minutes)
        if target_mode != world.lighting_mode:
            world.set_lighting_mode(target_mode)
            last_lighting_mode = target_mode

    schedule_refresh += delta
    if schedule_refresh >= SCHEDULE_REFRESH_SECONDS:
        schedule_refresh = 0.0
        refresh_schedule_context()

func set_game_time(minutes: float) -> void:
    game_minutes = fposmod(minutes, 1440.0)
    _apply_clock_lighting()
    refresh_schedule_context(true)

func _apply_clock_lighting() -> void:
    var target_mode: int = lighting_mode_for_time(game_minutes)
    world.set_lighting_mode(target_mode)
    last_lighting_mode = target_mode

func _sync_clock_to_lighting(mode: int) -> void:
    match mode:
        0:
            game_minutes = 12.0 * 60.0
        1:
            game_minutes = 17.0 * 60.0
        2:
            game_minutes = 18.0 * 60.0 + 30.0
        _:
            game_minutes = 20.0 * 60.0
    last_lighting_mode = mode
    refresh_schedule_context(true)

func lighting_mode_for_time(minutes: float) -> int:
    var value: float = fposmod(minutes, 1440.0)
    if value >= 6.0 * 60.0 and value < 16.5 * 60.0:
        return 0
    if value >= 16.5 * 60.0 and value < 18.0 * 60.0:
        return 1
    if value >= 18.0 * 60.0 and value < 19.0 * 60.0:
        return 2
    return 3

func is_lunch_peak() -> bool:
    return game_minutes >= 690.0 and game_minutes < 810.0

func period_name() -> String:
    if is_lunch_peak():
        return "Lunch rush"
    if game_minutes >= 6.0 * 60.0 and game_minutes < 10.0 * 60.0:
        return "Morning"
    if game_minutes >= 10.0 * 60.0 and game_minutes < 11.5 * 60.0:
        return "Late morning"
    if game_minutes >= 13.5 * 60.0 and game_minutes < 16.5 * 60.0:
        return "Afternoon"
    if game_minutes >= 16.5 * 60.0 and game_minutes < 19.0 * 60.0:
        return "Evening"
    return "Night"

func refresh_schedule_context(force: bool = false) -> void:
    if activities == null or weather == null:
        return
    activities.configure_schedule(game_minutes, weather.mode, force)
    active_routines = activities.active_activity_count()
    food_court_crowd = activities.food_court_crowd_count()

func status_text() -> String:
    var campus_life: UTownCampusLife = life
    if campus_life == null:
        campus_life = get_parent().get_node_or_null("CampusLife") as UTownCampusLife
    if campus_life == null:
        return "CAMPUS CLOCK"
    var total_ambient: int = 0
    for state_value in campus_life.pedestrians:
        if bool(state_value.get("ambient", false)):
            total_ambient += 1
    var hour: int = int(floor(game_minutes / 60.0))
    var minute: int = int(floor(fposmod(game_minutes, 60.0)))
    var clock_text: String = "%02d:%02d" % [hour, minute]
    var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    var chinese: bool = language != null and language.is_chinese()
    if chinese:
        var period_zh: String = "午餐高峰" if is_lunch_peak() else "早晨" if period_name() == "Morning" else "上午" if period_name() == "Late morning" else "下午" if period_name() == "Afternoon" else "傍晚" if period_name() == "Evening" else "夜间"
        return "时间 %s  |  %s  |  食堂 %d 人  |  活动 NPC %d/%d" % [clock_text, period_zh, food_court_crowd, active_routines, total_ambient]
    return "%s  |  %s  |  Food court %d  |  Active %d/%d" % [clock_text, period_name(), food_court_crowd, active_routines, total_ambient]
