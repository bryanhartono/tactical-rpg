class_name CharacterUnit extends Node
## Gameplay-side unit coordinator. Owns three components (StatsComponent,
## WeaponSlotComponent, PositionComponent) and exposes convenience accessors that
## preserve the full public interface from Phases 1-2.
## External code (commands, views, tests) accesses unit.atk, unit.grid_position, etc.
## directly — the getters/setters delegate to the appropriate component.
## See docs/gdd.md §7.7, §10.1 (principle 2).

# --- Identity (stays on coordinator, not in any component) ---
@export var unit_id: int = -1
@export var display_name: String = ""
## 0 = player, 1 = enemy.
@export var team: int = 0
@export var character_definition: CharacterDefinition

# --- Turn state ---
## True after this unit has used their action for the current phase.
## Move alone does not set this — only Attack / Wait do. (GDD §4.3.)
var has_acted: bool = false
## True after this unit has moved this phase. Prevents double-move.
var has_moved: bool = false

# --- Components (created in _init so accessors work before _ready fires) ---
var _stats: StatsComponent
var _weapon_slot: WeaponSlotComponent
var _position_comp: PositionComponent

# --- Stats convenience accessors (delegate to StatsComponent) ---
var max_hp: int:
	get: return _stats.max_hp
	set(v): _stats.max_hp = v

var current_hp: int:
	get: return _stats.current_hp
	set(v): _stats.current_hp = v

var max_mp: int:
	get: return _stats.max_mp
	set(v): _stats.max_mp = v

var current_mp: int:
	get: return _stats.current_mp
	set(v): _stats.current_mp = v

var atk: int:
	get: return _stats.atk
	set(v): _stats.atk = v

var def: int:
	get: return _stats.def
	set(v): _stats.def = v

var skill: int:
	get: return _stats.skill
	set(v): _stats.skill = v

var speed: int:
	get: return _stats.speed
	set(v): _stats.speed = v

var luck: int:
	get: return _stats.luck
	set(v): _stats.luck = v

var avoid: int:
	get: return _stats.avoid
	set(v): _stats.avoid = v

# --- Position convenience accessors (delegate to PositionComponent) ---
var grid_position: Vector2i:
	get: return _position_comp.grid_position
	set(v): _position_comp.grid_position = v

var facing: Vector2i:
	get: return _position_comp.facing
	set(v): _position_comp.facing = v

var move_budget: int:
	get: return _position_comp.move_budget
	set(v): _position_comp.move_budget = v

var last_move_path: Array[Vector2i]:
	get: return _position_comp.last_move_path
	set(v): _position_comp.last_move_path = v

# --- Weapon convenience accessor (delegates to WeaponSlotComponent) ---
var main_weapon: Weapon:
	get: return _weapon_slot.main_weapon
	set(v): _weapon_slot.main_weapon = v

# --- Local signals (CombatEventBus is for cross-cutting services).
## Signals always live on CharacterUnit, never on components. ---
## Emitted whenever HP changes, including healing.
signal hp_changed(old_hp: int, new_hp: int)
## Emitted after grid_position is updated.
@warning_ignore("unused_signal")
signal moved(from_tile: Vector2i, to_tile: Vector2i)
## Emitted after facing is updated.
@warning_ignore("unused_signal")
signal facing_changed(new_facing: Vector2i)
## Emitted exactly once when current_hp first reaches 0.
signal died
## Emitted from AttackCommand before damage resolves. View listens to play attack animation.
@warning_ignore("unused_signal")
signal attacked(target: CharacterUnit)

# ----------------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------------

func _init() -> void:
	_stats = StatsComponent.new()
	_weapon_slot = WeaponSlotComponent.new()
	_position_comp = PositionComponent.new()

# ----------------------------------------------------------------------------
# Queries
# ----------------------------------------------------------------------------

func is_alive() -> bool:
	return _stats.is_alive()

func is_player() -> bool:
	return team == 0

func is_enemy() -> bool:
	return team == 1

## Returns the active weapon from WeaponSlotComponent. Phase 4 adds sub-weapon support.
func active_weapon() -> Weapon:
	return _weapon_slot.active_weapon()

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
	_stats.take_damage(amount)
	hp_changed.emit(old_hp, current_hp)
	if current_hp == 0:
		died.emit()
		CombatEventBus.unit_killed.emit(null, self, source)

func reset_for_new_turn() -> void:
	has_acted = false
	has_moved = false

## Layer style base + character base + main weapon onto the live stats.
## Populates all three components from the CharacterDefinition resource.
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

	# StatsComponent: base stats. Growth-on-level-up is Phase 5.
	_stats.max_hp = style.base_hp + cd.base_hp
	_stats.current_hp = _stats.max_hp
	_stats.atk = style.base_atk + cd.base_atk
	_stats.def = style.base_def + cd.base_def
	_stats.skill = style.base_skill + cd.base_skill
	_stats.speed = style.base_speed + cd.base_speed
	_stats.luck = style.base_luck + cd.base_luck
	@warning_ignore("integer_division")
	_stats.avoid = _stats.speed + _stats.luck / 2

	# PositionComponent: move budget from locomotion type.
	# TODO(phase 8): replace with locomotion data lookup.
	_position_comp.move_type = style.move_type
	match style.move_type:
		StyleDefinition.MoveType.INFANTRY, StyleDefinition.MoveType.ADVANCED_INFANTRY:
			_position_comp.move_budget = 5
		StyleDefinition.MoveType.CAVALRY, StyleDefinition.MoveType.ADVANCED_CAVALRY:
			_position_comp.move_budget = 7
		StyleDefinition.MoveType.FLYING, StyleDefinition.MoveType.ADVANCED_FLYING:
			_position_comp.move_budget = 6
		StyleDefinition.MoveType.FLOATING:
			_position_comp.move_budget = 5
		_:
			_position_comp.move_budget = 5

	# WeaponSlotComponent: main weapon only for Phase 1-3.
	_weapon_slot.main_weapon = cd.default_main_weapon
