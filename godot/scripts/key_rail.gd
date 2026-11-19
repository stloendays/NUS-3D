extends Control
class_name NUS3DKeyRail
## Beveled keycaps depress on keyboard events; does not intercept gameplay input.

const ACTIONS = [
    {"id": "move", "key": "WASD", "hint": "MOVE", "width": 91, "codes": [KEY_W, KEY_A, KEY_S, KEY_D]},
    {"id": "run", "key": "SHIFT", "hint": "RUN", "width": 84, "codes": [KEY_SHIFT]},
    {"id": "discover", "key": "E", "hint": "DISCOVER", "width": 91, "codes": [KEY_E]},
    {"id": "interact", "key": "F", "hint": "ACTIVITY", "width": 83, "codes": [KEY_F]},
    {"id": "talk", "key": "Q", "hint": "TALK", "width": 75, "codes": [KEY_Q]},
    {"id": "interior", "key": "I", "hint": "INSIDE", "width": 80, "codes": [KEY_I]},
    {"id": "notes", "key": "C", "hint": "NOTES", "width": 78, "codes": [KEY_C]},
    {"id": "map", "key": "M", "hint": "MAP", "width": 72, "codes": [KEY_M]},
    {"id": "mail", "key": "J", "hint": "MAIL", "width": 74, "codes": [KEY_J]},
    {"id": "help", "key": "F1", "hint": "HELP", "width": 73, "codes": [KEY_F1]},
    {"id": "audio", "key": "F9", "hint": "SOUND", "width": 80, "codes": [KEY_F9]}
]

var _tiles: Dictionary = {}
var _captions: Dictionary = {}
var _held: Dictionary = {}
var _animations: Dictionary = {}

func _ready() -> void:
    name = "ActionRail"
    anchor_left = 0.0
    anchor_right = 1.0
    anchor_top = 1.0
    anchor_bottom = 1.0
    offset_left = 18.0
    offset_right = -18.0
    offset_top = -55.0
    offset_bottom = -7.0
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    var panel: PanelContainer = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bed: StyleBoxFlat = NUS3DUISkin.panel(Color(0.055, 0.11, 0.14, 0.94), Color("#558d95"), 11, 4)
    bed.shadow_size = 7
    panel.add_theme_stylebox_override("panel", bed)
    add_child(panel)
    var row: HBoxContainer = HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 7)
    panel.add_child(row)
    for action in ACTIONS:
        _add_tile(row, action)
    _refresh_audio_hint()

func _add_tile(row: HBoxContainer, action: Dictionary) -> void:
    var id: String = str(action["id"])
    var width: float = float(action["width"])
    var slot: Control = Control.new()
    slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slot.custom_minimum_size = Vector2(width, 37.0)
    row.add_child(slot)
    var tile: PanelContainer = PanelContainer.new()
    tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tile.size = Vector2(width, 35.0)
    tile.add_theme_stylebox_override("panel", NUS3DUISkin.keycap())
    slot.add_child(tile)
    var column: VBoxContainer = VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 0)
    tile.add_child(column)
    var heading: Label = Label.new()
    heading.text = str(action["key"])
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 15)
    heading.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    column.add_child(heading)
    var caption: Label = Label.new()
    caption.text = str(action["hint"])
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 9)
    caption.add_theme_color_override("font_color", NUS3DUISkin.DIM)
    column.add_child(caption)
    _tiles[id] = tile
    _captions[id] = caption
    _held[id] = false

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if key.echo:
        return
    for action in ACTIONS:
        if (action["codes"] as Array).has(key.keycode):
            var id: String = str(action["id"])
            if bool(_held.get(id, false)) != key.pressed:
                _set_pressed(id, key.pressed)
                if key.pressed:
                    if id == "audio":
                        UISound.toggle_enabled()
                        _refresh_audio_hint()
                    elif id != "move" and id != "run":
                        UISound.play_ui("press")

func _set_pressed(id: String, down: bool) -> void:
    _held[id] = down
    var tile: PanelContainer = _tiles[id]
    tile.add_theme_stylebox_override("panel", NUS3DUISkin.keycap(down))
    var previous: Tween = _animations.get(id) as Tween
    if previous != null and previous.is_running():
        previous.kill()
    var motion: Tween = tile.create_tween()
    motion.set_trans(Tween.TRANS_CUBIC)
    motion.set_ease(Tween.EASE_OUT)
    motion.tween_property(tile, "position:y", 3.0 if down else 0.0, 0.055 if down else 0.13)
    _animations[id] = motion

func _notification(what: int) -> void:
    if (what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) and not _tiles.is_empty():
        for id in _tiles.keys():
            if bool(_held[id]):
                _set_pressed(str(id), false)

func _refresh_audio_hint() -> void:
    if _captions.has("audio"):
        (_captions["audio"] as Label).text = "SOUND" if UISound.enabled else "MUTED"

func key_count() -> int:
    return _tiles.size()
