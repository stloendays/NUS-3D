extends CanvasLayer
class_name UTownExperienceGuide
## Read-only, event-aware UX overlay. No key input, action calls, saves or new physics.
## Built for the standalone UTown gameplay scene; will coexist with account and M6 HUD layers.

const REFRESH_SECONDS: float = 0.22
const ZONE_RADIUS_M: float = 39.0

@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var tour: UTownTour = $"../Tour"
@onready var challenge: UTownChallenge = $"../Challenge"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var indoor_npcs: UTownIndoorNPCs = $"../IndoorNPCs"
@onready var arcade: UTownArcade = $"../Arcade"
@onready var coins: UTownCoins = $"../Coins"
@onready var hud: CanvasLayer = $"../HUD"

var screen: Control
var prompt_card: PanelContainer
var prompt_key: Label
var prompt_name: Label
var prompt_detail: Label
var objective_card: PanelContainer
var objective_arrow: Label
var objective_name: Label
var objective_detail: Label
var objective_distance: Label
var zone_card: PanelContainer
var zone_heading: Label
var zone_caption: Label

var _refresh_elapsed: float = 0.0
var _zone_remaining: float = 0.0
var _active_zone: String = ""
var _visited_zones: Dictionary = {}
var _active_goal: String = ""
var _active_prompt: String = ""
var _zone_motion: Tween
var _goal_motion: Tween
var _prompt_motion: Tween


func _ready() -> void:
    layer = 2
    _make_screen()
    _make_action_card()
    _make_objective_card()
    _make_zone_card()
    # Let the neighbouring gameplay nodes complete their ready handlers.
    call_deferred("_refresh_feedback")


func _make_screen() -> void:
    screen = Control.new()
    screen.name = "ExperienceUI"
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(screen)


func _panel_style(background: Color, trim: Color, radius: int = 12, margin: int = 10) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = trim
    style.set_border_width_all(1)
    style.border_width_top = 2
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin
    style.content_margin_bottom = margin
    style.shadow_color = Color(0.01, 0.025, 0.04, 0.67)
    style.shadow_size = 7
    style.shadow_offset = Vector2(0, 4)
    return style


func _panel(name: String, from_left: float, to_right: float, from_top: float, to_bottom: float, anchor_x: float, anchor_y: float, background: Color, trim: Color) -> PanelContainer:
    var item: PanelContainer = PanelContainer.new()
    item.name = name
    item.anchor_left = anchor_x
    item.anchor_right = anchor_x
    item.anchor_top = anchor_y
    item.anchor_bottom = anchor_y
    item.offset_left = from_left
    item.offset_right = to_right
    item.offset_top = from_top
    item.offset_bottom = to_bottom
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    item.add_theme_stylebox_override("panel", _panel_style(background, trim))
    screen.add_child(item)
    return item


func _label(text_value: String, size_value: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size_value)
    label.add_theme_color_override("font_color", color)
    label.clip_text = true
    return label


func _make_action_card() -> void:
    prompt_card = _panel("ActionSuggestion", -220, 220, 30, 96, 0.5, 0.5, Color(0.065, 0.12, 0.16, 0.96), Color("#82dacb"))
    var horizontal: HBoxContainer = HBoxContainer.new()
    horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    horizontal.add_theme_constant_override("separation", 13)
    prompt_card.add_child(horizontal)

    var cap: PanelContainer = PanelContainer.new()
    cap.custom_minimum_size = Vector2(54, 39)
    cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cap.add_theme_stylebox_override("panel", _panel_style(Color("#315966"), Color("#a1f0dd"), 8, 5))
    horizontal.add_child(cap)
    prompt_key = _label("E", 19, Color("#f6fffe"))
    prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cap.add_child(prompt_key)

    var details: VBoxContainer = VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_theme_constant_override("separation", 3)
    horizontal.add_child(details)
    prompt_name = _label("INTERACT", 16, Color("#f1faf8"))
    prompt_detail = _label("Approach to use", 12, Color("#abcbd1"))
    details.add_child(prompt_name)
    details.add_child(prompt_detail)
    prompt_card.hide()


