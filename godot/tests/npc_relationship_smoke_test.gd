extends SceneTree
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("M11 NPC relationship smoke: " + message)
    quit(1)

func _run() -> void:
    var path: String = "user://m11-relationships-%d.cfg" % Time.get_ticks_usec()
    var relation: NUS3DRelationships = NUS3DRelationships.new()
    root.add_child(relation)
    relation.load_account(path)
    if relation.affinity("Maya") != 0 or relation.tier("Maya") != 0:
        _fail("new account must start with neutral relationships")
        return
    var first: String = relation.conversation("Maya", true)
    if relation.affinity("Maya") != 4 or not first.contains("+4"):
        _fail("Maya conversation affinity gain failed")
        return
    relation.conversation("Maya", true)
    if relation.affinity("Maya") != 4:
        _fail("conversation cooldown did not prevent repeated farming")
        return
    var tier_probe: NUS3DRelationships = NUS3DRelationships.new()
    tier_probe.scores["Maya"] = 9
    if not tier_probe.contextual_line("Maya", true).is_empty():
        _fail("Friendship dialogue must remain locked below the 10-point threshold")
        return
    tier_probe.scores["Maya"] = 10
    if tier_probe.contextual_line("Maya", true).is_empty():
        _fail("Friendship dialogue must unlock at the 10-point threshold")
        return
    relation.conversation("Ethan", true)
    if relation.affinity("Ethan") != 2:
        _fail("reserved personality should gain affinity more slowly")
        return
    var second: NUS3DRelationships = NUS3DRelationships.new()
    root.add_child(second)
    second.load_account(path)
    if second.affinity("Maya") != 4 or second.affinity("Ethan") != 2:
        _fail("relationship save did not persist")
        return
    second.load_account(path + ".other")
    if second.affinity("Maya") != 0:
        _fail("relationship data leaked across accounts")
        return
    for i in range(40):
        relation.scores["Maya"] = 98
        relation.last_talk["Maya"] = 0
        relation.conversation("Maya", true)
    if relation.affinity("Maya") > 100:
        _fail("affinity exceeded its cap")
        return
    print("PASS: M11 personality, affinity tiers, cooldown, persistence and account isolation")
    quit(0)
