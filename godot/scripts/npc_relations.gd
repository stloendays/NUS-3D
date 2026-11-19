extends Node
class_name NUS3DNPCRelations
## Fictional slapstick rivalry. Only named outdoor NPCs have reputation.
## No health/damage, no modifications to quests, account data or global player controls.

signal affinity_changed(character_name: String, value: int)

const SAVE_PATH := "user://nus3d_npc_relations.cfg"
const MIN_AFFINITY := -100
const MAX_AFFINITY := 100
const CHASE_THRESHOLD := -35
const STOP_THRESHOLD := -15
const CHASE_RADIUS := 25.0
const LEASH_RADIUS := 38.0
const CHASE_SPEED := 4.4
const TAG_DISTANCE := 1.6
const TAG_COOLDOWN := 6.0
const PERSONALITIES := {"Maya": "outgoing", "Ethan": "proud", "Aisha": "patient", "Lucas": "competitive", "Mei": "friendly", "Daniel": "reserved"}

@onready var campus: UTownCampusLife = $"../CampusLife"
@onready var player: UTownPlayer = $"../Player"
var affinity: Dictionary = {}
var last_tag: Dictionary = {}
var cooldown: Dictionary = {}
var notice: Label


func _ready() -> void:
    _load()
    var layer := CanvasLayer.new()
    layer.layer = 22
    add_child(layer)
    notice = Label.new()
    notice.position = Vector2(24, 115)
    notice.add_theme_font_size_override("font_size", 19)
    notice.add_theme_color_override("font_color", Color.html("#f5b7a6"))
    layer.add_child(notice)
    campus.talked_to.connect(_on_talked)


func _load() -> void:
    var file := ConfigFile.new()
    if file.load(SAVE_PATH) != OK:
        return
    for name in PERSONALITIES.keys():
        affinity[name] = clampi(int(file.get_value("affinity", name, 0)), MIN_AFFINITY, MAX_AFFINITY)


func _save() -> void:
    var file := ConfigFile.new()
    for name in PERSONALITIES.keys():
        file.set_value("affinity", name, int(affinity.get(name, 0)))
    if file.save(SAVE_PATH) != OK:
        push_warning("NPC relations could not be saved.")


func get_affinity(character_name: String) -> int:
    return int(affinity.get(character_name, 0))


func change_affinity(character_name: String, amount: int) -> void:
    if not PERSONALITIES.has(character_name):
        return
    affinity[character_name] = clampi(get_affinity(character_name) + amount, MIN_AFFINITY, MAX_AFFINITY)
    _save()
    affinity_changed.emit(character_name, get_affinity(character_name))


func _on_talked(character_name: String) -> void:
    if not PERSONALITIES.has(character_name):
        return
    var mood: int = get_affinity(character_name)
    if mood < CHASE_THRESHOLD:
        notice.text = "%s is furious! Run or apologize [U]." % character_name
    else:
        change_affinity(character_name, 2)
        notice.text = "%s  |  affinity %+d  |  [T] tease  [U] apologize" % [character_name, get_affinity(character_name)]


func _closest_name() -> String:
    var closest: float = 6.0
    var result: String = ""
    for state in campus.pedestrians:
        var npc: Node3D = state["node"]
        var distance: float = npc.global_position.distance_to(player.global_position)
        if distance < closest:
            closest = distance
            result = str(state["name"])
    return result


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    var name: String = _closest_name()
    if name.is_empty():
        return
    if event.keycode == KEY_T:
        var personality: String = str(PERSONALITIES.get(name, ""))
        change_affinity(name, -25 if personality == "proud" else -18)
        notice.text = "You teased %s. Affinity: %+d" % [name, get_affinity(name)]
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_U:
        change_affinity(name, 12)
        notice.text = "%s accepted your apology. Affinity: %+d" % [name, get_affinity(name)]
        get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
    if player == null or campus == null or campus.interior_active:
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    var chasing: int = 0
    for state in campus.pedestrians:
        var name: String = str(state["name"])
        var npc: Node3D = state["node"]
        var distance: float = npc.global_position.distance_to(player.global_position)
        var hostile: bool = bool(state.get("hostile", false))
        if hostile and (get_affinity(name) >= STOP_THRESHOLD or distance > LEASH_RADIUS):
            state["hostile"] = false
            hostile = false
        elif not hostile and get_affinity(name) <= CHASE_THRESHOLD and distance < CHASE_RADIUS:
            state["hostile"] = true
            hostile = true
        if not hostile:
            continue
        chasing += 1
        var toward: Vector3 = player.global_position - npc.global_position
        toward.y = 0.0
        if toward.length() > TAG_DISTANCE:
            var step: float = minf(CHASE_SPEED * delta, toward.length() - TAG_DISTANCE)
            npc.global_position += toward.normalized() * step
            npc.look_at(npc.global_position + toward, Vector3.UP)
            var gait: float = sin(now * 12.0)
            (state["left_leg"] as Node3D).rotation.x = gait * 0.8
            (state["right_leg"] as Node3D).rotation.x = -gait * 0.8
        elif now >= float(last_tag.get(name, 0.0)) + TAG_COOLDOWN:
            last_tag[name] = now
            # Harmless slapstick tag: a little screen shake via head rotation,
            # never changes health, player position, missions or inventory.
            var head: Node3D = player.get_node_or_null("Head")
            if head != null:
                var original: float = head.rotation.z
                head.rotation.z = original + 0.12
                var tween := create_tween()
                tween.tween_property(head, "rotation:z", original, 0.25)
            notice.text = "%s caught you! Campus rivalry continues..." % name
    if chasing > 0 and notice.text.is_empty():
        notice.text = "Angry students nearby! [U] apologize"
