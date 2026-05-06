extends GutTest
## P1-T06: Pathfinder.

func test_reachable_from_center_budget_3() -> void:
	var b: Board = Board.create_flat(10, 10)
	# Manhattan ≤ 3 from (5,5) — full diamond inside bounds = 25 tiles (incl origin).
	var r: Dictionary = Pathfinder.compute_reachable(b, Vector2i(5, 5), 3)
	assert_eq(r.size(), 25)
	assert_true(r.has(Vector2i(5, 5)))
	assert_eq(r[Vector2i(5, 5)], 0)
	assert_eq(r[Vector2i(8, 5)], 3)

func test_reachable_from_corner_clipped() -> void:
	var b: Board = Board.create_flat(10, 10)
	# From (0,0) budget 3: quarter-diamond clipped to bounds = 10 tiles.
	var r: Dictionary = Pathfinder.compute_reachable(b, Vector2i(0, 0), 3)
	assert_eq(r.size(), 10)

func test_blocker_removes_unreachable_tiles() -> void:
	var u := P1TestHelpers.make_unit(99, 1, Vector2i(2, 0))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [u])
	var r: Dictionary = Pathfinder.compute_reachable(b, Vector2i(0, 0), 3)
	# Going east is blocked by the unit at (2,0), so (3,0) cannot be reached within budget.
	assert_false(r.has(Vector2i(2, 0)))
	assert_false(r.has(Vector2i(3, 0)))
	u.free()

func test_path_to_returns_inclusive_path() -> void:
	var b: Board = Board.create_flat(10, 10)
	var p: Array = Pathfinder.path_to(b, Vector2i(0, 0), Vector2i(3, 0), 5)
	assert_eq(p.size(), 4)
	assert_eq(p[0], Vector2i(0, 0))
	assert_eq(p[3], Vector2i(3, 0))

func test_path_to_unreachable_returns_empty() -> void:
	var b: Board = Board.create_flat(10, 10)
	var p: Array = Pathfinder.path_to(b, Vector2i(0, 0), Vector2i(9, 9), 3)
	assert_eq(p.size(), 0)
