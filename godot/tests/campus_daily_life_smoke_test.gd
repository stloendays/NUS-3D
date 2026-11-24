extends SceneTree
## M27 contract: clock, lunch scheduling, weather shelters, personality profiles and occupancy.

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("M27 campus daily life: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene could not load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    await process_frame

    var daily: NUS3DCampusDailyLife = game.get_node_or_null("CampusDailyLife") as NUS3DCampusDailyLife
    var activities: NUS3DCampusAmbientActivities = game.get_node_or_null("CampusAmbientActivities") as NUS3DCampusAmbientActivities
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    var world: UTownWorld = game.get_node_or_null("World") as UTownWorld
    if daily == null or activities == null or life == null or weather == null or world == null:
        _fail("daily-life clock or existing campus systems did not load")
        return
    if life.pedestrians.size() != 24:
        _fail("the existing 24-person outdoor roster changed")
        return

    var profiles: Dictionary = {}
    var ambient_states: Array[Dictionary] = []
    var story_states: Array[Dictionary] = []
    for state_value in life.pedestrians:
        var state: Dictionary = state_value
        if bool(state.get("ambient", false)):
            ambient_states.append(state)
            var profile: String = str(state.get("routine_profile", ""))
            profiles[profile] = int(profiles.get(profile, 0)) + 1
        else:
            story_states.append(state)
    if ambient_states.size() != 18 or story_states.size() != 6:
        _fail("ambient/story NPC separation changed")
        return
    if profiles.size() != 6:
        _fail("ambient NPC personality profile distribution is incomplete")
        return

    var eat_spots: Array[Dictionary] = activities._available_spots("eat")
    var queue_spots: Array[Dictionary] = activities._available_spots("queue")
    var shelter_spots: Array[Dictionary] = activities._available_spots("shelter")
    if eat_spots.size() < 16 or queue_spots.size() < 9 or shelter_spots.size() < 5:
        _fail("food-court seating, stall queues or covered shelter anchors are missing")
        return
    if activities.occupancy_multimesh == null or activities.occupancy_multimesh.instance_count != activities.spots.size():
        _fail("facility occupancy markers were not built from the live spot registry")
        return

    daily.set_game_time(12.0 * 60.0)
    if not daily.is_lunch_peak() or not activities.lunch_peak or activities.activity_limit() != 10:
        _fail("12:00 did not activate the lunch rush schedule and larger crowd cap")
        return
    if world.lighting_mode != 0:
        _fail("midday clock did not preserve daylight lighting")
        return

    var foodie: Dictionary = {}
    for state in ambient_states:
        if str(state.get("routine_profile", "")) == "foodie":
            foodie = state
            break
    if foodie.is_empty() or not activities._start_next_single_activity(foodie, Time.get_ticks_msec() / 1000.0):
        _fail("food-focused ambient NPC could not start a lunch routine")
        return
    if str(foodie.get("activity_kind", "")) not in ["queue", "eat"]:
        _fail("lunch schedule did not route a foodie to the stall queue or dining seats")
        return
    if str(foodie.get("activity_area", "")) != "fine_food":
        _fail("lunch activity was not anchored to the existing Town Plaza food court")
        return
    activities.update_occupancy_markers(true)
    var occupied_index: int = -1
    for index in range(activities.spots.size()):
        if str(activities.spots[index]["id"]) == str(foodie.get("activity_spot_id", "")):
            occupied_index = index
            break
    if occupied_index < 0:
        _fail("active lunch routine did not reserve its facility")
        return
    if activities.occupancy_multimesh.get_instance_color(occupied_index).r < 0.8:
        _fail("reserved facility still reports the free state")
        return

    daily.set_game_time(17.0 * 60.0)
    if daily.is_lunch_peak() or world.lighting_mode != 1:
        _fail("17:00 did not switch to the evening lighting band")
        return
    daily.set_game_time(18.5 * 60.0)
    if world.lighting_mode != 2:
        _fail("18:30 did not switch to blue hour")
        return
    daily.set_game_time(20.0 * 60.0)
    if world.lighting_mode != 3:
        _fail("20:00 did not switch to evening lighting")
        return

    world.set_lighting_mode(2)
    daily._process(0.016)
    if absf(daily.game_minutes - 1110.0) > 0.1:
        _fail("manual [T] lighting change did not synchronize the campus clock")
        return

    daily.set_game_time(15.0 * 60.0)
    weather.set_mode(3)
    daily.refresh_schedule_context(true)
    if activities.weather_mode != 3:
        _fail("rain state was not propagated to ambient routines")
        return
    var shelter_state: Dictionary = ambient_states[4]
    if not activities._start_next_single_activity(shelter_state, Time.get_ticks_msec() / 1000.0):
        _fail("ambient pedestrian could not reserve a rain shelter")
        return
    if str(shelter_state.get("activity_kind", "")) != "shelter":
        _fail("rain did not redirect the pedestrian toward a covered campus location")
        return
    if str(shelter_state.get("activity_area", "")) not in ["fine_food", "flavours"]:
        _fail("rain shelter is not anchored to an existing covered food-court/awning area")
        return

    for state in story_states:
        if str(state.get("activity_mode", "walk")) != "walk":
            _fail("daily schedule modified a named story character")
            return
    activities._cancel_state(foodie, Time.get_ticks_msec() / 1000.0 + 2.0)
    activities._cancel_state(shelter_state, Time.get_ticks_msec() / 1000.0 + 2.0)
    print("PASS: M27 clock, lunch crowd, personality routines, rain shelter and occupancy state")
    game.queue_free()
    quit(0)
