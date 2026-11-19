extends Node
class_name UTownWeather
## Offline weather presets layered over the project's artistic time-of-day settings.

const MODE_COUNT: int = 5
var names: PackedStringArray = PackedStringArray(["Clear", "Cloudy", "Overcast", "Rain", "Thunderstorm"])
var sky_colors: Array[Color] = [Color("#c6d8df"), Color("#e5c4a9"), Color("#607e9c"), Color("#243951")]
var ambient_colors: Array[Color] = [Color("#e8edf0"), Color("#ffddb3"), Color("#a3b9d0"), Color("#96afce")]
var sun_energy_by_time: PackedFloat32Array = PackedFloat32Array([1.0, 0.76, 0.32, 0.14])
var ambient_energy_by_time: PackedFloat32Array = PackedFloat32Array([0.78, 0.74, 0.56, 0.43])

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"

var mode: int = 0
var indoor: bool = false
var rain: GPUParticles3D
var rain_streaks: MultiMeshInstance3D
var rain_multimesh: MultiMesh
var rain_offsets: Array[Vector3] = []
var rain_speeds: PackedFloat32Array = PackedFloat32Array()
var clouds: Node3D
var puddle_root: Node3D
var puddle_nodes: Array[Node3D] = []
var puddle_ripples: Array[MeshInstance3D] = []
var wet_materials: Array[Dictionary] = []
var puddle_water_material: StandardMaterial3D
var puddle_ripple_material: StandardMaterial3D
var wetness: float = 0.0
var target_wetness: float = 0.0
var target_sky: Color = Color("#c6d8df")
var target_ambient: Color = Color("#e8edf0")
var target_sun: float = 1.0
var target_ambient_energy: float = 0.78
var target_fog: float = 0.0
var atmosphere_ready: bool = false
var flash: OmniLight3D
var flash_wait: float = 8.0
var flash_time: float = 0.0
var applied_lighting: int = -1

func _ready() -> void:
    _build_effects()
    _build_puddles()
    _register_wet_surfaces()
    _apply()

func mode_count() -> int:
    return MODE_COUNT

func set_mode(value: int) -> bool:
    if value < 0 or value >= MODE_COUNT:
        return false
    mode = value
    target_wetness = 1.0 if mode >= 3 else 0.0
    flash_wait = randf_range(5.0, 11.0)
    flash_time = 0.0
    _apply()
    return true

func cycle() -> void:
    set_mode((mode + 1) % MODE_COUNT)

func set_indoor(value: bool) -> void:
    indoor = value
    _refresh_effects()

func _register_wet_surfaces() -> void:
    wet_materials.clear()
    for material in world.weather_reactive_materials:
        wet_materials.append({
            "material": material,
            "color": material.albedo_color,
            "roughness": material.roughness,
            "metallic": material.metallic,
            "kind": "paving"
        })
    for material in world.weather_reactive_grass:
        wet_materials.append({
            "material": material,
            "color": material.albedo_color,
            "roughness": material.roughness,
            "metallic": material.metallic,
            "kind": "vegetation"
        })

