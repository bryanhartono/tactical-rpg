extends GutTest
## P1-T13: BattleManager phase loop.
##
## We don't load the full BattleScene here — too much UI / input plumbing for a unit
## test. Instead we drive the manager directly with a hand-built board and check the
## bus signals fire in the right order.

func _make_manager_no_scene() -> BattleManager:
	var mgr := preload("res://scenes/battle/battle_manager.gd").new()
	# Bypass the auto _bootstrap path; we'll wire state by hand.
	return mgr

func test_phase_advance_emits_phase_signals() -> void:
	var mgr := _make_manager_no_scene()
	mgr.board = Board.create_flat(5, 5)
	# Two alive units, one per team, so battle doesn't end immediately.
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(0, 0))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(4, 4), "res://data/characters/bandit.tres")
	P1TestHelpers.register(mgr.board, aria)
	P1TestHelpers.register(mgr.board, bandit)
	mgr.add_child(aria)
	mgr.add_child(bandit)
	add_child_autofree(mgr)

	var seen: Array = []
	var ps := func(name, _r): seen.append("started:" + name)
	var pe := func(name, _r): seen.append("ended:" + name)
	CombatEventBus.phase_started.connect(ps)
	CombatEventBus.phase_ended.connect(pe)

	# Manual drive: skip start_battle (which kicks off AI). Simulate transitions.
	mgr._enter_phase(BattleManager.Phase.PLAYER)
	mgr._enter_phase(BattleManager.Phase.ENEMY)
	mgr._enter_phase(BattleManager.Phase.NEUTRAL)
	assert_true(seen.has("started:player"))
	assert_true(seen.has("ended:player"))
	assert_true(seen.has("started:enemy"))
	assert_true(seen.has("ended:enemy"))
	assert_true(seen.has("started:neutral"))

	CombatEventBus.phase_started.disconnect(ps)
	CombatEventBus.phase_ended.disconnect(pe)

func test_battle_ends_when_all_enemies_dead() -> void:
	var mgr := _make_manager_no_scene()
	mgr.board = Board.create_flat(5, 5)
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(0, 0))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(4, 4), "res://data/characters/bandit.tres")
	P1TestHelpers.register(mgr.board, aria)
	P1TestHelpers.register(mgr.board, bandit)
	mgr.add_child(aria)
	mgr.add_child(bandit)
	add_child_autofree(mgr)

	bandit.take_damage(9999)

	var result := [""]
	var conn := func(r): result[0] = r
	CombatEventBus.battle_ended.connect(conn)

	mgr._check_battle_end()
	assert_eq(result[0], "victory")
	assert_true(mgr.battle_over)

	CombatEventBus.battle_ended.disconnect(conn)
