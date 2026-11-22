# M26 — Ambient campus NPC routines

## Scope

M26 gives a small subset of existing ambient pedestrians short, autonomous routines around the existing UTown campus furniture. It reuses the 24-person outdoor roster, procedural character model, A* navigation and current map anchors.

## Routines

- Sit briefly on existing outdoor benches.
- Walk to one of the new path-side refill stations, raise a drink and pause.
- Walk to an existing vending machine, make a purchase gesture and carry a small bag.
- Meet another ambient pedestrian at a Town Green picnic patch, sit opposite them at the low picnic table and have a short conversation.

## Integration and safety

- Only the 18 ambient passers-by are eligible. The six named characters retain their current personality, dialogue and relationship logic.
- Movement to facilities uses the existing cached A* path service, collision sweep and pedestrian separation.
- A maximum of six ambient NPCs may be in an activity at once; spot reservations prevent multiple actors occupying the same seat or vending position.
- Player conversation, hostility and interior transitions cancel or pause ambient routines safely.
- No new collisions, persistent activity saves, rewards, currency changes, quest changes, account changes, input bindings or multiplayer RPCs are introduced.
- All activity props are small procedural primitives; temporary hand props are attached only while needed. Town Green picnic patches now include a compact low table, snacks and cups. Path-side refill stations are placed beside selected benches, with approach points offset from the seats.

## Validation

The dedicated M26 workflow checks A* movement progress to a reserved facility, bench/refill/vending/picnic routines, named-character affinity isolation and collision-free placement; it also renders four genuine Godot viewport captures.
