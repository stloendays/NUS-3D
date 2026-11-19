extends Node
class_name NUS3DRelationships
## Account-scoped, offline NPC affinity. No network RPC or progression rewards.
## Only three authored characters have persistent personality and relationship arcs.
## Other pedestrians remain lightweight ambient NPCs for low-spec machines.
const PROFILES: Dictionary = {
    "Maya": {"trait":"chaotic", "zh":"热情、戏精、DDL恐慌", "en":"Outgoing, dramatic, deadline-panicked"},
    "Ethan": {"trait":"reserved", "zh":"内向、认真、慢热", "en":"Reserved, studious, slow to trust"},
    "Mei": {"trait":"curious", "zh":"好奇、理工脑、咖啡控", "en":"Curious, analytical, coffee obsessed"}
}

const COOLDOWN_SECONDS: int = 45
const MAX_AFFINITY: int = 100
var save_path: String = ""
var scores: Dictionary = {}
var last_talk: Dictionary = {}
var talk_counts: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE


func load_account(path: String) -> void:
    scores.clear()
    last_talk.clear()
    talk_counts.clear()
    save_path = path
    if path.is_empty() or not FileAccess.file_exists(path):
        return
    var cfg: ConfigFile = ConfigFile.new()
    if cfg.load(path) != OK:
        return
    for name in PROFILES:
        scores[name] = clampi(int(cfg.get_value("affinity", name, 0)), 0, MAX_AFFINITY)
        talk_counts[name] = maxi(0, int(cfg.get_value("conversations", name, 0)))
        last_talk[name] = int(cfg.get_value("last_talk", name, 0))


func clear_account() -> void:
    save_path = ""
    scores.clear()
    last_talk.clear()
    talk_counts.clear()


func _save() -> void:
    if save_path.is_empty():
        return
    var cfg: ConfigFile = ConfigFile.new()
    for name in PROFILES:
        cfg.set_value("affinity", name, affinity(name))
        cfg.set_value("conversations", name, int(talk_counts.get(name, 0)))
        cfg.set_value("last_talk", name, int(last_talk.get(name, 0)))
    if cfg.save(save_path) != OK:
        push_warning("Unable to save NPC relationships")


func is_story_character(name: String) -> bool:
    return PROFILES.has(name)

func affinity(name: String) -> int:
    return clampi(int(scores.get(name, 0)), 0, MAX_AFFINITY)


func tier(name: String) -> int:
    var value: int = affinity(name)
    if value >= 80:
        return 4
    if value >= 55:
        return 3
    if value >= 30:
        return 2
    if value >= 10:
        return 1
    return 0


func trait_text(name: String, chinese: bool) -> String:
    var profile: Dictionary = PROFILES.get(name, {})
    return str(profile.get("zh" if chinese else "en", "神秘 / Mysterious"))


func tier_text(name: String, chinese: bool) -> String:
    var zh: Array[String] = ["陌生人", "眼熟", "朋友", "知己", "校园挚友"]
    var en: Array[String] = ["Stranger", "Acquaintance", "Friend", "Confidant", "Campus bestie"]
    return zh[tier(name)] if chinese else en[tier(name)]


func conversation(name: String, chinese: bool) -> String:
    if not PROFILES.has(name):
        return ""
    var now: int = int(Time.get_unix_time_from_system())
    var last: int = int(last_talk.get(name, 0))
    var eligible: bool = save_path != "" and now - last >= COOLDOWN_SECONDS
    var gain: int = 0
    if eligible:
        var profile: Dictionary = PROFILES[name]
        var trait: String = str(profile["trait"])
        gain = 2 if trait == "reserved" else 4 if trait == "chaotic" else 3
        scores[name] = mini(MAX_AFFINITY, affinity(name) + gain)
        last_talk[name] = now
        talk_counts[name] = int(talk_counts.get(name, 0)) + 1
        _save()
    var result: String = "好感 %d/100  %s" % [affinity(name), tier_text(name, true)] if chinese \
        else "Affinity %d/100  %s" % [affinity(name), tier_text(name, false)]
    if gain > 0:
        result += "  +%d" % gain
    return result


func invitation(name: String, chinese: bool) -> String:
    if not PROFILES.has(name) or tier(name) < 2:
        return ""
    var zh: Dictionary = {
        "Maya": "支线邀请：一起去食堂制定反 DDL 作战计划。",
        "Ethan": "支线邀请：一起去图书馆安静自习。",
        "Mei": "支线邀请：一起去咖啡厅研究神秘配方。"
    }
    var en: Dictionary = {
        "Maya": "Side activity: plan a deadline survival strategy at the canteen.",
        "Ethan": "Side activity: study quietly together at the library.",
        "Mei": "Side activity: investigate a mysterious coffee recipe."
    }
    return str((zh if chinese else en).get(name, ""))


func contextual_line(name: String, chinese: bool) -> String:
    if not PROFILES.has(name):
        return ""
    var value: int = tier(name)
    if value == 0:
        return ""
    var phrases: Dictionary = {
        "Maya": ["我记住你了！下次一起对抗 DDL。", "快来，我给你留了个咖啡位！", "如果 DDL 是怪兽，我们就是双人副本。", "毕业照你必须站我旁边。"],
        "Ethan": ["嗯……下次可以一起自习。", "我给你整理了一份复习提纲。", "其实我很少和别人聊这么久。", "图书馆最安静的角落，永远给你留一个位置。"],
        "Aisha": ["下次比比谁先赶上校车！", "我承认，你的速度有点东西。", "组队吧，今天我们绝不迟到。", "校园挑战赛，我只想和你搭档。"],
        "Lucas": ["来一起热身，先从走到食堂开始。", "你的坚持比我的健身计划靠谱。", "下次运动会我们组队。", "你是我唯一不会放鸽子的训练伙伴。"],
        "Mei": ["要不要一起研究咖啡的相图？", "我的实验笔记可以借你看。", "下次一起去做那个疯狂的小实验。", "我把最后一包咖啡豆留给你了。"],
        "Daniel": ["你出现了，今天的哲学问题有解了。", "我们的友谊比我的论文论证更严谨。", "下次一起探讨 DDL 的本体论。", "若校园是一场梦，我希望你也在梦里。"]
    }
    var english: Dictionary = {
        "Maya": ["I remember you! Let's fight the next deadline.", "I saved you a coffee seat!", "If deadlines are monsters, we're a co-op team.", "You have to stand next to me in the graduation photo."],
        "Ethan": ["We could study together sometime.", "I made a revision guide for you.", "I rarely talk to anyone this much.", "I'll always save you a quiet library corner."],
        "Aisha": ["Race you to the shuttle next time!", "Okay, you're surprisingly quick.", "Team up. We won't be late today.", "You're my first choice for the campus challenge."],
        "Lucas": ["Let's warm up by walking to the canteen.", "You're more consistent than my workout plan.", "Let's team up for sports day.", "You're my only training buddy who never cancels."],
        "Mei": ["Want to study the phase diagram of coffee?", "You can borrow my lab notes.", "Let's try that ridiculous experiment together.", "I saved my last coffee beans for you."],
        "Daniel": ["You're here. Today's philosophical puzzle is solved.", "Our friendship is better argued than my thesis.", "Let's debate the ontology of deadlines.", "If campus life is a dream, I hope you're in it."]
    }
    var options: Array = phrases.get(name, []) if chinese else english.get(name, [])
    return str(options[value - 1]) if options.size() >= value else ""
