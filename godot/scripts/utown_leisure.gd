extends Node
class_name UTownLeisure
## M3.8: offline, original post-course games. Not an actual NUS venue.
## No betting, real-world prizes, alcohol sales or real student profiles.

const SAVE_PATH: String = "user://nus3d_leisure.cfg"
const BOARD_SIZE: int = 9
const WIN_LENGTH: int = 5
const CARD_ROUNDS: int = 5
const SOCIAL_COOLDOWN: float = 75.0
const INTERACT_RADIUS: float = 2.9
const SECRET_LINES: Array[String] = [
    "深夜的 SRC 棋桌下，竟然藏着一份『绝对不会再布置作业』的承诺书。",
    "神秘学长：这张纸是上个学期的。教授已经在门口等你们了。",
    "收官彩蛋：你解锁了没有分数的自由时间。下一秒，邮件提示音响了。"
]
signal club_event(kind: String)
const SUITS: Array[String] = ["S", "H", "D", "C"]
const SOCIAL_LINES: Array[String] = [
    "Maya：终于不用追着队友要文档编辑权限了。",
    "Ethan：今天阅读的唯一文献，是饮料菜单。",
    "Aisha：你以为通关了？别忘了下学期还有截止日期。",
    "Daniel：干杯！不管喝什么，课程总算提交成功了。",
    "Mei：这一杯献给凌晨三点的备份文件。"
]
const SOCIAL_LINES_EN: Array[String] = [
    "Maya: No more chasing teammates for document editing access.",
    "Ethan: The only reading I did today was the drink menu.",
    "Aisha: Think you beat the game? Next semester still has deadlines.",
    "Daniel: Cheers! At least our coursework is finally submitted.",
    "Mei: A toast to every backup file saved at 3 a.m."
]

@onready var coursework: UTownCoursework = $"../Coursework"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage

var save_path: String = SAVE_PATH
var chess_board: PackedInt32Array = PackedInt32Array()
var chess_over: bool = false
var chess_winner: int = 0
var chess_last_message: String = ""
var chess_moves: int = 0
var chess_rng := RandomNumberGenerator.new()

var card_deck: Array[Dictionary] = []
var card_hand: Array[Dictionary] = []
var npc_hand: Array[Dictionary] = []
var card_round: int = 0
var card_player_points: int = 0
var card_npc_points: int = 0
var card_over: bool = false
var card_message: String = ""
var card_rng := RandomNumberGenerator.new()

var social_message: String = ""
var celebration_counter: int = 0
var adult_toast_cooldown: float = 0.0  # per-session only; no birth dates saved
var chess_wins: int = 0
var card_wins: int = 0
var chess_games: int = 0
var card_games: int = 0
var social_visits: int = 0
var lounge_root: Node3D
var seat_actors: Dictionary = {}
var station_highlights: Dictionary = {}
var station_targets: Dictionary = {
    "chess": Vector3(3.2, 0.18, -4.25),
    "cards": Vector3(7.5, 0.18, -4.25),
    "social": Vector3(-4.8, 0.18, 6.45)
}
var stone_models: Node3D
var board_stone_black: Material
var board_stone_white: Material
var last_card_prop: Label3D
var celebration_glow: MeshInstance3D
var active_reaction: String = ""
var reaction_left: float = 0.0
var ending_line_index: int = 0
var ending_seen: bool = false
var ending_message: String = ""

func _ready() -> void:
    chess_rng.randomize()
    card_rng.randomize()
    reset_chess()
    start_cards()
    _load_stats()
    _create_lounge_props()
    social_message = _t("截止时间危机结束，来杯饮料吧！", "Deadline crisis over. Care for a drink?")
    if language != null:
        language.language_changed.connect(_on_language_changed)


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en


func _on_language_changed(_locale: String) -> void:
    for node in get_tree().get_nodes_in_group("leisure_localized_signs"):
        if node is Label3D:
            (node as Label3D).text = _t(str(node.get_meta("zh_text", "")), str(node.get_meta("en_text", "")))
    reset_chess()
    start_cards()
    social_message = _t("截止时间危机结束，来杯饮料吧！", "Deadline crisis over. Care for a drink?")

