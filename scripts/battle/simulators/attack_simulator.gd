class_name AttackSimulator
## Pure-function combat simulator. See docs/gdd.md §5.5, §10.10.
##
## Two entry points:
##   predict() — deterministic preview used by DamagePreview UI (no RNG).
##   resolve() — execution path used by AttackCommand. When rng is null
##               the result is identical to predict() (always hits, no crit).
##               Phase 5 will inject the game's shared RNG for variance.
##
## No instance state. No Node inheritance. Callers never instantiate this class.

# ----------------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------------

## Compute the expected outcome assuming the attack hits without a critical.
## Used by the DamagePreview popup in TARGETING_ATTACK state.
static func predict(
		attacker: CharacterUnit,
		defender: CharacterUnit,
		weapon: Weapon,
		board: Board,
		bc: BattleConst
) -> AttackSimulatorResult:
	var result := AttackSimulatorResult.new()
	result.hit_chance = _compute_hit_chance(attacker, defender, weapon, board, bc)
	result.crit_chance = _compute_crit_chance(attacker, defender, weapon, bc)
	result.expected_damage = _compute_final_damage(attacker, defender, weapon, board, bc, false)
	result.will_kill = result.expected_damage >= defender.current_hp
	return result


## Roll the actual outcome. When rng is null behaves identically to predict()
## (always hits, no crit — deterministic for Phase 3 and tests).
## Pass a RandomNumberGenerator for live combat once Phase 5 wires it in.
static func resolve(
		attacker: CharacterUnit,
		defender: CharacterUnit,
		weapon: Weapon,
		board: Board,
		bc: BattleConst,
		rng: RandomNumberGenerator = null
) -> AttackSimulatorResult:
	var result := AttackSimulatorResult.new()
	result.hit_chance = _compute_hit_chance(attacker, defender, weapon, board, bc)
	result.crit_chance = _compute_crit_chance(attacker, defender, weapon, bc)

	var did_hit: bool
	var did_crit: bool
	if rng == null:
		did_hit = true
		did_crit = false
	else:
		did_hit = rng.randf() * 100.0 < float(result.hit_chance)
		did_crit = did_hit and rng.randf() * 100.0 < float(result.crit_chance)

	if not did_hit:
		result.expected_damage = 0
	else:
		result.expected_damage = _compute_final_damage(attacker, defender, weapon, board, bc, did_crit)

	result.will_kill = result.expected_damage >= defender.current_hp
	return result

# ----------------------------------------------------------------------------
# Private helpers
# ----------------------------------------------------------------------------

static func _compute_hit_chance(
		attacker: CharacterUnit,
		defender: CharacterUnit,
		weapon: Weapon,
		board: Board,
		bc: BattleConst
) -> int:
	var terrain_evade := _get_terrain_evade_bonus(defender, board)
	var raw: int = weapon.initial_hit + attacker.skill - defender.avoid - terrain_evade
	return clamp(raw, bc.min_hit_chance, bc.max_hit_chance)


static func _compute_crit_chance(
		attacker: CharacterUnit,
		defender: CharacterUnit,
		weapon: Weapon,
		bc: BattleConst
) -> int:
	@warning_ignore("integer_division")
	var raw: int = weapon.initial_crit + attacker.skill / 4 - defender.luck
	return clamp(raw, 0, bc.max_crit_chance)


## Returns the final clamped damage. `is_crit` applies BattleConst.crit_damage_modifier.
static func _compute_final_damage(
		attacker: CharacterUnit,
		defender: CharacterUnit,
		weapon: Weapon,
		board: Board,
		bc: BattleConst,
		is_crit: bool
) -> int:
	var terrain_def := _get_terrain_def_bonus(defender, board)
	@warning_ignore("integer_division")
	var base_damage: int = attacker.atk * weapon.initial_power / 100
	var mitigation: int = int(float(defender.def) * (1.0 + terrain_def))
	var raw: float = float(base_damage - mitigation)

	raw *= _get_facing_modifier(attacker, defender, bc)
	# Placeholders — all 1.0 until the respective phase wires them:
	# elevation_modifier (Phase 8), element_modifier (Phase 13),
	# type_modifier (Phase 13), pair_bonus (Phase 6)
	var crit_modifier: float = bc.crit_damage_modifier if is_crit else 1.0
	raw *= crit_modifier

	return clamp(int(raw), bc.min_damage, bc.max_damage)


## Returns the facing damage multiplier from BattleConst.
## Attacker position relative to the DEFENDER's facing determines the angle.
static func _get_facing_modifier(
		attacker: CharacterUnit,
		defender: CharacterUnit,
		bc: BattleConst
) -> float:
	var dir := _dominant_dir(attacker.grid_position - defender.grid_position)
	if dir == Vector2i.ZERO:
		return bc.front_attack_modifier
	if dir == defender.facing:
		return bc.front_attack_modifier
	elif dir == -defender.facing:
		return bc.back_attack_modifier
	else:
		return bc.side_attack_modifier


## Reduce delta to the dominant-axis unit cardinal direction.
static func _dominant_dir(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(sign(delta.x), 0)
	return Vector2i(0, sign(delta.y))


## Terrain defense bonus for the tile the defender stands on.
## Phase 3: always 0. Phase 8 will read LandformDefinition.defense_bonus.
static func _get_terrain_def_bonus(_defender: CharacterUnit, _board: Board) -> float:
	return 0.0


## Terrain evasion bonus for the tile the defender stands on.
## Phase 3: always 0. Phase 8 will read LandformDefinition.evasion_bonus.
static func _get_terrain_evade_bonus(_defender: CharacterUnit, _board: Board) -> int:
	return 0
