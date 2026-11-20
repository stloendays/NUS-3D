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
@onready var coursework: UTownCoursework = $"../Coursework"
@onready var green_dining: UTownGreenDining = $"../GreenDining"
@onready var hud: CanvasLayer = $"../HUD"
@onready var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage

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
var wallet_card: PanelContainer
var shop_panel: PanelContainer
var shop_status: Label
var shop_heading: Label
var shop_buttons: Array[Button] = []
var shop_open: bool = false
var capture_mouse_before_shop: bool = false
var previous_shop_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var previous_shop_player_lock: bool = false
var previous_shop_coursework_modal: bool = false
var known_hud_visibility: bool = true

func _ready() -> void:
    rng.randomize()
    _index_spawn_segments()
    _build_pickup_pool()
    _build_interface()
    _build_shop()
    get_viewport().size_changed.connect(_update_coin_ui_layout)
    _update_coin_ui_layout()
    _load_delivery_anchors()
    load_progress()
    source_student_wins = arcade.student_wins
    for i in range(5):
        _spawn_random_coin(true)
    _poll_mission_rewards()
    if language != null:
        language.language_changed.connect(_on_language_changed)
    _on_language_changed(language.locale if language != null else "en")


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en


func _reason(reason: String) -> String:
    var names: Dictionary = {
        "Found a dropped coin": "发现掉落金币",
        "Campus Explorer checkpoint": "校园探索打卡",
        "Field Note discovery": "发现探索笔记",
        "Campus indoor activity": "完成校园活动",
        "Professor's impossible homework": "完成教授的奇怪作业",
        "Campus Sprint finished": "校园竞速完成",
        "Campus Sprint silver": "校园竞速银牌",
        "Campus Sprint gold": "校园竞速金牌",
        "Cartoon student duel": "卡通对战胜利",
        "Lunch Express delivered": "送餐成功"
    }
    return _t(str(names.get(reason, reason)), reason)


func _shop_text(source: String) -> String:
    var titles: Dictionary = {
        "Lucky Badge - 35 C  |  Double next 5 coin pickups": "幸运徽章 · 35 金币 | 下五次拾取翻倍",
        "Lunch Time Pass - 28 C  |  +35 seconds on next delivery": "送餐加时券 · 28 金币 | 下次配送增加 35 秒",
        "Golden Tip Pass - 60 C  |  x2 next delivery payment": "双倍小费券 · 60 金币 | 下次配送双倍报酬",
        "Close  [O]": "关闭 [O]"
    }
    return _t(str(titles.get(source, source)), source)


func _on_language_changed(_code: String) -> void:
    if shop_heading != null:
        shop_heading.text = _t("校园金币商店 | 全天营业", "CAMPUS COIN SHOP | OPEN 24/7")
    for button in shop_buttons:
        button.text = _shop_text(str(button.get_meta("shop_original", "")))
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

func _update_coin_ui_layout() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if wallet_card != null:
        var wallet_width: float = minf(417.0, maxf(280.0, viewport_size.x * 0.36))
        wallet_card.offset_left = -wallet_width - 18.0
        wallet_card.offset_right = -18.0
        wallet_card.offset_top = 238.0 if viewport_size.y < 700.0 else 259.0
        wallet_card.offset_bottom = wallet_card.offset_top + 82.0
    if shop_panel != null:
        var shop_width: float = minf(436.0, maxf(280.0, viewport_size.x - 28.0))
        var shop_height: float = minf(412.0, maxf(280.0, viewport_size.y - 28.0))
        shop_panel.offset_left = -shop_width * 0.5
        shop_panel.offset_right = shop_width * 0.5
        shop_panel.offset_top = -shop_height * 0.5
        shop_panel.offset_bottom = shop_height * 0.5