func unlocked() -> bool:
    # Completion of all three chapters in ANY faculty is a persistent pass.
    # This remains unlocked when users switch to another faculty.
    if coursework.is_graduated():
        return true
    for faculty_id in coursework.faculty_progress:
        if not coursework.faculty_by_id.has(str(faculty_id)):
            continue
        var state: Dictionary = coursework.faculty_progress[faculty_id]
        var completed_count: int = coursework.faculty_by_id[faculty_id]["quests"].size()
        if int(state.get("quest", 0)) >= completed_count:
            return true
    return false

func grand_master_unlocked() -> bool:
    # Optional cosmetic epilogue for all 39 fictional coursework chapters.
    return coursework.total_completed() >= 39

func _load_stats() -> void:
    var file := ConfigFile.new()
    if file.load(save_path) != OK:
        return
    chess_wins = clampi(int(file.get_value("leisure", "chess_wins", 0)), 0, 999999)
    card_wins = clampi(int(file.get_value("leisure", "card_wins", 0)), 0, 999999)
    chess_games = clampi(int(file.get_value("leisure", "chess_games", 0)), 0, 999999)
    card_games = clampi(int(file.get_value("leisure", "card_games", 0)), 0, 999999)
    social_visits = clampi(int(file.get_value("leisure", "social_visits", 0)), 0, 999999)
    ending_seen = bool(file.get_value("leisure", "ending_seen", false))
    ending_line_index = clampi(int(file.get_value("leisure", "ending_line_index", 0)), 0, SECRET_LINES.size())

func _save_stats() -> bool:
    var file := ConfigFile.new()
    file.set_value("leisure", "chess_wins", chess_wins)
    file.set_value("leisure", "chess_games", chess_games)
    file.set_value("leisure", "card_wins", card_wins)
    file.set_value("leisure", "card_games", card_games)
    file.set_value("leisure", "social_visits", social_visits)
    file.set_value("leisure", "ending_seen", ending_seen)
    file.set_value("leisure", "ending_line_index", ending_line_index)
    var err: Error = file.save(save_path)
    if err != OK:
        push_warning("Leisure progress could not be persisted locally")
        return false
    return true

func reset_chess() -> void:
    chess_board = PackedInt32Array()
    chess_board.resize(BOARD_SIZE * BOARD_SIZE)
    chess_board.fill(0)
    chess_over = false
    chess_winner = 0
    chess_moves = 0
    chess_last_message = _t("五子棋：你先下黑棋，五子连线获胜。", "Gomoku: You play black first. Connect five stones to win.")
    _sync_board_stones()

func stone_at(x: int, y: int) -> int:
    if x < 0 or y < 0 or x >= BOARD_SIZE or y >= BOARD_SIZE:
        return -1
    return chess_board[y * BOARD_SIZE + x]

func _winner_from(x: int, y: int) -> int:
    var owner: int = stone_at(x, y)
    if owner <= 0:
        return 0
    for axis in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
        var run: int = 1
        for direction in [-1, 1]:
            var cx: int = x + axis.x * direction
            var cy: int = y + axis.y * direction
            while stone_at(cx, cy) == owner:
                run += 1
                cx += axis.x * direction
                cy += axis.y * direction
        if run >= WIN_LENGTH:
            return owner
    return 0

func _simulated_win(x: int, y: int, owner: int) -> bool:
    if stone_at(x, y) != 0:
        return false
    chess_board[y * BOARD_SIZE + x] = owner
    var result: bool = _winner_from(x, y) == owner
    chess_board[y * BOARD_SIZE + x] = 0
    return result

func _ai_move() -> Vector2i:
    # AI sees immediate wins/blocks, then prioritizes nearby connected groups.
    # This deliberately permits counterplay instead of using an unbeatable bot.
    var options: Array[Vector2i] = []
    for y in range(BOARD_SIZE):
        for x in range(BOARD_SIZE):
            if stone_at(x, y) == 0:
                options.append(Vector2i(x, y))
    for owner in [2, 1]:
        for square in options:
            if _simulated_win(square.x, square.y, owner):
                return square
    if options.is_empty():
        return Vector2i(-1, -1)
    var best: Vector2i = options[0]
    var high_score: float = -100000.0
    for square in options:
        var score: float = 4.0 - 0.15 * float(abs(square.x - 4) + abs(square.y - 4))
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if dx == 0 and dy == 0:
                    continue
                var adjacent: int = stone_at(square.x + dx, square.y + dy)
                var distance: int = maxi(abs(dx), abs(dy))
                if adjacent == 2:
                    score += 3.0 / float(distance)
                elif adjacent == 1:
                    score += 2.1 / float(distance)
        score += chess_rng.randf_range(0.0, 2.2)
        if score > high_score:
            high_score = score
            best = square
    return best

