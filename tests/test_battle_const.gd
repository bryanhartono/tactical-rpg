extends GutTest
## Sanity test that proves both GUT works and the battle_const.tres resource from
## P0-T04 loads with the values from GDD §11.1.

const BATTLE_CONST_PATH := "res://data/battle_const.tres"

func test_battle_const_loads() -> void:
	var bc: BattleConst = load(BATTLE_CONST_PATH)
	assert_not_null(bc, "battle_const.tres should load as a BattleConst resource")

func test_min_damage_is_one() -> void:
	var bc: BattleConst = load(BATTLE_CONST_PATH)
	assert_eq(bc.min_damage, 1, "min_damage should be 1 per GDD §11.1")

func test_rollback_free_count_is_three() -> void:
	var bc: BattleConst = load(BATTLE_CONST_PATH)
	assert_eq(bc.rollback_free_count, 3, "rollback_free_count should be 3 per GDD §11.1")
