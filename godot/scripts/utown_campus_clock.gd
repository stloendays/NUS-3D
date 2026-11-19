extends Node
class_name UTownCampusClock
## Fictional accelerated campus time, independent of local system clock.
signal minute_changed(hour: int, minute: int)
@export_range(1.0, 120.0, 1.0) var game_minutes_per_real_minute: float = 18.0
@export_range(0, 1439, 1) var start_minute: int = 690
var minute_of_day: float = 690.0
var paused: bool = false
@onready var world: UTownWorld = $"../World"
var last_lighting: int = -1

func _ready() -> void:
    minute_of_day = float(start_minute)
    _sync_lighting()

func _process(delta: float) -> void:
    if paused:
        return
    var old_minute: int = int(minute_of_day)
    minute_of_day = fposmod(minute_of_day + delta * game_minutes_per_real_minute / 60.0, 1440.0)
    if int(minute_of_day) != old_minute:
        minute_changed.emit(hour(), minute())
        _sync_lighting()

func hour() -> int:
    return int(minute_of_day) / 60

func minute() -> int:
    return int(minute_of_day) % 60

func formatted_time() -> String:
    return "%02d:%02d" % [hour(), minute()]

func set_time(hour_value: int, minute_value: int = 0) -> void:
    minute_of_day = float(posmod(hour_value, 24) * 60 + posmod(minute_value, 60))
    minute_changed.emit(hour(), minute())
    _sync_lighting()

func lunch_intensity() -> float:
    var t: float = minute_of_day
    if t < 660.0 or t > 870.0:
        return 0.0
    if t < 720.0:
        return (t - 660.0) / 60.0
    if t < 810.0:
        return 1.0
    return (870.0 - t) / 60.0

func dinner_intensity() -> float:
    var t: float = minute_of_day
    if t < 1020.0 or t > 1200.0:
        return 0.0
    if t < 1080.0:
        return (t - 1020.0) / 60.0
    if t < 1140.0:
        return 0.72
    return (1200.0 - t) / 60.0 * 0.72

func dining_intensity() -> float:
    return maxf(lunch_intensity(), dinner_intensity())

func _sync_lighting() -> void:
    if world == null:
        return
    var t: int = int(minute_of_day)
    var mode: int = 0 if t >= 420 and t < 960 else 1 if t >= 960 and t < 1080 else 2 if t >= 360 and t < 420 or t >= 1080 and t < 1140 else 3
    if mode != last_lighting:
        last_lighting = mode
        world.set_lighting_mode(mode)
