# M13 — Visually diverse campus NPCs

The existing six fictional named students now use a stable range of skin tones and hair colors, plus three inexpensive hair silhouettes. The same shared procedural builder is used outdoors and indoors, so a character's appearance remains consistent between scenes. Outfit colors remain independent.

This is **visual variety**, not a race classifier: no ethnicity is inferred from skin tone, and appearance does not control personality, dialogue, affinity, intelligence, rewards or behavior. Maya, Ethan and Mei remain the only authored personality/affinity NPCs from M12. Other NPCs are lightweight ambient pedestrians.

The implementation adds no new image textures, imported models, animation rigs or runtime material updates. It retains the existing Godot Compatibility renderer and account-save format.

Visual QA required: launch Godot and inspect all six characters in outdoor and indoor views; verify that the hair cap does not clip through the face, and that the palette is legible under day/night lighting.
