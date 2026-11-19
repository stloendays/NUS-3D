extends Node
class_name NUS3DGameLanguage
## Offline localization service. Catalog keys are English source strings.
## UI preferences are global to this installation, never tied to account XP/saves.

signal language_changed(locale: String)

const CATALOG_PATH: String = "res://data/language_catalog.json"
const LOCALE_SAVE: String = "user://nus3d_locale.cfg"
const SUPPORTED: PackedStringArray = PackedStringArray(["en", "zh"])

var locale: String = "en"
var save_path: String = LOCALE_SAVE
var catalog: Dictionary = {}
var fragments: Array = []
var stop_zh: Dictionary = {}


func _ready() -> void:
    _load_catalog()
    var saved: ConfigFile = ConfigFile.new()
    if saved.load(save_path) == OK:
        var candidate: String = str(saved.get_value("settings", "locale", "en"))
        locale = candidate if SUPPORTED.has(candidate) else "en"
    else:
        locale = "zh" if OS.get_locale_language().begins_with("zh") else "en"


func _load_catalog() -> void:
    if not FileAccess.file_exists(CATALOG_PATH):
        push_error("NUS-3D language catalogue missing")
        return
    var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    if typeof(payload) != TYPE_DICTIONARY:
        push_error("NUS-3D language catalogue is invalid")
        return
    catalog = payload
    var items: Variant = catalog.get("fragments", [])
    fragments = items if typeof(items) == TYPE_ARRAY else []
    fragments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("en", "")).length() > str(b.get("en", "")).length()
    )
    var stops: Variant = catalog.get("tour_zh", {})
    stop_zh = stops if typeof(stops) == TYPE_DICTIONARY else {}


func is_chinese() -> bool:
    return locale == "zh"


func set_locale(language_code: String) -> bool:
    if not SUPPORTED.has(language_code):
        return false
    if locale == language_code:
        return true
    locale = language_code
    var settings: ConfigFile = ConfigFile.new()
    settings.set_value("settings", "schema_version", 1)
    settings.set_value("settings", "locale", locale)
    if settings.save(save_path) != OK:
        push_warning("Language preference could not be saved")
    language_changed.emit(locale)
    return true


func ui_text(source: String) -> String:
    if not is_chinese():
        return source
    var translations: Dictionary = catalog.get("ui", {})
    return str(translations.get(source, source))


func localized_text(chinese: String, english: String) -> String:
    return chinese if is_chinese() else english


func game_text(source: String) -> String:
    # Use only for authored game output (HUD, scripted system mail, challenges).
    # NEVER call on player-written email bodies/subjects or usernames.
    if not is_chinese():
        return source
    var exact: String = ui_text(source)
    if exact != source:
        return exact
    var result: String = source
    for raw in fragments:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var fragment: Dictionary = raw
        var english: String = str(fragment.get("en", ""))
        if english.length() >= 4:
            result = result.replace(english, str(fragment.get("zh", english)))
    return result


func apply_static_ui(node: Node) -> void:
    # Preserve English sources once, so switching back does not translate Chinese twice.
    # Dynamic and user-generated fields opt out using i18n_dynamic metadata.
    if bool(node.get_meta("i18n_dynamic", false)):
        return
    if node is Label:
        var label: Label = node
        if not label.has_meta("i18n_original_text"):
            label.set_meta("i18n_original_text", label.text)
        label.text = ui_text(str(label.get_meta("i18n_original_text")))
    elif node is Button:
        var button: Button = node
        if not button.has_meta("i18n_original_text"):
            button.set_meta("i18n_original_text", button.text)
        button.text = ui_text(str(button.get_meta("i18n_original_text")))
    elif node is LineEdit:
        var edit: LineEdit = node
        if not edit.has_meta("i18n_original_placeholder"):
            edit.set_meta("i18n_original_placeholder", edit.placeholder_text)
        edit.placeholder_text = ui_text(str(edit.get_meta("i18n_original_placeholder")))
    elif node is TextEdit:
        var area: TextEdit = node
        if not area.has_meta("i18n_original_placeholder"):
            area.set_meta("i18n_original_placeholder", area.placeholder_text)
        area.placeholder_text = ui_text(str(area.get_meta("i18n_original_placeholder")))
    for child in node.get_children():
        apply_static_ui(child)


