# M11 — NPC personality and affinity

- Six named campus characters have distinct temperaments: Maya (chaotic/outgoing), Ethan (reserved), Aisha (competitive), Lucas (energetic), Mei (curious/analytical), and Daniel (philosophical/dry humour).
- Q conversations in outdoor campus areas and ERC/SRC interiors award affinity. Gains differ by personality (Ethan warms up slowly; Maya is more outgoing). A 45-second per-NPC cooldown is persisted to prevent relog/re-talk farming.
- Five relationship tiers: Stranger (0), Acquaintance (10), Friend (30), Confidant (55), Campus bestie (80). Affinity caps at 100.
- Higher tiers unlock character-specific Chinese/English follow-up lines. The normal dialogue bank remains intact; affinity dialogue is appended to it.
- Saves live in the current account's independent \`relationships\` feature file. Logout clears in-memory account state. No affinity, username credentials or personal save data is sent over multiplayer RPC.
- No XP, coins or coursework rewards are attached to affinity in this milestone.

Validation: \`godot --headless --path godot --script res://tests/npc_relationship_smoke_test.gd\`.
