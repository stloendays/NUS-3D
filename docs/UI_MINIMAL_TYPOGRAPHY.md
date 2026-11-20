# Minimal UI / typography pass

Scope: common UI skin, HUD and shared system-font fallback. The visual direction is warm off-white, charcoal text, muted teal accents, thin neutral borders, reduced shadows and a consistent CJK-capable sans-serif hierarchy.

- System font fallback prioritizes Noto Sans CJK SC, Noto Sans, PingFang SC and Microsoft YaHei UI. No font binaries are distributed.
- Common panels and keycaps have quieter borders and shadows; the same existing functions and theme override names remain in place.
- HUD uses one accent color instead of separate bright colors per card. Title is 17 px; nearby label is 12 px; existing controls, shortcut help, language behavior and feedback logic remain.
- No gameplay, save, account, network, NPC or terrain code changes.

Validation required before merge: Godot parse/import, screenshot review at 1280x720 and 1920x1080, English and Chinese fallback font check, F1 help and F11 settings overlay, button hover/focus contrast, low-spec rendering. This is a focused first pass, not yet a full UI redesign of every menu.
