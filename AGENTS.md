# NUS-3D — Development Rules for All Agents

## 1. Product identity
NUS-3D is a **stylized, comedic, stress-relief, lightweight open-world 3D campus game** inspired by the National University of Singapore. It is NOT a serious university simulator, navigation service, photorealistic digital twin, or academic training platform.

**North star:** Players should recognize the campus, laugh at exaggerated university life, discover surprising interactions, and want to play again after finishing coursework.

The main loop is: **explore → encounter absurd campus event → complete a short interactive challenge → earn coins/experience/items → unlock new areas, cosmetics, characters, activities, and story outcomes → freely explore**.

## 2. Design pillars (priority order)
1. **Fun and feel first.** Comedy, responsiveness, readable interactions, satisfying audiovisual feedback, and low friction beat feature count.
2. **Recognizable NUS geography.** Use credible public maps and official references for relative locations, building silhouettes, entrances, Science/Frontier, UTown, canteens, fields, transit, and sheltered walkways. Stylization and exaggerated proportions are encouraged, but avoid incorrect landmark identity or obvious collisions.
3. **Consistent low-poly visual language.** Rounded, playful, Goose Goose Duck-like clarity; compact readable HUD; restrained palette; coherent NPC proportions and customizable outfits. Avoid generic AI-generated clutter, floating labels, huge roadside arrows, excessive signs, and mismatched assets.
4. **Campus satire, not cruelty.** DDL panic, coursework, presentations, exams, lab mishaps, crowds, food queues, campus chickens, bus mishaps, professor/student NPCs. Conflict and combat must be cartoonish and non-graphic; do not frame real students or teachers as targets for real-world harm. Use fictionalized characters and no personal likenesses without permission.
5. **Performance and accessibility.** Stable frame pacing, reasonable memory and draw calls, scalable graphics, clear controls, adjustable audio, readable UI, and graceful fallback on modest hardware.
6. **Replayability.** After main quests, maintain minigames, social activities, side quests, exploration, cosmetics, random events, achievements, and light progression.

## 3. World and content rules
- Treat the campus as a connected world with meaningful travel, not isolated decorative boxes. UTown, Science/Frontier, Engineering, Library, Computing, Business, residences, sports areas, and transit should each have distinct silhouettes and reasons to visit.
- Base layout on NUS campus maps, official public pages, and legally usable geodata. Mark approximations explicitly; never claim game bus routes or invented fields are surveyed or official.
- Google Maps may guide **manual visual comparison only**. Do not copy, scrape, redistribute, or ship proprietary map tiles, Street View images, or Google 3D meshes without appropriate rights. Record source and license for external models/textures/audio.
- Use natural world boundaries: terrain, foliage, skyline, water, fences where plausible, or narrative limits. Avoid visible voids and abrupt invisible walls; make boundaries collision-safe.
- Enrich scenes with appropriate trees, covered paths, seating, canteen props, lighting, clouds, ambient audio, crowds, chickens, and interactive affordances. Prefer reusable instanced props and LOD/culling.
- Buildings need recognizable massing, facade rhythm, entrances, and scale before adding fine details. Do not claim photorealistic accuracy without validation.
- NPC behavior should reflect time of day: lunch queues, class changes, study periods, weather, and events. Use bounded spawn budgets and distance-based simulation.
- Story and UI text should default to concise, natural English; comedy must be situational rather than endless exposition.

## 4. Gameplay systems
- Preserve the existing player controller, interaction keys, mouse handling, bus travel, campus time/weather, coins, shops, outfits, levels, NPC dialogue, email/account features, and quest progression unless a change is explicitly scoped.
- Introduce a new mechanic only if it has a **player action, visible/audio feedback, state transition, reward or consequence, and test**. Static props alone are not gameplay.
- Coin/XP rewards must be balanced and exploit-resistant. Persistent one-time rewards must use existing save APIs and be idempotent; do not duplicate balances or overwrite other systems.
- Campus events should be short, funny, optional where possible, and varied. Avoid repetitive chores or mandatory grinding.
- Presentations may use microphone access only with explicit user permission, clear status, and a non-microphone fallback. Never record/transmit audio silently.
- External AI APIs (including GPT) must be optional, rate-limited, securely configured, and fail gracefully offline. Never ship API keys in clients or source control.
- Admin controls must be permission-gated and separated from normal progression; do not trust client-side flags for privileged actions.
- Account, in-game mail, and progression data need schema/versioning, error handling, and safe migration. Avoid exposing personal information.

