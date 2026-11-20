# Coin shop and wallet UI polish

This isolated UI pass styles the existing wallet card and coin shop with the shared neutral NUS3D UI skin. It adds viewport-aware width/height bounds for both panels and separates current balance from owned pass counts for easier reading.

**Conflict scope:** Only `godot/scripts/utown_coins.gd` is changed for runtime behavior. The UI PR chain (#86, #88, #89, #92, #93) is the base; this PR does not edit HUD, login, profile, mailbox, wardrobe, leisure, coursework UI, terrain or multiplayer files.

**Behavior contracts preserved:** coin prices, purchase IDs, eligibility checks, pass counts, reward values, ConfigFile path/schema, save/load functions, shop hotkey O, pickup hotkey Z and delivery hotkey N are unchanged. No inventory schema migration or new currency items.

Validation pending: Godot 4.4 parse/import; open/close O; buy each item with enough/insufficient balance; confirm pass counts and save/reload; F6 map visibility interaction; 960x540, 1280x720 and 1920x1080; Chinese/English text overflow. The source smoke test checks code hooks only, not actual rendering.
