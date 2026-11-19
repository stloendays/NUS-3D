extends RefCounted
class_name NUS3DCartoonSkin
## Simple, original campus-comedy UI. No external textures or branded characters.
## Limited palette, solid shapes, chunky borders, and minimal shadows.

const INK: Color = Color("#30333B")
const MUTED: Color = Color("#626670")
const PAPER: Color = Color("#FFF9ED")
const SKY: Color = Color("#98C9DE")
const GRASS: Color = Color("#B4D494")
const YELLOW: Color = Color("#F7CA55")
const BLUE: Color = Color("#C2E1EB")
const LIGHT: Color = Color("#FFFFFF")
const ERROR: Color = Color("#BA5747")


static func panel(fill: Color = PAPER, radius: int = 16, padding: int = 18) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = fill
    s.border_color = INK
    s.set_border_width_all(3)
    s.set_corner_radius_all(radius)
    s.content_margin_left = padding
    s.content_margin_right = padding
    s.content_margin_top = padding
    s.content_margin_bottom = padding
    s.shadow_color = Color(0.18, 0.24, 0.29, 0.27)
    s.shadow_size = 0
    s.shadow_offset = Vector2(4, 5)
    s.anti_aliasing = true
    return s


static func button(control: Button, is_primary: bool = false) -> void:
    control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    control.custom_minimum_size.y = maxf(36.0, control.custom_minimum_size.y)
    var normal: StyleBoxFlat = panel(YELLOW if is_primary else LIGHT, 10, 7)
    normal.set_border_width_all(2)
    normal.content_margin_left = 11
    normal.content_margin_right = 11
    normal.shadow_offset = Vector2(2, 3)
    var hover: StyleBoxFlat = panel(Color("#FFE29A") if is_primary else BLUE, 10, 7)
    hover.set_border_width_all(2)
    hover.content_margin_left = 11
    hover.content_margin_right = 11
    hover.shadow_offset = Vector2(2, 3)
    var pressed: StyleBoxFlat = panel(Color("#E9B847") if is_primary else Color("#D1E4E8"), 10, 7)
    pressed.set_border_width_all(2)
    pressed.content_margin_left = 11
    pressed.content_margin_right = 11
    pressed.shadow_offset = Vector2.ZERO
    var disabled: StyleBoxFlat = panel(Color("#DEDEDB"), 10, 7)
    disabled.set_border_width_all(2)
    control.add_theme_stylebox_override("normal", normal)
    control.add_theme_stylebox_override("hover", hover)
    control.add_theme_stylebox_override("pressed", pressed)
    control.add_theme_stylebox_override("hover_pressed", pressed)
    control.add_theme_stylebox_override("disabled", disabled)
    var focus: StyleBoxFlat = panel(Color.TRANSPARENT, 10, 0)
    focus.border_color = Color("#4B7BB4")
    focus.shadow_offset = Vector2.ZERO
    control.add_theme_stylebox_override("focus", focus)
    control.add_theme_color_override("font_color", INK)
    control.add_theme_color_override("font_hover_color", INK)
    control.add_theme_color_override("font_pressed_color", INK)
    control.add_theme_color_override("font_focus_color", INK)
    control.add_theme_color_override("font_disabled_color", MUTED)
    control.add_theme_font_size_override("font_size", 14)


static func field(control: Control) -> void:
    var base: StyleBoxFlat = panel(LIGHT, 9, 8)
    base.set_border_width_all(2)
    base.shadow_offset = Vector2.ZERO
    var focused: StyleBoxFlat = panel(Color("#F4FCFE"), 9, 8)
    focused.set_border_width_all(2)
    focused.border_color = Color("#4B7BB4")
    focused.shadow_offset = Vector2.ZERO
    control.add_theme_stylebox_override("normal", base)
    control.add_theme_stylebox_override("focus", focused)
    control.add_theme_stylebox_override("read_only", base)
    control.add_theme_color_override("font_color", INK)
    control.add_theme_color_override("font_placeholder_color", MUTED)
    control.add_theme_color_override("caret_color", INK)
    control.add_theme_color_override("font_readonly_color", MUTED)
    if control is LineEdit:
        control.custom_minimum_size.y = maxf(40.0, control.custom_minimum_size.y)