func _advance_atmosphere(delta: float) -> void:
    var blend: float = clampf(delta * 1.35, 0.0, 1.0)
    world.sky_environment.background_color = world.sky_environment.background_color.lerp(target_sky, blend)
    world.sky_environment.ambient_light_color = world.sky_environment.ambient_light_color.lerp(target_ambient, blend)
    world.sky_environment.ambient_light_energy = lerpf(world.sky_environment.ambient_light_energy, target_ambient_energy, blend)
    world.sunlight.light_energy = lerpf(world.sunlight.light_energy, target_sun, blend)
    var current_fog: float = world.sky_environment.fog_density
    world.sky_environment.fog_density = lerpf(current_fog, target_fog, blend)
    world.sky_environment.fog_enabled = target_fog > 0.0001 or world.sky_environment.fog_density > 0.0001

    # Drying is intentionally slower than wetting; rain-darkened paving
    # gradually returns to the original project materials after a shower.
    var wetting_speed: float = 0.68 if target_wetness > wetness else 0.18
    wetness = move_toward(wetness, target_wetness, wetting_speed * delta)
    for reference in wet_materials:
        var material: StandardMaterial3D = reference["material"]
        var base_color: Color = reference["color"]
        if str(reference["kind"]) == "vegetation":
            # Wet tropical grass absorbs light; dry materials are restored exactly.
            material.albedo_color = base_color.lerp(Color("#42614e"), wetness * 0.52)
            material.roughness = lerpf(float(reference["roughness"]), 0.70, wetness)
            material.metallic = float(reference["metallic"])
        else:
            material.albedo_color = base_color.lerp(Color("#566f7c"), wetness * 0.42)
            material.roughness = lerpf(float(reference["roughness"]), 0.22, wetness)
            material.metallic = lerpf(float(reference["metallic"]), 0.12, wetness)
    if puddle_water_material != null:
        var water_color: Color = puddle_water_material.albedo_color
        water_color.a = 0.12 + wetness * 0.35
        puddle_water_material.albedo_color = water_color
    if puddle_ripple_material != null:
        var ripple_color: Color = puddle_ripple_material.albedo_color
        ripple_color.a = 0.08 + wetness * 0.38
        puddle_ripple_material.albedo_color = ripple_color
    puddle_root.visible = (mode >= 3 or wetness > 0.07) and not indoor

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

    # A deterministic MultiMesh rain curtain guarantees readable streaks in
    # low-end and software-rendered preview environments where GPU particles
    # can be visually sparse.
    rain_streaks = MultiMeshInstance3D.new()
    rain_streaks.name = "RainStreakMultiMesh"
    rain_multimesh = MultiMesh.new()
    rain_multimesh.transform_format = MultiMesh.TRANSFORM_3D
    var streak_mesh := BoxMesh.new()
    streak_mesh.size = Vector3(0.025, 0.58, 0.025)
    var streak_material := StandardMaterial3D.new()
    streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    streak_material.albedo_color = Color(0.72, 0.86, 0.98, 0.82)
    streak_material.emission_enabled = true
    streak_material.emission = Color(0.22, 0.3, 0.38)
    streak_material.emission_energy_multiplier = 0.25
    streak_mesh.material = streak_material
    rain_multimesh.mesh = streak_mesh
    rain_multimesh.instance_count = 220
    for i in range(rain_multimesh.instance_count):
        var offset := Vector3(randf_range(-16.0, 16.0), randf_range(-6.0, 14.0), randf_range(-16.0, 16.0))
        rain_offsets.append(offset)
        rain_speeds.append(randf_range(13.0, 19.0))
        rain_multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-8.0)), offset))
    rain_streaks.multimesh = rain_multimesh
    rain_streaks.visible = false
    add_child(rain_streaks)

    flash = OmniLight3D.new()
    flash.name = "StormFlash"
    flash.light_color = Color(0.72, 0.83, 1.0)
    flash.light_energy = 0.0
    flash.omni_range = 150.0
    flash.shadow_enabled = false
    add_child(flash)

func _build_puddles() -> void:
    puddle_root = Node3D.new()
    puddle_root.name = "ProceduralRainPuddles"
    add_child(puddle_root)
    var water := StandardMaterial3D.new()
    water.albedo_color = Color(0.48, 0.67, 0.75, 0.46)
    puddle_water_material = water
    water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water.metallic = 0.68
    water.roughness = 0.12
    water.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    var ripple_material := StandardMaterial3D.new()
    ripple_material.albedo_color = Color(0.78, 0.9, 0.95, 0.48)
    puddle_ripple_material = ripple_material
    ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ripple_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ripple_material.roughness = 0.16
    var walkways: Array = world.layout.get("walkways", [])
    for path_index in range(walkways.size()):
        var coordinates: Array = walkways[path_index].get("lonlat", [])
        if coordinates.size() < 2:
            continue
        var segment_index: int = mini(path_index % (coordinates.size() - 1), coordinates.size() - 2)
        var a_coords: Array = coordinates[segment_index]
        var b_coords: Array = coordinates[segment_index + 1]
        var a: Vector3 = world.lonlat_to_world(float(a_coords[0]), float(a_coords[1]))
        var b: Vector3 = world.lonlat_to_world(float(b_coords[0]), float(b_coords[1]))
        var direction: Vector3 = (b - a).normalized()
        var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
        var centre: Vector3 = a.lerp(b, 0.42) + side * (1.2 + float(path_index % 2) * 0.55)
        var puddle := Node3D.new()
        puddle.name = "Puddle_%02d" % path_index
        # Conceptual walkway top surface is y=0.113; keep shallow water above it.
        puddle.position = centre + Vector3(0.0, 0.145, 0.0)
        puddle_root.add_child(puddle)
        var pool := MeshInstance3D.new()
        var pool_mesh := CylinderMesh.new()
        pool_mesh.top_radius = 1.0
        pool_mesh.bottom_radius = 1.0
        pool_mesh.height = 0.018
        pool_mesh.radial_segments = 24
        pool.mesh = pool_mesh
        pool.scale = Vector3(1.45, 1.0, 0.72)
        pool.material_override = water
        puddle.add_child(pool)
        var ripple := MeshInstance3D.new()
        var ripple_mesh := TorusMesh.new()
        ripple_mesh.inner_radius = 0.34
        ripple_mesh.outer_radius = 0.38
        ripple_mesh.rings = 6
        ripple_mesh.ring_segments = 20
        ripple.mesh = ripple_mesh
        # TorusMesh is horizontal in XZ by default; do not rotate it upright.
        ripple.rotation.x = 0.0
        ripple.scale = Vector3(1.15, 1.0, 0.72)
        ripple.position.y = 0.025
        ripple.material_override = ripple_material
        puddle.add_child(ripple)
        puddle_nodes.append(puddle)
        puddle_ripples.append(ripple)
        # A smaller second pool along the same existing path needs no new GIS data.
        var second_pool: Node3D = puddle.duplicate()
        second_pool.name = "Puddle_%02d_Secondary" % path_index
        second_pool.position = a.lerp(b, 0.72) - side * 0.75 + Vector3(0.0, 0.145, 0.0)
        second_pool.scale = Vector3(0.72, 1.0, 0.64)
        puddle_root.add_child(second_pool)
        puddle_nodes.append(second_pool)
        var extra_ripple: MeshInstance3D = second_pool.get_child(1) as MeshInstance3D
        puddle_ripples.append(extra_ripple)

