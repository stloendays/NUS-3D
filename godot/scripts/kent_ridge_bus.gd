extends CanvasLayer
class_name NUSCampusBusTravel
## Mouse-driven inter-campus express trips. No new hotkeys or input interception.
## D1/D2 names are real; in-game stop order, stops and express travel are schematic.

const BOARD_RADIUS_M: float = 17.0
const FEEDBACK_SECONDS: float = 3.8

@onready var network: NUSKentRidgeWorld = $"../KentRidgeExpansion"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var hud: CanvasLayer = $"../HUD"
@onready var coins: UTownCoins = $"../Coins"

var offer: PanelContainer
var offer_station: Label
var offer_button: Button
var menu: Control
var menu_title: Label
var menu_info: Label
var route_buttons: Dictionary = {}
var route_list: VBoxContainer
var map_canvas: Control
var travel_cover: Control
var travel_title: Label
var travel_detail: Label
var arrival_card: PanelContainer
var arrival_label: Label
var origin_id: String = ""
var selected_route: String = "D1"
var destination_id: String = ""
var menu_open: bool = false
var traveling: bool = false
var travel_remaining: float = 0.0
var travel_duration: float = 0.0
var arrival_remaining: float = 0.0
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _paused_by_bus: bool = false
var _refresh_timer: float = 0.0

func _ready() -> void:
    layer = 15
    # The account shell may have paused the gameplay scene already.
    # ALWAYS is needed only for a user-opened transit modal while the 3D world is frozen.
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_offer()
    _build_menu()
    _build_travel_cover()
    _build_arrival_message()


func _style(background: Color, border_color: Color, radius: int = 13, pad: int = 12) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border_color
    style.set_border_width_all(1)
    style.border_width_top = 2
    style.set_corner_radius_all(radius)
    style.content_margin_left = pad
    style.content_margin_right = pad
    style.content_margin_top = pad
    style.content_margin_bottom = pad
    style.shadow_color = Color(0.005, 0.025, 0.035, 0.65)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 4)
    return style


func _label(value: String, font_size_value: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size_value)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _button(text_value: String, callback: Callable) -> Button:
    var button: Button = Button.new()
    button.text = text_value
    button.custom_minimum_size.y = 37
    button.add_theme_stylebox_override("normal", _style(Color("#26434c"), Color("#83c6d3"), 8, 8))
    button.add_theme_stylebox_override("hover", _style(Color("#365c66"), Color("#bbf4e9"), 8, 8))
    button.add_theme_stylebox_override("pressed", _style(Color("#1d565c"), Color("#a2efcb"), 8, 8))
    button.add_theme_color_override("font_color", Color("#f4f8f1"))
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.pressed.connect(callback)
    return button


func _build_offer() -> void:
    offer = PanelContainer.new()
    offer.name = "NearBusStop"
    offer.anchor_left = 1.0
    offer.anchor_right = 1.0
    offer.offset_left = -338.0
    offer.offset_right = -18.0
    offer.offset_top = 259.0
    offer.offset_bottom = 359.0
    offer.add_theme_stylebox_override("panel", _style(Color(0.065, 0.14, 0.17, 0.96), Color("#f0ca77")))
    add_child(offer)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    offer.add_child(column)
    offer_station = _label("BUS STOP", 15, Color("#f8e9b5"))
    offer_station.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(offer_station)
    offer_button = _button("View bus routes  (Esc + click)", _open_menu)
    column.add_child(offer_button)
    offer.hide()


