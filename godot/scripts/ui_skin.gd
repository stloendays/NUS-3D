extends RefCounted
class_name NUS3DUISkin
## Soft-light system for NUS-3D: original iOS-inspired visual language, not
## Apple UI assets. StyleBoxFlat only; no backbuffer blur or shader passes.
## Readable dark type, translucent white surfaces, restrained blue/teal accents.

const TEXT: Color = Color("#26343B")
const DIM: Color = Color("#64727A")
const ACCENT: Color = Color("#397E91")
const TEAL: Color = Color("#397E91")
const WARM: Color = Color("#BA9160")
const SURFACE: Color = Color(0.98, 0.985, 0.984, 0.94)
const SURFACE_SOLID: Color = Color("#FAFBFA")
const SURFACE_MUTED: Color = Color("#F0F3F2")
const HAIRLINE: Color = Color(0.61, 0.74, 0.78, 0.52)
const BACKDROP: Color = Color(0.70, 0.79, 0.84, 0.48)

static func panel(background: Color, accent: Color = ACCENT, radius: int = 20, margin: int = 14) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = Color("#D7DFDF")
    style.set_border_width_all(1)
    style.border_width_top = 1
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin
    style.content_margin_bottom = margin
    style.shadow_color = Color(0.10, 0.16, 0.18, 0.09)
    style.shadow_size = 5
    style.shadow_offset = Vector2(0, 2)
    style.anti_aliasing = true
    return style

static func glass(accent: Color = ACCENT, radius: int = 23, margin: int = 17,
        dense: bool = false) -> StyleBoxFlat:
    # Slightly more opaque than real iOS glass, for contrast over moving 3D.
    return panel(Color(0.985, 0.99, 0.987, 0.96 if dense else 0.92),
        accent, radius, margin)

static func keycap(pressed: bool = false, highlighted: bool = false) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = (Color("#DCE9E9") if pressed else
        Color("#FFFFFF") if highlighted else Color("#F1F5F4"))
    style.border_color = (Color("#98B8BB") if pressed else
        Color("#DAE5E4") if highlighted else Color("#D8E2E1"))
    style.set_border_width_all(1)
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0.14, 0.32, 0.42, 0.15)
    style.shadow_size = 1 if pressed else 3
    style.shadow_offset = Vector2(0, 1 if pressed else 4)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 3
    style.content_margin_bottom = 3
    style.anti_aliasing = true
    return style

static func button(control: Button) -> void:
    control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 40.0)
    var normal: StyleBoxFlat = keycap()
    normal.content_margin_left = 14
    normal.content_margin_right = 14
    var hover: StyleBoxFlat = keycap(false, true)
    hover.content_margin_left = 14
    hover.content_margin_right = 14
    var down: StyleBoxFlat = keycap(true)
    down.content_margin_left = 14
    down.content_margin_right = 14
    control.add_theme_stylebox_override("normal", normal)
    control.add_theme_stylebox_override("hover", hover)
    control.add_theme_stylebox_override("pressed", down)
    control.add_theme_stylebox_override("hover_pressed", down)
    var focus: StyleBoxFlat = panel(Color.TRANSPARENT, ACCENT, 13, 0)
    focus.shadow_size = 0
    control.add_theme_stylebox_override("focus", focus)
    var disabled: StyleBoxFlat = panel(Color("#E6EAED"), Color("#C2C9CC"), 13, 9)
    disabled.shadow_size = 0
    control.add_theme_stylebox_override("disabled", disabled)
    control.add_theme_color_override("font_color", TEXT)
    control.add_theme_color_override("font_hover_color", Color("#126B8A"))
    control.add_theme_color_override("font_pressed_color", Color("#145B70"))
    control.add_theme_color_override("font_disabled_color", Color("#8F9FA8"))
    control.add_theme_font_size_override("font_size", 14)

static func field(control: Control) -> void:
    var base: StyleBoxFlat = panel(Color("#F2F8FA"), Color("#B4CCD4"), 13, 11)
    base.shadow_size = 2
    base.shadow_offset = Vector2(0, 1)
    var focused: StyleBoxFlat = panel(Color("#FFFFFF"), ACCENT, 13, 11)
    focused.border_width_top = 2
    focused.shadow_size = 5
    focused.shadow_color = Color(0.12, 0.43, 0.52, 0.12)
    control.add_theme_stylebox_override("normal", base)
    control.add_theme_stylebox_override("focus", focused)
    control.add_theme_stylebox_override("read_only", base)
    control.add_theme_color_override("font_color", TEXT)
    control.add_theme_color_override("font_placeholder_color", DIM)
    control.add_theme_color_override("caret_color", ACCENT)
    if control is LineEdit:
        control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 41.0)
