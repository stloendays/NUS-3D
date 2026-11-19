extends CanvasLayer
## Character wardrobe: uses the same capsule/sphere proportions as UTown pedestrians.
## Isolated from player movement, quests, money, and account progress.

const SAVE_PATH := "user://nus3d_outfit.cfg"
const SHIRTS := ["#6c96ad", "#db916f", "#8eac85", "#b49bc9", "#f2cb75", "#e9e8e0"]
const PANTS := ["#354353", "#6c594f", "#566b54", "#31313b"]
const SKINS := ["#d9ad8d", "#f0c5a5", "#a76c50", "#e6b58e"]
const HATS := ["None", "Cap", "Beanie", "Graduation"]
const BAGS := ["None", "Backpack", "Messenger"]

var outfit: Dictionary = {"shirt": 0, "pants": 0, "skin": 0, "hat": 0, "bag": 1}
var panel: PanelContainer
var preview: SubViewport
var character: Node3D
var summary: Label
var is_open: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var previous_movement_lock: bool = false
var previous_coursework_modal: bool = false
var language: NUS3DGameLanguage


func _ready() -> void:
    language = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    if language != null:
        language.language_changed.connect(_apply_ui_locale)
    _load_outfit()
    _make_interface()
    _build_preview()
    _refresh()
    panel.visible = false


func _make_interface() -> void:
    panel = PanelContainer.new()
    panel.name = "WardrobePanel"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -330
    panel.offset_right = 330
    panel.offset_top = -265
    panel.offset_bottom = 265
    add_child(panel)
    var style := StyleBoxFlat.new()
    style.bg_color = Color.html("#f4f1e9")
    style.border_color = Color.html("#30343b")
    style.set_border_width_all(3)
    style.set_corner_radius_all(16)
    panel.add_theme_stylebox_override("panel", style)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 12)
    panel.add_child(outer)
    var title := Label.new()
    title.name = "WardrobeTitle"
    title.text = "CAMPUS WARDROBE   |   F5 to close"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color.html("#252b33"))
    title.add_theme_font_size_override("font_size", 22)
    outer.add_child(title)
    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 16)
    outer.add_child(columns)
    var display := SubViewportContainer.new()
    display.custom_minimum_size = Vector2(270, 360)
    display.stretch = true
    columns.add_child(display)
    preview = SubViewport.new()
    preview.size = Vector2i(270, 360)
    preview.transparent_bg = false
    preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    display.add_child(preview)
    var choices := VBoxContainer.new()
    choices.custom_minimum_size = Vector2(310, 0)
    choices.add_theme_constant_override("separation", 12)
    columns.add_child(choices)
    for item in [
        ["shirt", "Top", SHIRTS.size()],
        ["pants", "Trousers", PANTS.size()],
        ["skin", "Skin tone", SKINS.size()],
        ["hat", "Headwear", HATS.size()],
        ["bag", "Bag", BAGS.size()]
    ]:
        var row := HBoxContainer.new()
        choices.add_child(row)
        var key: String = str(item[0])
        var label := Label.new()
        label.name = key + "Label"
        label.custom_minimum_size.x = 170
        label.add_theme_color_override("font_color", Color.html("#252b33"))
        row.add_child(label)
        var previous := Button.new()
        previous.text = "<"
        row.add_child(previous)
        previous.pressed.connect(_cycle.bind(key, -1, int(item[2])))
        var following := Button.new()
        following.text = ">"
        row.add_child(following)
        following.pressed.connect(_cycle.bind(key, 1, int(item[2])))
    summary = Label.new()
    summary.add_theme_color_override("font_color", Color.html("#46505a"))
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    choices.add_child(summary)
    var close := Button.new()
    close.name = "WardrobeSave"
    close.text = "SAVE & RETURN"
    close.pressed.connect(_toggle)
    outer.add_child(close)
    var rotate_row := HBoxContainer.new()
    outer.add_child(rotate_row)
    var turn_left := Button.new()
    turn_left.name = "WardrobeRotateLeft"
    turn_left.text = "ROTATE LEFT"
    rotate_row.add_child(turn_left)
    turn_left.pressed.connect(_rotate_preview.bind(-1.0))
    var turn_right := Button.new()
    turn_right.name = "WardrobeRotateRight"
    turn_right.text = "ROTATE RIGHT"
    rotate_row.add_child(turn_right)
    turn_right.pressed.connect(_rotate_preview.bind(1.0))


