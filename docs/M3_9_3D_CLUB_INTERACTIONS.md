# M3.9 — Walk-up 3D club, seated opponents and replay epilogue

**Status:** original Godot 4.4.1 offline game content; the SRC club is an imagined UTown space, not an actual NUS venue or floor plan.

## The 3D club is no longer a remote menu

M3.8 unlocked three minigames on pressing P from anywhere. M3.9 changes **where** they begin, but **not the unlock**:

- Finish all three fictional Coursework chapters of **any one faculty**. Unlock is permanent even after changing your faculty; all prior M3.8 saves remain valid.
- Go inside the standalone **SRC illustrated interior** via I, and stay on the ground floor. You can now see three separate lightweight room stations: a wooden Gomoku table, the card table and the social counter.
- **Walk next to a station** (approx. 2.9 game metres from its designated player-side space) and press **P**. The corresponding playable panel opens, with the player safely paused. Switching to a distant table requires closing the menu and walking to it.
- Contextual, small light rings and the HUD's proximity prompt replace obnoxious permanent direction signs. P outside the SRC room, on another floor or too far away does not open the minigame; instead an in-world message explains where to go.
- A table companion sits at each station. These are original non-colliding low-poly NPCs, not real students. They idle, move their arms and react to match outcomes.
- The physical Gomoku board now displays actual black/white pieces synchronized to completed game moves. The card table shows the last card duel result. Decorative chair backs, legs and table supports add depth; no new solid blockers are placed in old SRC circulation routes.

## More satisfying matches

- Victory and defeat trigger a brief seated-NPC reaction. Win and epilogue events also show a UI-scale pop and lightweight, original particle-style rectangles in 19 colors/positions.
- Seven original **procedurally synthesized audio cues** (move, card play, win tone, loss tone, social toast, ending tone and short synthetic clap/cheer layer). No music or third-party copyrighted sound recordings.
- A **SFX ON/OFF** toggle in the club header works without an online service, streaming or new persistent setting.
- The party scene still offers equivalent non-alcoholic social choices. Its optional, age-confirmed adult toast has no extra XP or club reward; temporary game transport restrictions and no sensitive drink/age data storage are preserved.

## Replayable hidden epilogue

After earning **two Gomoku wins**, **one card match win** and **one social visit**, a secret story control appears in the social station. Its three original comic beats cover a mysterious promise not to assign homework, the discovery that the promise is from last term, and the next DDL alert. The progress of the three beats is saved locally, while the story remains replayable once completed.

**True ending:** finish all 39 fictional Coursework chapters and reveal the last secret story beat for an extended final line and cosmetic all-faculty master acknowledgment. Neither secret route requires selecting alcohol or winning real money.

## Persistence and backward compatibility

- No save migrations: the game continues to read the original Coursework file and M3.8 anonymous gameplay statistics at `user://nus3d_leisure.cfg`.
- New save fields: `ending_seen` and `ending_line_index`. Older saves omit them and automatically load safe defaults. No name, birthday, location, consumption history or payment information is written.
- The original exploration challenges, NPC dialogue, campus weather, buses, bicycle, first-run faculty choice and 12-second introduction remain unchanged.

## Code and verification

- godot/scripts/utown_leisure.gd — walking-range checks, physical 3D stations, seated opponents, board visuals, animations and epilogue state
- godot/scripts/utown_leisure_ui.gd — proximity-specific full screen game, celebration animation, cue toggle and ending button
- godot/scripts/utown_leisure_audio.gd — single-run in-memory PCM synthesis for original tonal cues and synthetic cheering
- godot/scenes/main.tscn — audio child node under LeisureUI, no extra scene transitions
- godot/tests/smoke_test.gd — rejects remote opening, validates walking into SRC/changing tables, checks model pieces, NPCs, audio, saved results, secret story and original age/travel rules
- godot/scripts/export_self_test.gd and Windows CI — require the three stations, three seated NPCs, seven cues, 19 win animation sprites and hidden story UI
- godot/tests/render_viewpoints.gd — screenshots of actual SRC game-space, real 3D pieces, win overlay, each game and the hidden epilogue

Manual graphical testing is still required to evaluate table readability, camera positions, seating collision appearance, font support, sound comfort, framerate at 720p/1080p and player movement around the SRC stations. Automated Linux software-rendered screenshots are not a substitute for Windows GPU testing.