func play_chess(x: int, y: int) -> bool:
    if not unlocked() or chess_over or stone_at(x, y) != 0:
        return false
    chess_board[y * BOARD_SIZE + x] = 1
    chess_moves += 1
    club_event.emit("move")
    var human_winner: int = _winner_from(x, y)
    if human_winner == 1:
        _sync_board_stones()
        _finish_chess(1)
        return true
    if chess_moves >= BOARD_SIZE * BOARD_SIZE:
        _sync_board_stones()
        _finish_chess(0)
        return true
    var npc: Vector2i = _ai_move()
    if npc.x < 0:
        _sync_board_stones()
        _finish_chess(0)
        return true
    chess_board[npc.y * BOARD_SIZE + npc.x] = 2
    chess_moves += 1
    _sync_board_stones()
    var npc_winner: int = _winner_from(npc.x, npc.y)
    if npc_winner == 2:
        _finish_chess(2)
    elif chess_moves >= BOARD_SIZE * BOARD_SIZE:
        _finish_chess(0)
    else:
        chess_last_message = _t("你执黑棋 | 对手执白棋 | 已走 %d 手", "You: black | NPC: white | %d moves") % chess_moves
    return true

func _finish_chess(winner: int) -> void:
    chess_over = true
    chess_winner = winner
    chess_games += 1
    if winner == 1:
        chess_wins += 1
        chess_last_message = _t("五子棋获胜！对手：我本来也想下这里……", "Gomoku victory! Rival: I was about to play there...")
    elif winner == 2:
        chess_last_message = _t("对手赢了！队友终于做了件有用的事。", "Your rival wins! A teammate finally did something useful.")
    else:
        chess_last_message = _t("平局。谁都没逃过下学期的截止时间。", "Draw. Neither of you escaped next semester's deadlines.")
    _save_stats()
    _start_reaction("chess", "win" if winner == 1 else "lose")

func _new_deck() -> Array[Dictionary]:
    var cards: Array[Dictionary] = []
    for suit in range(4):
        for rank in range(2, 15):
            cards.append({"rank": rank, "suit": suit})
    return cards

func _deal_one() -> Dictionary:
    if card_deck.is_empty():
        return {}
    var index: int = card_rng.randi_range(0, card_deck.size() - 1)
    var card: Dictionary = card_deck[index]
    card_deck.remove_at(index)
    return card

func start_cards() -> void:
    card_deck = _new_deck()
    card_hand.clear()
    npc_hand.clear()
    for _i in range(CARD_ROUNDS):
        card_hand.append(_deal_one())
        npc_hand.append(_deal_one())
    card_round = 0
    card_player_points = 0
    card_npc_points = 0
    card_over = false
    card_message = _t("社团纸牌：五轮比点数，不下注。选择要出的牌。", "Club cards: Five high-card rounds, no wagers. Choose your card.")

func card_label(card: Dictionary) -> String:
    if card.is_empty():
        return "—"
    var rank: int = int(card["rank"])
    var display_rank: String = str(rank)
    match rank:
        11: display_rank = "J"
        12: display_rank = "Q"
        13: display_rank = "K"
        14: display_rank = "A"
    return "%s%s" % [SUITS[int(card["suit"])], display_rank]