## 5. Multi-agent engineering protocol — mandatory
- **One task = one scoped branch/PR.** Before editing, inspect the latest target branch, existing open PRs, touched files, and current CI status. Never assume an earlier conversation's SHA is current.
- **No uncoordinated shared-file changes.** Player input, main scene, HUD, global managers, save schema, and project settings are integration hotspots. Coordinate ownership before touching them. If another agent is fixing repeated key presses, do NOT modify input maps, event handlers, or that agent's files.
- Prefer additive scripts, isolated scenes, JSON data, and small documented integration points. Keep module boundaries explicit and minimize dependencies.
- Do not merge, force-push, rebase, close, or overwrite other agents' work without explicit authorization and a fresh conflict review. A draft PR is not a completed release.
- Preserve existing functionality and backward compatibility. Reuse established APIs for coins, XP, save/load, NPC interaction, audio, and quests rather than creating parallel systems.
- When an edit overlaps another PR, report the overlap and coordinate the integration base; do not silently replace work.
- Each PR must state: goal, affected systems, gameplay change, compatibility risks, test evidence, performance impact, source/asset provenance, and known limitations.

## 6. UI, sound, and tactile feedback
- Inputs should feel immediate and physical: short press-depth animation, subtle shadow/highlight change, distinct confirm/cancel/error sounds, restrained 3D layering, and smooth nonblocking transitions.
- Use a coherent sound palette and expose master/music/SFX sliders; do not spam sounds on every frame or trigger.
- Prioritize legibility and contextual cues over signposts, persistent tutorials, and crowded panels. Guidance can use environmental composition, minimap markers, camera framing, and short contextual prompts.
- Support keyboard/mouse first, with clear focus behavior and no duplicate action dispatch. Respect pause state and mouse capture.

## 7. Performance budgets and QA
- Target a stable **60 FPS on a representative midrange PC** at a documented resolution/settings; provide a scalable 30 FPS mode for weaker devices. These are targets, not claims of current performance.
- Measure draw calls, active NPC count, mesh instances, texture sizes, memory, loading time, and stutter. Reuse materials/meshes, MultiMesh repeated objects, and avoid unbounded per-frame scans or physics bodies.
- Every gameplay PR needs a Godot headless import/parse check, scene-launch smoke, and focused regression tests. Check player spawn, input ownership, quest state, coin persistence, bus travel, map bounds, and scene node paths.
- Visual changes require in-engine screenshots from relevant viewpoints (ground level, aerial/minimap, day/night where applicable), not just generated concept art.
- Mark CI as **pending**, **failed**, or **passed** based on actual runs. Never equate “committed” with “tested,” “merged,” or “released.”
- Fix only issues caused by the scoped PR. If an inherited test fails, document the baseline and create a separate issue/PR rather than hiding or broadening unrelated changes.

## 8. Definition of done
A feature is done only when:
1. The player can reach and use it in the actual game.
2. It matches the established visual and comedic direction.
3. It has sensible interaction feedback, rewards, and failure/exit paths.
4. It preserves existing controls, save data, progression, and other active branches.
5. Godot import, focused smoke/regression tests, and relevant build checks pass.
6. Performance is measured or the unmeasured risk is explicitly disclosed.
7. Relevant screenshots, source/license notes, and PR documentation are supplied.
8. Integration into main occurs only after review/approval and conflict checks.

## 9. Agent decision rule
When choosing between more features and a better experience, **polish the existing player loop first**. When choosing between realism and humor, preserve recognizable NUS landmarks but exaggerate gameplay. When choosing between speed and safety, protect other agents' branches, save data, and player input. Never claim work is finished without evidence.