func _make_objective_card() -> void:
    objective_card = _panel("ObjectiveCompass", -233, 233, 66, 115, 0.5, 0.0, Color(0.055, 0.115, 0.14, 0.95), Color("#e4c783"))
    var row: HBoxContainer = HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 11)
    objective_card.add_child(row)
    objective_arrow = _label("↑", 27, Color("#f5d98d"))
    objective_arrow.custom_minimum_size.x = 32
    objective_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    objective_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(objective_arrow)
    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_theme_constant_override("separation", 0)
    row.add_child(content)
    objective_name = _label("NEXT OBJECTIVE", 14, Color("#f9ead1"))
    objective_detail = _label("Schematic direction only", 11, Color("#9cb9be"))
    content.add_child(objective_name)
    content.add_child(objective_detail)
    objective_distance = _label("0 m", 16, Color("#f1e0aa"))
    objective_distance.custom_minimum_size.x = 68
    objective_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    objective_distance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(objective_distance)
    objective_card.hide()


func _make_zone_card() -> void:
    zone_card = _panel("DistrictPostcard", 18, 402, 354, 430, 0.0, 0.0, Color(0.07, 0.14, 0.16, 0.96), Color("#b1e4c4"))
    var column: VBoxContainer = VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 5)
    zone_card.add_child(column)
    zone_heading = _label("AREA DISCOVERED", 16, Color("#e3f9e9"))
    zone_caption = _label("Your next deadline is already loading.", 12, Color("#b3cfd1"))
    zone_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(zone_heading)
    column.add_child(zone_caption)
    zone_card.hide()


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _candidate(best: Dictionary, priority: int, key: String, title: String, detail: String, distance: float) -> Dictionary:
    if best.is_empty() or priority > int(best.get("priority", 0)) or (priority == int(best.get("priority", 0)) and distance < float(best.get("distance", 9999.0))):
        return {"priority": priority, "key": key, "title": title, "detail": detail, "distance": distance}
    return best


