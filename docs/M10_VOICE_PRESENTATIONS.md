# M10 — English Oral Presentation / opt-in microphone challenge

**Fictional NUS-3D gameplay content.** These presentation briefs are original and not NUS exam materials or assessed coursework. All student-facing slides, questions, controls, feedback and explanations in this module are **English-only**.

## Gameplay

- After selecting one of the existing 13 faculties, press **F9**, or open **Coursework Journal → ENGLISH ORAL PRESENTATION [F9]**.
- Choose one of **32 major-aligned presentations** (matching the existing English exam catalog) and explicitly click **ENABLE MICROPHONE & START**. There are **3 slides**: introduction, academic explanation and conclusion. Each slide needs at least **5 seconds of sound activity** (approximately 15 seconds in total). One **audience multiple-choice question** follows the slides. The exercise runs on a **150-second timer**.
- Sound level is indicated by a local volume meter. The displayed progress is based on amplitude and time **only**—there is no speech recognition, transcription, grammar analysis or semantic marking.
- Grading: each completed speaking slide contributes **20 points**, answering the audience question correctly contributes **20**, and on-time submission of a fully completed presentation contributes **20**. A first valid completion pays **+70 Coursework XP and +20 Coursework Credits**. Replaying it can improve the score but never pays the same bonus twice.
- User can also choose **PRACTICE WITHOUT MICROPHONE**. This opens every slide and Q&A even if there is no microphone or permission. Practice is not treated as verified and **does not pay XP or credits**. Missing devices, disabled input and a headless audio driver automatically fall back to practice.
- Current faculty gates the library. Example: Chemistry belongs to Science, Chemical Engineering to CDE, Computer Science to Computing. Switching a faculty does not reset prior performance.
- Starting, ending, cancelling, switching slides and completing the Q&A never modify the existing Coursework quests, campus routes, NPCs, coins or exam questions.
- The interface locks player movement while visible, restores previous input/mouse mode on exit and blocks F8 exam, Coursework/Leisure dialogs from opening concurrently.

## Microphone and privacy

- Godot project setting `[audio] driver/enable_input=true` is necessary for Godot 4.4 AudioStreamMicrophone. **This only enables support; the microphone capture player and audio bus are created after a player explicitly clicks the mic-start button.**
- A dedicated **muted** audio bus contains one `AudioEffectCapture` ring buffer (0.25 seconds). The stream is never routed audibly to the player's speakers; the microphone player and temporary bus are removed when leaving, timing out, entering Q&A or closing the UI.
- Only signed floating-point stereo PCM frames in the temporary ring buffer are inspected to estimate RMS, with a ~100 ms sampling/poll interval and a bounded **8192 frames/poll**. The raw buffers are **not written to disk, saved in a game record, uploaded to any server, recorded, transcribed or passed to an AI service**.
- `user://nus3d_presentations.cfg` saves only IDs, attempt counts, best numeric scores and first-completed topic flags. A single-use reward ID is persisted together with Coursework XP and credits in the existing Coursework file, using its `claim_exam_reward_once` method.
- Speech detection is intentionally *not* a claim to verify an actual human talk: sufficiently loud background audio can also trigger the amplitude threshold. In noisy environments, use headphones and a quiet room. A future opted-in local speech-recognition mode could be added separately, but this version does not assess content.
- **Windows**: Settings → Privacy & security → Microphone → Allow desktop apps to access your microphone. Confirm a default recording input device. On some operating systems additional OS permissions or packaging metadata may be required; no permission request is bypassed or forced.

## Files and integration

| File | Purpose |
| --- | --- |
| `godot/data/presentation_briefs.json` | 32 original English briefs / 96 speaking slide prompts / 32 Q&As |
| `godot/scripts/utown_voice_presentation.gd` | UI, microphone start/stop, bounded RMS sampling, grading, attempts and save |
| `godot/scenes/main.tscn` | A new `VoicePresentation` CanvasLayer under resource ID 30 in the integrated main game |
| `godot/scripts/utown_coursework_ui.gd` | A new presentation button in the original Coursework Journal |
| `godot/scripts/utown_english_exams.gd` and `godot/scripts/utown_leisure_ui.gd` | Small guards against conflicting modal hotkeys |
| `godot/project.godot` | Allows microphone input; never starts capture on its own |
| `godot/tests/voice_presentation_smoke_test.gd` | Headless test using **mock audio activity**, no microphone access |
| `tools/validate_presentations.py`, `tools/test_presentations.py` | Validate language, major mapping, privacy and reward/data contracts |

## Verification

```bash
python tools/validate_presentations.py
python -m unittest discover -s tools -t . -v
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/smoke_test.gd
godot --headless --path godot --script res://tests/english_exams_smoke_test.gd -- --nus3d-self-test
godot --headless --path godot --script res://tests/voice_presentation_smoke_test.gd -- --nus3d-self-test
```

**Testing limitation**: CI validates three-slide rules, synthetic RMS windows, duration thresholds, Q&A, exam-input isolation, storage and reward idempotency. Headless CI does **not** grant OS microphone permissions or establish live device performance. Manual validation of actual sound capture on the target Windows build, device removal and OS permission denial remains necessary before merging.

## Parallel branch safety

This forward-port is based on the integrated main gameplay after #48, rather than the obsolete PR #23 branch. Only its own new modules, main-scene registration, shared UI guards and microphone input capability are touched; existing NPC, admin, economy and progression state remains untouched. CI must pass on this exact branch before integration; validate actual microphone permission and capture on Windows separately.