func play_card(index: int) -> bool:
    if not unlocked() or card_over or index < 0 or index >= card_hand.size() or npc_hand.is_empty():
        return false
    var player_card: Dictionary = card_hand[index]
    card_hand.remove_at(index)
    # NPC has a concealed hand but sometimes plays defensively; no deck stakes.
    var npc_index: int = card_rng.randi_range(0, npc_hand.size() - 1)
    if card_rng.randf() < 0.35:
        npc_index = 0
        for i in range(1, npc_hand.size()):
            if int(npc_hand[i]["rank"]) > int(npc_hand[npc_index]["rank"]):
                npc_index = i
    var npc_card: Dictionary = npc_hand[npc_index]
    npc_hand.remove_at(npc_index)
    card_round += 1
    var own_rank: int = int(player_card["rank"])
    var other_rank: int = int(npc_card["rank"])
    if own_rank > other_rank:
        card_player_points += 1
        card_message = _t("第 %d 轮：你出 %s，对手出 %s。你得分！", "Round %d: You played %s, NPC played %s. Point for you!") % [card_round, card_label(player_card), card_label(npc_card)]
    elif own_rank < other_rank:
        card_npc_points += 1
        card_message = _t("第 %d 轮：你出 %s，对手出 %s。对手得分！", "Round %d: You played %s, NPC played %s. Point for the NPC!") % [card_round, card_label(player_card), card_label(npc_card)]
    else:
        card_message = _t("第 %d 轮：你出 %s，对手出 %s。平手！", "Round %d: You played %s, NPC played %s. Tie!") % [card_round, card_label(player_card), card_label(npc_card)]
    if last_card_prop != null:
        last_card_prop.text = "%s vs %s" % [card_label(player_card), card_label(npc_card)]
    if card_round >= CARD_ROUNDS or card_hand.is_empty():
        _finish_cards()
    else:
        club_event.emit("card")
    return true

func _finish_cards() -> void:
    card_over = true
    card_games += 1
    if card_player_points > card_npc_points:
        card_wins += 1
        card_message += _t("\n牌局胜利！队友：下次让我洗牌吧？", "\nYou win the match! Teammate: Can I shuffle next time?")
    elif card_player_points < card_npc_points:
        card_message += _t("\n对手获胜！终于有人愿意当组长了。", "\nNPC wins! Someone finally volunteers to lead the group.")
    else:
        card_message += _t("\n本场平局。奖品是不用写作业。", "\nDraw. Your prize is zero extra homework.")
    _save_stats()
    _start_reaction("cards", "win" if card_player_points > card_npc_points else "lose")

func celebrate(kind: String, adult_confirmed: bool = false) -> bool:
    if not unlocked():
        social_message = _t("先完成任意学院的三章任务。", "Finish three quests in any faculty to unlock the club.")
        return false
    if kind == "adult" and not adult_confirmed:
        social_message = _t("含酒精选项仅面向达到所在地法定饮酒年龄的玩家，也可选择无酒精饮品。",
            "The optional alcoholic drink is for players of legal drinking age. Non-alcoholic options are available.")
        return false
    if kind not in ["mocktail", "tea", "adult"]:
        return false
    celebration_counter += 1
    social_visits += 1
    if kind == "adult":
        adult_toast_cooldown = SOCIAL_COOLDOWN
    var drink: String = ""
    match kind:
        "mocktail":
            drink = _t("无酒精特调", "Mocktail")
        "tea":
            drink = _t("茶饮", "Tea")
        "adult":
            drink = _t("成年人小酌", "Adult toast")
    var index: int = (celebration_counter - 1) % SOCIAL_LINES.size()
    var line: String = SOCIAL_LINES[index] if language != null and language.is_chinese() else SOCIAL_LINES_EN[index]
    social_message = _t("%s：干杯！\n%s\n饮品选择不会增加经验或解锁额外剧情。",
        "%s: Cheers!\n%s\nYour drink choice does not grant XP or unlock extra stories.") % [drink, line]
    _save_stats()
    _start_reaction("social", "social")
    return true

func safe_to_ride() -> bool:
    return adult_toast_cooldown <= 0.0

func _process(delta: float) -> void:
    adult_toast_cooldown = maxf(0.0, adult_toast_cooldown - delta)
    if lounge_root != null:
        lounge_root.visible = unlocked()
    _animate_club(delta)
    # This is a cooldown for this fictional game session, not BAC simulation.

