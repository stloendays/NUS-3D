extends RefCounted
class_name UTownUIFont
## OS-provided CJK fonts only. No font binaries are included or distributed.
## On Windows, Microsoft YaHei is normally available; on Linux, Noto CJK
## can be installed by the user/distribution. GitHub visual CI installs Noto.

static func make_font() -> SystemFont:
    var font := SystemFont.new()
    font.font_names = PackedStringArray([
        "Noto Sans CJK SC",
        "Microsoft YaHei",
        "Microsoft JhengHei",
        "PingFang SC",
        "WenQuanYi Micro Hei",
        "Arial"
    ])
    return font

static func make_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font = make_font()
    theme.default_font_size = 14
    return theme
