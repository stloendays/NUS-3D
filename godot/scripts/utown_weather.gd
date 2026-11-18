extends Node
class_name UTownWeather
## Offline weather presets layered over the project's artistic time-of-day settings.

const NAMES: PackedStringArray = PackedStringArray(["Clear", "Cloudy", "Overcast", "Rain", "Thunderstorm"])
const SKY: Array[Color] = [Color("#c6d8df"), Color("#e5c4a9"), Color("#607e9c"), Color("#243951")]
const AMBIENT: Array[Color] = [Color("#e8edf0"), Color("#ffddb3"), Color("#a3b9d0"), Color("#96afce")]
const SUN: PackedFloat32Array = PackedFloat32Array([1.0, 0.76, 0.32, 0.14])
const AMBIENT_ENERGY: PackedFloat32Array = PackedFloat32Array([0.78, 0.74, 0.56, 0.43])

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"

var mode: int = 0
var indoor: bool = false
var rain: GPUParticles3D
var clouds: Node3D
var flash: OmniLight3D
var flash_wait: float = 8.0
var flash_time: float = 0.0
var applied_lighting: int = -1

func _ready() -> void:
    _build_effects()
    _apply()

func set_mode(value: int) -> bool:
    if value < 0 or value >= NAMES.size():
        return false
    mode = value
    flash_wait = randf_range(5.0, 11.0)
    flash_time = 0.0
    _apply()
    return true

func cycle() -> void:
    set_mode((mode + 1) % NAMES.size())

func set_indoor(value: bool) -> void:
    indoor = value
    _refresh_effects()

func _build_effects() -> void:
    clouds = Node3D.new()
    clouds.name = "ProceduralClouds"
    add_child(clouds)
    var cloud_material := StandardMaterial3D.new()
    cloud_material.albedo_color = Color(0.78, 0.82, 0.84, 0.34)
    cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    cloud_material.roughness = 1.0
    for i in range(9):
        var cloud := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 1.0
        sphere.height = 2.0
        cloud.mesh = sphere
        cloud.material_override = cloud_material
        cloud.scale = Vector3(8.0 + float(i % 3) * 2.0, 1.35, 4.5 + float(i % 2))
        cloud.position = Vector3(float((i % 3) - 1) * 28.0, 28.0 + float(i % 2) * 2.0, float((i / 3) - 1) * 24.0)
        cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        clouds.add_child(cloud)

    rain = GPUParticles3D.new()
    rain.name = "RainParticles"
    rain.amount = 1100
    rain.lifetime = 1.15
    rain.local_coords = false
    var process_material := ParticleProcessMaterial.new()
    process_material.direction = Vector3(0.0, -1.0, 0.0)
    process_material.spread = 5.0
    process_material.initial_velocity_min = 15.0
    process_material.initial_velocity_max = 19.0
    process_material.gravity = Vector3(0.0, -9.8, 0.0)
    process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process_material.emission_box_extents = Vector3(19.0, 8.0, 19.0)
    rain.process_material = process_material
    var streak := QuadMesh.new()
    streak.size = Vector2(0.025, 0.42)
    var rain_material := StandardMaterial3D.new()
    rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rain_material.albedo_color = Color(0.68, 0.82, 0.95, 0.56)
    streak.material = rain_material
    rain.draw_pass_1 = streak
    add_child(rain)

    flash = OmniLight3D.new()
    flash.name = "StormFlash"
    flash.light_color = Color(0.72, 0.83, 1.0)
    flash.light_energy = 0.0
    flash.omni_range = 150.0
    flash.shadow_enabled = false
    add_child(flash)

func _process(delta: float) -> void:
    if world.lighting_mode != applied_lighting:
        _apply()
    clouds.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
    rain.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
    flash.global_position = player.global_position + Vector3(0.0, 22.0, 0.0)
    if mode == 4 and not indoor:
        flash_wait -= delta
        if flash_wait <= 0.0 and flash_time <= 0.0:
            flash_time = 0.16
            flash_wait = randf_range(6.0, 13.0)
        if flash_time > 0.0:
            flash_time = maxf(0.0, flash_time - delta)
            flash.light_energy = 5.5 if flash_time > 0.04 else 0.0
        else:
            flash.light_energy = 0.0
    else:
        flash.light_energy = 0.0
    _refresh_effects()

func _apply() -> void:
    var t: int = clampi(world.lighting_mode, 0, 3)
    applied_lighting = t
    var sky: Color = SKY[t]
    var ambient: Color = AMBIENT[t]
    var sun_energy: float = SUN[t]
    var ambient_energy: float = AMBIENT_ENERGY[t]
    match mode:
        1:
            sky = sky.lerp(Color("#aebbc3"), 0.24)
            ambient = ambient.lerp(Color("#c4cbd0"), 0.18)
            sun_energy *= 0.84
        2:
            sky = sky.lerp(Color("#8f9ca6"), 0.48)
            ambient = ambient.lerp(Color("#aeb9c2"), 0.32)
            sun_energy *= 0.68
            ambient_energy *= 0.88
        3:
            sky = sky.lerp(Color("#6f8292"), 0.62)
            ambient = ambient.lerp(Color("#91a2b0"), 0.45)
            sun_energy *= 0.48
            ambient_energy *= 0.78
        4:
            sky = sky.lerp(Color("#394a5d"), 0.76)
            ambient = ambient.lerp(Color("#788b9d"), 0.62)
            sun_energy *= 0.28
            ambient_energy *= 0.66
    world.sky_environment.background_color = sky
    world.sky_environment.ambient_light_color = ambient
    world.sky_environment.ambient_light_energy = ambient_energy
    world.sky_environment.fog_enabled = mode >= 2
    world.sky_environment.fog_light_color = sky
    world.sky_environment.fog_density = 0.0015 if mode == 2 else 0.0025 if mode >= 3 else 0.0
    world.sunlight.light_energy = sun_energy
    _refresh_effects()

func _refresh_effects() -> void:
    if clouds == null or rain == null:
        return
    clouds.visible = mode >= 1 and not indoor
    rain.visible = mode >= 3 and not indoor
    rain.emitting = mode >= 3 and not indoor
    if indoor:
        flash.light_energy = 0.0

func status_text() -> String:
    var condition: String = "Dry" if mode <= 2 else "Rain active" if mode == 3 else "Lightning possible"
    return "WEATHER  %s  |  %s  |  [Y] change" % [str(NAMES[mode]).to_upper(), condition]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y:
        cycle()
