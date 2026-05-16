extends GutTest
## P3-T02: AttackCommand test suite — verifies orchestration (signals, state),
## not damage values (those are tested in test_attack_simulator.gd).

func test_attack_happy_path_emits_bus_signals() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, bandit])
	# High atk so the new formula still deals damage.
	aria.atk = 1000

	var dealt := [false]
	var weapon := [false]
	var ended := [false]
	var d_conn := func(_a, _d, _dmg, _s): dealt[0] = true
	var w_conn := func(_u, _w, _slot): weapon[0] = true
	var t_conn := func(_u): ended[0] = true
	CombatEventBus.damage_dealt.connect(d_conn)
	CombatEventBus.weapon_used.connect(w_conn)
	CombatEventBus.turn_ended.connect(t_conn)

	var cmd := AttackCommand.new(b, aria, bandit)
	assert_true(cmd.validate())
	cmd.prepare()
	cmd.execute()

	assert_lt(bandit.current_hp, bandit.max_hp, "bandit should take damage")
	assert_true(aria.has_acted)
	assert_true(dealt[0])
	assert_true(weapon[0])
	assert_true(ended[0])

	CombatEventBus.damage_dealt.disconnect(d_conn)
	CombatEventBus.weapon_used.disconnect(w_conn)
	CombatEventBus.turn_ended.disconnect(t_conn)
	aria.free(); bandit.free()

func test_attack_lethal_emits_unit_killed() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, bandit])
	aria.atk = 1000  # guaranteed kill with new formula (1000 * 5 / 100 - 5 = 45 >> 25 hp)

	var killed := [false]
	var conn := func(_a, _d, _src): killed[0] = true
	CombatEventBus.unit_killed.connect(conn)

	var cmd := AttackCommand.new(b, aria, bandit)
	cmd.prepare(); cmd.execute()
	assert_eq(bandit.current_hp, 0)
	assert_false(bandit.is_alive())
	assert_true(killed[0])

	CombatEventBus.unit_killed.disconnect(conn)
	aria.free(); bandit.free()

func test_attack_rejects_out_of_range() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(0, 0))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, bandit])
	var cmd := AttackCommand.new(b, aria, bandit)
	assert_false(cmd.validate())
	aria.free(); bandit.free()

func test_attack_rejects_same_team() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var reni := P1TestHelpers.make_unit(2, 0, Vector2i(5, 5))
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, reni])
	var cmd := AttackCommand.new(b, aria, reni)
	assert_false(cmd.validate())
	aria.free(); reni.free()

func test_attack_delegates_to_simulator_not_inline_formula() -> void:
	# Confirm there is no private _compute_damage on AttackCommand.
	# The method was removed in P3-T02; AttackSimulator owns all formula logic.
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	assert_false(aria.has_method("_compute_damage"),
			"CharacterUnit should not have _compute_damage")
	var cmd := AttackCommand.new(Board.create_flat(2, 2), aria, aria)
	assert_false(cmd.has_method("_compute_damage"),
			"AttackCommand should not have _compute_damage after P3-T02")
	aria.free()
