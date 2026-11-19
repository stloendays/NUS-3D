extends Node3D
class_name UTownCoins
## Fictional, offline coins for existing UTown tasks and an optional lunch-delivery mini-game.
## Uses a bounded reusable 3D pickup pool and its own ConfigFile (never edits other saves).

const DEFAULT_SAVE_PATH: String = "user://nus3d_coins.cfg"
const MAX_BALANCE: int = 999999
const MAX_PICKUPS: int = 12
const DROP_INTERVAL: float = 13.0
const DROP_LIFETIME: float = 65.0
const PICKUP_RADIUS: float = 3.0
const DELIVERY_START_RADIUS: float = 13.0
const DELIVERY_FINISH_RADIUS: float = 13.0
const DELIVERY_SECONDS: float = 100.0
const DELIVERY_COOLDOWN_SECONDS: float = 32.0

@onready var player: UTownPlayer = $"../Player"
@onready var world: UTownWorld = $"../World"
@onready var tour: UTownTour = $"../Tour"
@onready var challenge: UTownChallenge = $"../Challenge"
@onready var campus_life: UTownCampusLife = $"../CampusLife"
@onready var arcade: UTownArcade = $"../Arcade"
@onready var green_dining: UTownGreenDining = $"../GreenDining"
@onready var hud: CanvasLayer = $"../HUD"

var save_path: String = DEFAULT_SAVE_PATH
var balance: int = 0
var lifetime_earned: int = 0
var claimed_rewards: Dictionary = {}
var lucky_pickups: int = 0
var lunch_passes: int = 0
var double_tip_passes: int = 0
var source_student_wins: int = 0
var reward_poll_timer: float = 0.0
var drop_timer: float = 0.0
var refresh_timer: float = 0.0
var notice: String = ""
var notice_time: float = 0.0

var rng := RandomNumberGenerator.new()
var spawn_segments: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var pickup_mesh: CylinderMesh
var pickup_material: StandardMaterial3D
var pickup_cursor: int = 0
var delivery_active: bool = false
var delivery_time: float = 0.0
var delivery_cooldown: float = 0.0
var delivery_count: int = 0
var delivery_origin: Vector3 = Vector3.ZERO
var delivery_destination: Vector3 = Vector3.ZERO

var interface: CanvasLayer
var wallet_label: Label
var shop_panel: PanelContainer
var shop_status: Label
var shop_open: bool = false
var capture_mouse_before_shop: bool = false
var known_hud_visibility: bool = true

func _ready() -> void:
    rng.randomize()
    _index_spawn_segments()
    _build_pickup_pool()
    _build_interface()
    _build_shop()
    _load_delivery_anchors()
    load_progress()
    source_student_wins = arcade.student_wins
    for i in range(5):
        _spawn_random_coin(true)
    _poll_mission_rewards()
    _refresh_display()

func _index_spawn_segments() -> void:
    for raw in world.layout.get("walkways", []):
        var coords: Array = raw.get("lonlat", [])
        for index in range(coords.size() - 1):
            var a: Vector3 = world.lonlat_to_world(float(coords[index][0]), float(coords[index][1]))
            var b: Vector3 = world.lonlat_to_world(float(coords[index + 1][0]), float(coords[index + 1][1]))
            if a.distance_to(b) > 3.0:
                spawn_segments.append({"a": a, "b": b})

func _build_pickup_pool() -> void:
    pickup_mesh = CylinderMesh.new()
    pickup_mesh.top_radius = 0.34
    pickup_mesh.bottom_radius = 0.34
    pickup_mesh.height = 0.09
    pickup_mesh.radial_segments = 14
    pickup_material = StandardMaterial3D.new()
    pickup_material.albedo_color = Color.html("#ffcc52")
    pickup_material.metallic = 0.54
    pickup_material.roughness = 0.27
    pickup_material.emission_enabled = true
    pickup_material.emission = Color.html("#c18a19")
    pickup_material.emission_energy_multiplier = 0.43
    for i in range(MAX_PICKUPS):
        var root := Node3D.new()
        root.name = "PooledCoin_%02d" % i
        var coin := MeshInstance3D.new()
        coin.mesh = pickup_mesh
        coin.rotation.x = PI * 0.5
        coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        coin.material_override = pickup_material
        root.add_child(coin)
        var stamp := Label3D.new()
        stamp.text = "C"
        stamp.font_size = 28
        stamp.pixel_size = 0.012
        stamp.outline_size = 4
        stamp.modulate = Color.html("#fff2ab")
        stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        stamp.position.y = 0.40
        root.add_child(stamp)
        root.visible = false
        add_child(root)
        pickups.append({
            "node": root, "active": false, "value": 0,
            "life": 0.0, "phase": float(i) * 0.87,
            "base": Vector3.ZERO
        })

