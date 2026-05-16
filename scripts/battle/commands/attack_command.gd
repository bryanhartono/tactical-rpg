class_name AttackCommand extends Command
## Single attack with the unit's main weapon against a target unit.
## See docs/gdd.md §5.5, §10.4.
##
## Phase 3: all damage math lives in AttackSimulator. This command orchestrates
## the event sequence (signal ordering, animation hooks, bus events) only.

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
	var bc: BattleConst = MasterDataService.battle_const
	var result := AttackSimulator.predict(attacker, target, attacker.main_weapon, board, bc)
	_damage = result.expected_damage
	_was_lethal = result.will_kill

func execute() -> void:
	var bc: BattleConst = MasterDataService.battle_const
	# rng=null → deterministic (always hit, no crit) for Phase 3.
	# Phase 5 will inject the shared game RNG here.
	var result := AttackSimulator.resolve(attacker, target, attacker.main_weapon, board, bc)
	var damage_ref: Array = [result.expected_damage]

	# attack_resolving lets future BondActionService (Phase 7) insert a guard / mutate
	# the damage. Listeners modify mutable_damage_ref[0].
	CombatEventBus.attack_resolving.emit(attacker, target, attacker.main_weapon, damage_ref)
	var final_damage: int = damage_ref[0]

	# Face the attacker toward the target before the animation fires.
	var delta := target.grid_position - attacker.grid_position
	if delta.x != 0 or delta.y != 0:
		attacker.facing = Vector2i(sign(delta.x), 0) if abs(delta.x) >= abs(delta.y) \
				else Vector2i(0, sign(delta.y))
		attacker.facing_changed.emit(attacker.facing)

	# Local view-side signal (Phase 2): UnitView3D listens to play the attack animation.
	# Fired before take_damage so the attacker animates before the defender flinches.
	attacker.attacked.emit(target)

	target.take_damage(final_damage, attacker.main_weapon)
	CombatEventBus.damage_dealt.emit(attacker, target, final_damage, attacker.main_weapon)
	CombatEventBus.weapon_used.emit(attacker, attacker.main_weapon, 0)
	attacker.has_acted = true
	CombatEventBus.turn_ended.emit(attacker)

func cancel() -> void:
	# Best-effort cancel. Canonical undo path is RollbackService.rewind_last_action (P3-T05).
	var restored_old := target.current_hp
	target.current_hp = min(target.current_hp + _damage, target.max_hp)
	target.hp_changed.emit(restored_old, target.current_hp)
	attacker.has_acted = false
