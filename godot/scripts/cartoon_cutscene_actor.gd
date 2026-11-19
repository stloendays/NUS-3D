extends Node3D
class_name NUS3DCartoonActor
## Tiny Godot-native character, same sphere-head/capsule-body language as campus NPCs.
## Only used inside an isolated cutscene SubViewport.

var body: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var head: Node3D
var base_y: float = 0.0


func _material(hex: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = 0.9
    return material


func _capsule(parent: Node3D, position_value: Vector3, radius: float, height: float, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    var shape := CapsuleMesh.new()
    shape.radius = radius
    shape.height = height
    mesh.mesh = shape
    mesh.position = position_value
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)


func _sphere(parent: Node3D, position_value: Vector3, radius: float, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = radius
    mesh.mesh = shape
    mesh.position = position_value
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)


func _ready() -> void:
    body = Node3D.new()
    add_child(body)
    var shirt := _material("#77a6b7")
    var trousers := _material("#37485e")
    var skin := _material("#e4b393")
    var ink := _material("#263443")
    _capsule(body, Vector3(0, 1.0, 0), 0.27, 1.02, shirt)
    head = Node3D.new()
    head.position.y = 1.71
    body.add_child(head)
    _sphere(head, Vector3.ZERO, 0.23, skin)
    for x in [-0.085, 0.085]:
        _sphere(head, Vector3(x, 0.03, 0.215), 0.027, ink)
    left_arm = Node3D.new()
    left_arm.position = Vector3(-0.33, 1.32, 0)
    body.add_child(left_arm)
    _capsule(left_arm, Vector3(0, -0.3, 0), 0.10, 0.64, shirt)
    right_arm = Node3D.new()
    right_arm.position = Vector3(0.33, 1.32, 0)
    body.add_child(right_arm)
    _capsule(right_arm, Vector3(0, -0.3, 0), 0.10, 0.64, shirt)
    left_leg = Node3D.new()
    left_leg.position = Vector3(-0.14, 0.65, 0)
    body.add_child(left_leg)
    _capsule(left_leg, Vector3(0, -0.28, 0), 0.12, 0.64, trousers)
    right_leg = Node3D.new()
    right_leg.position = Vector3(0.14, 0.65, 0)
    body.add_child(right_leg)
    _capsule(right_leg, Vector3(0, -0.28, 0), 0.12, 0.64, trousers)


func pose(kind: String, phase: int, duration: float) -> Tween:
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var lean: float = 0.0
    var rise: float = 0.0
    var arm_angle: float = 0.0
    var leg_angle: float = 0.0
    match kind:
        "campus_hero", "loop_breaker":
            arm_angle = -2.3
            rise = 0.23 if phase == 2 else 0.05
        "ddl_survivor":
            arm_angle = -1.8 if phase == 2 else 0.8
            rise = 0.18 if phase == 2 else 0.0
        "burnout":
            lean = -1.15 if phase == 2 else -0.2 * (phase + 1)
            arm_angle = 1.0
        "integrity_alarm":
            arm_angle = -2.5
            lean = 0.20 if phase % 2 == 0 else -0.20
        "ddl_blackhole":
            lean = -0.7 if phase == 2 else -0.15
            arm_angle = -0.9
        _:
            arm_angle = 0.0
    if phase == 0:
        leg_angle = 0.55
    tween.tween_property(body, "rotation:z", lean, duration)
    tween.tween_property(body, "position:y", base_y + rise, duration)
    tween.tween_property(left_arm, "rotation:x", arm_angle, duration)
    tween.tween_property(right_arm, "rotation:x", -arm_angle, duration)
    tween.tween_property(left_leg, "rotation:x", leg_angle, duration)
    tween.tween_property(right_leg, "rotation:x", -leg_angle, duration)
    tween.tween_property(head, "rotation:z", -lean * 0.22, duration)
    return tween
