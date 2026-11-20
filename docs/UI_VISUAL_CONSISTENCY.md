# UI visual consistency pass

This pass tightens the shared NUS-3D light-campus visual system without changing gameplay behavior.

## Shared rules
- All major glass panels use a common minimum 18 px corner radius, one-pixel neutral hairline, restrained five-pixel shadow and existing light surface opacity.
- `NUS3DUISkin.ink_for()` maps legacy pastel-on-dark label colors onto readable primary/secondary ink on light panels. Dark semantic colors remain intact.
- Semantic success, warning and error colors are centralized as `SUCCESS`, `WARNING` and `DANGER`; the accent remains muted teal.
- The small interaction keycap uses the same tactile keycap material as the HUD action rail.

## Harmonized surfaces
- Login/profile labels and profile toolbar width now follow the shared ink and viewport rules.
- Coursework, leisure, experience-guide and wardrobe labels use the same ink mapping.
- Wardrobe no longer creates an obsolete panel StyleBox and immediately overwrites it; duplicate label color overrides were removed.
- Leisure shortcut chip uses the shared muted-teal accent.
- Checkbox labels use the shared primary/disabled text colors and the same teal focus/hover cue.
- The contextual weather/life card is clipped to three lines with ellipsis, preventing long campus messages from expanding over other HUD elements.
- Arcade status placement now measures the weather panel’s rendered viewport-space bottom edge, so expanded weather content cannot overlap the arcade summary.
- Profile toolbar height/width are clamped to the viewport instead of overflowing narrow windows.

## Scope boundaries
No changes to authentication, local account data, mailbox behavior, wardrobe selections or outfit saves, coin prices/rewards, coursework progress, leisure game rules, hotkeys, network protocol, terrain, NPC logic or gameplay state.

## Validation
The soft-glass regression now checks common radius, primary/secondary ink mapping, preservation of semantic colors, and actual panel styles across HUD, profile, session, coursework, interaction guide, wardrobe, leisure, coin wallet and shop. It also verifies the leisure age-gate checkbox contrast. It also checks that legacy pastel helper labels resolve through the shared ink helper. The arcade smoke test checks that the status card clears an expanded weather panel.

Required CI: Godot 4.4.1 import, integrated UI smoke, bilingual regression, screenshots and cold-launch. This PR must not merge if any of these checks fail. Visual review at 960x540, 1280x720 and 1920x1080 is still required after CI. The login/account shell is intentionally left untouched because an older open login-redesign branch edits the same file; it should be reconciled separately rather than forcing overlapping changes.
