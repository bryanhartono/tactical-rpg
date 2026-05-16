extends GutTest
## P3-T02: AttackSimulator — full formula tests. See docs/gdd.md §5.5.

const BATTLE_CONST_PATH := "res://data/battle_const.tres"

var _bc: BattleConst
var _board: Board  # Resource — do not call .free() on it

func before_each() -> void:
	_bc = (load(BATTLE_CONST_PATH) as BattleConst).duplicate()
	_board = Board.create_flat(10, 10)

## Helper: unit with explicit stats, no definition loading.
func _unit(atk: int, def_val: int, skill: int, luck: int, avoid: int,
		grid: Vector2i, facing: Vector2i = Vector2i.RIGHT) -> CharacterUnit:
	var u := CharacterUnit.new()
	u.atk = atk
	u.def = def_val
	u.skill = skill
	u.luck = luck
	u.avoid = avoid
	u.grid_position = grid
	u.facing = facing
	u.current_hp = 200
	u.max_hp = 200
	return u

## Helper: weapon with explicit stats.
func _weapon(power: int, hit: int = 90, crit: int = 0) -> Weapon:
	var w := Weapon.new()
	w.initial_power = power
	w.initial_hit = hit
	w.initial_crit = crit
	return w

# ─────────────────────────────────────────────────────────────
# 1. predict() returns a valid result
# ─────────────────────────────────────────────────────────────
func test_predict_returns_non_null_result() -> void:
	var atk := _unit(200, 0, 5, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5))
	var result := AttackSimulator.predict(atk, def, _weapon(100), _board, _bc)
	assert_not_null(result)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 2. Base damage formula: atk * power / 100 − def (front attack)
# ─────────────────────────────────────────────────────────────
func test_base_damage_front_attack() -> void:
	# atk=200, power=100 → base=200. def=5. raw=195. facing=front(1.0). final=195.
	# Setup: attacker at (6,5), defender at (5,5) facing RIGHT → front attack.
	var atk := _unit(200, 0, 5, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 5, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var result := AttackSimulator.predict(atk, def, _weapon(100), _board, _bc)
	assert_eq(result.expected_damage, 195)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 3. Back attack modifier (1.5×)
# ─────────────────────────────────────────────────────────────
func test_back_attack_modifier() -> void:
	# Attacker at (4,5) = behind defender (5,5) who faces RIGHT.
	# Direction from defender to attacker = (-1,0) = opposite of facing → back.
	# base=200, raw=200, × 1.5 = 300.
	var atk := _unit(200, 0, 5, 0, 0, Vector2i(4, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var result := AttackSimulator.predict(atk, def, _weapon(100), _board, _bc)
	assert_eq(result.expected_damage, 300)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 4. Side attack modifier (1.2×)
# ─────────────────────────────────────────────────────────────
func test_side_attack_modifier() -> void:
	# Attacker at (5,4) = north of defender (5,5) facing RIGHT → perpendicular → side.
	# base=200, raw=200, × 1.2 = 240.
	var atk := _unit(200, 0, 5, 0, 0, Vector2i(5, 4))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var result := AttackSimulator.predict(atk, def, _weapon(100), _board, _bc)
	assert_eq(result.expected_damage, 240)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 5. Mitigation caps at min_damage (never zero or negative)
# ─────────────────────────────────────────────────────────────
func test_damage_clamped_to_min_damage() -> void:
	# atk=1, power=1, def=999 → raw extremely negative → clamp to min_damage=1.
	var atk := _unit(1, 0, 0, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 999, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var result := AttackSimulator.predict(atk, def, _weapon(1), _board, _bc)
	assert_eq(result.expected_damage, _bc.min_damage)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 6. Hit chance calculated and clamped to [min, max]
# ─────────────────────────────────────────────────────────────
func test_hit_chance_calculated_correctly() -> void:
	# hit=90, skill=5, avoid=7, terrain=0 → 90+5-7=88 → within [5,95] → 88.
	var atk := _unit(0, 0, 5, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 7, Vector2i(5, 5))
	var w := _weapon(0, 90, 0)
	var result := AttackSimulator.predict(atk, def, w, _board, _bc)
	assert_eq(result.hit_chance, 88)
	atk.free(); def.free()

func test_hit_chance_clamped_to_max() -> void:
	var atk := _unit(0, 0, 200, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5))
	var result := AttackSimulator.predict(atk, def, _weapon(0, 90, 0), _board, _bc)
	assert_eq(result.hit_chance, _bc.max_hit_chance)
	atk.free(); def.free()

func test_hit_chance_clamped_to_min() -> void:
	var atk := _unit(0, 0, 0, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 999, Vector2i(5, 5))
	var result := AttackSimulator.predict(atk, def, _weapon(0, 0, 0), _board, _bc)
	assert_eq(result.hit_chance, _bc.min_hit_chance)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 7. Crit chance calculated correctly
# ─────────────────────────────────────────────────────────────
func test_crit_chance_calculated_correctly() -> void:
	# crit=0, skill=20, luck=0 → 0 + 20/4 - 0 = 5.
	var atk := _unit(0, 0, 20, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5))
	var result := AttackSimulator.predict(atk, def, _weapon(0, 90, 0), _board, _bc)
	assert_eq(result.crit_chance, 5)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 8. will_kill flag
# ─────────────────────────────────────────────────────────────
func test_will_kill_true_when_lethal() -> void:
	var atk := _unit(9999, 0, 0, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5))
	def.current_hp = 1
	var result := AttackSimulator.predict(atk, def, _weapon(100), _board, _bc)
	assert_true(result.will_kill)
	atk.free(); def.free()

func test_will_kill_false_when_not_lethal() -> void:
	var atk := _unit(1, 0, 0, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5))
	def.current_hp = 9999
	var result := AttackSimulator.predict(atk, def, _weapon(1), _board, _bc)
	assert_false(result.will_kill)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 9. BattleConst mutation changes result
