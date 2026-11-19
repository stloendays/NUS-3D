extends Node
class_name UTownVisualPolish
## M3.5 original low-poly material/light finishing. All layouts are conceptual.
## Deliberately avoids imported textures, real campus branding and expensive shaders.

@onready var world: UTownWorld = $"../World"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var weather: UTownWeather = $"../Weather"

var facade_groups: Array[Node3D] = []
var facade_panes: int = 0
var indoor_finish_groups: Dictionary = {}
var indoor_lamps: Dictionary = {}
var glass_materials: Dictionary = {}
var facade_lamps: Array[OmniLight3D] = []
var material_panel_count: int = 0
var active_room_id: String = ""

func _ready() -> void:
    _finish_facades()
    _finish_rooms()
    _update_lights(0.5)

func _mat(hex: String, roughness: float = 0.7, metalness: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex)
    m.roughness = roughness
    m.metallic = metalness
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = Color.html(hex)
        m.emission_energy_multiplier = glow
    return m

func _panel(parent: Node3D, name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = at
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(mesh)
    material_panel_count += 1
    return mesh

func _finish_facades() -> void:
    # Attach to F2-toggleable M2 architecture layers; M1 comparison stays intact.
    for record in world.layout.get("buildings", []):
        if str(record.get("priority", "")) != "P0":
            continue
        var identifier: String = str(record.get("id", ""))
        var main: Node3D = world.get_node_or_null("BuildingMassing_Estimated/%s/ArchitecturalStudy_NotSurveyed" % identifier) as Node3D
        if main == null:
            continue
        var finish := Node3D.new()
        finish.name = "M35ArchitecturalMaterialStudy"
        main.add_child(finish)
        facade_groups.append(finish)
        var parts: Array = record.get("parts", [])
        var frames := _mat("#566d77", 0.38, 0.42)
        var glass := _mat("#385769", 0.22, 0.18)
        var glint := _mat("#86b5c7", 0.27, 0.22)
        var canopies := _mat("#d6d4c8", 0.75, 0.12)
        var concrete := _mat("#c4c8bf", 0.89, 0.0)
        var light_strip := _mat("#ecd9b1", 0.48, 0.1, 0.6)
        for part_index in range(parts.size()):
            var part: Dictionary = parts[part_index]
            var wing := Node3D.new()
            wing.name = "MaterialWing_%d" % part_index
            wing.position = Vector3(float(part.get("dx", 0.0)), 0.0, -float(part.get("dn", 0.0)))
            finish.add_child(wing)
            var w: float = float(part.get("w", 30.0))
            var d: float = float(part.get("d", 25.0))
            var h: float = float(part.get("h", 12.0))
            # Facade overlays have no physics. They are game materials, not surveys.
            _panel(wing, "RoofParapetFront", Vector3(0, h + 0.43, d * 0.5), Vector3(w + 0.8, 0.38, 0.20), concrete)
            _panel(wing, "RoofParapetSide", Vector3(w * 0.5, h + 0.43, 0), Vector3(0.2, 0.38, d + 0.8), concrete)
            var bays: int = clampi(int(w / 5.0), 4, 9)
            var levels: int = clampi(int(h / 3.6), 2, 4)
            for floor_index in range(levels):
                var y: float = 2.35 + float(floor_index) * 3.45
                if y + 0.9 >= h:
                    continue
                for bay in range(bays):
                    var x: float = -w * 0.5 + (float(bay) + 0.5) * w / float(bays)
                    var depth: float = d * 0.5 + 0.34
                    var half_span: float = w / float(bays) * 0.42
                    _panel(wing, "PBRGlazing_%d_%d" % [floor_index, bay],
                        Vector3(x, y, depth), Vector3(half_span * 2.0, 1.25, 0.07), glass if bay % 3 != 0 else glint)
                    facade_panes += 1
                    _panel(wing, "AluminiumMullion", Vector3(x - half_span, y, depth + 0.04),
                        Vector3(0.075, 1.39, 0.13), frames)
                _panel(wing, "ContinuousSill", Vector3(0, y - 0.72, d * 0.5 + 0.42),
                    Vector3(w * 0.92, 0.07, 0.24), frames)
            _panel(wing, "EntranceCanopyUnderside", Vector3(0, 3.08, d * 0.5 + 1.08),
                Vector3(minf(16.0, w * 0.55), 0.09, 2.3), canopies)
            _panel(wing, "WarmEntranceEdge", Vector3(0, 3.025, d * 0.5 + 2.22),
                Vector3(minf(14.0, w * 0.50), 0.06, 0.11), light_strip)
            if part_index == 0:
                var light := OmniLight3D.new()
                light.name = identifier + "_EntranceAccent"
                light.position = wing.to_global(Vector3(0, 2.85, d * 0.5 + 1.25))
                # Light is parented to finish, so convert global to local.
                light.position = finish.to_local(light.position)
                light.light_color = Color.html("#f2d4ac")
                light.omni_range = 11.0
                light.light_energy = 0.0
                light.shadow_enabled = false
                finish.add_child(light)
                facade_lamps.append(light)

func _finish_rooms() -> void:
    for id in ["ERC", "SRC"]:
        if not life.interiors.has(id):
            continue
        var room: Node3D = life.interiors[id]
        var finish := Node3D.new()
        finish.name = "M35SurfaceAndLighting"
        room.add_child(finish)
        indoor_finish_groups[id] = finish
        var tile := _mat("#8b9d99" if id == "ERC" else "#536f7b", 0.63, 0.06)
        var grout := _mat("#405962" if id == "ERC" else "#324f5a", 0.93)
        var wood := _mat("#9b7555", 0.72)
        var aluminium := _mat("#546875", 0.35, 0.40)
        var glass := _mat("#729aa8", 0.28, 0.16)
        glass_materials[id] = glass
        var linen := _mat("#d5c29f" if id == "ERC" else "#a5b9bf", 0.80)
        # Floor grout lines read as inexpensive material detail without a
        # texture import or extra collision; avoid the entrance centre aisle.
        for x in [-9.4, -6.2, -3.0, 3.0, 6.2, 9.4]:
            for z in [-6.5, -2.6, 1.3, 5.2]:
                _panel(finish, "StoneFloorTile", Vector3(x, 0.023, z), Vector3(2.75, 0.024, 3.55), tile)
        for z in [-8.4, -6.4, -2.1, 2.2, 6.3]:
            _panel(finish, "TransitionInlay", Vector3(0, 0.037, z),
                Vector3(2.45, 0.015, 0.045), grout)
        # Timber/aluminium cladding beside the seating bays.
        for wall_side in [-1.0, 1.0]:
            for strip_index in range(6):
                _panel(finish, "RibbedInteriorWall", Vector3(wall_side * 11.70, 2.28,
                    -7.4 + float(strip_index) * 2.85),
                    Vector3(0.12, 2.65, 0.13), wood if strip_index % 2 == 0 else aluminium)
        for upper_x in [-7.5, -3.0, 3.0, 7.5]:
            _panel(finish, "MezzanineAcousticPanel", Vector3(upper_x, 5.25, -8.73),
                Vector3(2.6, 0.85, 0.07), linen)
        for z in [-6.0, -1.0, 4.0]:
            _panel(finish, "UpperGlazedAccent", Vector3(11.72, 4.65, z),
                Vector3(0.07, 1.15, 2.9), glass)
            _panel(finish, "UpperGlazedEdge", Vector3(11.65, 4.65, z),
                Vector3(0.06, 1.20, 0.09), aluminium)
        # Accent lighting uses cheap non-shadow lamps plus one shadowed
        # nearby pool, enabled only for the currently visited room.
        var lights: Array[OmniLight3D] = []
        for n in range(3):
            var lamp := OmniLight3D.new()
            lamp.name = "M35BounceAccent_%d" % n
            lamp.position = Vector3(-6.0 + 6.0 * float(n), 3.5 if n < 2 else 5.45,
                2.2 if n < 2 else -6.0)
            lamp.light_color = Color.html("#f6d9ae" if id == "ERC" else "#cae7ff")
            lamp.omni_range = 8.0
            lamp.light_energy = 0.0
            lamp.shadow_enabled = n == 0
            lamp.visible = false
            finish.add_child(lamp)
            lights.append(lamp)
        indoor_lamps[id] = lights

func _process(delta: float) -> void:
    _update_lights(delta)

func _update_lights(delta: float) -> void:
    if life == null or weather == null or world == null:
        return
    active_room_id = life.active_interior if life.interior_active else ""
    var daytime: bool = world.lighting_mode == 0
    var rainy: bool = weather.mode >= 3
    var night_factor: float = 0.32 if world.lighting_mode >= 2 else 0.0
    var storm_factor: float = 0.18 if rainy else 0.0
    var blend: float = clampf(delta * 3.0, 0.0, 1.0)
    for id in indoor_lamps:
        var interior_active: bool = active_room_id == str(id)
        var lights: Array[OmniLight3D] = indoor_lamps[id]
        for light in lights:
            light.visible = interior_active
            var intensity: float = 0.60 + night_factor + storm_factor if interior_active else 0.0
            light.light_energy = lerpf(light.light_energy, intensity, blend)
    for lamp in facade_lamps:
        var target: float = 0.0 if daytime and not rainy else 0.48 if rainy else 0.74
        lamp.light_energy = lerpf(lamp.light_energy, target, blend)
    for id in glass_materials:
        var glass: StandardMaterial3D = glass_materials[id]
        glass.roughness = lerpf(glass.roughness, 0.36 if rainy else 0.27, blend)
        glass.albedo_color = glass.albedo_color.lerp(
            Color.html("#526e7c" if rainy else "#729aa8"), blend)