func _nearest_offer() -> Dictionary:
    if life.on_shuttle:
        return _candidate({}, 150, "X", "ALIGHT SHUTTLE", "Back to walking before your next class", 0.0)
    if player.movement_locked or coins.shop_open:
        return {}

    var best: Dictionary = {}
    if life.interior_active:
        var activity: Dictionary = life.nearest_activity()
        if not activity.is_empty():
            var activity_id: String = "%s/%s" % [life.active_interior, str(activity["id"])]
            var caption: String = "Revisit activity" if life.visited_activities.has(activity_id) else "Discover a new indoor activity"
            best = _candidate(best, 120, "F", str(activity.get("name", "Campus activity")), caption, 0.0)
        var person_name: String = indoor_npcs.nearby_name()
        if not person_name.is_empty():
            best = _candidate(best, 108, "Q", "TALK TO " + person_name.to_upper(), "The hallway gossip has lore", 0.0)
        best = _candidate(best, 20, "I", "LEAVE " + life.active_interior, "L: change floor  •  I: back outdoors", 2.0)
        return best

    if coins.delivery_active and _horizontal_distance(player.global_position, coins.delivery_destination) <= coins.DELIVERY_FINISH_RADIUS:
        best = _candidate(best, 150, "N", "DELIVER THE LUNCH", "Your food has survived the deadline", 0.0)
    elif not coins.delivery_active and coins.delivery_cooldown <= 0.0 and coins.delivery_origin != Vector3.ZERO:
        var start_distance: float = _horizontal_distance(player.global_position, coins.delivery_origin)
        if start_distance <= coins.DELIVERY_START_RADIUS:
            best = _candidate(best, 95, "N", "START LUNCH EXPRESS", "Deliver before the food loses hope", start_distance)

    for pickup in coins.pickups:
        if not bool(pickup.get("active", false)):
            continue
        var coin_distance: float = _horizontal_distance(player.global_position, pickup["base"])
        if coin_distance <= coins.PICKUP_RADIUS:
            best = _candidate(best, 135, "Z", "PICK UP CAMPUS COIN", "+%d C for your questionable spending" % int(pickup["value"]), coin_distance)

    var note_index: int = challenge.nearest_item_index()
    if note_index >= 0:
        best = _candidate(best, 130, "C", "COLLECT FIELD NOTE", "A tiny achievement, a huge academic ego", 0.0)
    if tour.can_check_in():
        var stop: Dictionary = tour.current_stop()
        best = _candidate(best, 125, "E", str(stop.get("title", "DISCOVERY CHECKPOINT")).to_upper(), "Check in and keep exploring UTown", tour.current_distance_m())

    for professor in arcade.professors:
        var professor_node: Node3D = professor.get("node") as Node3D
        if professor_node == null or not is_instance_valid(professor_node):
            continue
        var professor_distance: float = _horizontal_distance(player.global_position, professor_node.global_position)
        if professor_distance <= 4.5:
            best = _candidate(best, 112, "K", "MEET " + str(professor.get("name", "PROFESSOR")).to_upper(), "May assign bizarre homework", professor_distance)

    for person in life.pedestrians:
        var node: Node3D = person.get("node") as Node3D
        if node == null or not is_instance_valid(node):
            continue
        var talk_distance: float = _horizontal_distance(player.global_position, node.global_position)
        if talk_distance <= life.TALK_RADIUS:
            best = _candidate(best, 90, "Q", "TALK TO " + str(person.get("name", "STUDENT")).to_upper(), "Campus stories are more fun than DDLs", talk_distance)

    if not life.bicycle_enabled:
        for room_id in ["ERC", "SRC"]:
            if not life.entry_positions.has(room_id):
                continue
            var entry_distance: float = _horizontal_distance(player.global_position, life.entry_positions[room_id])
            if entry_distance <= life.ENTRY_RADIUS:
                best = _candidate(best, 70, "I", "EXPLORE " + room_id + " INTERIOR", "Enter a fictional indoor space", entry_distance)
        if life.shuttle != null:
            var shuttle_distance: float = _horizontal_distance(player.global_position, life.shuttle.global_position)
            if shuttle_distance <= life.BOARD_RADIUS:
                best = _candidate(best, 80, "X", "BOARD UTOWN SHUTTLE", "A suspiciously convenient commute", shuttle_distance)
    return best


func _goal_offer() -> Dictionary:
    # Interior coordinates are deliberately far outside the outdoor world;
    # never point to outdoor objectives while the player is in a room.
    if life.interior_active or life.on_shuttle:
        return {}
    if coins.delivery_active:
        return {
            "id": "lunch",
            "position": coins.delivery_destination,
            "title": "LUNCH EXPRESS  /  TOWN GREEN",
            "detail": "%ds left  •  Press N at the destination" % ceili(coins.delivery_time)
        }
    if challenge.sprint_active and challenge.sprint_next_index < challenge.sprint_route.size():
        return {
            "id": "sprint:%d" % challenge.sprint_next_index,
            "position": challenge.sprint_route[challenge.sprint_next_index],
            "title": "CAMPUS SPRINT  /  CHECKPOINT",
            "detail": "Beat the clock  •  Keep moving"
        }
    if not tour.completed and not tour.current_stop().is_empty():
        var stop: Dictionary = tour.current_stop()
        return {
            "id": "tour:%d" % tour.current_index,
            "position": tour.stop_world_position(tour.current_index),
            "title": "DISCOVERY  /  " + str(stop.get("title", "NEXT STOP")).to_upper(),
            "detail": "Waypoint %d/%d  •  Illustrative route" % [tour.discovered_ids.size() + 1, tour.stops.size()]
        }
    return {}


func _direction_arrow(point: Vector3) -> String:
    var to_goal: Vector3 = point - player.global_position
    to_goal.y = 0.0
    if to_goal.length_squared() < 0.0001:
        return "●"
    to_goal = to_goal.normalized()
    var front: Vector3 = -player.global_transform.basis.z
    var right: Vector3 = player.global_transform.basis.x
    var angle: float = atan2(right.dot(to_goal), front.dot(to_goal))
    var headings: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
    return headings[posmod(int(round(angle / (PI / 4.0))), headings.size())]


