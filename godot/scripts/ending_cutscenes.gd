extends CanvasLayer
class_name NUS3DEndingCutscenes
## Lightweight vector/cartoon ending sequences. No external textures or gameplay mutation.
signal finished

const PALETTES := {
    "loop_breaker": ["#202c58", "#f8d56c", "03:01", "TIME LOOP BROKEN"],
    "campus_hero": ["#27645b", "#ffe1a1", "NUS", "CAMPUS HERO"],
    "ddl_survivor": ["#244f6a", "#b3e8b5", "100%", "SUBMITTED!"],
    "burnout": ["#674350", "#f2b080", "COFFEE", "SYSTEM OVERHEAT"],
    "integrity_alarm": ["#772f40", "#ffb7a5", "!", "PLOT TWIST!"],
    "ddl_blackhole": ["#322a60", "#d9a5ee", "9999", "TOMORROW FOREVER"]
}
const SHOTS := {
    "loop_breaker": ["03:00", "03:01", "8 AM IS THE FINAL BOSS"],
    "campus_hero": ["GROUP PROJECT SAVED", "LAB NOTES RETURNED", "ONE-PAGE SPEECH"],
    "ddl_survivor": ["UPLOAD 99%", "UPLOAD 100%", "NEW SEMESTER UNLOCKED"],
    "burnout": ["ESPRESSO x4", "LAPTOP FAN: MAX", "COFFEE MACHINE HEIR"],
    "integrity_alarm": ["SLIDES: PERFECT", "DATA: NOT SO MUCH", "REPEAT THE EXPERIMENT"],
    "ddl_blackhole": ["I'LL DO IT TOMORROW", "TOMORROW x9999", "THE DEADLINE BLACK HOLE"]
}

var curtain: ColorRect
var actor: Control
var actor_face: Label
var stage: SubViewport
var puppet: NUS3DCartoonActor
var puppet_tween: Tween
var camera_3d: Camera3D
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var headline: Label
var subline: Label
var skip: Button
var active: bool = false
var generation: int = 0
var timeline: Tween


func _ready() -> void:
    layer = 90
    process_mode = Node.PROCESS_MODE_ALWAYS
    curtain = ColorRect.new()
    curtain.name = "EndingCutscene"
    curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    curtain.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(curtain)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    curtain.add_child(center)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(480, 330)
    column.add_theme_constant_override("separation", 18)
    center.add_child(column)
    headline = Label.new()
    headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    headline.add_theme_font_size_override("font_size", 32)
    column.add_child(headline)
    actor = Control.new()
    actor.custom_minimum_size = Vector2(320, 155)
    column.add_child(actor)
    var viewport_box := SubViewportContainer.new()
    viewport_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_box.stretch = true
    actor.add_child(viewport_box)
    stage = SubViewport.new()
    stage.size = Vector2i(420, 210)
    stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_box.add_child(stage)
    var world := Node3D.new()
    stage.add_child(world)
    var environment := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color.html("#dce5e4")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color.WHITE
    environment.environment = settings
    world.add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-30, -30, 0)
    world.add_child(light)
    puppet = NUS3DCartoonActor.new()
    world.add_child(puppet)
    camera_3d = Camera3D.new()
    camera_3d.position = Vector3(2.4, 1.6, 3.8)
    world.add_child(camera_3d)
    camera_3d.look_at(Vector3(0, 0.95, 0), Vector3.UP)
    camera_3d.current = true
    actor_face = Label.new()
    actor_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    actor_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    actor_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    actor_face.add_theme_font_size_override("font_size", 24)
    actor_face.add_theme_color_override("font_color", Color.html("#243543"))
    actor.add_child(actor_face)
    subline = Label.new()
    subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subline.add_theme_font_size_override("font_size", 23)
    column.add_child(subline)
    skip = Button.new()
    skip.text = "SKIP / CONTINUE  [ESC]"
    skip.custom_minimum_size.y = 44
    skip.pressed.connect(stop)
    column.add_child(skip)
    curtain.hide()


func play(ending_id: String) -> void:
    if not PALETTES.has(ending_id):
        return
    stop()
    active = true
    generation += 1
    var current: int = generation
    var palette: Array = PALETTES[ending_id]
    curtain.color = Color.html(str(palette[0]))
    actor_face.add_theme_color_override("font_color", Color.html(str(palette[1])))
    headline.text = str(palette[3])
    previous_mouse_mode = Input.mouse_mode
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    curtain.show()
    # Three small, readable beats; every sequence is skippable.
    var shots: Array = SHOTS[ending_id]
    for i in range(shots.size()):
        if not active or generation != current:
            return
        subline.text = str(shots[i])
        actor_face.text = str(palette[2]) if i == 2 else ""
        if puppet_tween != null and puppet_tween.is_running():
            puppet_tween.kill()
        puppet_tween = puppet.pose(ending_id, i, 0.48)
        if camera_3d != null:
            camera_3d.position = Vector3(2.4, 1.6, 3.8)
            camera_3d.fov = 65.0
            var zoom := create_tween().set_parallel(true)
            zoom.tween_property(camera_3d, "position", Vector3(1.85, 1.5, 3.0), 0.9).set_trans(Tween.TRANS_SINE)
            zoom.tween_property(camera_3d, "fov", 54.0, 0.9).set_trans(Tween.TRANS_SINE)
        actor.pivot_offset = actor.size * 0.5
        actor.scale = Vector2(0.82, 0.82)
        actor.rotation = -0.08 if i % 2 == 0 else 0.08
        timeline = create_tween()
        timeline.set_parallel(true)
        timeline.tween_property(actor, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        timeline.tween_property(actor, "rotation", 0.0, 0.38).set_trans(Tween.TRANS_BACK)
        await get_tree().create_timer(1.15, true).timeout
    if active and generation == current:
        stop()


func stop() -> void:
    if not active:
        return
    active = false
    generation += 1
    if timeline != null and timeline.is_running():
        timeline.kill()
    if puppet_tween != null and puppet_tween.is_running():
        puppet_tween.kill()
    curtain.hide()
    Input.mouse_mode = previous_mouse_mode
    finished.emit()


func _unhandled_input(event: InputEvent) -> void:
    if active and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        stop()
        get_viewport().set_input_as_handled()
