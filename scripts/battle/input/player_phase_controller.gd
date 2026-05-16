class_name PlayerPhaseController extends Node
## State machine that drives a player phase: select unit → menu → target → command.
## See docs/gdd.md §4.3.
##
## Reads tile / unit clicks from TileInputController, action choices from ActionMenu,
## builds Commands, submits them to CommandQueue, and asks BattleManager to advance the
## phase when every player unit has acted.

const _MOVE_COLOR: Color = Color(0.30, 0.85, 0.40)
const _ATTACK_COLOR: Color = Color(0.95, 0.30, 0.30)

enum State { IDLE, UNIT_SELECTED, TARGETING_MOVE, TARGETING_ATTACK }

@export var manager_path: NodePath
@export var input_path: NodePath
@export var board_view_path: NodePath
@export var action_menu_path: NodePath
@export var damage_preview_path: NodePath
@export var status_panel_path: NodePath

var _manager: BattleManager
var _input: TileInputController
var _board_view: BoardView3D
var _menu: ActionMenu
var _damage_preview: Node           # DamagePreview; typed loose to avoid load-order issues
var _status_panel: Node             # UnitStatusPanel; loose-typed for the same reason

var _state: State = State.IDLE
var _selected: CharacterUnit
## Tile the selected unit occupied when it was first clicked. Tentative moves keep the
## unit's grid_position updated, but Cancel snaps back here.
var _selection_origin: Vector2i = Vector2i.ZERO
var _move_targets: Array[Vector2i] = []
var _attack_targets: Array[CharacterUnit] = []

## Public accessor for the currently-selected unit. Used by CameraInputController so it
## doesn't have to reach into `_selected` directly (private-by-convention).
func get_selected_unit() -> CharacterUnit:
	return _selected

## Called by CameraInputController when pan mode is enabled. Snaps any tentative move
## back to origin and clears all selection UI so the board is clean during panning.
func cancel_selection() -> void:
	_snap_unit_to_origin()
	_to_idle()

func _ready() -> void:
	_manager = get_node(manager_path)
	_input = get_node(input_path)
	_board_view = get_node(board_view_path)
	_menu = get_node(action_menu_path)
	if damage_preview_path != NodePath(""):
		_damage_preview = get_node(damage_preview_path)
	if status_panel_path != NodePath(""):
		_status_panel = get_node(status_panel_path)

	_input.tile_clicked.connect(_on_tile_clicked)
	_input.unit_clicked.connect(_on_unit_clicked)
	_input.cancel_pressed.connect(_on_cancel_pressed)
	_menu.attack_chosen.connect(_on_attack_chosen)
	_menu.wait_chosen.connect(_on_wait_chosen)
	_menu.cancel_chosen.connect(_on_cancel_pressed)
	_manager.phase_changed.connect(_on_phase_changed)

# ----------------------------------------------------------------------------
# Phase gating
# ----------------------------------------------------------------------------

func _on_phase_changed(p: int, _round: int) -> void:
	# Re-enable input only on player phase, otherwise suppress and clear UI state.
	if p == BattleManager.Phase.PLAYER:
		_input.set_enabled(true)
	else:
		_input.set_enabled(false)
		_to_idle()

# ----------------------------------------------------------------------------
# Input handlers
# ----------------------------------------------------------------------------

func _on_unit_clicked(unit: CharacterUnit, _grid: Vector2i) -> void:
	if _state == State.TARGETING_ATTACK and unit.team != _selected.team and _attack_targets.has(unit):
		_resolve_attack(unit)
		return
	if unit.team != 0 or not unit.is_alive() or unit.has_acted:
		return
	if _state == State.UNIT_SELECTED:
		if unit == _selected:
			return
		_snap_unit_to_origin()  # Snap previous unit before switching selection.
	_select_unit(unit)

func _on_tile_clicked(grid: Vector2i) -> void:
	match _state:
		State.UNIT_SELECTED:
			if _move_targets.has(grid):
				_do_tentative_move(grid)
		State.TARGETING_ATTACK:
			pass
		_:
			pass

func _on_cancel_pressed() -> void:
	if _state == State.UNIT_SELECTED:
		_snap_unit_to_origin()
		_to_idle()
	elif _state == State.TARGETING_ATTACK:
		# Pop back to UNIT_SELECTED, restore move highlights without resetting origin.
		_state = State.UNIT_SELECTED
		_board_view.clear_highlights()
		_board_view.set_grid_visible(true)
		_board_view.highlight_tiles(_move_targets, _MOVE_COLOR)
		var can_attack := not _selected.has_acted
		_menu.show_for_unit(_selected, false, can_attack)
	else:
		_to_idle()

# ----------------------------------------------------------------------------
# Menu choice handlers
# ----------------------------------------------------------------------------

func _on_attack_chosen() -> void:
	if _selected == null:
		return
	_state = State.TARGETING_ATTACK
	_menu.hide_menu()
	_attack_targets = _find_attack_targets(_selected)
	_board_view.clear_highlights()
	_board_view.set_grid_visible(true)
	var tiles: Array[Vector2i] = []
	for u in _attack_targets:
		tiles.append(u.grid_position)
	_board_view.highlight_tiles(tiles, _ATTACK_COLOR)

func _on_wait_chosen() -> void:
	if _selected == null:
		return
	var dest := _selected.grid_position
	_snap_unit_to_origin()
	if dest != _selection_origin:
		# Convert tentative move to a real command (no new snapshot — already snapshotted on select).
		_selected.has_moved = false
		var ok := CommandQueue.submit_presnapshot(MoveCommand.new(_manager.board, _selected, dest))
		if ok:
			var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
			if view != null:
				await view.animation_complete
	CommandQueue.submit_presnapshot(WaitCommand.new(_selected))
	_after_action_committed()

