extends Node3D
class_name NUS3DRemotePlayers
## Cosmetic-only remote avatars. No camera, physics, rewards or local input.
const MAX_DISTANCE: float = 110.0
var avatars: Dictionary = {}
var targets: Dictionary = {}


func add_player(peer_id: int, display_name: String) -> void:
    if avatars.has(peer_id):
        return
    var root: Node3D = Node3D.new()
    root.name = "Peer_%d" % peer_id
    var color: Color = Color.from_hsv(fposmod(float(peer_id) * 0.173, 1.0), 0.48, 0.84)
    var shirt: StandardMaterial3D = StandardMaterial3D.new()
    shirt.albedo_color = color
    var skin: StandardMaterial3D = StandardMaterial3D.new()
    skin.albedo_color = Color("#dfb796")
    var torso: MeshInstance3D = MeshInstance3D.new()
    var torso_shape: CapsuleMesh = CapsuleMesh.new()
    torso_shape.radius = 0.29
    torso_shape.height = 1.0
    torso.mesh = torso_shape
    torso.position.y = 1.08
    torso.material_override = shirt
    root.add_child(torso)
    var head: MeshInstance3D = MeshInstance3D.new()
    var head_shape: SphereMesh = SphereMesh.new()
    head_shape.radius = 0.23
    head.mesh = head_shape
    head.position.y = 1.78
    head.material_override = skin
    root.add_child(head)
    var label: Label3D = Label3D.new()
    label.text = display_name.left(20)
    label.position.y = 2.25
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    label.pixel_size = 0.012
    label.outline_size = 5
    label.no_depth_test = false
    root.add_child(label)
    add_child(root)
    avatars[peer_id] = root


func remove_player(peer_id: int) -> void:
    if avatars.has(peer_id):
        (avatars[peer_id] as Node).queue_free()
        avatars.erase(peer_id)
    targets.erase(peer_id)


func clear_players() -> void:
    for peer_id in avatars.keys():
        remove_player(peer_id)


func update_pose(peer_id: int, position: Vector3, yaw: float) -> void:
    if not avatars.has(peer_id):
        return
    var avatar: Node3D = avatars[peer_id]
    if not targets.has(peer_id):
        avatar.position = position
        avatar.rotation.y = yaw
    targets[peer_id] = {"position": position, "yaw": yaw}


func _process(delta: float) -> void:
    var camera: Camera3D = get_viewport().get_camera_3d()
    for peer_id in avatars:
        var avatar: Node3D = avatars[peer_id]
        if not targets.has(peer_id):
            avatar.visible = false
            continue
        var state: Dictionary = targets[peer_id]
        var goal: Vector3 = state["position"]
        if avatar.position.distance_to(goal) > 18.0:
            avatar.position = goal
        else:
            avatar.position = avatar.position.lerp(goal, clampf(delta * 12.0, 0.0, 1.0))
        avatar.rotation.y = lerp_angle(avatar.rotation.y, float(state["yaw"]), clampf(delta * 12.0, 0.0, 1.0))
        avatar.visible = camera != null and camera.global_position.distance_to(avatar.global_position) <= MAX_DISTANCE