func _build_interface() -> void:
    interface = CanvasLayer.new()
    interface.name = "CoinsOverlay"
    interface.layer = 4
    add_child(interface)
    wallet_card = PanelContainer.new()
    wallet_card.name = "WalletPanel"
    # Wallet occupies the right-hand gap under the map, and yields to F6 GIS.
    wallet_card.anchor_left = 1.0
    wallet_card.anchor_right = 1.0
    wallet_card.offset_left = -435.0
    wallet_card.offset_right = -18.0
    wallet_card.offset_top = 259.0
    wallet_card.offset_bottom = 344.0
    wallet_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var card_style: StyleBoxFlat = NUS3DUISkin.glass(Color("#E8EEEC"), 14, 10)
    wallet_card.add_theme_stylebox_override("panel", card_style)
    interface.add_child(wallet_card)
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wallet_card.add_child(row)
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
    wallet_label.add_theme_font_size_override("font_size", 12)
    wallet_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(wallet_label)

func _shop_button(parent_node: Node, title: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = _shop_text(title)
    button.set_meta("shop_original", title)
    shop_buttons.append(button)
    button.custom_minimum_size.y = 38.0
    NUS3DUISkin.button(button)
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
    var style: StyleBoxFlat = NUS3DUISkin.glass(Color("#E8EEEC"), 16, 14, true)
    shop_panel.add_theme_stylebox_override("panel", style)
    interface.add_child(shop_panel)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 9)
    shop_panel.add_child(contents)
    shop_heading = Label.new()
    shop_heading.text = _t("校园金币商店 | 全天营业", "CAMPUS COIN SHOP | OPEN 24/7")
    shop_heading.add_theme_font_size_override("font_size", 18)
    shop_heading.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    contents.add_child(shop_heading)
    shop_status = Label.new()
    shop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    shop_status.add_theme_color_override("font_color", NUS3DUISkin.DIM)
    shop_status.add_theme_font_size_override("font_size", 12)
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
                _notify(_t("幸运徽章仍在生效。", "Lucky Badge is still active."), 2.5)
                return false
        "lunch":
            price = 28
            if lunch_passes >= 3:
                _notify(_t("未使用的送餐加时券太多了。", "Too many unused lunch passes."), 2.5)
                return false
        "tip":
            price = 60
            if double_tip_passes >= 3:
                _notify(_t("请先使用现有的双倍小费券。", "Use an existing Golden Tip first."), 2.5)
                return false
        _:
            return false
    if balance < price:
        _notify(_t("需要 %d 金币。先探索或送餐！", "Need %d coins. Explore or deliver lunch first!") % price, 3.0)
        return false
    var previous_balance: int = balance
    var previous_lucky: int = lucky_pickups
    var previous_lunch: int = lunch_passes
    var previous_tips: int = double_tip_passes
    balance -= price
    match item_id:
        "lucky":
            lucky_pickups = 5
        "lunch":
            lunch_passes += 1
        "tip":
            double_tip_passes += 1
    if not _save_progress():
        balance = previous_balance
        lucky_pickups = previous_lucky
        lunch_passes = previous_lunch
        double_tip_passes = previous_tips
        _notify("Purchase was not saved. No coins were spent.", 3.0)
        return false
    _notify(_t("购买成功：%s，花费 %d 金币。", "Bought %s for %d C") % [
        _t("幸运徽章", "Lucky Badge") if item_id == "lucky" else
        _t("送餐加时券", "Lunch Time Pass") if item_id == "lunch" else _t("双倍小费券", "Golden Tip Pass"), price
    ], 3.0)
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
    return (hud.visible and not shop_open and not campus_life.interior_active
        and not campus_life.on_shuttle and not player.movement_locked
        and not coursework.modal_open)

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
        root.visible = hud.visible
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
        _notify(_t("附近没有金币，寻找金色标记！", "No coin nearby. Look for the gold C symbol!"), 2.0)
        return false
    var state: Dictionary = pickups[best]
    var amount: int = int(state["value"])
    var doubled: bool = lucky_pickups > 0
    if doubled:
        amount *= 2
        lucky_pickups -= 1
    # One write commits both the coin amount and consumed Lucky Badge charge.
    if not credit(amount, "Found a dropped coin"):
        if doubled:
            lucky_pickups += 1
        return false
    state["active"] = false
    var root: Node3D = state["node"]
    root.visible = false
    return true

