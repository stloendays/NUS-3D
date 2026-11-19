# Campus building fidelity pass (M4.4)

The 26 existing Kent Ridge landmarks now have separate procedural architectural profiles instead of identical boxes. Facade grammars include library sunshades, academic floor slabs and columns, computing/medical glass curtain walls, residential balconies, covered tropical campus walkways, auditoria, canteens, courtyard pergolas and MRT canopy roofs.

This is a stylised visual interpretation of NUS architecture based on public NUS maps and virtual tours, **not** a Google Maps export, licensed 3D mesh, building blueprint or exact photogrammetry. Coordinates and road geometry remain approximate. The 10 districts, 11 game stops and D1/D2 bus functionality are unchanged.

Official visual reference: https://map.nus.edu.sg/ and https://www.nus.edu.sg/oam/nus-experience/virtual-tour

Google Maps may be used manually to compare campus layout, but no Google satellite imagery, Street View screenshots, map tiles or proprietary 3D assets are copied into the game.

## Verification
Run `godot --headless --path godot --script res://tests/kent_ridge_expansion_smoke_test.gd` after Godot import. The 26 landmarks now use per-building style metadata from `godot/data/kent_ridge_expansion.json`. Visual QA and performance benchmarking on low-end GPUs remain required.