func tour_card(tour: UTownTour) -> String:
    if not is_chinese():
        return tour.card_text()
    if tour.last_discovered_index >= 0 and tour.toast_remaining > 0.0:
        var found: Dictionary = tour.stops[tour.last_discovered_index]
        var item: Dictionary = stop_zh.get(str(found.get("id", "")), {})
        var heading: String = "UTOWN 探索全部完成！" if tour.completed else "探索打卡 %d / %d" % [tour.discovered_ids.size(), tour.stops.size()]
        var footer: String = "按 G 可以重新探索。" if tour.completed else "前往下一个打卡点，DDL 没有在等你。"
        return "%s  —  %s\n%s\n%s" % [
            heading, str(item.get("title", found.get("title", ""))),
            str(item.get("discovery", found.get("discovery", ""))), footer
        ]
    if tour.completed:
        return "UTOWN 探索者 | %d 个地点全部打卡\n非官方校园探索已完成。按 G 可以重玩。" % tour.stops.size()
    if tour.can_check_in():
        var current: Dictionary = tour.current_stop()
        var text: Dictionary = stop_zh.get(str(current.get("id", "")), {})
        return "打卡点 — %s\n%s\n按 E 打卡。此路线仅为游戏示意。" % [
            str(text.get("title", current.get("title", ""))),
            str(text.get("observation", current.get("observation", "")))
        ]
    return ""


func challenge_card(challenge: UTownChallenge) -> String:
    return game_text(challenge.status_text())


func weather_card(weather: UTownWeather) -> String:
    if not is_chinese():
        return weather.status_text()
    var condition: String = "路面逐渐变干" if weather.mode < 3 and weather.wetness > 0.07 \
        else "干燥" if weather.mode <= 2 else "雨天 / 地面湿滑" if weather.mode == 3 else "雷暴 / 地面湿滑"
    var weather_names: PackedStringArray = PackedStringArray(["晴天", "多云", "阴天", "下雨", "雷暴"])
    return "天气 %s | %s | [Y] 切换" % [weather_names[clampi(weather.mode, 0, 4)], condition]


func hud_hint(world: UTownWorld) -> String:
    if not is_chinese():
        return "M2 %s [F2] | %s [T] | OSM %s [F6] | Notes [C] | Sprint [V]" % [
            "ON" if world.m2_details_visible else "OFF", world.lighting_name(),
            "ON" if world.osm_reference_visible else "OFF"]
    return "M2 %s [F2] | 光线 %s [T] | OSM %s [F6] | 笔记 [C] | 竞速 [V]" % [
        "开" if world.m2_details_visible else "关",
        game_text(world.lighting_name()),
        "开" if world.osm_reference_visible else "关"
    ]


func hud_target(tour: UTownTour) -> String:
    if not is_chinese():
        if tour.completed:
            return "Tour complete  |  %d/%d stops  [G replay]" % [tour.discovered_ids.size(), tour.stops.size()]
        if not tour.current_stop().is_empty():
            var destination: Dictionary = tour.current_stop()
            return "Tour %d/%d  |  %s  %.0f m" % [
                tour.discovered_ids.size(), tour.stops.size(), str(destination["id"]), tour.current_distance_m()]
        return "Tour unavailable"
    if tour.completed:
        return "探索完成 | %d/%d 地点 [G 重玩]" % [tour.discovered_ids.size(), tour.stops.size()]
    var stop: Dictionary = tour.current_stop()
    if stop.is_empty():
        return "探索暂不可用"
    return "探索 %d/%d | %s %.0f 米" % [
        tour.discovered_ids.size(), tour.stops.size(), str(stop.get("id", "")), tour.current_distance_m()
    ]


func system_mail(subject: String, body: String) -> Dictionary:
    # Only system-generated mail is eligible; never translate user mail.
    if not is_chinese():
        return {"subject": subject, "body": body}
    if subject == "Welcome to NUS-3D!":
        return {"subject": "欢迎来到 NUS-3D！",
            "body": "离线探索账号已创建！\n\n探索四个打卡点、收集笔记、完成校园竞速，就能积累经验。按 J 打开游戏邮箱。\n\n这是非官方游戏，不是 NUS 登录或真实邮件服务。"}
    if subject.begins_with("Level up! LV "):
        var number: String = subject.trim_prefix("Level up! LV ")
        return {"subject": "升级啦！LV " + number,
            "body": "恭喜你升级到 LV %s！\n保持探索，DDL 追得上你，经验也追得上。" % number}
    return {"subject": game_text(subject), "body": game_text(body)}