func _prop_material(color_hex: String, emission: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(color_hex)
    material.roughness = 0.58
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = Color.html(color_hex)
        material.emission_energy_multiplier = emission
    return material

func _prop_box(parent: Node3D, name: String, at: Vector3, size: Vector3, tint: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var geometry := BoxMesh.new()
    geometry.size = size
    mesh.mesh = geometry
    mesh.position = at
    mesh.material_override = tint
    parent.add_child(mesh)

func _prop_sign(parent: Node3D, zh_text: String, en_text: String, at: Vector3) -> void:
    var label := Label3D.new()
    label.text = _t(zh_text, en_text)
    label.set_meta("zh_text", zh_text)
    label.set_meta("en_text", en_text)
    label.add_to_group("leisure_localized_signs")
    label.name = "ClubLabel"
    label.font_size = 22
    label.pixel_size = 0.01
    label.outline_size = 5
    label.modulate = Color.html("#fff3ca")
    label.position = at
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)

func nearest_station() -> String:
    # Enter the real in-game SRC room before using a game table. No P shortcut
    # from another building, the shuttle, a mezzanine or the outdoor map.
    if not unlocked() or not life.interior_active or life.active_interior != "SRC" or life.interior_floor != 0:
        return ""
    if life.on_shuttle or life.bicycle_enabled:
        return ""
    var room: Node3D = life.interiors["SRC"]
    var local_player: Vector3 = room.to_local(life.player.global_position)
    var closest: String = ""
    var nearest_distance: float = INTERACT_RADIUS
    for id in station_targets:
        var point: Vector3 = station_targets[id]
        var distance: float = Vector2(local_player.x, local_player.z).distance_to(Vector2(point.x, point.z))
        if distance <= nearest_distance:
            nearest_distance = distance
            closest = str(id)
    return closest

func can_open_station(id: String) -> bool:
    return nearest_station() == id

func station_global_position(id: String) -> Vector3:
    if not life.interiors.has("SRC") or not station_targets.has(id):
        return Vector3.ZERO
    var room: Node3D = life.interiors["SRC"]
    return room.to_global(station_targets[id])

func secret_unlocked() -> bool:
    return unlocked() and chess_wins >= 2 and card_wins >= 1 and social_visits >= 1

func reveal_secret() -> String:
    if not secret_unlocked():
        ending_message = "神秘收官剧情：先赢 2 局五子棋、1 场牌局，再参加一次社团聚会。"
        return ending_message
    var index: int = mini(SECRET_LINES.size() - 1, ending_line_index)
    ending_message = SECRET_LINES[index]
    if grand_master_unlocked() and index == SECRET_LINES.size() - 1:
        ending_message += "\n隐藏真结局：全部 39 个学院章节通关！『最终成绩：可以光明正大地摸鱼。』"
    ending_line_index = mini(SECRET_LINES.size(), ending_line_index + 1)
    ending_seen = true
    _save_stats()
    _start_reaction("social", "ending")
    return ending_message

func _start_reaction(station: String, event_type: String) -> void:
    active_reaction = station
    reaction_left = 2.1 if event_type == "win" or event_type == "ending" else 0.9
    club_event.emit(event_type)

func _sync_board_stones() -> void:
    if stone_models == null:
        return
    for child in stone_models.get_children():
        stone_models.remove_child(child)
        child.queue_free()
    for y in range(BOARD_SIZE):
        for x in range(BOARD_SIZE):
            var player_id: int = stone_at(x, y)
            if player_id <= 0:
                continue
            var piece := MeshInstance3D.new()
            piece.name = "Stone_%d_%d" % [x, y]
            var mesh := CylinderMesh.new()
            mesh.top_radius = 0.067
            mesh.bottom_radius = 0.067
            mesh.height = 0.037
            piece.mesh = mesh
            piece.material_override = board_stone_black if player_id == 1 else board_stone_white
            piece.position = Vector3(3.2 + (float(x) - 4.0) * 0.17, 0.873,
                -5.7 + (float(y) - 4.0) * 0.17)
            stone_models.add_child(piece)

func _create_seated_opponent(station: String, index: int, at: Vector3, facing: float) -> void:
    var actor: Node3D = life._make_person(index)
    actor.name = "ClubOpponent_" + station
    actor.position = at
    actor.rotation.y = facing
    actor.scale = Vector3.ONE * 0.94
    lounge_root.add_child(actor)
    var left_leg: Node3D = actor.get_node("LeftLegPivot")
    var right_leg: Node3D = actor.get_node("RightLegPivot")
    left_leg.rotation.x = -1.05
    right_leg.rotation.x = -1.05
    # A thin chair, rather than a floating seated character.
    var wood: Material = _prop_material("#8d755a")
    _prop_box(lounge_root, station + "_ChairSeat", at + Vector3(0.0, 0.42, 0.02),
        Vector3(0.78, 0.10, 0.78), wood)
    _prop_box(lounge_root, station + "_ChairBack", at + Vector3(0.0, 0.87, -0.30),
        Vector3(0.77, 0.90, 0.11), wood)
    _prop_box(lounge_root, station + "_ChairLegA", at + Vector3(-0.26, 0.22, 0.0),
        Vector3(0.09, 0.41, 0.09), wood)
    _prop_box(lounge_root, station + "_ChairLegB", at + Vector3(0.26, 0.22, 0.0),
        Vector3(0.09, 0.41, 0.09), wood)
    var title := Label3D.new()
    title.name = "SeatCompanionName"
    title.text = "NPC / " + ("棋友" if station == "chess" else "牌友" if station == "cards" else "社团朋友")
    title.font_size = 17
    title.pixel_size = 0.009
    title.outline_size = 3
    title.position = Vector3(0, 2.10, 0)
    title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    actor.add_child(title)
    var hair := MeshInstance3D.new()
    hair.name = "ClubHair"
    var hair_mesh := SphereMesh.new()
    hair_mesh.radius = 0.22
    hair.mesh = hair_mesh
    hair.position = Vector3(0.0, 1.84, 0.0)
    hair.scale = Vector3(1.0, 0.45, 1.0)
    hair.material_override = _prop_material("#333d46" if station != "social" else "#51423f")
    actor.add_child(hair)
    seat_actors[station] = {
        "node": actor, "left_arm": actor.get_node("LeftArmPivot"),
        "right_arm": actor.get_node("RightArmPivot"), "position": at
    }

func _animate_club(delta: float) -> void:
    if lounge_root == null:
        return
    reaction_left = maxf(0.0, reaction_left - delta)
    var now: float = float(Time.get_ticks_msec()) * 0.001
    for station in seat_actors:
        var state: Dictionary = seat_actors[station]
        var node: Node3D = state["node"]
        var excited: bool = reaction_left > 0.0 and str(station) == active_reaction
        var phase: float = now * (8.0 if excited else 1.5)
        node.position = state["position"] + Vector3(0.0, absf(sin(phase)) * (0.065 if excited else 0.006), 0.0)
        var left_arm: Node3D = state["left_arm"]
        var right_arm: Node3D = state["right_arm"]
        left_arm.rotation.x = -0.9 + sin(phase) * (0.58 if excited else 0.09)
        right_arm.rotation.x = -0.9 - sin(phase) * (0.58 if excited else 0.09)
    for id in station_highlights:
        var halo: MeshInstance3D = station_highlights[id]
        if not unlocked() or not life.interior_active or life.active_interior != "SRC":
            halo.visible = false
            continue
        halo.visible = nearest_station() == str(id)
        halo.scale = Vector3.ONE * (1.0 + 0.07 * sin(now * 4.0))
    if celebration_glow != null:
        celebration_glow.visible = reaction_left > 0.0
        if reaction_left > 0.0:
            celebration_glow.position.y = 2.30 + 0.20 * sin(now * 7.0)
            celebration_glow.scale = Vector3.ONE * (1.0 + 0.16 * sin(now * 5.0))
            celebration_glow.position.x = 3.2 if active_reaction == "chess" else 7.5 if active_reaction == "cards" else -4.8
            celebration_glow.position.z = -5.7 if active_reaction in ["chess", "cards"] else 5.4

func _create_lounge_props() -> void:
    if not life.interiors.has("SRC"):
        return
    # Three enterable 3D activity stations; menus require proximity in SRC.
    # Avoid solid colliders, preserving the existing room circulation paths.
    lounge_root = Node3D.new()
    lounge_root.name = "PostCourseClub_Illustrative"
    life.interiors["SRC"].add_child(lounge_root)
    var wood := _prop_material("#91755b")
    var trim := _prop_material("#f0c371", 0.12)
    var dark := _prop_material("#344c57")
    var glass := _prop_material("#85c8d4")
    _prop_box(lounge_root, "ChessTable", Vector3(3.2, 0.73, -5.7), Vector3(2.5, 0.12, 2.3), wood)
    for x in [-1.0, 1.0]:
        for z in [-1.0, 1.0]:
            _prop_box(lounge_root, "ChessTableLeg", Vector3(3.2 + x * 0.98, 0.37, -5.7 + z * 0.82),
                Vector3(0.14, 0.67, 0.14), wood)
    _prop_box(lounge_root, "GomokuBoard", Vector3(3.2, 0.82, -5.7), Vector3(1.55, 0.03, 1.55), trim)
    for i in range(9):
        var offset: float = (float(i) - 4.0) * 0.17
        _prop_box(lounge_root, "BoardLineX", Vector3(3.2, 0.841, -5.7 + offset), Vector3(1.38, 0.006, 0.016), dark)
        _prop_box(lounge_root, "BoardLineZ", Vector3(3.2 + offset, 0.842, -5.7), Vector3(0.016, 0.006, 1.38), dark)
    _prop_box(lounge_root, "CardsTable", Vector3(7.5, 0.73, -5.7), Vector3(2.7, 0.13, 2.1), dark)
    _prop_box(lounge_root, "CardTablePedestal", Vector3(7.5, 0.34, -5.7),
        Vector3(0.35, 0.68, 0.35), wood)
    for j in range(4):
        _prop_box(lounge_root, "PlayingCard", Vector3(6.65 + float(j) * 0.44, 0.81, -5.7),
            Vector3(0.31, 0.015, 0.53), trim if j % 2 == 0 else glass)
    _prop_box(lounge_root, "SocialCounter", Vector3(-4.8, 1.0, 5.4), Vector3(2.5, 0.16, 0.85), wood)
    for j in range(3):
        _prop_box(lounge_root, "PartyCup", Vector3(-5.5 + float(j) * 0.63, 1.21, 5.4),
            Vector3(0.22, 0.29, 0.22), glass)
    # Reserved scene nodes for board pieces / card results, updated by real matches.
    stone_models = Node3D.new()
    stone_models.name = "LiveGomokuStones"
    lounge_root.add_child(stone_models)
    board_stone_black = _prop_material("#1f2832")
    board_stone_white = _prop_material("#f2f2e8")
    last_card_prop = Label3D.new()
    last_card_prop.name = "LastCardDuelResult"
    last_card_prop.text = "?"
    last_card_prop.font_size = 23
    last_card_prop.pixel_size = 0.013
    last_card_prop.outline_size = 3
    last_card_prop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    last_card_prop.position = Vector3(7.5, 1.43, -5.7)
    lounge_root.add_child(last_card_prop)
    _create_seated_opponent("chess", 3, Vector3(3.2, -0.26, -7.3), PI)
    _create_seated_opponent("cards", 4, Vector3(7.5, -0.26, -7.2), PI)
    _create_seated_opponent("social", 5, Vector3(-4.8, -0.24, 4.15), 0.0)
    var gold := _prop_material("#f2c47e", 0.22)
    for station in station_targets:
        var orb := MeshInstance3D.new()
        orb.name = str(station) + "_ContextualHalo"
        var torus := TorusMesh.new()
        torus.inner_radius = 0.35
        torus.outer_radius = 0.43
        orb.mesh = torus
        orb.position = station_targets[station] + Vector3(0.0, -0.06, 0.0)
        orb.material_override = gold
        orb.visible = false
        lounge_root.add_child(orb)
        station_highlights[station] = orb
    celebration_glow = MeshInstance3D.new()
    celebration_glow.name = "ClubCelebrationHalo"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.66
    ring_mesh.outer_radius = 0.78
    celebration_glow.mesh = ring_mesh
    celebration_glow.material_override = gold
    celebration_glow.visible = false
    lounge_root.add_child(celebration_glow)
    lounge_root.visible = unlocked()