func _build_menu() -> void:
    menu = Control.new()
    menu.name = "CampusBusMenu"
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(menu)
    var scrim: ColorRect = ColorRect.new()
    scrim.color = Color(0.015, 0.03, 0.045, 0.83)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    menu.add_child(scrim)
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(center)
    var card: PanelContainer = PanelContainer.new()
    card.custom_minimum_size = Vector2(930, 550)
    card.add_theme_stylebox_override("panel", _style(Color("#132b36"), Color("#e9c77d"), 17, 18))
    center.add_child(card)

    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 9)
    card.add_child(column)
    var heading: HBoxContainer = HBoxContainer.new()
    heading.add_theme_constant_override("separation", 14)
    column.add_child(heading)
    menu_title = _label("CAMPUS BUS  /  NUS-3D", 23, Color("#ffecc1"))
    menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(menu_title)
    heading.add_child(_button("CLOSE", _close_menu))
    menu_info = _label("ILLUSTRATIVE ROUTES ONLY • NOT REAL NAVIGATION", 12, Color("#bad0d0"))
    menu_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(menu_info)
    var columns: HBoxContainer = HBoxContainer.new()
    columns.add_theme_constant_override("separation", 14)
    column.add_child(columns)

    var map_panel: PanelContainer = PanelContainer.new()
    map_panel.custom_minimum_size = Vector2(505, 405)
    map_panel.add_theme_stylebox_override("panel", _style(Color("#172b32"), Color("#62888d"), 10, 9))
    columns.add_child(map_panel)
    map_canvas = Control.new()
    map_canvas.name = "CampusAtlas"
    map_canvas.custom_minimum_size = Vector2(485, 387)
    map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_canvas.draw.connect(_draw_atlas)
    map_panel.add_child(map_canvas)

    var right: VBoxContainer = VBoxContainer.new()
    right.custom_minimum_size.x = 354
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 8)
    columns.add_child(right)
    right.add_child(_label("CHOOSE A GAME BUS LINE", 14, Color("#e5e7e0")))
    var switcher: HBoxContainer = HBoxContainer.new()
    switcher.add_theme_constant_override("separation", 7)
    right.add_child(switcher)
    for route_id in ["D1", "D2"]:
        var button: Button = _button(route_id, _select_route.bind(route_id))
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        route_buttons[route_id] = button
        switcher.add_child(button)
    right.add_child(_label("EXPRESS DESTINATIONS / SCHEMATIC", 12, Color("#a7c6c9")))
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(354, 310)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right.add_child(scroll)
    route_list = VBoxContainer.new()
    route_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    route_list.add_theme_constant_override("separation", 7)
    scroll.add_child(route_list)
    right.add_child(_label("Game rides skip the journey with a brief transition.\nFor real travel, consult NUS UCI routes.", 11, Color("#a0b4b8")))
    menu.hide()


func _build_travel_cover() -> void:
    travel_cover = Control.new()
    travel_cover.name = "TransitSequence"
    travel_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    travel_cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(travel_cover)
    var scrim: ColorRect = ColorRect.new()
    scrim.color = Color(0.01, 0.06, 0.075, 0.97)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    travel_cover.add_child(scrim)
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    travel_cover.add_child(center)
    var card: PanelContainer = PanelContainer.new()
    card.custom_minimum_size = Vector2(520, 178)
    card.add_theme_stylebox_override("panel", _style(Color("#1c424a"), Color("#f1c777"), 19, 22))
    center.add_child(card)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    card.add_child(column)
    travel_title = _label("CAMPUS BUS EXPRESS", 24, Color("#fff4d7"))
    travel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(travel_title)
    travel_detail = _label("Loading route...", 16, Color("#c1e7e4"))
    travel_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(travel_detail)
    travel_cover.hide()


func _build_arrival_message() -> void:
    arrival_card = PanelContainer.new()
    arrival_card.name = "ArrivedAtCampus"
    arrival_card.anchor_left = 0.5
    arrival_card.anchor_right = 0.5
    arrival_card.offset_left = -235.0
    arrival_card.offset_right = 235.0
    arrival_card.offset_top = 282.0
    arrival_card.offset_bottom = 354.0
    arrival_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    arrival_card.add_theme_stylebox_override("panel", _style(Color(0.075, 0.19, 0.19, 0.95), Color("#9de4ca")))
    add_child(arrival_card)
    arrival_label = _label("WELCOME TO THE NEXT CAMPUS ZONE", 15, Color("#f0ffdc"))
    arrival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    arrival_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    arrival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    arrival_card.add_child(arrival_label)
    arrival_card.hide()


func _can_offer() -> bool:
    return not get_tree().paused and not menu_open and not traveling and hud.visible and not coins.shop_open and not life.interior_active and not life.on_shuttle and not player.movement_locked