func _coin_icon_draw(control: Control) -> void:
    control.draw_circle(Vector2(21, 21), 19.0, Color.html("#6f4813"))
    control.draw_circle(Vector2(21, 20), 17.5, Color.html("#e6a631"))
    control.draw_circle(Vector2(21, 18), 15.0, Color.html("#ffda67"))
    control.draw_arc(Vector2(21, 18), 12.0, 0.0, TAU, 32, Color.html("#a87520"), 2.0, true)
    control.draw_string(ThemeDB.fallback_font, Vector2(15, 25), "C",
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color.html("#785017"))

func _build_interface() -> void:
    interface = CanvasLayer.new()
    interface.name = "CoinsOverlay"
    interface.layer = 4
    add_child(interface)
    var card := PanelContainer.new()
    card.name = "WalletPanel"
    card.anchor_left = 0.5
    card.anchor_right = 0.5
    card.offset_left = -217.0
    card.offset_right = 217.0
    card.offset_top = 164.0
    card.offset_bottom = 254.0
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.14, 0.16, 0.21, 0.88)
    card_style.set_corner_radius_all(12)
    card_style.content_margin_left = 11.0
    card_style.content_margin_right = 11.0
    card_style.content_margin_top = 7.0
    card_style.content_margin_bottom = 7.0
    card.add_theme_stylebox_override("panel", card_style)
    interface.add_child(card)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(row)
    var icon_control := Control.new()
    icon_control.name = "GoldenCoinIcon"
    icon_control.custom_minimum_size = Vector2(44.0, 44.0)
    icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon_control.draw.connect(_coin_icon_draw.bind(icon_control))
    row.add_child(icon_control)
    wallet_label = Label.new()
    wallet_label.name = "WalletStatus"
    wallet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    wallet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wallet_label.add_theme_font_size_override("font_size", 13)
    wallet_label.add_theme_color_override("font_color", Color.html("#ffe9bb"))
    wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(wallet_label)

func _shop_button(parent_node: Node, title: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 40.0
    button.pressed.connect(callback)
    parent_node.add_child(button)
    return button

func _build_shop() -> void:
    shop_panel = PanelContainer.new()
    shop_panel.name = "CoinShop"
    shop_panel.anchor_left = 0.5
    shop_panel.anchor_top = 0.5
    shop_panel.anchor_right = 0.5
    shop_panel.anchor_bottom = 0.5
    shop_panel.offset_left = -218.0
    shop_panel.offset_right = 218.0
    shop_panel.offset_top = -205.0
    shop_panel.offset_bottom = 206.0
    shop_panel.visible = false
    shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.13, 0.19, 0.22, 0.96)
    style.set_corner_radius_all(14)
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 15.0
    style.content_margin_bottom = 15.0
    shop_panel.add_theme_stylebox_override("panel", style)
    interface.add_child(shop_panel)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 9)
    shop_panel.add_child(contents)
    var heading := Label.new()
    heading.text = "CAMPUS COIN SHOP  |  OPEN 24/7"
    heading.add_theme_font_size_override("font_size", 20)
    contents.add_child(heading)
    shop_status = Label.new()
    shop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    contents.add_child(shop_status)
    _shop_button(contents, "Lucky Badge - 35 C  |  Double next 5 coin pickups", _purchase_lucky)
    _shop_button(contents, "Lunch Time Pass - 28 C  |  +35 seconds on next delivery", _purchase_lunch)
    _shop_button(contents, "Golden Tip Pass - 60 C  |  x2 next delivery payment", _purchase_tip)
    _shop_button(contents, "Close  [O]", _close_shop)

func _purchase_lucky() -> void:
    purchase("lucky")

func _purchase_lunch() -> void:
    purchase("lunch")

func _purchase_tip() -> void:
    purchase("tip")

