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
    if NUS3DRelationships.PROFILES.size() != 3 or not relation.is_story_character("Mei") or relation.is_story_character("Aisha"):
        _fail("only three named story NPCs may have persistent personalities")
        return
    if not relation.conversation("Aisha", false).is_empty():
        _fail("ambient NPC unexpectedly creates relationship state")
        return
    var first: String = relation.conversation("Maya", true)
    if relation.affinity("Maya") != 4 or not first.contains("+4"):
        _fail("Maya conversation affinity gain failed")
        return
    relation.conversation("Maya", true)
    if relation.affinity("Maya") != 4:
        _fail("conversation cooldown did not prevent repeated farming")
        return
    if not relation.contextual_line("Maya", true).is_empty():
        _fail("contextual dialogue unlocked before first friendship tier")
        return
    relation.scores["Maya"] = 10
    if relation.contextual_line("Maya", true).is_empty():
        _fail("relationship dialogue did not unlock at friendship tier one")
        return
    relation.scores["Maya"] = 4
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
    if not relation.invitation("Maya", false).is_empty() and relation.tier("Maya") < 2:
        _fail("side activity invitation unlocked before friendship")
        return
    if relation.talk_counts.has("Aisha") or relation.scores.has("Lucas"):
        _fail("ambient NPCs acquired persistent relationship entries")
        return
    NUS3DServices.ensure_scene_services(self)
    var shell_scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    var shell: NUS3DGameShell = shell_scene.instantiate() as NUS3DGameShell
    var accounts: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    accounts.storage_root = "user://m11-relationships-accounts-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame
    var actor_affinity: NUS3DRelationships = shell.game.get_node_or_null("Relationships") as NUS3DRelationships
    if actor_affinity == null:
        _fail("game shell failed to mount account-scoped NPC relationships")
        return
    if accounts.register("maya_test", "password-for-maya-2026") != "":
        _fail("cannot register test account one")
        return
    shell._enter_game()
    if actor_affinity.save_path != accounts.feature_save_path("relationships"):
        _fail("NPC affinity save location not bound to signed-in account")
        return
    actor_affinity.conversation("Maya", false)
    if actor_affinity.affinity("Maya") != 4:
        _fail("first account relation did not advance")
        return
    shell._logout()
    if actor_affinity.save_path != "" or not actor_affinity.scores.is_empty():
        _fail("NPC relationship data retained after logout")
        return
    if accounts.register("ethan_test", "password-for-ethan-2026") != "":
        _fail("cannot register test account two")
        return
    shell._enter_game()
    if actor_affinity.affinity("Maya") != 0:
        _fail("relationship from account one leaked into account two")
        return
    print("PASS: selected Maya/Ethan/Mei, cooldown, invitation gates and GameShell multi-account isolation")
    quit(0)
