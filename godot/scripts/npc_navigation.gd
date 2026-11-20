extends Node
class_name NUS3DNPCNavigation
## Small, cached A* grid for outdoor NPCs. Uses the same estimated building
## massing as UTownWorld; final motion still checks physical collisions.
const CELL: float = 4.0
const CLEARANCE: float = 1.4
const REPATH_SECONDS: float = 0.85
const ARRIVAL: float = 1.6
const MAX_GRID_CELLS: int = 40000
const STUCK_TIMEOUT: float = 1.25
const STUCK_MOVEMENT: float = 0.12
const MAX_STUCK_REPATHS: int = 3

@onready var campus: UTownCampusLife = $"../CampusLife"
@onready var world: UTownWorld = $"../World"
var grid: AStarGrid2D
var min_x: float
var min_z: float
var paths: Dictionary = {}
var last_goal: Dictionary = {}
var repath_at: Dictionary = {}
var repath_count: int = 0
var last_position: Dictionary = {}
var stuck_since: Dictionary = {}
var stuck_repaths: Dictionary = {}


func _ready() -> void:
    _build_grid()


func _build_grid() -> void:
    var extents: Array = world.layout.get("ground_size_m", [550, 800])
    min_x = -float(extents[0]) * 0.5
    min_z = -float(extents[1]) * 0.5
    var width: int = ceili(float(extents[0]) / CELL)
    var height: int = ceili(float(extents[1]) / CELL)
    if width * height > MAX_GRID_CELLS:
        push_warning("NPC grid too large; using collision-only navigation")
        return
    grid = AStarGrid2D.new()
    grid.region = Rect2i(0, 0, width, height)
    grid.cell_size = Vector2.ONE
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for raw in world.layout.get("buildings", []):
        var record: Dictionary = raw
        var base: Vector3 = world.lonlat_to_world(float(record.get("lon", world.origin_lon)), float(record.get("lat", world.origin_lat)))
        var angle: float = deg_to_rad(float(record.get("rotation_deg", 0.0)))
        for raw_piece in record.get("parts", []):
            var part: Dictionary = raw_piece
            var offset: Vector3 = Vector3(float(part.get("dx", 0.0)), 0, -float(part.get("dn", 0.0))).rotated(Vector3.UP, angle)
            var center: Vector3 = base + offset
            var half_w: float = float(part.get("w", 24.0)) * 0.5 + CLEARANCE
            var half_d: float = float(part.get("d", 24.0)) * 0.5 + CLEARANCE
            var radius: float = sqrt(half_w * half_w + half_d * half_d)
            var lo: Vector2i = _cell(center + Vector3(-radius, 0, -radius))
            var hi: Vector2i = _cell(center + Vector3(radius, 0, radius))
            for z in range(maxi(0, lo.y), mini(height - 1, hi.y) + 1):
                for x in range(maxi(0, lo.x), mini(width - 1, hi.x) + 1):
                    var p: Vector3 = _world(Vector2i(x, z))
                    var relative: Vector3 = (p - center).rotated(Vector3.UP, -angle)
                    if absf(relative.x) <= half_w and absf(relative.z) <= half_d:
                        grid.set_point_solid(Vector2i(x, z), true)


func _cell(position: Vector3) -> Vector2i:
    return Vector2i(floori((position.x - min_x) / CELL), floori((position.z - min_z) / CELL))


func _world(cell: Vector2i) -> Vector3:
    return Vector3(min_x + (float(cell.x) + 0.5) * CELL, 0, min_z + (float(cell.y) + 0.5) * CELL)


func _free_cell(origin: Vector2i) -> Vector2i:
    if grid == null:
        return origin
    if grid.is_in_boundsv(origin) and not grid.is_point_solid(origin):
        return origin
    for radius in range(1, 9):
        for z in range(origin.y - radius, origin.y + radius + 1):
            for x in range(origin.x - radius, origin.x + radius + 1):
                var candidate := Vector2i(x, z)
                if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
                    return candidate
    return origin