func credit(amount: int, reason: String) -> bool:
    var gain: int = mini(maxi(amount, 0), MAX_BALANCE - balance)
    if gain <= 0:
        return false
    var previous_balance: int = balance
    var previous_lifetime: int = lifetime_earned
    balance += gain
    lifetime_earned = mini(MAX_BALANCE * 100, lifetime_earned + gain)
    if not _save_progress():
        balance = previous_balance
        lifetime_earned = previous_lifetime
        return false
    _notify(_t("+%d 金币 | %s", "+%d C | %s") % [gain, _reason(reason)], 3.0)
    return true

func reward_once(reward_id: String, amount: int, reason: String) -> bool:
    if reward_id.is_empty() or claimed_rewards.has(reward_id) or amount <= 0:
        return false
    # Include the claim in the same atomic ConfigFile write as the deposit.
    # A crash between two saves must not make an already-paid quest claimable again.
    claimed_rewards[reward_id] = true
    if not credit(amount, reason):
        claimed_rewards.erase(reward_id)
        return false
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
            _notify(_t("饭快凉了！赶到中央草坪按 N。", "Lunch is getting cold! Reach Town Green and press N."), 3.0)
            return false
        var base_reward: int = 38 + (15 if delivery_time >= 50.0 else 0)
        var previously_tipped: int = double_tip_passes
        var previous_time: float = delivery_time
        var previous_count: int = delivery_count
        if double_tip_passes > 0:
            double_tip_passes -= 1
            base_reward *= 2
        delivery_active = false
        delivery_time = 0.0
        delivery_cooldown = DELIVERY_COOLDOWN_SECONDS
        delivery_count += 1
        # Reward, delivery count and consumed tip pass share one save.
        if not credit(base_reward, "Lunch Express delivered"):
            delivery_active = true
            delivery_time = previous_time
            delivery_cooldown = 0.0
            delivery_count = previous_count
            double_tip_passes = previously_tipped
            _notify("Delivery could not be saved. Please try again.", 3.0)
            return false
        return true
    if delivery_cooldown > 0.0:
        _notify(_t("食堂备餐中（剩余 %d 秒）。", "Food court is preparing the next order (%ds).") % ceili(delivery_cooldown), 2.3)
        return false
    if delivery_origin == Vector3.ZERO or delivery_destination == Vector3.ZERO:
        _notify(_t("食堂配送点暂不可用。", "Food-court anchors are unavailable."), 3.0)
        return false
    if _horizontal_distance(player.global_position, delivery_origin) > DELIVERY_START_RADIUS:
        _notify(_t("前往中央广场食堂，按 N 开始送餐。", "Visit Fine Food at Town Plaza and press N for lunch delivery."), 3.0)
        return false
    delivery_active = true
    delivery_time = DELIVERY_SECONDS
    if lunch_passes > 0:
        lunch_passes -= 1
        delivery_time += 35.0
        if not _save_progress():
            lunch_passes += 1
            delivery_active = false
            delivery_time = 0.0
            _notify("Order could not be saved. Please try again.", 3.0)
            return false
    _notify(_t("送餐挑战开始！赶往中央草坪，抵达后按 N。", "LUNCH EXPRESS! Deliver to Town Green. Press N at destination."), 4.2)
    return true

func _close_shop() -> void:
    if not shop_open:
        return
    shop_open = false
    shop_panel.visible = false
    # Restore the exact state that existed before the shop acquired the modal.
    # Do not clear a lock introduced by a different overlay while this was open.
    var course_ui: Node = get_parent().get_node_or_null("CourseworkUI")
    var exams: Node = get_parent().get_node_or_null("EnglishExams")
    var leisure: Node = get_parent().get_node_or_null("LeisureUI")
    var another_modal: bool = (
        (course_ui != null and bool(course_ui.get("modal_visible")))
        or (exams != null and bool(exams.get("is_open")))
        or (leisure != null and bool(leisure.get("is_open")))
    )
    coursework.modal_open = previous_shop_coursework_modal or another_modal
    player.movement_locked = previous_shop_player_lock or coursework.modal_open or campus_life.on_shuttle
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if another_modal else previous_shop_mouse_mode

