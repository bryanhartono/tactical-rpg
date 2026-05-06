extends GutTest
## P1-T10: MoveCommand.

func test_move_happy_path() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i(2, 2))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [u])
	var cmd := MoveCommand.new(b, u, Vector2i(4, 2))
	assert_true(cmd.validate())
	cmd.prepare()
	cmd.execute()
	assert_eq(u.grid_position, Vector2i(4, 2))
	assert_eq(b.get_tile(Vector2i(2, 2)).occupant_id, -1)
	assert_eq(b.get_tile(Vector2i(4, 2)).occupant_id, 1)
	# Move alone does NOT set has_acted.
	assert_false(u.has_acted)
	u.free()

func test_move_rejects_out_of_range() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i(0, 0))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [u])
	# Aria's move_budget is 5; (9,9) is Manhattan 18 — unreachable.
	var cmd := MoveCommand.new(b, u, Vector2i(9, 9))
	assert_false(cmd.validate())
	u.free()

func test_move_rejects_out_of_bounds() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i(0, 0))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [u])
	var cmd := MoveCommand.new(b, u, Vector2i(20, 20))
	assert_false(cmd.validate())
	u.free()

func test_cancel_reverses_move() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i(2, 2))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [u])
	var cmd := MoveCommand.new(b, u, Vector2i(4, 2))
	cmd.prepare(); cmd.execute()
	cmd.cancel()
	assert_eq(u.grid_position, Vector2i(2, 2))
	assert_eq(b.get_tile(Vector2i(2, 2)).occupant_id, 1)
	assert_eq(b.get_tile(Vector2i(4, 2)).occupant_id, -1)
	u.free()
