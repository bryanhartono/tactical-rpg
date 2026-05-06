extends GutTest
## P1-T20: BattleLogService records bus events.

func before_each() -> void:
	BattleLogService.clear()

func test_logs_attack_command_events() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	var b: Board = P1TestHelpers.make_board_with_units(10, 10, [aria, bandit])
	aria.atk = 30

	var cmd := AttackCommand.new(b, aria, bandit)
	cmd.prepare(); cmd.execute()

	# AttackCommand should produce attack_resolving, damage_dealt, weapon_used, turn_ended.
	assert_gt(BattleLogService.get_log_for("attack_resolving").size(), 0)
	assert_gt(BattleLogService.get_log_for("damage_dealt").size(), 0)
	assert_gt(BattleLogService.get_log_for("weapon_used").size(), 0)
	assert_gt(BattleLogService.get_log_for("turn_ended").size(), 0)

	aria.free(); bandit.free()

func test_clear_empties_log() -> void:
	CombatEventBus.battle_ended.emit("test")
	assert_gt(BattleLogService.get_log().size(), 0)
	BattleLogService.clear()
	assert_eq(BattleLogService.get_log().size(), 0)