func next_target(name: String, from: Vector3, goal: Vector3, now: float) -> Vector3:
    if grid == null:
        return goal
    var previous: Vector3 = last_goal.get(name, Vector3(99999, 0, 99999))
    if now >= float(repath_at.get(name, 0.0)) or previous.distance_squared_to(goal) > 16.0:
        var start: Vector2i = _free_cell(_cell(from))
        var end: Vector2i = _free_cell(_cell(goal))
        var waypoints: Array[Vector3] = []
        if grid.is_in_boundsv(start) and grid.is_in_boundsv(end) and not grid.is_point_solid(start) and not grid.is_point_solid(end):
            var cells: Array[Vector2i] = grid.get_id_path(start, end)
            for i in range(1, cells.size()):
                waypoints.append(_world(cells[i]))
        paths[name] = waypoints
        last_goal[name] = goal
        repath_at[name] = now + REPATH_SECONDS
        repath_count += 1
    var path: Array = paths.get(name, [])
    # Waypoints are stored on the XZ plane; terrain elevation must not
    # prevent them from being consumed.
    while not path.is_empty() and Vector2(from.x, from.z).distance_squared_to(Vector2(path[0].x, path[0].z)) < ARRIVAL * ARRIVAL:
        path.pop_front()
    paths[name] = path
    if not path.is_empty():
        return path[0]
    # Never fall back to a straight line through a building when A* failed.
    var destination: Vector2i = _cell(goal)
    if grid.is_in_boundsv(destination) and not grid.is_point_solid(destination):
        return goal
    return from


func report_movement(name: String, before: Vector3, after: Vector3, now: float) -> void:
    # A collision-stalled NPC gets a fresh path from its actual position.
    # Rate limiting avoids expensive A* queries every physics frame.
    var horizontal_move: float = Vector2(before.x, before.z).distance_to(Vector2(after.x, after.z))
    if horizontal_move > STUCK_MOVEMENT:
        stuck_since.erase(name)
        stuck_repaths.erase(name)
        return
    if not stuck_since.has(name):
        stuck_since[name] = now
        return
    if now - float(stuck_since[name]) < STUCK_TIMEOUT:
        return
    stuck_since[name] = now
    repath_at[name] = 0.0
    stuck_repaths[name] = mini(int(stuck_repaths.get(name, 0)) + 1, MAX_STUCK_REPATHS)


func separation_offset(name: String, position: Vector3, neighbours: Array, radius: float = 1.35) -> Vector3:
    # Lightweight local steering; does not alter persistent NPC positions.
    var result := Vector3.ZERO
    for neighbour in neighbours:
        if str(neighbour.get("name", "")) == name:
            continue
        var other: Node3D = neighbour.get("node") as Node3D
        if other == null:
            continue
        var away: Vector3 = position - other.global_position
        away.y = 0.0
        var distance: float = away.length()
        if distance > 0.01 and distance < radius:
            result += away.normalized() * (1.0 - distance / radius)
    return result.limit_length(1.0)


func clear_path(name: String) -> void:
    paths.erase(name)
    last_goal.erase(name)
    repath_at.erase(name)
    stuck_since.erase(name)
    stuck_repaths.erase(name)


func move_safe(current: Vector3, desired: Vector3, delta: float) -> Vector3:
    # Use a short capsule sweep for collision safety even if the grid is approximate.
    var displacement: Vector3 = desired - current
    displacement.y = 0.0
    if displacement.length_squared() < 0.000001:
        return current
    var shape := SphereShape3D.new()
    shape.radius = 0.48
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = Transform3D(Basis.IDENTITY, current + Vector3.UP * 0.95)
    query.motion = displacement
    query.collision_mask = 1
    query.collide_with_areas = false
    var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
    var travel: PackedFloat32Array = space.cast_motion(query)
    var fraction: float = clampf(float(travel[0]) if travel.size() > 0 else 0.0, 0.0, 1.0)
    var limited: Vector3 = current + displacement * maxf(0.0, fraction - 0.04)
    if fraction <= 0.05:
        return current
    var grounded: Vector3 = campus.npc_ground_position(current, limited, delta)
    # Never cross a cliff or staircase too tall for this lightweight walker.
    if absf(grounded.y - current.y) > campus.NPC_STEP_HEIGHT:
        return current
    return grounded
