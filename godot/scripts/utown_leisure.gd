extends Node
class_name UTownLeisure
## M3.8: offline, original post-course games. Not an actual NUS venue.
## No betting, real-world prizes, alcohol sales or real student profiles.

const SAVE_PATH: String = "user://nus3d_leisure.cfg"
const BOARD_SIZE: int = 9
const WIN_LENGTH: int = 5
const CARD_ROUNDS: int = 5
const SOCIAL_COOLDOWN: float = 75.0
const SUITS: Array[String] = ["S", "H", "D", "C"]
const SOCIAL_LINES: Array[String] = [
    "Maya：终于不用追着队友要 Google Docs 编辑权限了。",
    "Ethan：今天阅读的唯一文献，是饮料菜单。",
    "Aisha：你以为通关了？别忘了下学期还有 DDL。",
    "Daniel：干杯！不管喝什么，课程总算提交成功了。",
    "Mei：这一杯献给凌晨 3 点的备份文件。"
]

@onready var coursework: UTownCoursework = $"../Coursework"
@onready var life: UTownCampusLife = $"../CampusLife"

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

var social_message: String = "DDL 已清空。来一杯什么？"
var celebration_counter: int = 0
var adult_toast_cooldown: float = 0.0  # per-session only; no birth dates saved
var chess_wins: int = 0
var card_wins: int = 0
var chess_games: int = 0
var card_games: int = 0
var social_visits: int = 0
var lounge_root: Node3D

func _ready() -> void:
    chess_rng.randomize()
    card_rng.randomize()
    reset_chess()
    start_cards()
    _load_stats()
    _create_lounge_props()

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

func _save_stats() -> bool:
    var file := ConfigFile.new()
    file.set_value("leisure", "chess_wins", chess_wins)
    file.set_value("leisure", "chess_games", chess_games)
    file.set_value("leisure", "card_wins", card_wins)
    file.set_value("leisure", "card_games", card_games)
    file.set_value("leisure", "social_visits", social_visits)
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
    chess_last_message = "五子棋：你执黑先手。把五颗棋子连成一线！"

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
    var human_winner: int = _winner_from(x, y)
    if human_winner == 1:
        _finish_chess(1)
        return true
    if chess_moves >= BOARD_SIZE * BOARD_SIZE:
        _finish_chess(0)
        return true
    var npc: Vector2i = _ai_move()
    if npc.x < 0:
        _finish_chess(0)
        return true
    chess_board[npc.y * BOARD_SIZE + npc.x] = 2
    chess_moves += 1
    var npc_winner: int = _winner_from(npc.x, npc.y)
    if npc_winner == 2:
        _finish_chess(2)
    elif chess_moves >= BOARD_SIZE * BOARD_SIZE:
        _finish_chess(0)
    else:
        chess_last_message = "你：黑棋  |  NPC：白棋  |  已走 %d 手" % chess_moves
    return true

func _finish_chess(winner: int) -> void:
    chess_over = true
    chess_winner = winner
    chess_games += 1
    if winner == 1:
        chess_wins += 1
        chess_last_message = "五子棋胜利！NPC：『我本来想走那里的……』"
    elif winner == 2:
        chess_last_message = "NPC 赢了这局。队友终于做了点有用的事。"
    else:
        chess_last_message = "平局。你们谁也没有躲过下学期的 DDL。"
    _save_stats()

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
    card_message = "社团牌局：五轮比点数，不下注。选出你最适合的一张牌。"

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
        card_message = "第%d轮：你出 %s，NPC 出 %s。你赢这一手！" % [card_round, card_label(player_card), card_label(npc_card)]
    elif own_rank < other_rank:
        card_npc_points += 1
        card_message = "第%d轮：你出 %s，NPC 出 %s。NPC 得分！" % [card_round, card_label(player_card), card_label(npc_card)]
    else:
        card_message = "第%d轮：你出 %s，NPC 出 %s。平手！" % [card_round, card_label(player_card), card_label(npc_card)]
    if card_round >= CARD_ROUNDS or card_hand.is_empty():
        _finish_cards()
    return true

