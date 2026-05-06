extends GutTest
## P1-T11: AttackCommand.

func test_attack_happy_path_emits_bus_signals() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, bandit])
	# Boost atk so we deal real damage with the toy formula.
	aria.atk = 30  # 30 * 5 / 10 - 5 = 10

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

	assert_eq(bandit.current_hp, 15)
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
	aria.atk = 1000  # absurd — guaranteed kill

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

func test_predict_damage_matches_resolved_damage() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	aria.atk = 30
	var predicted := AttackCommand.predict_damage(aria, bandit, aria.main_weapon)
	assert_eq(predicted, 10)
	aria.free(); bandit.free()