func purchase(item_id: String) -> bool:
    var price: int = 0
    match item_id:
        "lucky":
            price = 35
            if lucky_pickups > 0:
                _notify("Lucky Badge is still active.", 2.5)
                return false
        "lunch":
            price = 28
            if lunch_passes >= 3:
                _notify("Too many unused lunch passes.", 2.5)
                return false
        "tip":
            price = 60
            if double_tip_passes >= 3:
                _notify("Use an existing Golden Tip first.", 2.5)
                return false
        _:
            return false
    if balance < price:
        _notify("Need %d coins. Explore or deliver lunch first!" % price, 3.0)
        return false
    balance -= price
    match item_id:
        "lucky":
            lucky_pickups = 5
        "lunch":
            lunch_passes += 1
        "tip":
            double_tip_passes += 1
    _save_progress()
    _notify("Bought %s for %d C" % [item_id, price], 3.0)
    return true

func _load_delivery_anchors() -> void:
    var plaza: Node3D = world.get_node_or_null("TownPlaza_approximate") as Node3D
    if plaza != null:
        delivery_origin = plaza.global_position
    for raw in world.layout.get("loop", []):
        if str(raw.get("id", "")) == "GREEN":
            delivery_destination = world.lonlat_to_world(float(raw["lon"]), float(raw["lat"]))
            break

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _can_interact() -> bool:
    return hud.visible and not shop_open and not campus_life.interior_active and not campus_life.on_shuttle and not player.movement_locked

func _drop_at(position: Vector3, amount: int) -> bool:
    if amount <= 0 or amount > 50:
        return false
    for state in pickups:
        if bool(state["active"]):
            continue
        state["active"] = true
        state["value"] = amount
        state["base"] = Vector3(position.x, 0.89, position.z)
        state["life"] = DROP_LIFETIME
        var root: Node3D = state["node"]
        root.global_position = state["base"]
        root.visible = true
        return true
    return false

func _spawn_random_coin(force: bool = false) -> bool:
    if spawn_segments.is_empty() or campus_life.interior_active:
        return false
    var origin: Vector3 = player.global_position
    var candidate: Vector3 = Vector3.ZERO
    var found: bool = false
    for tries in range(18):
        var index: int = rng.randi_range(0, spawn_segments.size() - 1)
        var segment: Dictionary = spawn_segments[index]
        candidate = (segment["a"] as Vector3).lerp(segment["b"], rng.randf_range(0.10, 0.90))
        var distance: float = _horizontal_distance(candidate, origin)
        if distance >= 3.0 and distance <= (125.0 if force else 70.0):
            found = true
            break
    if not found:
        return false
    var roll: float = rng.randf()
    var denomination: int = 1 if roll < 0.67 else 3 if roll < 0.94 else 8
    return _drop_at(candidate, denomination)

func pickup_nearby() -> bool:
    if not _can_interact():
        return false
    var best: int = -1
    var nearest: float = PICKUP_RADIUS
    for i in range(pickups.size()):
        var state: Dictionary = pickups[i]
        if not bool(state["active"]):
            continue
        var coin_at: Vector3 = state["base"]
        var distance: float = _horizontal_distance(player.global_position, coin_at)
        if distance <= nearest:
            nearest = distance
            best = i
    if best < 0:
        _notify("No coin nearby. Look for the gold C symbol!", 2.0)
        return false
    var state: Dictionary = pickups[best]
    var amount: int = int(state["value"])
    var doubled: bool = lucky_pickups > 0
    if doubled:
        amount *= 2
    if not credit(amount, "Found a dropped coin"):
        return false
    if doubled:
        lucky_pickups -= 1
        _save_progress()
    state["active"] = false
    var root: Node3D = state["node"]
    root.visible = false
    return true

func credit(amount: int, reason: String) -> bool:
    var gain: int = mini(maxi(amount, 0), MAX_BALANCE - balance)
    if gain <= 0:
        return false
    balance += gain
    lifetime_earned = mini(MAX_BALANCE * 100, lifetime_earned + gain)
    _save_progress()
    _notify("+%d C  |  %s" % [gain, reason], 3.0)
    return true

func reward_once(reward_id: String, amount: int, reason: String) -> bool:
    if reward_id.is_empty() or claimed_rewards.has(reward_id) or amount <= 0:
        return false
    if not credit(amount, reason):
        return false
    claimed_rewards[reward_id] = true
    _save_progress()
    return true

