# M10: Multiplayer-ready NUS-3D + low-spec compatibility

This feature is intentionally layered on the 2026-11-19 integrated gameplay branch. It does not merge or overwrite the independently developed campus/map/story PRs.

## What is playable

- Press **F8** after local sign-in for the campus room / graphics panel.
- **Host LAN** creates an ENet UDP room (default port **24568**, up to four players). **Join LAN** accepts the host's LAN IP/hostname and port. Both clients must run the same game version and protocol.
- The host relays 15 Hz position/yaw snapshots. Remote avatars are lightweight, interpolated and distance-culled at 110 m. Invalid coordinates and implausibly large position jumps are discarded.
- Host weather and time-of-day selections are shared; joining clients cannot persist these changes into local profile data.
- Leaving or losing the host returns to offline mode. The room is *not* an internet matchmaking service, relay, account authentication provider, or anti-cheat system.
- Local usernames are display labels only. Never send passwords, email, coursework records, inventory, XP or coin saves over the network.

## Hardware compatibility

The project already defaults to Godot 4.4 **OpenGL Compatibility**. This work retains that renderer rather than forcing Vulkan. A device-local graphics panel offers:

| Preset | FPS cap | 3D scale | Adaptive floor | Camera far plane | Rain particles | Details |
|---|---:|---:|---:|---:|---:|---|
| Low | 30 | 70% | 60% | 280 m | 180 | Off |
| Balanced | 60 | 85% | 70% | 450 m | 500 | On |
| High | 60 | 100% | 80% | 650 m | 1100 | On |
| Ultra | 120 | 100% | 85% | 800 m | 1100 | On |

The scaler samples FPS every 1.5 seconds and changes 3D resolution by 5 percentage points with recovery hysteresis. OpenGL Compatibility uses bilinear viewport scaling; **do not claim FSR or Vulkan-specific screen-space effects**. The setting persists to a device-local ConfigFile, not to the account. Headless CI is uncapped.

This adapts the architectural lessons from [Myworld performance](https://github.com/stloendays/Myworld/blob/main/docs/PERFORMANCE.md) and [Myworld co-op](https://github.com/stloendays/Myworld/blob/main/docs/COOP.md), without copying dependencies or assuming the two games share their scene architecture.

## Safety and limitations

- Only avatars and shared atmosphere are synchronized. NPCs, quests, bus occupancy, combat, coins, email and progression are **not yet authoritative multiplayer systems**. They remain local; this prevents duplicating rewards or changing another player's save.
- The host is a trusted peer and positions are only sanity-checked. Production public matchmaking requires authoritative movement simulation, action validation, rate limiting, identity, moderation and abuse protection.
- Direct internet hosting requires firewall/router UDP forwarding or a trusted VPN. This build does not request UPnP permissions or silently modify a router.
- If a host disconnects, guests return offline. Host migration and reconnect/rejoin are future milestones.
- Quality presets reduce rendering work but do not yet remove prebuilt collision or procedural scene memory. The next optimization pass should partition campus geometry and defer loading distant districts, with actual CPU/GPU profiling before choosing cell sizes.

## Validation

```sh
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/multiplayer_performance_smoke_test.gd
godot --headless --path godot --script res://tests/integration_smoke_test.gd
```

A two-process ENet loopback test and GPU/GUI compatibility matrix are still required before treating the feature as release-ready. No measured FPS improvements are claimed without benchmarking.