func _open_menu() -> void:
    if not _can_offer():
        return
    var stop: Dictionary = network.nearest_stop(player.global_position, BOARD_RADIUS_M)
    if stop.is_empty():
        return
    origin_id = str(stop["id"])
    _previous_mouse_mode = Input.mouse_mode
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    player.movement_locked = true
    player.velocity = Vector3.ZERO
    menu_open = true
    menu_title.text = "CAMPUS BUS  /  " + str(stop["name"]).to_upper()
    menu_info.text = "ILLUSTRATIVE CAMPUS TRANSPORT • SELECT A DESTINATION • NOT REAL BUS TIMETABLES"
    selected_route = "D1" if network.route_serves("D1", origin_id) else "D2"
    _refresh_destinations()
    offer.hide()
    menu.show()
    _paused_by_bus = not get_tree().paused
    get_tree().paused = true


func _select_route(route_id: String) -> void:
    if not menu_open or not network.route_serves(route_id, origin_id):
        return
    selected_route = route_id
    _refresh_destinations()


func _refresh_destinations() -> void:
    for route_id in route_buttons:
        var button: Button = route_buttons[route_id]
        button.disabled = not network.route_serves(str(route_id), origin_id)
        button.text = ("● " if selected_route == route_id else "") + str(route_id)
    for child in route_list.get_children():
        route_list.remove_child(child)
        child.queue_free()
    var source: Dictionary = network.stop_record(origin_id)
    if source.is_empty():
        return
    for stop_id in network.routes.get(selected_route, []):
        if str(stop_id) == origin_id:
            continue
        var target: Dictionary = network.stop_record(str(stop_id))
        if target.is_empty():
            continue
        var from_world: Vector3 = source["position"]
        var to_world: Vector3 = target["position"]
        var distance_m: float = Vector2(from_world.x, from_world.z).distance_to(Vector2(to_world.x, to_world.z))
        var label: String = "%s\n  %.0f m straight-line" % [str(target["name"]), distance_m]
        var button: Button = _button(label, _ride_to.bind(str(stop_id)))
        button.custom_minimum_size.y = 57.0
        route_list.add_child(button)
    if map_canvas != null:
        map_canvas.queue_redraw()


func _ride_to(stop_id: String) -> void:
    if not menu_open or not network.route_serves(selected_route, origin_id) or not network.route_serves(selected_route, stop_id) or stop_id == origin_id:
        return
    var destination: Dictionary = network.stop_record(stop_id)
    if destination.is_empty():
        return
    destination_id = stop_id
    menu_open = false
    traveling = true
    travel_duration = 2.4
    travel_remaining = travel_duration
    menu.hide()
    travel_cover.show()
    travel_title.text = "%s  /  CAMPUS EXPRESS" % selected_route
    travel_detail.text = "Boarding ...  " + str(destination["name"])


func _finish_trip() -> void:
    traveling = false
    travel_cover.hide()
    var destination: Dictionary = network.stop_record(destination_id)
    if not destination.is_empty():
        player.global_position = (destination["position"] as Vector3) + Vector3(0.0, 0.18, 11.0)
        player.velocity = Vector3.ZERO
        player.rotation.y = 0.0
        player.head.rotation = Vector3.ZERO
        arrival_label.text = "ARRIVED  /  %s\n%s" % [str(destination["name"]), str(destination["tagline"])]
        arrival_card.show()
        arrival_remaining = FEEDBACK_SECONDS
    origin_id = ""
    destination_id = ""
    _end_boarding()


func _end_boarding() -> void:
    player.movement_locked = false
    if _paused_by_bus:
        get_tree().paused = false
    _paused_by_bus = false
    Input.mouse_mode = _previous_mouse_mode


func _close_menu() -> void:
    if not menu_open:
        return
    menu_open = false
    menu.hide()
    origin_id = ""
    _end_boarding()


