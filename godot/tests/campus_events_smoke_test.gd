extends SceneTree
## M28 contract: schedule selection, distinct ambient Q-talk, location gating and one-time rewards.

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("M28 campus events: " + reason)
    quit(1)


func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene could not load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    await process_frame
    NUS3DServices.enter_test_playmode(game)

    var events: NUS3DCampusEventDirector = game.get_node_or_null("CampusEvents") as NUS3DCampusEventDirector
    var daily: NUS3DCampusDailyLife = game.get_node_or_null("CampusDailyLife") as NUS3DCampusDailyLife
    var activities: NUS3DCampusAmbientActivities = game.get_node_or_null("CampusAmbientActivities") as NUS3DCampusAmbientActivities
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    var coins: UTownCoins = game.get_node_or_null("Coins") as UTownCoins
    var dining: UTownGreenDining = game.get_node_or_null("GreenDining") as UTownGreenDining
    var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
    if events == null or daily == null or activities == null or life == null or weather == null or coins == null or dining == null or player == null:
        _fail("one or more existing campus services were not wired")
        return

    events.set_process(false)
    daily.set_process(false)
    activities.set_process(false)
    life.set_process(false)
    weather.set_process(false)
    coins.set_process(false)
    player.set_physics_process(false)
    coins.save_path = "user://nus3d-m28-events-%d.cfg" % Time.get_ticks_usec()
    coins.load_progress()

    var ambient_states: Array[Dictionary] = []
    var story_states: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if bool(state.get("ambient", false)):
            ambient_states.append(state)
        else:
            story_states.append(state)
    if ambient_states.size() != 18 or story_states.size() != 6:
        _fail("the existing 18 ambient / 6 story NPC separation changed")
        return

    # Lunch Rush: the player must be near Fine Food and speak to two different
    # ambient NPCs. Repeating one conversation cannot complete the event.
    daily.set_game_time(12.0 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    if events.current_event_id != "lunch_rush":
        _fail("12:00 did not activate Lunch Rush")
        return
    var food_area: Dictionary = dining.dining_areas.get("fine_food", {})
    var food_root: Node3D = food_area.get("root") as Node3D
    if food_root == null:
        _fail("existing Fine Food root is unavailable")
        return
    player.global_position = food_root.global_position + Vector3(60.0, 0.0, 60.0)
    if not _talk_to(life, player, ambient_states[0]):
        _fail("could not talk to an ambient NPC outside the event zone")
        return
    if events.event_progress != 0:
        _fail("Lunch Rush counted a conversation outside Fine Food")
        return
    player.global_position = food_root.global_position
    if not _talk_to(life, player, ambient_states[0]):
        _fail("first Fine Food conversation failed")
        return
    if events.event_progress != 1 or events.event_complete:
        _fail("first unique ambient conversation did not advance progress to 1/2")
        return
    if not _talk_to(life, player, ambient_states[0]) or events.event_progress != 1:
        _fail("repeating the same NPC conversation incorrectly advanced progress")
        return
    if not _talk_to(life, player, ambient_states[1]):
        _fail("second Fine Food conversation failed")
        return
    if not events.event_complete or not coins.claimed_rewards.has("campus_event:lunch_rush") or coins.balance != 15:
        _fail("Lunch Rush did not grant its one-time 15-coin reward")
        return
    var lunch_balance: int = coins.balance
    _talk_to(life, player, ambient_states[2])
    if coins.balance != lunch_balance:
        _fail("completed Lunch Rush paid more than once")
        return

    # Rain Shelter: named story characters must not count toward ambient events.
    daily.set_game_time(15.0 * 60.0)
    weather.set_mode(3)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    if events.current_event_id != "rain_shelter":
        _fail("rain outside lunch did not activate Rain Shelter")
        return
    var shelter_position: Vector3 = Vector3.ZERO
    for spot_value in activities.spots:
        var spot: Dictionary = spot_value
        if str(spot.get("kind", "")) == "shelter":
            shelter_position = spot.get("position", Vector3.ZERO)
            break
    if shelter_position == Vector3.ZERO:
        _fail("existing covered shelter anchors are missing")
        return
    player.global_position = shelter_position
    if not _talk_to(life, player, story_states[0]):
        _fail("story NPC exclusion probe could not talk")
        return
    if events.event_progress != 0:
        _fail("a named story character incorrectly counted toward Rain Shelter")
        return
    if not _talk_to(life, player, ambient_states[2]) or events.event_progress != 1:
        _fail("first covered-shelter conversation did not count")
        return
    if not _talk_to(life, player, ambient_states[3]):
        _fail("second covered-shelter conversation failed")
        return
    if not events.event_complete or not coins.claimed_rewards.has("campus_event:rain_shelter"):
        _fail("Rain Shelter did not complete and persist its one-time reward")
        return
    if coins.balance != 33:
        _fail("Rain Shelter reward did not add exactly 18 coins")
        return

    # Evening Picnic: the event uses the existing Town Green picnic group anchors.
    daily.set_game_time(18.5 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    if events.current_event_id != "evening_picnic":
        _fail("18:30 in clear weather did not activate Evening Picnic")
        return
    if activities.picnic_groups.is_empty():
        _fail("existing Town Green picnic group anchors are missing")
        return
    var picnic: Dictionary = activities.picnic_groups[0]
    var picnic_positions: Array = picnic.get("positions", [])
    if picnic_positions.size() < 2:
        _fail("picnic group does not have two seats")
        return
    player.global_position = picnic_positions[0]
    if not _talk_to(life, player, ambient_states[4]) or events.event_progress != 1:
        _fail("first Town Green conversation did not count")
        return
    if not _talk_to(life, player, ambient_states[5]):
        _fail("second Town Green conversation failed")
        return
    if not events.event_complete or not coins.claimed_rewards.has("campus_event:evening_picnic"):
        _fail("Evening Picnic did not complete and persist its one-time reward")
        return
    if coins.balance != 53:
        _fail("all three campus events should award 53 coins in total")
        return

    daily.set_game_time(14.0 * 60.0)
    weather.set_mode(0)
    daily.refresh_schedule_context(true)
    events.refresh_event(true)
    if not events.current_event_id.is_empty() or not events.status_text().is_empty():
        _fail("campus event status remained visible outside all event windows")
        return

    print("PASS: M28 schedule windows, Q-talk zone checks, ambient/story isolation and three one-time rewards")
    game.queue_free()
    await process_frame
    quit(0)


func _talk_to(life: UTownCampusLife, player: UTownPlayer, target_state: Dictionary) -> bool:
    for index in range(life.pedestrians.size()):
        var state: Dictionary = life.pedestrians[index]
        var actor: Node3D = state.get("node") as Node3D
        if actor != null:
            actor.global_position = player.global_position + Vector3(90.0 + float(index) * 3.0, 0.0, 90.0)
    var target: Node3D = target_state.get("node") as Node3D
    if target == null:
        return false
    target.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
    return life.talk_to_nearest()
