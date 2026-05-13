extends GutTest
## P2-T16: trivial coverage for the view-side signal contract on CharacterUnit.
## Headless GUT can't verify visual rendering; this proves the data the view subscribes
## to fires with the right payloads.

func test_hp_changed_payload() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var captured := [-1, -1]
	u.hp_changed.connect(func(o, n): captured[0] = o; captured[1] = n)
	u.take_damage(7)
	assert_eq(captured[0], 25)
	assert_eq(captured[1], 18)
	u.free()

func test_attacked_signal_exists_and_fires() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, bandit])
	aria.atk = 30

	var saw_target := [null]
	aria.attacked.connect(func(t): saw_target[0] = t)

	var cmd := AttackCommand.new(b, aria, bandit)
	cmd.prepare()
	cmd.execute()
	assert_eq(saw_target[0], bandit, "attacked should fire with the target unit as payload")

	aria.free(); bandit.free()

func test_last_move_path_is_set_by_move_command() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i(0, 0))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [u])
	var cmd := MoveCommand.new(b, u, Vector2i(3, 0))
	cmd.prepare()
	cmd.execute()
	assert_eq(u.last_move_path.size(), 4, "path should include origin + 3 steps")
	assert_eq(u.last_move_path[0], Vector2i(0, 0))
	assert_eq(u.last_move_path[3], Vector2i(3, 0))
	u.free()
