extends CanvasLayer
class_name NUSScienceCampusActivities
## Mouse-only interactions for the Science canteen and sports field.
## No input events or new key bindings; rewards are persistent and claim-once.

const RANGE_M: float = 16.0
@onready var player: UTownPlayer = $"../Player"
@onready var network: NUSKentRidgeWorld = $"../KentRidgeExpansion"
@onready var coins: UTownCoins = $"../Coins"
@onready var hud: CanvasLayer = $"../HUD"

var panel: PanelContainer
var title: Label
var description: Label
var buttons: VBoxContainer
var message: Label
var _near_zone: String = ""
var _hide_time: float = 0.0
var _rest_time: float = 0.0
var _shoot_cooldown: float = 0.0
var _claimed_today: bool = false


func _ready() -> void:
    layer = 16
    _build_ui()


func _style(background: Color, border: Color) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = background
    s.border_color = border
    s.set_border_width_all(1)
    s.border_width_top = 2
    s.set_corner_radius_all(13)
    s.content_margin_left = 14
    s.content_margin_right = 14
    s.content_margin_top = 11
    s.content_margin_bottom = 11
    s.shadow_color = Color(0.01, 0.03, 0.05, 0.65)
    s.shadow_size = 8
    s.shadow_offset = Vector2(0, 4)
    return s


func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "ScienceActivitiesCard"
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -210
    panel.offset_right = 210
    panel.offset_top = -255
    panel.offset_bottom = -85
    panel.add_theme_stylebox_override("panel", _style(Color("#17343b"), Color("#a4d9bd")))
    add_child(panel)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    panel.add_child(column)
    title = Label.new()
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", Color("#f5edcf"))
    column.add_child(title)
    description = Label.new()
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.add_theme_font_size_override("font_size", 12)
    description.add_theme_color_override("font_color", Color("#c4d8d1"))
    column.add_child(description)
    buttons = VBoxContainer.new()
    buttons.add_theme_constant_override("separation", 5)
    column.add_child(buttons)
    message = Label.new()
    message.add_theme_font_size_override("font_size", 12)
    message.add_theme_color_override("font_color", Color("#f0d79a"))
    column.add_child(message)
    panel.hide()


func _button(text_value: String, callback: Callable) -> Button:
    var b: Button = Button.new()
    b.text = text_value
    b.custom_minimum_size.y = 34
    b.add_theme_stylebox_override("normal", _style(Color("#294a50"), Color("#80bcb0")))
    b.add_theme_stylebox_override("hover", _style(Color("#39636a"), Color("#c3edcf")))
    b.add_theme_color_override("font_color", Color("#f3f4e9"))
    b.pressed.connect(callback)
    return b


func _clear_buttons() -> void:
    for child in buttons.get_children():
        buttons.remove_child(child)
        child.queue_free()


func _show_canteen() -> void:
    _clear_buttons()
    title.text = "FRONTIER CANTEEN"
    description.text = "A break between lab reports. Sit down, grab a drink, and let your laptop cool off."
    buttons.add_child(_button("Take a proper lunch break  /  Restore focus", _take_break))
    buttons.add_child(_button("Ask the canteen auntie for today's special", _canteen_chat))
    panel.show()


func _show_sports() -> void:
    _clear_buttons()
    title.text = "SCIENCE SPORTS FIELD"
    description.text = "A little exercise before the next deadline. The goalposts are judging your technique."
    buttons.add_child(_button("Take a penalty shot  /  +8 C first-time reward", _penalty_shot))
    buttons.add_child(_button("Cheer for the campus team", _cheer))
    panel.show()


func _take_break() -> void:
    _rest_time = 8.0
    player.velocity = Vector3.ZERO
    message.text = "Focus restored. The assignment is still there, unfortunately."
    description.text = "You take a quiet seat beneath the covered walkway. Take a breath."
    _hide_time = 4.0


func _canteen_chat() -> void:
    message.text = "Auntie: 'You look like you have not seen sunlight since reading week.'"
    _hide_time = 5.0


func _penalty_shot() -> void:
    if _shoot_cooldown > 0.0:
        message.text = "Ball retrieval in progress. Please respect the goalkeeper."
        return
    _shoot_cooldown = 2.0
    var paid: bool = coins.reward_once("science_field_penalty_first_visit", 8, "Science field first goal")
    message.text = "GOAL!  +8 C" if paid else "GOAL! The crowd celebrates. Your first-time reward is already claimed."
    var goal: Node3D = network.get_node_or_null("ScienceSportsGround") as Node3D
    if goal != null:
        var ball: MeshInstance3D = goal.get_node_or_null("PracticeBall") as MeshInstance3D
        if ball != null:
            ball.visible = false
            var tween: Tween = create_tween()
            tween.tween_interval(0.35)
            tween.tween_callback(func() -> void: if is_instance_valid(ball): ball.visible = true)
    _hide_time = 4.0


func _cheer() -> void:
    message.text = "Your team scores. The lab group chat immediately asks who is writing the report."
    _hide_time = 4.0


func _process(delta: float) -> void:
    if _shoot_cooldown > 0.0:
        _shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)
    if _rest_time > 0.0:
        _rest_time = maxf(0.0, _rest_time - delta)
    if _hide_time > 0.0:
        _hide_time = maxf(0.0, _hide_time - delta)
        if _hide_time <= 0.0 and not message.text.is_empty():
            panel.hide()
            _near_zone = ""
    if get_tree().paused or not hud.visible or player.movement_locked:
        panel.hide()
        return
    var science_stop: Vector3 = network.stop_position("SCIENCE")
    var sports_stop: Vector3 = network.stop_position("SPORTS")
    var d_science: float = Vector2(player.global_position.x - science_stop.x, player.global_position.z - science_stop.z).length()
    var d_sports: float = Vector2(player.global_position.x - sports_stop.x, player.global_position.z - sports_stop.z).length()
    var zone: String = "canteen" if d_science <= RANGE_M else "sports" if d_sports <= RANGE_M else ""
    if zone != _near_zone:
        _near_zone = zone
        message.text = ""
        _hide_time = 0.0
        if zone == "canteen":
            _show_canteen()
        elif zone == "sports":
            _show_sports()
        else:
            panel.hide()