func _process(delta: float) -> void:
    if world.lighting_mode != applied_lighting:
        _apply()
    _advance_atmosphere(delta)
    if clouds != null:
        clouds.rotation.y += delta * 0.0018
    clouds.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
    for i in range(puddle_ripples.size()):
        var ripple: MeshInstance3D = puddle_ripples[i]
        ripple.rotation.y += delta * (0.22 + float(i % 3) * 0.08)
        var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.0018 + float(i)) * 0.045
        ripple.scale = Vector3(1.15 * pulse, 1.0, 0.72 * pulse)
    rain.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
    rain_streaks.global_position = player.global_position
    if mode >= 3 and not indoor:
        for i in range(rain_offsets.size()):
            var offset: Vector3 = rain_offsets[i]
            offset.y -= rain_speeds[i] * delta
            offset.x -= 1.15 * delta
            if offset.y < -6.0:
                offset.y = randf_range(10.0, 16.0)
                offset.x = randf_range(-16.0, 16.0)
                offset.z = randf_range(-16.0, 16.0)
            rain_offsets[i] = offset
            rain_multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-8.0)), offset))
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
    var sky: Color = sky_colors[t]
    var ambient: Color = ambient_colors[t]
    var sun_energy: float = sun_energy_by_time[t]
    var ambient_energy: float = ambient_energy_by_time[t]
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
    target_sky = sky
    target_ambient = ambient
    target_sun = sun_energy
    target_ambient_energy = ambient_energy
    target_fog = 0.0015 if mode == 2 else 0.0025 if mode >= 3 else 0.0
    if not atmosphere_ready:
        world.sky_environment.background_color = target_sky
        world.sky_environment.ambient_light_color = target_ambient
        world.sky_environment.ambient_light_energy = target_ambient_energy
        world.sky_environment.fog_density = target_fog
        world.sunlight.light_energy = target_sun
        atmosphere_ready = true
    world.sky_environment.fog_light_color = sky
    _refresh_effects()

func _refresh_effects() -> void:
    if clouds == null or rain == null:
        return
    clouds.visible = mode >= 1 and not indoor
    puddle_root.visible = (mode >= 3 or wetness > 0.07) and not indoor
    rain.visible = mode >= 3 and not indoor
    rain.emitting = mode >= 3 and not indoor
    rain_streaks.visible = mode >= 3 and not indoor
    if indoor:
        flash.light_energy = 0.0

func status_text() -> String:
    var condition: String = "Drying pavement" if mode < 3 and wetness > 0.07 else "Dry" if mode <= 2 else "Rain / wet ground" if mode == 3 else "Storm / wet ground"
    return "WEATHER  %s  |  %s  |  [Y] change" % [str(names[mode]).to_upper(), condition]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y:
        cycle()
