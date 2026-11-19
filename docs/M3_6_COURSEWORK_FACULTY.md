# M3.6 — Faculty choice and Coursework: The DDL Apocalypse

**Status:** Offline, original comedy-game content. School/faculty labels are inspiration for roleplay, not real admissions, actual NUS modules, real deadlines, transcripts, student login, course records, campus directions, or university endorsements.

## First-run faculty choice

At first launch, a full-screen selector offers 13 named colleges / schools / faculties (including cross-disciplinary college options). Players confirm a choice before walking. Choose with the dropdown, then click **进入学院 / START THE DDL CHAOS**. At any later point, press **O** to change the faculty; each faculty's unfinished chapter and its countdown are separately preserved.

Available roleplay options (names based on NUS's AY2026/27 public academic-unit listings; quest content is wholly fictional):

| Option | Short |
|---|---|
| Faculty of Science | FoS |
| College of Design and Engineering | CDE |
| School of Computing | SoC |
| NUS Business School | Biz |
| Faculty of Arts and Social Sciences | FASS |
| College of Humanities and Sciences | CHS |
| Yong Loo Lin School of Medicine | Medicine |
| Faculty of Law | Law |
| Faculty of Dentistry | Dentistry |
| Yong Siew Toh Conservatory of Music | Music |
| NUS College | NUSC |
| Saw Swee Hock School of Public Health | SPH |
| Lee Kuan Yew School of Public Policy | LKYSPP |

**NUS College and CHS have cross-disciplinary academic roles**; the in-game chooser is a gameplay affiliation, not an assertion that these programmes constitute mutually exclusive real-world enrolment categories. Future releases may offer additional options without changing the stable save schema.

## 39 original coursework stories

Every choice has a separate original 3-chapter story. All chapters have a four-stage physical quest loop:

1. **K — Brief pickup:** find the floating golden fictional homework marker at a previously modeled schematic waypoint; accept the lecturer's very urgent message
2. **F — Activity:** enter an ERC or SRC concept interior with **I**; approach the target study/cafe/sport/gallery activity and interact using the existing **F** key
3. **Q — Groupmate:** talk to a named fictional NPC in the room using the existing **Q** action; cannot advance by talking to an unrelated NPC
4. **K — Submit:** return to the designated campus waypoint and submit before the game clock expires; graded submission awards XP and campus credits

Example story hooks include "编译器吃掉了作业", "Git Merge Conflict：队友失踪", "烧杯的复仇", "PPT 有 200 页但没人写结论", and "4000 字论文：最后一个标点". These are **fictional humor**, not real NUS module titles.

The first chapter grants 210 **gameplay** seconds once briefed, followed by 300 and 390 second chapters. An on-screen count, direction prompt and deadline journal update during play. If a player misses the deadline, the quest remains completable but gives a lower, late-submission reward; there is **no hard fail or academic penalty**. The game is intended to be humorous and stress-relieving.

### Grade and progress

- Before the deadline, submissions receive original-game grades **S** (with 40%+ of timer remaining) or **A**.
- After the deadline, submissions receive **C (Late)** but still finish and advance.
- XP, campus credits and **Coursework level** increase with chapter completion; this progression is independent of the existing exploration/sprint loops and does not alter any external account or official academic data.
- When all three chapters are completed in a faculty, the original school storyline ends; choose another one to continue. Switching does not wipe a previous faculty's completed chapters.

## On-screen controls

| Input | Behavior |
|---|---|
| O | Select/change faculty; first launch opens chooser automatically |
| J | Coursework journal: chapter, story, countdown, XP/level and grades |
| K | Accept a nearby brief or submit at the marked campus terminal |
| F | Complete the highlighted fictional indoor activity step |
| Q | Talk to the correct groupmate NPC for the active course |
| I / L | Enter the illustrative ERC/SRC interior / change floor |
| Esc | Close journal; initial faculty selection must be confirmed |

The gold book/ripple marker indicates the current exterior campus target. It follows the existing four game-world waypoints; no GPS, new measured location, or real assignment location is invented. F7 clean photo mode hides it.

## Offline save boundaries

The only new save is **user://nus3d_coursework.cfg**. It includes a chosen faculty ID, per-faculty quest/stage/timer/grade progress, aggregate XP/credits and the latest grade. It stores no name, email address, password, login details, health data or telemetry. Existing Field Notes, Campus Sprint and six fictional interior activities use their original separate save files.

**Development safety:** Linux tests override the save path with a temporary one and remove it afterwards. Actual coursework profiles should never be overwritten by smoke tests.

## Automated acceptance

- tools/validate_coursework_data.py checks 13 choices / 39 unique quests, fictional/offline provenance, waypoint IDs and valid F/Q destinations
- godot/tests/smoke_test.gd tests choosing a school, the locked first-run modal, a real four-stage ERC course, timer pause/resume in the journal, late submissions, rewards, per-faculty switching and save/reload
- godot/scripts/export_self_test.gd and the Windows x64 runtime contract confirm packaged JSON, 13 faculty-picker options and all 39 quests
- godot/tests/render_viewpoints.gd adds actual Godot screenshots for the faculty picker, on-screen mission prompt, task journal and DDL countdown

**Remaining manual QA:** Windows GUI picker sizing and Chinese glyph support, keyboard focus, mission marker reachability, finite-time pressure balance, ESC/input-release behavior, and a full multi-faculty playthrough. This is not an actual educational course-management system.

## Public naming source

NUS Bulletin AY2026/27 public faculties/schools/colleges listing: https://www.nus.edu.sg/nusbulletin/ay202627/programmes/

All course-specific stories and missions in this repository are invented.


## M3.8 after-course gameplay

Completing all three chapters for one faculty permanently unlocks the original Post-Course Club, even after changing to another faculty. P opens real Gomoku, a no-wager card duel and fictional NPC celebration scene. Completing all 39 chapters adds an optional cosmetic title. Details and controls are described in M3_8_POSTCOURSE_CLUB.md.
