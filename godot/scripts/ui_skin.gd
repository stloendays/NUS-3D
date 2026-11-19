extends RefCounted
class_name NUS3DUISkin
## Reusable low-cost beveled HUD, dialog and keycap styling. No texture assets.

const TEXT: Color = Color("#eff9fc")
const DIM: Color = Color("#a2bdc8")
const ACCENT: Color = Color("#79e3dc")

static func panel(background: Color, accent: Color = ACCENT, radius: int = 13, margin: int = 13) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = accent.darkened(0.35)
    style.set_border_width_all(1)
    style.border_width_top = 2
    style.set_corner_radius_all(radius)
    style.content_margin_left = margin
    style.content_margin_right = margin
    style.content_margin_top = margin
    style.content_margin_bottom = margin
    style.shadow_color = Color(0.01, 0.035, 0.055, 0.63)
    style.shadow_size = 10
    style.shadow_offset = Vector2(0, 5)
    style.anti_aliasing = true
    return style

static func keycap(pressed: bool = false, highlighted: bool = false) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = Color("#356474") if pressed else Color("#294451") if highlighted else Color("#1e333f")
    s.border_color = Color("#8ef4e6") if pressed else Color("#7da9b5")
    s.border_width_left = 1
    s.border_width_right = 1
    s.border_width_top = 2 if not pressed else 1
    s.border_width_bottom = 3 if not pressed else 1
    s.set_corner_radius_all(7)
    s.shadow_color = Color(0.015, 0.04, 0.055, 0.78)
    s.shadow_size = 3 if pressed else 5
    s.shadow_offset = Vector2(0, 1 if pressed else 4)
    s.content_margin_left = 5
    s.content_margin_right = 5
    s.content_margin_top = 2
    s.content_margin_bottom = 2
    return s

static func button(control: Button) -> void:
    control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 39.0)
    var base: StyleBoxFlat = keycap()
    base.content_margin_left = 13
    base.content_margin_right = 13
    var hover: StyleBoxFlat = keycap(false, true)
    hover.content_margin_left = 13
    hover.content_margin_right = 13
    var down: StyleBoxFlat = keycap(true)
    down.content_margin_left = 13
    down.content_margin_right = 13
    control.add_theme_stylebox_override("normal", base)
    control.add_theme_stylebox_override("hover", hover)
    control.add_theme_stylebox_override("pressed", down)
    control.add_theme_stylebox_override("hover_pressed", down)
    control.add_theme_stylebox_override("focus", panel(Color.TRANSPARENT, ACCENT, 8, 0))
    control.add_theme_stylebox_override("disabled", panel(Color("#18242b"), Color("#40525b"), 8, 8))
    control.add_theme_color_override("font_color", TEXT)
    control.add_theme_color_override("font_hover_color", Color.WHITE)
    control.add_theme_color_override("font_pressed_color", Color("#d4fff6"))
    control.add_theme_color_override("font_disabled_color", Color("#6f8590"))
    control.add_theme_font_size_override("font_size", 14)

static func field(control: Control) -> void:
    var base: StyleBoxFlat = panel(Color("#132a35"), Color("#63838d"), 8, 9)
    base.shadow_size = 2
    base.shadow_offset = Vector2(0, 2)
    var focused: StyleBoxFlat = panel(Color("#163441"), ACCENT, 8, 9)
    focused.border_width_top = 2
    focused.shadow_size = 4
    control.add_theme_stylebox_override("normal", base)
    control.add_theme_stylebox_override("focus", focused)
    control.add_theme_stylebox_override("read_only", base)
    control.add_theme_color_override("font_color", TEXT)
    control.add_theme_color_override("font_placeholder_color", DIM)
    control.add_theme_color_override("caret_color", ACCENT)
    if control is LineEdit:
        control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 40.0)
