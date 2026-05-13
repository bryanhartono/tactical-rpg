class_name BattleManager extends Node
## Drives the battle's phase state machine and ticks subsystems.
## See docs/gdd.md §4.2, §10.2.
##
## Phase 1 hardcodes a 2v2 test battle. BattleMap-driven setup arrives in Phase 14
## once the Battle Map Painter exists.

const _UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/battle/units/unit_view_3d.tscn")
const _PLAYER_DEF_PATH: String = "res://data/characters/aria.tres"
const _ENEMY_DEF_PATH: String = "res://data/characters/bandit.tres"
const _PLAYER_FRAMES_PATH: String = "res://art/sprites/warrior/warrior.tres"
const _ENEMY_FRAMES_PATH: String = "res://art/sprites/skeleton/skeleton.tres"

const _BOARD_WIDTH: int = 10
const _BOARD_HEIGHT: int = 10

enum Phase { NONE, PLAYER, ENEMY, NEUTRAL }

var board: Board
var current_phase: Phase = Phase.NONE
var round_number: int = 0
var battle_over: bool = false
## Lookup from unit_id to UnitView3D, populated at spawn. Used by PlayerPhaseController
## and AIController to await view animations between commands.
var _views_by_unit_id: Dictionary = {}

@onready var _board_view: BoardView3D = get_node_or_null("../Board/GridOverlay")
@onready var _units_layer: Node3D = get_node_or_null("../Board/UnitsLayer")
@onready var _battle_camera: Node3D = get_node_or_null("../BattleCamera")
@onready var _tile_input: TileInputController = get_node_or_null("../TileInputController")
@onready var _click_layer: Control = get_node_or_null("../BattleUI/UnitClickLayer")

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
	# Auto-focus the camera on each enemy as their turn starts (player phase stays
	# user-controlled; F focuses on the selected unit there).
	CombatEventBus.turn_started.connect(_on_turn_started)
	start_battle()

func _on_turn_started(unit: CharacterUnit) -> void:
	if current_phase != Phase.ENEMY:
		return
	if _battle_camera == null or unit == null:
		return
	if _battle_camera.has_method("focus_on_unit"):
		_battle_camera.focus_on_unit(unit, 0.4)

func _setup_camera() -> void:
	# Position the camera rig at the board center; orientation/zoom come from the
	# active CameraSetting via BattleCamera._apply_setting_instant in T07.
	var center := Vector3((_BOARD_WIDTH - 1) * 0.5, 0.0, (_BOARD_HEIGHT - 1) * 0.5)
	_battle_camera.position = center

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
	view.sprite_frames_resource = load(_PLAYER_FRAMES_PATH if team == 0 else _ENEMY_FRAMES_PATH)
	_units_layer.add_child(view)
	_views_by_unit_id[id] = view

	# Per-unit 2D click region (Button) — tracks the sprite's screen rect every frame
	# so the clickable area always matches what the player sees.
	if _click_layer != null:
		var cam: Camera3D = _battle_camera.get_node("Pivot/Camera3D")
		var region := UnitClickRegion.new()
		region.name = "ClickRegion_%d" % id
		region.unit = u
		region.camera = cam
		region.clicked.connect(_on_unit_region_clicked)
		_click_layer.add_child(region)

func _on_unit_region_clicked(unit: CharacterUnit) -> void:
	# Forward through TileInputController so PlayerPhaseController only has to listen
	# to one source of truth for unit clicks.
	if _tile_input != null and _tile_input.has_method("emit_unit_click"):
		_tile_input.emit_unit_click(unit)

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

## Returns the UnitView3D associated with `unit_id`, or null if the unit has been
## freed (e.g. died and queue_free'd). Used by orchestration code that awaits view
## animations between commands.
func get_view_for(unit_id: int) -> UnitView3D:
	var view = _views_by_unit_id.get(unit_id)
	if view != null and is_instance_valid(view):
		return view
	return null

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
