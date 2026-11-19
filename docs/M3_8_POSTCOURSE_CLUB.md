# M3.8 — Post-Course Club / 完成 Coursework 后的休闲玩法

**Status:** original, entirely fictional offline Godot 4.4.1 content. No real NUS venue, game-money stakes, real drinks or students are implied.

## Unlock and progression

Finish all three Coursework chapters in any single selected faculty to permanently unlock the Post-Course Club. Press P while on foot to open it. The unlock remains after switching faculties, derived from existing per-faculty saved coursework progress; no separate paid entitlement or account exists.

Finish all 39 chapters across thirteen academic roleplay options for the additional cosmetic "校园休闲大师 / All Faculty Master" label. This is not required to access the club.

Original Coursework, Field Notes, Sprint, bus, bicycle, weather and world exploration remain. The leisure menu pauses the fictional DDL countdown like the existing journal.

## Three playable activities

| Activity | Gameplay | Saving |
|---|---|---|
| 五子棋 / Gomoku | Interactive 9 by 9 board. Player plays black, NPC plays white. Five contiguous stones horizontally, vertically or diagonally win. NPC responds and recognizes immediate wins/blocks. Rematches at any time. | Games and wins |
| 打牌 / Cards | Five-round high-card duel. Player receives five cards from a shuffled 52-card deck and chooses one each round. NPC uses a concealed hand. Higher rank wins; equal ranks tie. No wagering. | Matches and wins |
| 下课后聚会 / Social | Choose a mocktail, tea/juice or an optional adult toast. The same fictional comedy dialogue rotates for every beverage, and none offers an academic reward. | Visit count only |

**No betting:** there are no wagers, paid purchases, gambling services, cash exchanges or prize redemptions. Chess/card statistics are separate from coursework XP and credits.

**Optional adult social choice:** all content is available with non-alcoholic beverages. The fictional adult toast requires an in-session declaration that the player is of legal drinking age for their location; that declaration is never saved. The alcoholic option gives no XP, additional credits or exclusive dialogue. Bicycle and shuttle boarding are temporarily blocked after it. This is not real-life drinking advice or a blood-alcohol simulator.

## In-world dressing

The conceptual SRC lounge gets a procedural Gomoku table, card table, drinks counter and signs. Props are decorative and non-colliding, appear only after unlocking, and do not replace original SRC NPCs or navigation.

## Controls

- P opens or closes the unlocked club while the player is on foot.
- Esc closes the club and restores mouse-look.
- Use mouse clicks for chess moves, card selection, drink options and rematches.
- O/J retain their original faculty selector and coursework journal behavior but do not open through this modal.
- F7 photo mode hides the small unlocked-club prompt with the rest of the HUD.

## Source, persistence and QA

- godot/scripts/utown_leisure.gd — unlock conditions, 9 by 9 chess and NPC AI, five-round cards, social choices, 3D club props.
- godot/scripts/utown_leisure_ui.gd — interactive modal, game tabs and optional adult checkbox.
- godot/scenes/main.tscn — leisure nodes in the existing scene.
- godot/scripts/utown_campus_life.gd — limited transport restriction after adult social scene.
- godot/tests/smoke_test.gd — tests locked/unlocked states, chess winner and AI, card rounds, nonalcoholic option, age confirmation, save/reload and faculty switching.
- godot/scripts/export_self_test.gd plus Windows CI — checks gameplay/UI assets packaged with the actual executable.
- godot/tests/render_viewpoints.gd — real in-engine screenshots for all three tabs.

Only an anonymous game statistics file at user://nus3d_leisure.cfg is written: games, wins and social visits. No ages, emails, payment information, drinks history or accounts are recorded.

Manual Windows GUI QA is still required for glyph coverage, cursor focus, layout on smaller windows, skill balance, 3D prop placement and controller behavior.
