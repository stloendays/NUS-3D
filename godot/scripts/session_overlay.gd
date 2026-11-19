extends CanvasLayer
class_name NUS3DSessionOverlay
## F11 opens LAN room/graphics panel. Lives outside the gameplay HUD and hotkeys.
var shell: Variant
var language: NUS3DGameLanguage
var session_title: Label
var graphics_title: Label
var menu_buttons: Array[Button] = []
var network: NUS3DNetworkSession
var graphics: NUS3DGraphicsSettings
var panel: PanelContainer
var status: Label
var address: LineEdit
var port_input: SpinBox
var quality: OptionButton
var adaptive: CheckBox
var is_open: bool = false


func setup(owner_shell: Variant, game: Node3D) -> void:
    shell = owner_shell
    language = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    network = NUS3DNetworkSession.new()
    network.name = "NetworkSession"
    add_child(network)
    network.bind_game(game)
    graphics = NUS3DGraphicsSettings.new()
    graphics.name = "GraphicsSettings"
    add_child(graphics)
    graphics.apply_to_game(game)
    network.changed.connect(_refresh)
    network.notice.connect(_notice)
    _build()
    if language != null:
        language.language_changed.connect(_on_language_changed)
    _on_language_changed(language.locale if language != null else "en")


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en


func _quality_label(option: String) -> String:
    match option:
        "low":
            return _t("低画质", "Low")
        "medium", "balanced":
            return _t("平衡", "Balanced")
        "high":
            return _t("高画质", "High")
        "ultra":
            return _t("极高", "Ultra")
    return option.capitalize()


func _on_language_changed(_code: String) -> void:
    if panel == null:
        return
    session_title.text = _t("校园联机与性能 [F11]", "CAMPUS LOBBY & PERFORMANCE [F11]")
    graphics_title.text = _t("画质（仅影响本机）", "Graphics quality (local device only)")
    address.placeholder_text = _t("局域网地址（例如 192.168.1.20）",
        "LAN IP or hostname (e.g. 192.168.1.20)")
    port_input.prefix = _t("端口 ", "UDP port ")
    adaptive.text = _t("自适应三维分辨率", "Adaptive 3D resolution")
    for i in range(menu_buttons.size()):
        var key: String = str(menu_buttons[i].get_meta("locale_key", ""))
        match key:
            "host": menu_buttons[i].text = _t("创建房间", "Host LAN")
            "join": menu_buttons[i].text = _t("加入房间", "Join LAN")
            "leave": menu_buttons[i].text = _t("离开房间", "Leave")
            "resume": menu_buttons[i].text = _t("返回游戏 [F11]", "Resume Game [F11]")
    var selected: int = quality.selected
    for i in range(NUS3DGraphicsSettings.ORDER.size()):
        quality.set_item_text(i, _quality_label(str(NUS3DGraphicsSettings.ORDER[i])))
    if selected >= 0:
        quality.select(selected)
    _refresh()


