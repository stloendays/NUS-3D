# M28 — Scheduled campus micro-events

## Player loop

M28 turns the existing M26/M27 ambient campus ecosystem into three optional, short player-facing events. It reuses the existing **Q** conversation action, campus clock, weather presets, ambient NPC roster and account-scoped coin reward API.

| Event | Schedule | Player action | One-time reward |
|---|---|---|---:|
| Lunch Rush | 11:30–13:30 | Speak to two different ambient NPCs near Fine Food | 15 coins |
| Rain Shelter | Rain/thunderstorm, 13:30–22:00 | Speak to two different ambient NPCs near an existing covered shelter | 18 coins |
| Evening Picnic | 18:00–20:00 in clear/cloudy weather | Speak to two different ambient NPCs near Town Green picnic spots | 20 coins |

The compact campus HUD displays the active event and progress. The event ends when its schedule window closes or another scheduled event takes priority.

## Integrity and compatibility

- Only ambient pedestrians count; the six named story characters and their affinity/dialogue state are unchanged.
- A conversation counts only when the player is inside the relevant event area and not in an interior, on the shuttle or using bicycle mode.
- Each NPC is counted once per event using its stable navigation key.
- Rewards use the existing \`UTownCoins.reward_once()\` API and account-specific coin save. Each event reward is claimable once per account; repeated conversations and relaunches cannot farm it.
- No new input bindings, collision shapes, NPC routines, multiplayer RPCs or parallel currency/save systems are introduced.
- Rain during lunch keeps the existing covered Fine Food lunch schedule as the primary event; Rain Shelter is offered outside the lunch window.

## Validation

\`campus_events_smoke_test.gd\` checks schedule windows, location gating, duplicate NPC prevention, story-character exclusion, one-time rewards and leaving event windows. \`render_campus_events.gd\` captures genuine Godot viewport screenshots for the lunch, rain and evening HUD states.

All campus times, positions and shelters remain schematic game-world data. They are not official NUS schedules, live weather, real campus services or navigation directions.