func _poll_mission_rewards() -> void:
    for stop_id in tour.discovered_ids:
        reward_once("tour:" + str(stop_id), 12, "Campus Explorer checkpoint")
    for i in range(challenge.items.size()):
        var item_id: String = challenge.item_id(i)
        if challenge.is_item_collected(item_id):
            reward_once("note:" + item_id, 14, "Field Note discovery")
    for visited in campus_life.visited_activities.keys():
        reward_once("activity:" + str(visited), 17, "Campus indoor activity")
    for professor_id in arcade.met_professors:
        reward_once("professor:" + str(professor_id), 10, "Professor's impossible homework")
    if challenge.sprint_best_time >= 0.0:
        reward_once("sprint:finish", 25, "Campus Sprint finished")
        if challenge.sprint_best_time <= challenge.SILVER_TIME_S:
            reward_once("sprint:silver", 12, "Campus Sprint silver")
        if challenge.sprint_best_time <= challenge.GOLD_TIME_S:
            reward_once("sprint:gold", 18, "Campus Sprint gold")
    if arcade.student_wins > source_student_wins:
        var new_wins: int = mini(arcade.student_wins - source_student_wins, 50)
        for i in range(new_wins):
            credit(6, "Cartoon student duel")
            if rng.randf() < 0.32:
                _spawn_random_coin(true)
    source_student_wins = arcade.student_wins

func delivery_interact() -> bool:
    if not _can_interact():
        return false
    if delivery_active:
        if _horizontal_distance(player.global_position, delivery_destination) > DELIVERY_FINISH_RADIUS:
            _notify("Lunch is getting cold! Reach Town Green and press N.", 3.0)
            return false
        var base_reward: int = 38 + (15 if delivery_time >= 50.0 else 0)
        if double_tip_passes > 0:
            double_tip_passes -= 1
            base_reward *= 2
        delivery_active = false
        delivery_time = 0.0
        delivery_cooldown = DELIVERY_COOLDOWN_SECONDS
        delivery_count += 1
        credit(base_reward, "Lunch Express delivered")
        _save_progress()
        return true
    if delivery_cooldown > 0.0:
        _notify("Food court is preparing the next order (%ds)." % ceili(delivery_cooldown), 2.3)
        return false
    if delivery_origin == Vector3.ZERO or delivery_destination == Vector3.ZERO:
        _notify("Food-court anchors are unavailable.", 3.0)
        return false
    if _horizontal_distance(player.global_position, delivery_origin) > DELIVERY_START_RADIUS:
        _notify("Visit Fine Food at Town Plaza and press N for lunch delivery.", 3.0)
        return false
    delivery_active = true
    delivery_time = DELIVERY_SECONDS
    if lunch_passes > 0:
        lunch_passes -= 1
        delivery_time += 35.0
        _save_progress()
    _notify("LUNCH EXPRESS! Deliver to Town Green. Press N at destination.", 4.2)
    return true

func _close_shop() -> void:
    if not shop_open:
        return
    shop_open = false
    shop_panel.visible = false
    if capture_mouse_before_shop:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_shop() -> void:
    if shop_open:
        _close_shop()
        return
    if not hud.visible or campus_life.on_shuttle or campus_life.interior_active:
        return
    shop_open = true
    shop_panel.visible = true
    capture_mouse_before_shop = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _refresh_display()

func _notify(value: String, seconds: float) -> void:
    notice = value
    notice_time = seconds
    _refresh_display()

func _refresh_display() -> void:
    if wallet_label != null:
        var lines := PackedStringArray()
        lines.append("COINS  %d C  |  Earned %d" % [balance, lifetime_earned])
        if delivery_active:
            lines.append("LUNCH EXPRESS  %ds  |  Town Green [N]" % ceili(delivery_time))
        elif delivery_cooldown > 0.0:
            lines.append("Fine Food restocking: %ds" % ceili(delivery_cooldown))
        else:
            lines.append("[Z] collect  [N] Fine Food job  [O] shop")
        if notice_time > 0.0:
            lines.append(notice)
        else:
            lines.append("Explore, discover and collect for more coins.")
        wallet_label.text = "\n".join(lines)
    if shop_status != null:
        shop_status.text = "Wallet: %d C  |  Lucky %d pickups  |  Lunch %d  |  Tips %d" % [
            balance, lucky_pickups, lunch_passes, double_tip_passes
        ]

