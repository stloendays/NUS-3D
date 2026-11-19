# M9 — English Major Exam Papers

This is an **original, fictional, offline game feature**. These papers are not NUS modules, authentic assessments, academic records, or admissions requirements. All exam questions, answer options, labels, explanations, grading messages, and paper titles are **English only**.

## Gameplay

Players first choose one of the **13 existing faculties** through the original Coursework selector. Press **F8** in normal outdoor play, or use the **ENGLISH MAJOR EXAM PAPERS [F8]** button inside the Coursework Journal.

The exam library only shows majors associated with the selected faculty. Switching faculty from the original menu changes the available major papers without deleting previous results.

- **32 major-specific exam papers**, **160 original multiple-choice questions**, five questions per paper.
- **180-second timer**, four possible choices for each question, 20 marks per correct answer, **60% to pass**.
- Prev/Next navigation preserves answers; papers may be submitted with unanswered questions (unanswered = incorrect), or are submitted automatically at time expiry.
- Original academic content follows each major (e.g. Chemistry reaction kinetics, Chemical Engineering mass balance, Computer Science algorithmic complexity, Finance NPV, Clinical Medicine safety, Public Law judicial review).
- Score review shows the player's choice, expected answer, whether the response was correct, and an English explanation for every question.
- Letter grades: **A+ at 100%, A at 80%, B at 60%, F otherwise**. Retakes are unlimited; the best score and attempt count are recorded.
- **First pass only:** +90 Coursework XP and +25 Coursework Credits. The reward is written to the **existing Coursework save in the same transaction as its single-use ID**, and remains unrewardable across retakes/restarts.
- The exam record has its own file, `user://nus3d_english_exams.cfg`, containing attempts, best/last scores and passed paper IDs. The Coursework-only bonus ledger is stored in `user://nus3d_coursework.cfg` with the original XP and credits. A resume-repair function handles a crash between the two saves.
- Exams lock player movement while open, release the mouse for clicking, and restore previous input mode when closed. The timed assessment does not alter the physical campus, other task/quest stages, intro cinematics, account data or NPC dialog.
- Opening is blocked while the cinematic, another Coursework dialog, the leisure menu, cycling or shuttle is active. Existing O/J/P/Q/K controls are prevented from triggering other modals during an exam.

## Covered faculties and major tracks

| Existing faculty ID | Major papers |
|---|---|
| science | Chemistry; Physics; Biological Sciences |
| cde | Chemical Engineering; Mechanical Engineering; Electrical Engineering; Architecture |
| computing | Computer Science; Cybersecurity; Data Science |
| business | Finance; Accounting; Marketing |
| fass | Economics; Psychology; Sociology |
| chs | Environmental Studies; Interdisciplinary Studies |
| medicine | Clinical Medicine; Biomedical Sciences |
| law | Contract Law; Public Law |
| dentistry | Restorative Dentistry; Oral Biology |
| music | Music Theory; Music Composition |
| nusc | Global Studies; Science and Society |
| public_health | Epidemiology; Health Policy |
| public_policy | Policy Analysis; Public Administration |

These are **gameplay tracks**, not claims about the official degree structure of each school.

## Integration and performance

- Data: `godot/data/english_exam_papers.json` (86 KB plain UTF-8 JSON, no image/font download).
- UI and scoring: `godot/scripts/utown_english_exams.gd` (one CanvasLayer; controls are created once, not rebuilt for each question).
- Coursework reward bridge: `godot/scripts/utown_coursework.gd` (one new atomic reward method and backward-compatible ledger).
- Existing Coursework and leisure panels only receive an extra exam entry and a guard that prevents conflicting hotkeys while the exam is open.
- Scene: `godot/scenes/main.tscn` appends a single `EnglishExams` node, resource ID 18. Does not replace or renumber earlier resources.
- No new 3D geometry, collision bodies, timers per paper, network calls, microtransactions, or heavyweight rendering resources.

## Verification commands

```bash
python tools/validate_english_exams.py
python -m unittest discover -s tools -t . -v
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/smoke_test.gd
godot --headless --path godot --script res://tests/english_exams_smoke_test.gd -- --nus3d-self-test
```

Regression checks include faculty coverage, question uniqueness, English-only content, answer-key validity, score thresholds, empty/invalid answers, deadline submission, another-faculty gating, mouse/player lock, modal input guard, persistence and first-pass XP idempotency.

## Concurrency

This is a **draft stacked PR based on the current Coursework branch**. It does not merge to main or overwrite the concurrent coins/map/architecture, account, dialogue, sound or story branches. Those features can be reconciled in the integration branch after their own PRs are stable.
