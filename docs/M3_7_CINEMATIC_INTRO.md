# M3.7 — 12-second cinematic opening / 入场动画

**Project:** NUS-3D UTown comedy prototype. This is original scripted animation in Godot 4.4.1; no prerendered movie, official logos or recorded campus footage.

## What plays on launch?

1. **Town Green fly-in (0–3 s)** — camera approaches the schematic green with a big NUS-3D title, fan-made disclaimer and welcome message.
2. **ERC coursework crisis (3–6 s)** — camera glides to the conceptual ERC exterior while fictional group-project dialogue appears.
3. **SRC DDL alarm (6–9 s)** — faster angled camera move with mock submission failure and 23:59 deadline subtitles.
4. **Town Plaza to gameplay (9–12 s)** — the player is invited to choose a faculty and begin the 39-chapter Coursework comedy.

Six camera keyframes are smoothly interpolated from the four existing UTown schematic walking-route points. Shot positions are artistic offsets, not survey coordinates. No real faculty deadlines are represented.

The cinema-style overlay features a live progress bar, changeable captions, letterboxing and opacity fades. All effects are authored entirely in Godot: no third-party images, downloaded audio or imported video.

## Accessibility and skipping

- The intro plays once at every game launch. Skip at any time with Space, Esc, Enter, left mouse-click anywhere, or the top-right 跳过 button.
- Gameplay keypresses and mouse-look are swallowed while the cinematic camera is current.
- Player movement and the fictional DDL timer pause during the intro.
- If the player has not selected a faculty, the film hands off to the first-run faculty picker.
- If there is a saved faculty, the intro returns to the original first-person camera and resumed progress.
- Changing faculty later never automatically replays the intro.

The opening camera does not physically move the player, alter spawn, task progress, weather, exploration inventory or saved school.

## Implementation and test files

- godot/scripts/utown_intro.gd — animated 3D camera, four story beats and 2D overlay.
- godot/scenes/main.tscn — introductory node after gameplay and faculty UI.
- godot/scripts/utown_coursework_ui.gd — suspends and restores the first-run selector.
- godot/tests/smoke_test.gd — tests playback, a mid-story beat, skip and camera/faculty handoff.
- godot/scripts/export_self_test.gd — checks packaged cinema resources on Windows.
- godot/tests/render_viewpoints.gd — captures four real Godot viewpoint images of the introduction.

Manual GUI verification is still needed for skip controls, captions, camera visual continuity and smooth 720p/1080p performance on real Windows GPUs. Tests do not establish real-world site precision or official campus endorsement.
