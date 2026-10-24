extends CharacterBody3D
## Simple offline first-person controller, metres/second.
## Player origin is at foot level; camera height is defined by the scene.

const GRAVITY: float = 21.0
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const JUMP_SPEED: float = 4.7
const MOUSE_SENSITIVITY: float = 0.0023
const SPAWN: Vector3 = Vector3(0.0, 0.18, 0.0)

@onready var head: Node3D = $Head

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    floor_snap_length = 0.25

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
    var forward_axis: float = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    var strafe_axis: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
    var input_vector: Vector2 = Vector2(strafe_axis, forward_axis).normalized()
    var direction: Vector3 = (global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
    var speed: float = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif Input.is_physical_key_pressed(KEY_SPACE):
        velocity.y = JUMP_SPEED
    else:
        velocity.y = -0.1

    move_and_slide()
    if global_position.y < -12.0:
        reset_player()

func reset_player() -> void:
    global_position = SPAWN
    velocity = Vector3.ZERO
    rotation = Vector3.ZERO
    head.rotation = Vector3.ZERO
