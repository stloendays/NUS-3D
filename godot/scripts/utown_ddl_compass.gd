extends Control
class_name UTownDDLCompass
## Short-lived in-HUD wayfinding pulse. Never creates a world-space sign or arrow.
## Angle is relative to the player's heading; only drawn while focus is requested.

var bearing_radians: float = 0.0
var distance_metres: float = 0.0
var opacity: float = 0.0

func update_ping(bearing: float, distance_m: float, alpha: float) -> void:
    bearing_radians = bearing
    distance_metres = maxf(0.0, distance_m)
    opacity = clampf(alpha, 0.0, 1.0)
    visible = opacity > 0.01
    if visible:
        queue_redraw()

func _draw() -> void:
    if opacity <= 0.01:
        return
    var c: Vector2 = Vector2(size.x * 0.5, 37.0)
    var ink: Color = Color(0.96, 0.94, 0.84, opacity)
    var subtle: Color = Color(0.15, 0.20, 0.22, opacity * 0.79)
    draw_circle(c, 31.0, subtle)
    draw_arc(c, 24.0, -PI * 0.5, PI * 1.5, 36, Color(1.0, 0.93, 0.72, opacity * 0.72), 1.7, true)
    draw_circle(c, 2.6, ink)
    # Camera-forward is up. The pointer uses a local 2-D rotation, not a 3-D signpost.
    var forward: Vector2 = Vector2(sin(bearing_radians), -cos(bearing_radians))
    var sideways: Vector2 = Vector2(-forward.y, forward.x)
    var tip: Vector2 = c + forward * 19.0
    var tail: Vector2 = c - forward * 8.0
    draw_colored_polygon(PackedVector2Array([tip, c - forward * 6.0 + sideways * 6.0, tail, c - forward * 6.0 - sideways * 6.0]), ink)
    var metres_label: String = "%.0f m" % distance_metres
    draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 30.0, 83.0), metres_label, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12, ink)
