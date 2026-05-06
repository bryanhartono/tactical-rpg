class_name BattleManager extends Node
## Drives the battle's phase state machine and ticks subsystems.
## See docs/gdd.md §4.2, §10.2.
##
## Phase 1 hardcodes a 2v2 test battle. BattleMap-driven setup arrives in Phase 14
## once the Battle Map Painter exists.

const _UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/battle/units/unit_view_3d.tscn")
const _PLAYER_DEF_PATH: String = "res://data/characters/aria.tres"
const _ENEMY_DEF_PATH: String = "res://data/characters/bandit.tres"

const _BOARD_WIDTH: int = 10
const _BOARD_HEIGHT: int = 10

enum Phase { NONE, PLAYER, ENEMY, NEUTRAL }

var board: Board
var current_phase: Phase = Phase.NONE
var round_number: int = 0
var battle_over: bool = false

@onready var _board_view: BoardView3D = get_node_or_null("../Board/GridOverlay")
@onready var _units_layer: Node3D = get_node_or_null("../Board/UnitsLayer")
@onready var _battle_camera: Node3D = get_node_or_null("../BattleCamera")
@onready var _tile_input: TileInputController = get_node_or_null("../TileInputController")

## phase_changed exposed locally so PlayerPhaseController and the ActionMenu can react
## without going through the bus (they're tightly coupled to manager state).
signal phase_changed(new_phase: Phase, round_number: int)

# ----------------------------------------------------------------------------
# Bootstrap
# ----------------------------------------------------------------------------

func _ready() -> void:
	# Skip the bootstrap when not embedded in the real BattleScene (e.g. unit tests
	# that instance the manager directly). Tests drive _enter_phase / _check_battle_end
	# manually instead of going through the scene-tree-coupled setup path.
	if _board_view == null or _battle_camera == null or _tile_input == null:
		return
	# Defer the battle setup one frame so the BoardView3D's @onready vars and the
	# autoloads have fully initialized before we start emitting signals.
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	_setup_camera()
	_setup_test_battle()
	_tile_input.bind(board, _battle_camera.get_node("Pivot/Camera3D"))
	start_battle()

func _setup_camera() -> void:
	# Tactical preset (GDD §6.3): far view, ~50° pitch, framed on the board.
	# Place the Pivot at the board center so cycling presets in Phase 9 can keep the
	# pivot fixed while the camera child moves; for now just look_at from a high-Z
	# viewpoint.
	var center := Vector3(_BOARD_WIDTH * 0.5, 0.0, _BOARD_HEIGHT * 0.5)
	_battle_camera.position = center
	var pivot: Node3D = _battle_camera.get_node("Pivot")
	pivot.rotation = Vector3.ZERO
	var cam: Camera3D = pivot.get_node("Camera3D")
	# Sit south of the board (positive Z), elevated. Distance / pitch chosen to fit a
	# 10x10 board in the default 75° FOV with ~10% margin.
	cam.position = Vector3(0, 7.5, 8.5)
	cam.look_at(center, Vector3.UP)

func _setup_test_battle() -> void:
	board = Board.create_flat(_BOARD_WIDTH, _BOARD_HEIGHT)
	_board_view.set_board(board)

	var aria_def: CharacterDefinition = load(_PLAYER_DEF_PATH)
	var bandit_def: CharacterDefinition = load(_ENEMY_DEF_PATH)

	_spawn_unit(1, aria_def, 0, "Aria",  Vector2i(1, 1))
	_spawn_unit(2, aria_def, 0, "Reni",  Vector2i(1, 3))
	_spawn_unit(3, bandit_def, 1, "Bandit A", Vector2i(8, 1))
	_spawn_unit(4, bandit_def, 1, "Bandit B", Vector2i(8, 3))

func _spawn_unit(id: int, definition: CharacterDefinition, team: int, display_name: String, tile: Vector2i) -> void:
	var u := CharacterUnit.new()
	u.unit_id = id
	u.team = team
	u.initialize_from_definition(definition)
	# Override display_name so we can tell same-template units apart in the HP label.
	u.display_name = display_name
	u.grid_position = tile
	u.facing = Vector2i.LEFT if team == 1 else Vector2i.RIGHT
	add_child(u)  # Lives under BattleManager — gameplay-side
	board.units[id] = u
	board.get_tile(tile).occupant_id = id

	var view: UnitView3D = _UNIT_VIEW_SCENE.instantiate()
	view.unit = u
	_units_layer.add_child(view)

# ----------------------------------------------------------------------------
# Phase loop
# ----------------------------------------------------------------------------

func start_battle() -> void:
	round_number = 1
	# TODO(phase 14): pass real BattleMap when authored maps land.
	CombatEventBus.battle_started.emit(null)
	_enter_phase(Phase.PLAYER)

func advance_phase() -> void:
	if battle_over:
		return
	match current_phase:
		Phase.PLAYER:  _enter_phase(Phase.ENEMY)
		Phase.ENEMY:   _enter_phase(Phase.NEUTRAL)
		Phase.NEUTRAL:
			round_number += 1
			_enter_phase(Phase.PLAYER)

func _enter_phase(p: Phase) -> void:
	if current_phase != Phase.NONE:
		CombatEventBus.phase_ended.emit(_phase_name(current_phase), round_number)
	current_phase = p
	var phase_name := _phase_name(p)
	CombatEventBus.phase_started.emit(phase_name, round_number)
	phase_changed.emit(p, round_number)
	_reset_turn_state(p)
	_check_battle_end()
	if battle_over:
		return

	# Hand off to AI for the enemy phase. AIController.run_enemy_phase is async; it
	# calls back to advance_phase() when done.
	if p == Phase.ENEMY:
		AIController.run_enemy_phase(self)
	elif p == Phase.NEUTRAL:
		# Phase 1: nothing happens in neutral phase. Phase 8 adds terrain hazards /
		# status ticks here.
		advance_phase()

func _reset_turn_state(p: Phase) -> void:
	for unit in board.units.values():
		var u := unit as CharacterUnit
		if u == null or not u.is_alive():
			continue
		if (p == Phase.PLAYER and u.team == 0) or (p == Phase.ENEMY and u.team == 1):
			u.reset_for_new_turn()
			CombatEventBus.turn_started.emit(u)

# ----------------------------------------------------------------------------
# End-of-battle check
# ----------------------------------------------------------------------------

func _check_battle_end() -> void:
	var alive_players := 0
	var alive_enemies := 0
	for unit in board.units.values():
		var u := unit as CharacterUnit
		if u == null or not u.is_alive():
			continue
		if u.team == 0:
			alive_players += 1
		else:
			alive_enemies += 1
	if alive_enemies == 0:
		battle_over = true
		CombatEventBus.battle_ended.emit("victory")
	elif alive_players == 0:
		battle_over = true
		CombatEventBus.battle_ended.emit("defeat")

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

## Returns the alive units of `team`. Used by AIController and PlayerPhaseController.
func get_alive_team(team: int) -> Array[CharacterUnit]:
	var result: Array[CharacterUnit] = []
	for unit in board.units.values():
		var u := unit as CharacterUnit
		if u != null and u.is_alive() and u.team == team:
			result.append(u)
	return result

## True if every player unit has acted this phase. PlayerPhaseController calls this
## after each command to auto-advance the phase.
func all_players_acted() -> bool:
	for u in get_alive_team(0):
		if not u.has_acted:
			return false
	return true

static func _phase_name(p: Phase) -> String:
	match p:
		Phase.PLAYER: return "player"
		Phase.ENEMY:  return "enemy"
		Phase.NEUTRAL: return "neutral"
		_: return "none"