func toggle_shop() -> void:
    if shop_open:
        _close_shop()
        return
    if (not hud.visible or campus_life.on_shuttle or campus_life.interior_active
        or player.bicycle_mode or player.movement_locked or coursework.modal_open):
        return
    previous_shop_mouse_mode = Input.mouse_mode
    previous_shop_player_lock = player.movement_locked
    previous_shop_coursework_modal = coursework.modal_open
    capture_mouse_before_shop = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
    shop_open = true
    shop_panel.visible = true
    coursework.modal_open = true
    player.movement_locked = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _refresh_display()

## Session-only state may never follow a different local account. Keep wallet,
## purchased buffs and claimed rewards in the account-specific ConfigFile.
func reset_runtime_session() -> void:
    _close_shop()
    delivery_active = false
    delivery_time = 0.0
    delivery_cooldown = 0.0
    source_student_wins = 0
    reward_poll_timer = 0.0
    drop_timer = 0.0
    refresh_timer = 0.0
    notice = ""
    notice_time = 0.0
    pickup_cursor = 0
    for pickup in pickups:
        pickup["active"] = false
        pickup["life"] = 0.0
        pickup["value"] = 0
        var node: Node3D = pickup["node"]
        node.visible = false
    _refresh_display()

func seed_session_drops() -> void:
    # New accounts do not inherit the previous avatar's world pickups.
    for i in range(5):
        _spawn_random_coin(true)

func _notify(value: String, seconds: float) -> void:
    notice = value
    notice_time = seconds
    _refresh_display()

func _refresh_display() -> void:
    if wallet_label != null:
        var lines := PackedStringArray()
        lines.append(_t("金币 %d | 累计获得 %d", "COINS %d C | Earned %d") % [balance, lifetime_earned])
        if delivery_active:
            lines.append(_t("送餐任务 | 剩余 %d 秒 | 中央草坪 [N]",
                "LUNCH EXPRESS | %ds | Town Green [N]") % ceili(delivery_time))
        elif delivery_cooldown > 0.0:
            lines.append(_t("食堂备餐中：%d 秒", "Food restocking: %ds") % ceili(delivery_cooldown))
        else:
            lines.append(_t("[Z] 拾取 [N] 送餐任务 [O] 商店",
                "[Z] collect [N] food delivery [O] shop"))
        lines.append(notice if notice_time > 0.0 else _t(
            "探索校园、完成活动来获得金币。",
            "Explore, discover and collect for more coins."))
        wallet_label.text = "\n".join(lines)
    if shop_status != null:
        shop_status.text = _t("余额：%d 金币\n持有：幸运拾取 %d · 送餐加时券 %d · 双倍小费券 %d",
            "BALANCE %d C\nOWNED: Lucky %d · Lunch %d · Double tips %d") % [
            balance, lucky_pickups, lunch_passes, double_tip_passes]

func save_progress() -> void:
    _save_progress()

func _save_progress() -> bool:
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
    var status: Error = data.save(save_path)
    if status != OK:
        push_warning("Could not save independent campus coins file (error %d)" % status)
        return false
    return true

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
        _refresh_display()
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
    # F6 map validation has its own panel in the same region.
    if interface != null:
        if wallet_card != null:
            wallet_card.visible = not world.osm_reference_visible
    notice_time = maxf(0.0, notice_time - delta)
    delivery_cooldown = maxf(0.0, delivery_cooldown - delta)
    if delivery_active:
        delivery_time = maxf(0.0, delivery_time - delta)
        if delivery_time <= 0.0:
            delivery_active = false
            delivery_cooldown = 15.0
            _notify(_t("饭凉了！回食堂领取新订单吧。", "Lunch got cold! Try another order at Fine Food."), 3.8)
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

func _input(event: InputEvent) -> void:
    if not shop_open:
        return
    if event is InputEventKey:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and not key.echo and key.keycode in [KEY_ESCAPE, KEY_O]:
            _close_shop()
        # While the modal is open no gameplay keys should reach other systems.
        get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
    if shop_open or player.movement_locked:
        return
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
