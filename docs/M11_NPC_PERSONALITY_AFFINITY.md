# NUS-3D M11: selected NPC relationships

This is a clean integration of historic #29 core with selective characters from #32, targeting modern main.

- **Authored relationship characters:** Maya (outgoing), Ethan (reserved), and Mei (curious/analytical).
- **Ambient-only NPCs:** Aisha, Lucas, Daniel and background pedestrians retain their ordinary dialogue and animations; they receive **no** relationship save records or persistent simulation.
- Q interaction outdoors and in ERC/SRC uses the existing dialogue bank and mission/event hooks, appending friendship status only for authored characters.
- A 45-second *persisted per-person* cooldown prevents rapid repeat farming; affinity caps at 100, with five tiers and bilingual original dialogue.
- Tier 2 introduces *narrative-only* friend invitations; accepting/completing these tasks is not yet implemented and grants no rewards.
- Saves go through AccountStore's independent `relationships` feature path. Logout clears active relationship dictionaries before the next login. Nothing related to NPC affinity is sent over network RPC, LLM APIs, or other players' sessions.
- Relationship controller is created at runtime by GameShell instead of editing `main.tscn`. This avoids conflicts with simultaneous campus-map, wardrobe and graphics changes. Direct opening of the world scene alone retains ambient dialogue without relationship saving.

Validation: dedicated `npc_relationships.yml` workflow runs a fresh-account progression/cooldown/multi-account test plus existing integration smoke. The main Godot/Windows/admin/security/multiplayer pipelines must also stay green. Runtime screen QA and low-spec profiling remain necessary before release.
