class_name AttackCommand extends Command
## Single attack with the unit's main weapon against a target unit.
## See docs/gdd.md §5.5, §10.4.
##
## Phase 1 inlines the damage formula and the simulator-style prediction in
## `predict_damage()`. Phase 3 extracts both into AttackSimulator so AI / damage
## preview / actual resolution share one source of truth.
## TODO(phase 3): extract _compute_damage and predict_damage to AttackSimulator.

var board: Board
var attacker: CharacterUnit
var target: CharacterUnit

# Computed in prepare().
var _damage: int = 0
var _was_lethal: bool = false

func _init(p_board: Board, p_attacker: CharacterUnit, p_target: CharacterUnit) -> void:
	board = p_board
	attacker = p_attacker
	target = p_target

func validate() -> bool:
	if attacker == null or target == null or board == null:
		return false
	if attacker.has_acted:
		return false
	if not target.is_alive():
		return false
	if attacker.team == target.team:
		return false
	if attacker.main_weapon == null:
		return false
	var shape := RangeShapeResolver.get_shape_by_id(attacker.main_weapon.range_shape_id)
	if shape == null:
		return false
	var in_range := RangeShapeResolver.resolve(shape, attacker.grid_position, attacker.facing)
	return in_range.has(target.grid_position)

func prepare() -> void:
	_damage = _compute_damage(attacker, target, attacker.main_weapon)
	_was_lethal = (_damage >= target.current_hp)

func execute() -> void:
	# attack_resolving lets future BondActionService (Phase 7) insert a guard / mutate
	# the damage. Listeners modify mutable_damage_ref[0]. No listeners exist in Phase 1
	# but firing the hook means future code wires in cleanly.
	var damage_ref: Array = [_damage]
	CombatEventBus.attack_resolving.emit(attacker, target, attacker.main_weapon, damage_ref)
	var final_damage: int = damage_ref[0]

	target.take_damage(final_damage, attacker.main_weapon)
	CombatEventBus.damage_dealt.emit(attacker, target, final_damage, attacker.main_weapon)
	CombatEventBus.weapon_used.emit(attacker, attacker.main_weapon, 0)
	attacker.has_acted = true
	CombatEventBus.turn_ended.emit(attacker)

func cancel() -> void:
	# Phase 1: best-effort. Real rollback wiring lands in Phase 3 (RollbackService).
	var restored_old := target.current_hp
	target.current_hp = min(target.current_hp + _damage, target.max_hp)
	target.hp_changed.emit(restored_old, target.current_hp)
	attacker.has_acted = false

# ----------------------------------------------------------------------------
# Helpers (also used by the damage-preview UI in P1-T17)
# ----------------------------------------------------------------------------

## Predicts the damage this command would deal without executing. Used by the
## damage-preview popup. TODO(phase 3): move to AttackSimulator.predict().
static func predict_damage(atk: CharacterUnit, def: CharacterUnit, w: Weapon) -> int:
	if atk == null or def == null or w == null:
		return 0
	return _compute_damage(atk, def, w)

# Phase 1 damage formula: simplified from GDD §5.5.
# Missing: facing/elevation/element/type modifiers, hit/crit rolls. Phase 3 + 5 add them.
static func _compute_damage(atk: CharacterUnit, def: CharacterUnit, w: Weapon) -> int:
	var base: int = atk.atk * w.initial_power / 10
	var mitigated: int = base - def.def
	return clamp(mitigated, 1, 9999)
