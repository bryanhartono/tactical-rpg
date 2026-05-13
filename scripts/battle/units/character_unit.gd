class_name CharacterUnit extends Node
## Gameplay-side unit. Tracks stats, position, facing, equipment.
## The visual representation is UnitView3D (separate node) listening to this node's
## local signals. See docs/gdd.md §7.7, §10.1 (principle 4).
##
## Phase 1 keeps stats inline. Phase 3 splits them into StatsComponent /
## WeaponSlotComponent / etc. (composition over inheritance). Inlined now to ship the
## slice; the split happens alongside the Phase 3 simulator extraction.
## TODO(phase 3): split stats and equipment into components.

# --- Identity ---
@export var unit_id: int = -1
@export var display_name: String = ""
## 0 = player, 1 = enemy. More teams later (e.g. neutral guests).
@export var team: int = 0
@export var character_definition: CharacterDefinition

# --- Position and facing ---
var grid_position: Vector2i = Vector2i.ZERO
## Gameplay-facing. Phase 1 doesn't consult this in the damage formula; Phase 5 does.
var facing: Vector2i = Vector2i.RIGHT

# --- Stats (current). Layered: style base + character base + level growth.
# Phase 5 wires growth on level up. ---
var max_hp: int = 0
var current_hp: int = 0
var atk: int = 0
var def: int = 0
## How many tile-units they can move this turn.
var move_budget: int = 0

# --- Equipment (Phase 1: main weapon only; sub weapon arrives Phase 4) ---
var main_weapon: Weapon

# --- Turn state ---
## True after this unit has used their action for the current phase. Move alone does not
## set this — only Attack / Wait do. (See GDD §4.3: Move + Action + Face.)
var has_acted: bool = false

# --- Local signals (CombatEventBus is for cross-cutting services) ---
## Emitted whenever HP changes, including healing. Receivers: UnitView3D.
signal hp_changed(old_hp: int, new_hp: int)
## Emitted after grid_position is updated. Phase 1: instant; Phase 2: view tweens.
signal moved(from_tile: Vector2i, to_tile: Vector2i)
## Emitted after facing is updated.
signal facing_changed(new_facing: Vector2i)
## Emitted exactly once when current_hp first reaches 0.
signal died
## Emitted from AttackCommand BEFORE damage resolves on the target. The view layer
## listens to play the attacker's attack animation. Bus-side observers should listen
## to CombatEventBus.damage_dealt instead — this signal is intentionally local.
signal attacked(target: CharacterUnit)

# Phase 2 view affordance: the most recent move's path, in tile coords (origin first,
# destination last). MoveCommand sets this before emitting `moved`; UnitView3D walks
# along it. Documented as a deliberate small leak of view concerns into the gameplay
# node — the cleaner "pass via signal payload" alternative was considered and rejected
# because the signal is also used by RollbackService etc. that don't need the path.
var last_move_path: Array[Vector2i] = []

# ----------------------------------------------------------------------------
# Queries
# ----------------------------------------------------------------------------

func is_alive() -> bool:
	return current_hp > 0

func is_player() -> bool:
	return team == 0

func is_enemy() -> bool:
	return team == 1

# ----------------------------------------------------------------------------
# Mutations
# ----------------------------------------------------------------------------

## Apply `amount` damage. Clamps to [0, max_hp]. Emits hp_changed.
## On lethal (alive→dead transition), emits died and CombatEventBus.unit_killed.
## This is the ONLY HP-mutating method; combat resolution always goes through here.
func take_damage(amount: int, source: Resource = null) -> void:
	if amount <= 0 or not is_alive():
		return
	var old_hp := current_hp
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(old_hp, current_hp)
	if current_hp == 0:
		died.emit()
		# `null` attacker is acceptable here: take_damage doesn't know who hit; the
		# emitting Command should also fire damage_dealt with the attacker. unit_killed's
		# attacker-side observers (BattleLog, future EXP) get attacker via context.
		CombatEventBus.unit_killed.emit(null, self, source)

func reset_for_new_turn() -> void:
	has_acted = false

## Layer style base + character base + main weapon onto the live stats. Called once at
## spawn. Phase 5 will add growth-rate level-ups and equipment swaps.
func initialize_from_definition(cd: CharacterDefinition) -> void:
	if cd == null:
		push_error("CharacterUnit.initialize_from_definition: definition is null")
		return
	character_definition = cd
	display_name = cd.display_name

	var style := cd.default_style
	if style == null:
		push_error("CharacterDefinition '%s' has no default_style" % cd.display_name)
		return

	# Stat layering: style base + character base. Growth-on-level-up is Phase 5.
	max_hp = style.base_hp + cd.base_hp
	current_hp = max_hp
	atk = style.base_atk + cd.base_atk
	def = style.base_def + cd.base_def

	# Move budget per locomotion type. Phase 1 hardcodes the table; Phase 8 reads
	# proper values from a movetype-data resource.
	# TODO(phase 8): replace with locomotion data lookup.
	match style.move_type:
		StyleDefinition.MoveType.INFANTRY, StyleDefinition.MoveType.ADVANCED_INFANTRY:
			move_budget = 5
		StyleDefinition.MoveType.CAVALRY, StyleDefinition.MoveType.ADVANCED_CAVALRY:
			move_budget = 7
		StyleDefinition.MoveType.FLYING, StyleDefinition.MoveType.ADVANCED_FLYING:
			move_budget = 6
		StyleDefinition.MoveType.FLOATING:
			move_budget = 5
		_:
			move_budget = 5

	main_weapon = cd.default_main_weapon
