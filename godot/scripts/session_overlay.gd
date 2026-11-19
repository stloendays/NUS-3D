extends CanvasLayer
class_name NUS3DSessionOverlay
## F11 opens LAN room/graphics panel. Lives outside the gameplay HUD and hotkeys.
var shell: Variant
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
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color("#12232d")
    style.border_color = Color("#79a6b5")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(18)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var layout: VBoxContainer = VBoxContainer.new()
    layout.add_theme_constant_override("separation", 9)
    panel.add_child(layout)
    var title: Label = Label.new()
    title.text = "CAMPUS LOBBY / PERFORMANCE  [F11]"
    title.add_theme_font_size_override("font_size", 19)
    layout.add_child(title)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(status)
    address = LineEdit.new()
    address.placeholder_text = "LAN IP or hostname (e.g. 192.168.1.20)"
    layout.add_child(address)
    port_input = SpinBox.new()
    port_input.min_value = 1024
    port_input.max_value = 65535
    port_input.value = NUS3DNetworkSession.PORT
    port_input.prefix = "UDP port "
    layout.add_child(port_input)
    var buttons: HBoxContainer = HBoxContainer.new()
    layout.add_child(buttons)
    buttons.add_child(_button("Host LAN", _host))
    buttons.add_child(_button("Join LAN", _join))
    buttons.add_child(_button("Leave", _leave))
    var divider: HSeparator = HSeparator.new()
    layout.add_child(divider)
    var label: Label = Label.new()
    label.text = "Graphics quality (local device only)"
    layout.add_child(label)
    quality = OptionButton.new()
    for option in NUS3DGraphicsSettings.ORDER:
        quality.add_item(option.capitalize())
    quality.select(NUS3DGraphicsSettings.ORDER.find(graphics.preset))
    quality.item_selected.connect(_quality_changed)
    layout.add_child(quality)
    adaptive = CheckBox.new()
    adaptive.text = "Adaptive 3D resolution"
    adaptive.button_pressed = graphics.adaptive_resolution
    adaptive.toggled.connect(func(value: bool) -> void: graphics.set_adaptive_resolution(value); _refresh())
    layout.add_child(adaptive)
    layout.add_child(_button("Resume game  [F11]", toggle))
    panel.hide()
    _refresh()


func _button(text_value: String, action: Callable) -> Button:
    var button: Button = Button.new()
    button.text = text_value
    button.pressed.connect(action)
    return button


func _quality_changed(index: int) -> void:
    graphics.set_preset(NUS3DGraphicsSettings.ORDER[index])
    _refresh()


func _host() -> void:
    if not shell.accounts.is_logged_in():
        _notice("Sign in before creating a room.")
        return
    _notice(network.host_room(shell.accounts.get_username(), int(port_input.value)))


func _join() -> void:
    if not shell.accounts.is_logged_in():
        _notice("Sign in before joining a room.")
        return
    _notice(network.join_room(shell.accounts.get_username(), address.text, int(port_input.value)))


func _leave() -> void:
    network.leave_room()
    _refresh()


func _notice(message: String) -> void:
    if not message.is_empty():
        status.text = message + "\n" + status.text


func _refresh() -> void:
    if status == null:
        return
    var mode: String = ["OFFLINE", "HOST", "CONNECTING", "CLIENT"][network.state]
    status.text = "Session: %s   Players: %d/%d\n%s\n" % [
        mode, network.player_count(), NUS3DNetworkSession.MAX_PLAYERS, graphics.status_text()]
    if network.is_online():
        var names: PackedStringArray = PackedStringArray()
        for id in network.roster:
            names.append(str(network.roster[id]))
        status.text += "Roster: " + ", ".join(names)


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