func _fade_in(card: PanelContainer, mode: String) -> void:
    var tween: Tween
    if mode == "prompt":
        if _prompt_motion != null and _prompt_motion.is_running():
            _prompt_motion.kill()
        tween = create_tween()
        _prompt_motion = tween
    elif mode == "goal":
        if _goal_motion != null and _goal_motion.is_running():
            _goal_motion.kill()
        tween = create_tween()
        _goal_motion = tween
    else:
        if _zone_motion != null and _zone_motion.is_running():
            _zone_motion.kill()
        tween = create_tween()
        _zone_motion = tween
    card.modulate.a = 0.0
    card.show()
    tween.tween_property(card, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_prompt(focus: Dictionary) -> void:
    if focus.is_empty():
        prompt_card.hide()
        _active_prompt = ""
        return
    var key_text: String = str(focus["key"])
    var identity: String = key_text + ":" + str(focus["title"])
    prompt_key.text = key_text
    prompt_name.text = str(focus["title"])
    prompt_detail.text = str(focus["detail"])
    if identity != _active_prompt or not prompt_card.visible:
        _active_prompt = identity
        _fade_in(prompt_card, "prompt")


func _update_goal(goal: Dictionary) -> void:
    if goal.is_empty():
        objective_card.hide()
        _active_goal = ""
        return
    var goal_position: Vector3 = goal["position"]
    objective_arrow.text = _direction_arrow(goal_position)
    objective_name.text = str(goal["title"])
    objective_detail.text = str(goal["detail"])
    objective_distance.text = "%d m" % roundi(_horizontal_distance(player.global_position, goal_position))
    var id_value: String = str(goal["id"])
    if id_value != _active_goal or not objective_card.visible:
        _active_goal = id_value
        _fade_in(objective_card, "goal")


func _zone_text(zone: String) -> String:
    var lowered: String = zone.to_lower()
    if lowered.contains("green"):
        return "Deadline demons are doing cardio on the lawn."
    if lowered.contains("erc") or lowered.contains("education"):
        return "Printer queue: a boss fight nobody requested."
    if lowered.contains("src") or lowered.contains("sport"):
        return "You cannot outrun coursework, but you can try."
    if lowered.contains("plaza"):
        return "Coins first. Existential crisis after lunch."
    return "New district unlocked. Coursework remains unlocked too."


func _update_zone() -> void:
    var current_zone: String = ""
    if life.interior_active:
        current_zone = life.active_interior + " INTERIOR"
    else:
        var nearest: Dictionary = world.nearest_landmark(player.global_position)
        if float(nearest.get("distance", 9999.0)) <= ZONE_RADIUS_M:
            current_zone = str(nearest.get("name", ""))
    if current_zone == _active_zone:
        return
    _active_zone = current_zone
    if current_zone.is_empty() or _visited_zones.has(current_zone):
        return
    _visited_zones[current_zone] = true
    zone_heading.text = "NOW ENTERING  /  " + current_zone.to_upper()
    zone_caption.text = _zone_text(current_zone)
    _zone_remaining = 4.5
    _fade_in(zone_card, "zone")


func _refresh_feedback() -> void:
    if screen == null or player == null or coins == null:
        return
    var is_playing: bool = hud.visible and not coins.shop_open and not get_tree().paused
    screen.visible = is_playing
    if not is_playing:
        return
    _update_prompt(_nearest_offer())
    _update_goal(_goal_offer())
    _update_zone()


func _process(delta: float) -> void:
    _refresh_elapsed += delta
    if _zone_remaining > 0.0:
        _zone_remaining = maxf(0.0, _zone_remaining - delta)
        if _zone_remaining <= 0.0 and zone_card != null:
            zone_card.hide()
    if _refresh_elapsed >= REFRESH_SECONDS:
        _refresh_elapsed = fmod(_refresh_elapsed, REFRESH_SECONDS)
        _refresh_feedback()
