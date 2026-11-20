# M20 — Walkable graded links

This patch corrects the 3D orientation of the M19 graded strips using a local orthonormal basis and adds static collision to pedestrian and cycle strips. Shared road strips remain cosmetic to avoid overlapping collision surfaces. It preserves bus state, UTown terrain, save data and multiplayer schema.

**Not a complete continuous terrain implementation.** The large base plane and district terraces still use separate elevations. Stops, ramps and building entrances may have gaps. Some long straight links may cut across other structures, and routes may be too steep for the player controller. No measured elevation data is used.

**Required runtime QA:** Godot parse and source smoke test, player uphill/downhill traversal, station landings, MD1/Science entrance and route crossings, bus clearance and FPS. No test is claimed passed until executed.