func _finish_cards() -> void:
    card_over = true
    card_games += 1
    if card_player_points > card_npc_points:
        card_wins += 1
        card_message += "\n你赢下这场牌局！队友：『下局能不能让我洗牌？』"
    elif card_player_points < card_npc_points:
        card_message += "\nNPC 获胜！现在终于有人愿意做组长了。"
    else:
        card_message += "\n本场平局，奖金是零张作业。"
    _save_stats()

func celebrate(kind: String, adult_confirmed: bool = false) -> bool:
    if not unlocked():
        social_message = "先通关任一学院的 3 个 Coursework 任务。"
        return false
    if kind == "adult" and not adult_confirmed:
        social_message = "含酒精选项仅供已达到所在地合法饮酒年龄的玩家。也可以选择无酒精饮品。"
        return false
    if kind not in ["mocktail", "tea", "adult"]:
        return false
    celebration_counter += 1
    social_visits += 1
    if kind == "adult":
        adult_toast_cooldown = SOCIAL_COOLDOWN
    var drink: String = "无酒精特调" if kind == "mocktail" else "茶饮" if kind == "tea" else "成年人小酌"
    var line: String = SOCIAL_LINES[(celebration_counter - 1) % SOCIAL_LINES.size()]
    social_message = "%s：%s\n%s\n不会获得额外 XP，也无需喝酒才能解锁剧情。" % [drink, "Cheers!" if kind == "adult" else "干杯！", line]
    _save_stats()
    return true

func safe_to_ride() -> bool:
    return adult_toast_cooldown <= 0.0

func _process(delta: float) -> void:
    adult_toast_cooldown = maxf(0.0, adult_toast_cooldown - delta)
    if lounge_root != null:
        lounge_root.visible = unlocked()
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

func _prop_sign(parent: Node3D, text_value: String, at: Vector3) -> void:
    var label := Label3D.new()
    label.text = text_value
    label.name = "ClubLabel"
    label.font_size = 22
    label.pixel_size = 0.01
    label.outline_size = 5
    label.modulate = Color.html("#fff3ca")
    label.position = at
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)

func _create_lounge_props() -> void:
    if not life.interiors.has("SRC"):
        return
    # Club tables are illustration only; game menu opens via [P] after clear.
    # Avoid solid colliders, preserving the existing room circulation paths.
    lounge_root = Node3D.new()
    lounge_root.name = "PostCourseClub_Illustrative"
    life.interiors["SRC"].add_child(lounge_root)
    var wood := _prop_material("#91755b")
    var trim := _prop_material("#f0c371", 0.12)
    var dark := _prop_material("#344c57")
    var glass := _prop_material("#85c8d4")
    _prop_box(lounge_root, "ChessTable", Vector3(3.2, 0.73, -5.7), Vector3(2.5, 0.12, 2.3), wood)
    _prop_box(lounge_root, "GomokuBoard", Vector3(3.2, 0.82, -5.7), Vector3(1.55, 0.03, 1.55), trim)
    for i in range(9):
        var offset: float = (float(i) - 4.0) * 0.17
        _prop_box(lounge_root, "BoardLineX", Vector3(3.2, 0.841, -5.7 + offset), Vector3(1.38, 0.006, 0.016), dark)
        _prop_box(lounge_root, "BoardLineZ", Vector3(3.2 + offset, 0.842, -5.7), Vector3(0.016, 0.006, 1.38), dark)
    _prop_box(lounge_root, "CardsTable", Vector3(7.5, 0.73, -5.7), Vector3(2.7, 0.13, 2.1), dark)
    for j in range(4):
        _prop_box(lounge_root, "PlayingCard", Vector3(6.65 + float(j) * 0.44, 0.81, -5.7),
            Vector3(0.31, 0.015, 0.53), trim if j % 2 == 0 else glass)
    _prop_box(lounge_root, "SocialCounter", Vector3(-4.8, 1.0, 5.4), Vector3(2.5, 0.16, 0.85), wood)
    for j in range(3):
        _prop_box(lounge_root, "PartyCup", Vector3(-5.5 + float(j) * 0.63, 1.21, 5.4),
            Vector3(0.22, 0.29, 0.22), glass)
    _prop_sign(lounge_root, "POST-COURSE CLUB  |  [P]", Vector3(0.0, 2.45, -5.7))
    _prop_sign(lounge_root, "CHEERS / MOCKTAILS", Vector3(-4.8, 2.22, 5.4))
    lounge_root.visible = unlocked()