# ----------------------------------------------------------------------------
# Command resolution
# ----------------------------------------------------------------------------

func _resolve_attack(target: CharacterUnit) -> void:
	var dest := _selected.grid_position
	_snap_unit_to_origin()
	if dest != _selection_origin:
		_selected.has_moved = false
		var ok := CommandQueue.submit_presnapshot(MoveCommand.new(_manager.board, _selected, dest))
		if ok:
			var move_view: UnitView3D = _manager.get_view_for(_selected.unit_id)
			if move_view != null:
				await move_view.animation_complete
	if not is_instance_valid(_selected) or not _selected.is_alive():
		_to_idle()
		_maybe_end_phase()
		return
	_board_view.clear_highlights()
	CommandQueue.submit_presnapshot(AttackCommand.new(_manager.board, _selected, target))
	var atk_view: UnitView3D = _manager.get_view_for(_selected.unit_id)
	if atk_view != null:
		await atk_view.animation_complete
	_to_idle()
	_maybe_end_phase()

func _after_action_committed() -> void:
	_board_view.clear_highlights()
	_to_idle()
	_maybe_end_phase()

# ----------------------------------------------------------------------------
# Selection / state transitions
# ----------------------------------------------------------------------------

func _select_unit(unit: CharacterUnit) -> void:
	# Snapshot current board state so one rewind restores everything done this selection.
	RollbackService.snapshot_before_command(null)
	_selected = unit
	_selection_origin = unit.grid_position
	_state = State.UNIT_SELECTED
	# Compute reachable tiles from origin and show immediately — no Move button needed.
	var reachable := Pathfinder.compute_reachable(_manager.board, _selection_origin, unit.move_budget)
	_move_targets.clear()
	for tile in reachable.keys():
		_move_targets.append(tile)
	_board_view.clear_highlights()
	_board_view.set_grid_visible(true)
	_board_view.highlight_tiles(_move_targets, _MOVE_COLOR)
	var can_attack := not unit.has_acted
	_menu.show_for_unit(unit, false, can_attack)
	if _status_panel != null:
		_status_panel.show_for_unit(unit)

func _to_idle() -> void:
	_state = State.IDLE
	_selected = null
	_selection_origin = Vector2i.ZERO
	_move_targets.clear()
	_attack_targets.clear()
	_menu.hide_menu()
	if _status_panel != null:
		_status_panel.hide_panel()
	_board_view.clear_highlights()
	_board_view.set_grid_visible(false)

## Move the selected unit back to _selection_origin, undoing any tentative repositioning.
func _snap_unit_to_origin() -> void:
	if _selected == null or _selection_origin == _selected.grid_position:
		return
	var board := _manager.board
	board.get_tile(_selected.grid_position).occupant_id = -1
	_selected.grid_position = _selection_origin
	board.get_tile(_selection_origin).occupant_id = _selected.unit_id
	var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
	if view != null:
		view.snap_to_unit()

## Move the selected unit to `grid` directly (bypassing CommandQueue). The highlight
## tiles remain visible so the player can freely reposition before committing.
func _do_tentative_move(grid: Vector2i) -> void:
	if _selected == null or grid == _selected.grid_position:
		return
	var board := _manager.board
	board.get_tile(_selected.grid_position).occupant_id = -1
	_selected.grid_position = grid
	board.get_tile(grid).occupant_id = _selected.unit_id
	var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
	if view != null:
		view.snap_to_unit()

func _maybe_end_phase() -> void:
	if _manager.all_players_acted():
		_to_idle()
		_manager.advance_phase()

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _find_attack_targets(unit: CharacterUnit) -> Array[CharacterUnit]:
	var result: Array[CharacterUnit] = []
	if unit.main_weapon == null:
		return result
	var shape := RangeShapeResolver.get_shape_by_id(unit.main_weapon.range_shape_id)
	if shape == null:
		return result
	var tiles := RangeShapeResolver.resolve(shape, unit.grid_position, unit.facing)
	for tile in tiles:
		var u := _manager.board.get_unit_at(tile)
		if u != null and u.team != unit.team and u.is_alive():
			result.append(u)
	return result

# ----------------------------------------------------------------------------
# Damage preview hover (Phase 1: poll the cursor each frame in TARGETING_ATTACK)
# ----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _damage_preview == null:
		return
	if _state != State.TARGETING_ATTACK:
		_damage_preview.hide_preview()
		return
	var hovered := _hovered_target()
	if hovered == null:
		_damage_preview.hide_preview()
	else:
		_damage_preview.show_preview(_selected, hovered,
				get_viewport().get_mouse_position(), _manager.board)

func _hovered_target() -> CharacterUnit:
	var cam := _manager.get_node("../BattleCamera/Pivot/Camera3D") as Camera3D
	if cam == null:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse_pos)
	var direction := cam.project_ray_normal(mouse_pos)
	if direction.y >= 0.0:
		return null
	var t := -origin.y / direction.y
	var world_hit := origin + direction * t
	var grid := Vector2i(roundi(world_hit.x), roundi(world_hit.z))
	if not _manager.board.is_in_bounds(grid):
		return null
	var u := _manager.board.get_unit_at(grid) as CharacterUnit
	if u != null and _attack_targets.has(u):
		return u
	return null
