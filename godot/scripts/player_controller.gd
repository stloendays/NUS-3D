extends CharacterBody3D
class_name UTownPlayer
## Simple offline first-person controller, metres/second.
## Player origin is at foot level; camera height is defined by the scene.

const GRAVITY: float = 21.0
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const BICYCLE_SPEED: float = 13.0
const JUMP_SPEED: float = 4.7
const MOUSE_SENSITIVITY: float = 0.0023
const SPAWN: Vector3 = Vector3(0.0, 0.18, 0.0)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var bicycle_mode: bool = false
var movement_locked: bool = false
var camera_target_position: Vector3 = Vector3.ZERO
var camera_target_rotation: Vector3 = Vector3.ZERO
var camera_target_fov: float = 78.0

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    floor_snap_length = 0.25
    camera_target_position = camera.position
    camera_target_rotation = camera.rotation
    camera_target_fov = camera.fov

func set_bicycle_mode(enabled: bool) -> void:
    bicycle_mode = enabled
    camera_target_position = Vector3(0.0, 0.35, 4.0) if enabled else Vector3.ZERO
    camera_target_rotation = Vector3(-0.18, 0.0, 0.0) if enabled else Vector3.ZERO
    camera_target_fov = 84.0 if enabled else 78.0

func _process(delta: float) -> void:
    if camera == null:
        return
    var blend: float = clampf(delta * 6.5, 0.0, 1.0)
    camera.position = camera.position.lerp(camera_target_position, blend)
    camera.rotation = camera.rotation.lerp(camera_target_rotation, blend)
    camera.fov = lerpf(camera.fov, camera_target_fov, blend)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.48, 1.48)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        elif event.keycode == KEY_R:
            reset_player()

func _physics_process(delta: float) -> void:
    if movement_locked:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    var forward_axis: float = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    var strafe_axis: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
    var input_vector: Vector2 = Vector2(strafe_axis, forward_axis).normalized()
    var direction: Vector3 = (global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
    var speed: float = BICYCLE_SPEED if bicycle_mode else RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
    var crowds: UTownDiningCrowds = get_parent().get_node_or_null("DiningCrowds") as UTownDiningCrowds
    if crowds != null and not bicycle_mode and not Input.is_key_pressed(KEY_SHIFT):
        speed *= crowds.player_slowdown
    var target_x: float = direction.x * speed
    var target_z: float = direction.z * speed
    if bicycle_mode:
        velocity.x = move_toward(velocity.x, target_x, 18.0 * delta)
        velocity.z = move_toward(velocity.z, target_z, 18.0 * delta)
    else:
        velocity.x = target_x
        velocity.z = target_z

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_physical_key_pressed(KEY_SPACE) and not bicycle_mode:
        velocity.y = JUMP_SPEED
    else:
        velocity.y = -0.1

    move_and_slide()
    if global_position.y < -12.0:
        reset_player()

func reset_player() -> void:
    # Restore campus-life state before respawning, otherwise R can leave
    # the player physically outside while UI/weather still think they are indoors.
    var life: UTownCampusLife = get_parent().get_node_or_null("CampusLife") as UTownCampusLife
    if life != null:
        if life.on_shuttle:
            life.alight_shuttle()
        if life.interior_active:
            life.exit_interior()
        if life.bicycle_enabled:
            life.set_bicycle(false)
    global_position = SPAWN
    velocity = Vector3.ZERO
    rotation = Vector3.ZERO
    head.rotation = Vector3.ZERO
    movement_locked = false
    head.position.y = 1.66
    set_bicycle_mode(false)
