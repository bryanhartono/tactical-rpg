extends GutTest
## P3-T01: validate battle_const.tres loads with default values from GDD §11.1
## and is accessible via MasterDataService.

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

func test_hit_chance_defaults() -> void:
	var bc: BattleConst = load(BATTLE_CONST_PATH)
	assert_eq(bc.min_hit_chance, 5)
	assert_eq(bc.max_hit_chance, 95)
	assert_eq(bc.max_crit_chance, 50)

func test_master_data_service_exposes_battle_const() -> void:
	var mds: Node = get_tree().root.get_node_or_null("MasterDataService")
	assert_not_null(mds, "MasterDataService autoload should be present")
	if mds == null:
		return
	assert_not_null(mds.battle_const, "MasterDataService.battle_const should not be null")
	assert_is(mds.battle_const, BattleConst)
