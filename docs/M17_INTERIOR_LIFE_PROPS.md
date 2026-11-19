# M17 — Study and recreation props

Adds static prop sets to the existing ERC and SRC illustrative interiors.

ERC: 60 bookshelf volumes, 9 loose revision sheets, 3 pencil cases, and a quiet-zone notice. SRC: 5 sports balls, equipment rack, 4 training cones, chessboard with 8 simple pieces, cards box and a club poster.

All objects are decorative, made from primitive Godot meshes and labels, with no new collision, texture downloads, shaders, persistent state, currency or network RPCs. These are fictional spaces, not architectural reproductions.

Test: `godot --headless --path godot --script res://tests/interior_life_props_smoke_test.gd`. Pending runtime/visual QA: bookshelf clipping, upper-floor tabletop heights, SRC chessboard alignment, FPS/draw-call impact on integrated low-spec mode. Do not claim items are interactable or the test has passed before CI.