func _atlas_position(world_point: Vector3) -> Vector2:
    var min_x: float = INF
    var min_z: float = INF
    var max_x: float = -INF
    var max_z: float = -INF
    for station in network.stops:
        var at: Vector3 = station["position"]
        min_x = minf(min_x, at.x)
        min_z = minf(min_z, at.z)
        max_x = maxf(max_x, at.x)
        max_z = maxf(max_z, at.z)
    var width_m: float = maxf(1.0, max_x - min_x)
    var height_m: float = maxf(1.0, max_z - min_z)
    var canvas_size: Vector2 = map_canvas.size
    var scale_value: float = minf((canvas_size.x - 65.0) / width_m, (canvas_size.y - 60.0) / height_m)
    var center: Vector2 = Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
    return Vector2(canvas_size.x * 0.5 + (world_point.x - center.x) * scale_value,
        canvas_size.y * 0.5 + (world_point.z - center.y) * scale_value)


func _draw_atlas() -> void:
    if map_canvas == null or network.stops.is_empty():
        return
    var bounds: Rect2 = Rect2(Vector2.ZERO, map_canvas.size)
    map_canvas.draw_rect(bounds, Color("#1b3139"), true)
    for i in range(1, 6):
        var x: float = map_canvas.size.x * float(i) / 6.0
        var y: float = map_canvas.size.y * float(i) / 6.0
        map_canvas.draw_line(Vector2(x, 0), Vector2(x, map_canvas.size.y), Color(0.20, 0.34, 0.39, 0.35), 1.0)
        map_canvas.draw_line(Vector2(0, y), Vector2(map_canvas.size.x, y), Color(0.20, 0.34, 0.39, 0.35), 1.0)
    for route_id in ["D1", "D2"]:
        var route: Array = network.routes.get(route_id, [])
        var color: Color = Color("#4ed1c7") if route_id == "D1" else Color("#e5ba6b")
        if route_id != selected_route:
            color.a = 0.23
        for i in range(route.size() - 1):
            var left: Dictionary = network.stop_record(str(route[i]))
            var right: Dictionary = network.stop_record(str(route[i + 1]))
            if left.is_empty() or right.is_empty():
                continue
            map_canvas.draw_line(_atlas_position(left["position"]), _atlas_position(right["position"]), color, 3.5 if route_id == selected_route else 1.5, true)
    for station in network.stops:
        var point: Vector2 = _atlas_position(station["position"])
        var is_origin: bool = str(station["id"]) == origin_id
        var served: bool = network.route_serves(selected_route, str(station["id"]))
        var tint: Color = Color("#ffffff") if is_origin else Color("#f1ce7b") if served else Color("#6c888e")
        map_canvas.draw_circle(point, 5.7 if is_origin else 3.5, tint)
        if is_origin:
            map_canvas.draw_arc(point, 10.0, 0.0, TAU, 24, Color("#9bf9ee"), 2.0)
        var short: String = str(station["id"]).replace("_", " ")
        map_canvas.draw_string(ThemeDB.fallback_font, point + Vector2(6.5, -5), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e8ecdf") if served or is_origin else Color("#81999d"))
    var you: Vector2 = _atlas_position(player.global_position)
    map_canvas.draw_circle(you, 3.0, Color("#9cf5f0"))
    map_canvas.draw_string(ThemeDB.fallback_font, Vector2(10, 20), "NORTH  ↑  /  SCHEMATIC NUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d9e8de"))
    map_canvas.draw_string(ThemeDB.fallback_font, Vector2(10, map_canvas.size.y - 10), "D1 aqua   •   D2 amber   •   not a route planner", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a9bfc2"))


func _process(delta: float) -> void:
    if traveling:
        travel_remaining = maxf(0.0, travel_remaining - delta)
        var done: float = 1.0 - travel_remaining / maxf(travel_duration, 0.1)
        travel_detail.text = "Cross-campus express  /  %d%%" % mini(100, roundi(done * 100.0))
        if travel_remaining <= 0.0:
            _finish_trip()
        return
    if arrival_remaining > 0.0:
        arrival_remaining = maxf(0.0, arrival_remaining - delta)
        if arrival_remaining <= 0.0:
            arrival_card.hide()
    if menu_open:
        return
    _refresh_timer += delta
    if _refresh_timer < 0.23:
        return
    _refresh_timer = 0.0
    var nearby: Dictionary = network.nearest_stop(player.global_position, BOARD_RADIUS_M) if _can_offer() else {}
    if nearby.is_empty():
        offer.hide()
        return
    offer_station.text = "NUS BUS  /  " + str(nearby["name"])
    offer.show()