func _mat(hex: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex)
    m.roughness = 0.9
    return m


func _capsule(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := CapsuleMesh.new()
    shape.radius = radius
    shape.height = height
    mesh.mesh = shape
    mesh.position = pos
    mesh.material_override = material
    parent.add_child(mesh)
    return mesh


func _sphere(parent: Node3D, name: String, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := SphereMesh.new()
    shape.radius = radius
    mesh.mesh = shape
    mesh.position = pos
    mesh.material_override = material
    parent.add_child(mesh)
    return mesh


func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.position = pos
    mesh.material_override = material
    parent.add_child(mesh)
    return mesh


func _build_preview() -> void:
    var world := Node3D.new()
    preview.add_child(world)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color.html("#dce8e4")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 0.8
    environment.environment = env
    world.add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35, -25, 0)
    sun.light_energy = 0.8
    world.add_child(sun)
    character = Node3D.new()
    world.add_child(character)
    var camera := Camera3D.new()
    camera.position = Vector3(2.4, 1.5, 3.8)
    world.add_child(camera)
    camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
    camera.current = true


func _refresh() -> void:
    if character == null:
        return
    for child in character.get_children():
        child.queue_free()
    var skin := _mat(SKINS[int(outfit["skin"])])
    var top := _mat(SHIRTS[int(outfit["shirt"])])
    var pants := _mat(PANTS[int(outfit["pants"])])
    var dark := _mat("#303c4a")
    _capsule(character, "Torso", Vector3(0, 0.98, 0), 0.27, 1.08, top)
    _sphere(character, "Head", Vector3(0, 1.72, 0), 0.22, skin)
    for side in [-1.0, 1.0]:
        _capsule(character, "Leg", Vector3(side * 0.14, 0.37, 0), 0.12, 0.72, pants)
        _capsule(character, "Arm", Vector3(side * 0.34, 0.98, 0), 0.095, 0.7, top)
        _sphere(character, "Eye", Vector3(side * 0.085, 1.75, 0.205), 0.027, dark)
    var hat: int = int(outfit["hat"])
    if hat == 1:
        _box(character, "Cap", Vector3(0, 1.97, 0), Vector3(0.43, 0.13, 0.4), top)
        _box(character, "Brim", Vector3(0, 1.91, 0.22), Vector3(0.43, 0.05, 0.22), top)
    elif hat == 2:
        _sphere(character, "Beanie", Vector3(0, 1.93, 0), 0.24, top)
    elif hat == 3:
        _box(character, "Mortarboard", Vector3(0, 2.0, 0), Vector3(0.6, 0.06, 0.6), dark)
    var bag: int = int(outfit["bag"])
    if bag == 1:
        _box(character, "Backpack", Vector3(0, 1.05, -0.3), Vector3(0.43, 0.62, 0.22), dark)
    elif bag == 2:
        _box(character, "Messenger", Vector3(0.28, 0.83, 0.02), Vector3(0.28, 0.35, 0.25), dark)
    _apply_ui_locale()


func _tr(chinese: String, english: String) -> String:
    return language.choose(chinese, english) if language != null else english


func _apply_ui_locale(_locale: String = "") -> void:
    if panel == null:
        return
    var title: Label = panel.find_child("WardrobeTitle", true, false) as Label
    if title != null:
        title.text = _tr("校园衣橱  |  F5 关闭", "CAMPUS WARDROBE   |   F5 to close")
    var save: Button = panel.find_child("WardrobeSave", true, false) as Button
    if save != null:
        save.text = _tr("保存并返回", "SAVE & RETURN")
    var turn_left: Button = panel.find_child("WardrobeRotateLeft", true, false) as Button
    if turn_left != null:
        turn_left.text = _tr("向左旋转", "ROTATE LEFT")
    var turn_right: Button = panel.find_child("WardrobeRotateRight", true, false) as Button
    if turn_right != null:
        turn_right.text = _tr("向右旋转", "ROTATE RIGHT")
    var zh_titles: Dictionary = {
        "shirt": "上衣", "pants": "长裤", "skin": "肤色", "hat": "帽子", "bag": "背包"
    }
    var en_titles: Dictionary = {
        "shirt": "Top", "pants": "Trousers", "skin": "Skin tone", "hat": "Headwear", "bag": "Bag"
    }
    var zh_hats: Array[String] = ["无", "棒球帽", "针织帽", "学士帽"]
    var zh_bags: Array[String] = ["无", "双肩包", "斜挎包"]
    for key in ["shirt", "pants", "skin", "hat", "bag"]:
        var label: Label = panel.find_child(key + "Label", true, false) as Label
        if label == null:
            continue
        var selected: String = str(int(outfit[key]) + 1)
        if key == "hat":
            selected = _tr(zh_hats[int(outfit[key])], HATS[int(outfit[key])])
        elif key == "bag":
            selected = _tr(zh_bags[int(outfit[key])], BAGS[int(outfit[key])])
        label.text = _tr(str(zh_titles[key]), str(en_titles[key])) + ": " + selected
    if summary != null:
        summary.text = _tr(
            "使用游戏现有学生 NPC 的卡通身形。仅为外观预览，不影响游戏属性。",
            "Based on the existing NUS-3D student NPC silhouette. Cosmetic only; no gameplay advantages."
        )


func _cycle(key: String, direction: int, count: int) -> void:
    outfit[key] = posmod(int(outfit[key]) + direction, count)
    _refresh()
    _save_outfit()


func _load_outfit() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return
    for key in outfit.keys():
        var maximum: int = 6 if key == "shirt" else 4 if key == "pants" or key == "skin" or key == "hat" else 3
        outfit[key] = clampi(int(config.get_value("outfit", key, outfit[key])), 0, maximum - 1)


func _save_outfit() -> void:
    var config := ConfigFile.new()
    config.set_value("outfit", "version", 1)
    for key in outfit.keys():
        config.set_value("outfit", key, outfit[key])
    if config.save(SAVE_PATH) != OK:
        push_warning("Could not save cosmetic outfit.")


func _rotate_preview(direction: float) -> void:
    if character != null:
        character.rotate_y(direction * 0.4)


func _can_open() -> bool:
    if get_tree().paused:
        return false
    var player: UTownPlayer = get_parent().get_node_or_null("Player") as UTownPlayer
    var coursework: UTownCoursework = get_parent().get_node_or_null("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = get_parent().get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if player == null or coursework == null or course_ui == null:
        return false
    if player.movement_locked or coursework.modal_open or course_ui.modal_visible or course_ui.intro_blocked:
        return false
    for path in ["EnglishExams", "VoicePresentation", "LeisureUI"]:
        var modal: Node = get_parent().get_node_or_null(path)
        if modal != null and modal.get("is_open") == true:
            return false
    return true


func _toggle() -> void:
    if not is_open and not _can_open():
        return
    var player: UTownPlayer = get_parent().get_node_or_null("Player") as UTownPlayer
    var coursework: UTownCoursework = get_parent().get_node_or_null("Coursework") as UTownCoursework
    if player == null or coursework == null:
        return
    is_open = not is_open
    panel.visible = is_open
    if is_open:
        previous_mouse_mode = Input.mouse_mode
        previous_movement_lock = player.movement_locked
        previous_coursework_modal = coursework.modal_open
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        player.movement_locked = true
        coursework.modal_open = true
    else:
        Input.mouse_mode = previous_mouse_mode
        player.movement_locked = previous_movement_lock
        coursework.modal_open = previous_coursework_modal
        _save_outfit()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F5 or (is_open and event.keycode == KEY_ESCAPE):
            _toggle()
            get_viewport().set_input_as_handled()
