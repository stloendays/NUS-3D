# M25 — Campus scene density and outdoor amenities

## Scope

M25 extends the existing Kent Ridge map-dressing layer with small, low-poly objects and outdoor amenities. It does not replace the existing UTown picnic patches, food-court furniture, street snack machine, bus shelters, or the faculty amenity zones.

## Added content

- Everyday props: phones, headphones, folded umbrellas, cardboard boxes and frisbees, alongside the existing notebooks, papers, cups, bottles, food packs, backpacks, balls and shuttlecocks.
- Outdoor furniture: benches and waste bins, plus picnic tables with shade umbrellas in selected commons and civic districts.
- Convenience: vending machines in teaching, residential and transit districts; refill stations in Science, Engineering and Central Library areas.

## Placement and rendering

- Deterministic random seed; the same map load produces the same object layout.
- Placement checks building footprints, promenade corridors, bus stops, existing trees, planters and known faculty amenity pads.
- Small props, benches, bins and amenity types are rendered as bounded MultiMesh batches using original primitive meshes.
- Decorative objects do not add collision shapes, save data, rewards, player input, NPC behavior or multiplayer RPCs.
- No external model, texture or audio assets are introduced.

## Validation

The dedicated M25 workflow runs the scattered-props smoke test and the existing map-dressing regression. It also renders three genuine Godot viewport captures for the vending machine, shaded picnic table and water refill station.

Latest successful smoke result before the final model-detail pass: 372 instances across 22 MultiMesh batches, including 7 vending machines, 5 shaded picnic tables and 3 refill stations. The current CI rerun also checks product displays, water bottles, drip trays and building-adjacent amenity placement. These counts are test-scene results, not a claim of measured frame-rate improvement.