func save_progress() -> void:
    _save_progress()

func _save_progress() -> void:
    var data := ConfigFile.new()
    data.set_value("coins", "schema_version", 1)
    data.set_value("coins", "balance", balance)
    data.set_value("coins", "lifetime_earned", lifetime_earned)
    data.set_value("coins", "lucky_pickups", lucky_pickups)
    data.set_value("coins", "lunch_passes", lunch_passes)
    data.set_value("coins", "double_tip_passes", double_tip_passes)
    data.set_value("coins", "delivery_count", delivery_count)
    var ids := PackedStringArray()
    for claimed in claimed_rewards.keys():
        ids.append(str(claimed))
    ids.sort()
    data.set_value("coins", "claimed_rewards", ids)
    if data.save(save_path) != OK:
        push_warning("Could not save independent campus coins file")

func load_progress() -> void:
    balance = 0
    lifetime_earned = 0
    lucky_pickups = 0
    lunch_passes = 0
    double_tip_passes = 0
    delivery_count = 0
    claimed_rewards.clear()
    var data := ConfigFile.new()
    if data.load(save_path) != OK:
        return
    balance = clampi(int(data.get_value("coins", "balance", 0)), 0, MAX_BALANCE)
    lifetime_earned = maxi(balance, int(data.get_value("coins", "lifetime_earned", balance)))
    lucky_pickups = clampi(int(data.get_value("coins", "lucky_pickups", 0)), 0, 5)
    lunch_passes = clampi(int(data.get_value("coins", "lunch_passes", 0)), 0, 3)
    double_tip_passes = clampi(int(data.get_value("coins", "double_tip_passes", 0)), 0, 3)
    delivery_count = maxi(0, int(data.get_value("coins", "delivery_count", 0)))
    var saved_ids: Variant = data.get_value("coins", "claimed_rewards", PackedStringArray())
    if typeof(saved_ids) == TYPE_PACKED_STRING_ARRAY or typeof(saved_ids) == TYPE_ARRAY:
        for raw in saved_ids:
            var reward_id: String = str(raw)
            if not reward_id.is_empty():
                claimed_rewards[reward_id] = true
    _refresh_display()

func _process(delta: float) -> void:
    notice_time = maxf(0.0, notice_time - delta)
    delivery_cooldown = maxf(0.0, delivery_cooldown - delta)
    if delivery_active:
        delivery_time = maxf(0.0, delivery_time - delta)
        if delivery_time <= 0.0:
            delivery_active = false
            delivery_cooldown = 15.0
            _notify("Lunch got cold! Try another order at Fine Food.", 3.8)
    drop_timer += delta
    if drop_timer >= DROP_INTERVAL:
        drop_timer -= DROP_INTERVAL
        _spawn_random_coin()
    for state in pickups:
        if not bool(state["active"]):
            continue
        state["life"] = maxf(0.0, float(state["life"]) - delta)
        var actor: Node3D = state["node"]
        if float(state["life"]) <= 0.0:
            actor.visible = false
            state["active"] = false
            continue
        actor.rotation.y += delta * 1.4
        var base: Vector3 = state["base"]
        actor.position = Vector3(base.x, base.y + sin(float(Time.get_ticks_msec()) * 0.003 + float(state["phase"])) * 0.11, base.z)
    if known_hud_visibility != hud.visible:
        known_hud_visibility = hud.visible
        interface.visible = hud.visible
        for state in pickups:
            var actor: Node3D = state["node"]
            actor.visible = hud.visible and bool(state["active"])
        if not hud.visible and shop_open:
            _close_shop()
    reward_poll_timer += delta
    if reward_poll_timer >= 0.35:
        reward_poll_timer = 0.0
        _poll_mission_rewards()
    refresh_timer += delta
    if refresh_timer >= 0.25:
        refresh_timer = 0.0
        _refresh_display()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_Z:
                if not shop_open:
                    pickup_nearby()
            KEY_N:
                if not shop_open:
                    delivery_interact()
            KEY_O:
                toggle_shop()
                get_viewport().set_input_as_handled()