func _build() -> void:
    layer = 35
    process_mode = Node.PROCESS_MODE_ALWAYS
    panel = PanelContainer.new()
    panel.name = "SessionPanel"
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -255
    panel.offset_right = 255
    panel.offset_top = -235
    panel.offset_bottom = 235
    var style: StyleBoxFlat = NUS3DUISkin.glass(Color("#86B4C5"), 25, 19, true)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var layout: VBoxContainer = VBoxContainer.new()
    layout.add_theme_constant_override("separation", 9)
    panel.add_child(layout)
    session_title = Label.new()
    session_title.text = _t("校园联机与性能 [F11]", "CAMPUS LOBBY & PERFORMANCE [F11]")
    session_title.add_theme_font_size_override("font_size", 19)
    layout.add_child(session_title)
    session_title.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_color_override("font_color", NUS3DUISkin.DIM)
    layout.add_child(status)
    address = LineEdit.new()
    address.placeholder_text = _t("局域网地址（例如 192.168.1.20）", "LAN IP or hostname (e.g. 192.168.1.20)")
    layout.add_child(address)
    NUS3DUISkin.field(address)
    port_input = SpinBox.new()
    port_input.min_value = 1024
    port_input.max_value = 65535
    port_input.value = NUS3DNetworkSession.PORT
    port_input.prefix = _t("端口 ", "UDP port ")
    layout.add_child(port_input)
    var buttons: HBoxContainer = HBoxContainer.new()
    layout.add_child(buttons)
    buttons.add_child(_button("host", _t("创建房间", "Host LAN"), _host))
    buttons.add_child(_button("join", _t("加入房间", "Join LAN"), _join))
    buttons.add_child(_button("leave", _t("离开房间", "Leave"), _leave))
    var divider: HSeparator = HSeparator.new()
    layout.add_child(divider)
    graphics_title = Label.new()
    graphics_title.text = _t("画质（仅影响本机）", "Graphics quality (local device only)")
    layout.add_child(graphics_title)
    graphics_title.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    quality = OptionButton.new()
    for option in NUS3DGraphicsSettings.ORDER:
        quality.add_item(_quality_label(str(option)))
    quality.select(NUS3DGraphicsSettings.ORDER.find(graphics.preset))
    quality.item_selected.connect(_quality_changed)
    NUS3DUISkin.button(quality)
    layout.add_child(quality)
    adaptive = CheckBox.new()
    adaptive.text = _t("自适应三维分辨率", "Adaptive 3D resolution")
    adaptive.button_pressed = graphics.adaptive_resolution
    adaptive.toggled.connect(func(value: bool) -> void: graphics.set_adaptive_resolution(value); _refresh())
    layout.add_child(adaptive)
    adaptive.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    layout.add_child(_button("resume", _t("返回游戏 [F11]", "Resume Game [F11]"), toggle))
    panel.hide()
    _refresh()


func _button(key: String, text_value: String, action: Callable) -> Button:
    var button: Button = Button.new()
    button.text = text_value
    NUS3DUISkin.button(button)
    button.set_meta("locale_key", key)
    menu_buttons.append(button)
    button.pressed.connect(action)
    return button


func _quality_changed(index: int) -> void:
    graphics.set_preset(NUS3DGraphicsSettings.ORDER[index])
    _refresh()


func _host() -> void:
    if not shell.accounts.is_logged_in():
        _notice(_t("请先登录，再创建房间。", "Sign in before creating a room."))
        return
    _notice(network.host_room(shell.accounts.get_username(), int(port_input.value)))


func _join() -> void:
    if not shell.accounts.is_logged_in():
        _notice(_t("请先登录，再加入房间。", "Sign in before joining a room."))
        return
    _notice(network.join_room(shell.accounts.get_username(), address.text, int(port_input.value)))


func _leave() -> void:
    network.leave_room()
    _refresh()


func _notice(message: String) -> void:
    if not message.is_empty():
        status.text = (language.game_text(message) if language != null else message) + "\n" + status.text


func _refresh() -> void:
    if status == null:
        return
    var modes: Array[String] = [
        _t("离线", "Offline"), _t("房主", "Host"),
        _t("连接中", "Connecting"), _t("客户端", "Client")]
    var mode: String = modes[network.state]
    var graphics_status: String = graphics.status_text()
    if language != null:
        graphics_status = language.game_text(graphics_status)
    status.text = _t("状态：%s | 玩家 %d/%d\n%s\n",
        "Session: %s | Players: %d/%d\n%s\n") % [
        mode, network.player_count(), NUS3DNetworkSession.MAX_PLAYERS, graphics_status]
    if network.is_online():
        var names: PackedStringArray = PackedStringArray()
        for id in network.roster:
            names.append(str(network.roster[id]))
        status.text += _t("名单：", "Roster: ") + ", ".join(names)


func toggle() -> void:
    if shell.mail_cover != null and shell.mail_cover.visible:
        return
    if shell.login_cover != null and shell.login_cover.visible:
        return
    if not is_open and get_tree().paused:
        # Respect login, exam, story and player-modal ownership.
        return
    is_open = not is_open
    panel.visible = is_open
    if is_open:
        get_tree().paused = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        _refresh()
    else:
        get_tree().paused = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
        toggle()
        get_viewport().set_input_as_handled()
