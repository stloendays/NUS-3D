# M12 — Selective NPC personalities

Only **Maya, Ethan, and Mei** are authored relationship characters. The other existing pedestrians (Aisha, Lucas, Daniel) retain normal bilingual dialogue, walking animations, indoor interactions and coursework dialogue triggers, but do **not** receive relationship scores, character arcs or recurring affinity calculations. This keeps the world populated without giving every passerby an expensive persistent simulation.

At friendship tier 2, the three authored characters offer a localized side-activity invitation in dialogue. These are **narrative hooks**, not yet completable quest state machines or rewards. The existing account-scoped relationship save format remains compatible; old scores for ambient NPCs are ignored rather than migrated into other characters.

Follow-up implementation should add lightweight daily schedules and invitation acceptance/decline with event completion tracking; keep background NPCs pooled and update distant actors less frequently. Do not broadcast account-specific affinity in multiplayer.

Validation: `godot --headless --path godot --script res://tests/npc_relationship_smoke_test.gd` and the integration smoke test.