# ─────────────────────────────────────────────────────────────
func test_battle_const_modifier_affects_result() -> void:
	# Back attack: change back_attack_modifier → result changes proportionally.
	var atk := _unit(200, 0, 0, 0, 0, Vector2i(4, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var w := _weapon(100)

	_bc.back_attack_modifier = 2.0
	var r_2x := AttackSimulator.predict(atk, def, w, _board, _bc)
	assert_eq(r_2x.expected_damage, 400)  # 200 * 2.0

	_bc.back_attack_modifier = 1.5
	var r_1_5x := AttackSimulator.predict(atk, def, w, _board, _bc)
	assert_eq(r_1_5x.expected_damage, 300)  # 200 * 1.5

	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 10. resolve(null) matches predict() — deterministic Phase 3 behaviour
# ─────────────────────────────────────────────────────────────
func test_resolve_null_rng_matches_predict() -> void:
	var atk := _unit(200, 0, 5, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 5, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var w := _weapon(100)
	var predicted := AttackSimulator.predict(atk, def, w, _board, _bc)
	var resolved := AttackSimulator.resolve(atk, def, w, _board, _bc, null)
	assert_eq(resolved.expected_damage, predicted.expected_damage)
	assert_eq(resolved.hit_chance, predicted.hit_chance)
	assert_eq(resolved.crit_chance, predicted.crit_chance)
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 11. Crit with real RNG produces damage × 1.5
# ─────────────────────────────────────────────────────────────
func test_crit_produces_1_5x_damage_when_it_occurs() -> void:
	# Set up attacker with max crit chance (skill=999, initial_crit=50 → 50 max).
	# Use seeded RNG that produces crit: loop seeds until we find one.
	var atk := _unit(200, 0, 999, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 0, Vector2i(5, 5), Vector2i.RIGHT)
	var w := _weapon(100, 95, 50)  # max crit chance
	var non_crit_dmg := AttackSimulator.predict(atk, def, w, _board, _bc).expected_damage

	# Try a batch of seeds to find one that crits.
	var found_crit := false
	for seed_val in range(0, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var r := AttackSimulator.resolve(atk, def, w, _board, _bc, rng)
		if r.expected_damage > non_crit_dmg:
			# Verify it's 1.5× (within int rounding).
			var expected := int(float(non_crit_dmg) * 1.5)
			assert_eq(r.expected_damage, expected,
					"Crit damage should be int(base * 1.5)")
			found_crit = true
			break
	assert_true(found_crit, "At least one seed in [0,200) should produce a crit at 50% chance")
	atk.free(); def.free()

# ─────────────────────────────────────────────────────────────
# 12. resolve() with RNG can produce a miss (expected_damage == 0)
# ─────────────────────────────────────────────────────────────
func test_resolve_with_rng_can_miss() -> void:
	# Force low hit chance (weapon.hit=0, avoid=100 → clamped to 5%).
	var atk := _unit(200, 0, 0, 0, 0, Vector2i(6, 5))
	var def := _unit(0, 0, 0, 0, 100, Vector2i(5, 5))
	var w := _weapon(100, 0, 0)  # hit=0 → hit_chance=min_hit_chance=5

	var found_miss := false
	for seed_val in range(0, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var r := AttackSimulator.resolve(atk, def, w, _board, _bc, rng)
		if r.expected_damage == 0:
			found_miss = true
			break
	assert_true(found_miss, "At 5% hit chance, at least one seed should miss")
	atk.free(); def.free()
