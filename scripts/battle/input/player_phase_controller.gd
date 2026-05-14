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
var _move_targets: Array[Vector2i] = []
var _attack_targets: Array[CharacterUnit] = []

## Public accessor for the currently-selected unit. Used by CameraInputController so it
## doesn't have to reach into `_selected` directly (private-by-convention).
func get_selected_unit() -> CharacterUnit:
	return _selected

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
	_menu.move_chosen.connect(_on_move_chosen)
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
	# Only own, alive, unacted units can be selected. If we're targeting an attack and
	# the click landed on an enemy unit in range, fall through to the tile handler.
	if _state == State.TARGETING_ATTACK and unit.team != _selected.team and _attack_targets.has(unit):
		_resolve_attack(unit)
		return
	if unit.team != 0 or not unit.is_alive() or unit.has_acted:
		return
	_select_unit(unit)

func _on_tile_clicked(grid: Vector2i) -> void:
	match _state:
		State.TARGETING_MOVE:
			if _move_targets.has(grid):
				_resolve_move(grid)
		State.TARGETING_ATTACK:
			# Attacks resolve via the unit_clicked path; clicking a non-occupant tile
			# in attack-targeting state is a no-op (treat as "deselect target" later).
			pass
		_:
			pass

func _on_cancel_pressed() -> void:
	_to_unit_selected_or_idle()

# ----------------------------------------------------------------------------
# Menu choice handlers
# ----------------------------------------------------------------------------

func _on_move_chosen() -> void:
	if _selected == null or _selected.has_acted:
		return
	_state = State.TARGETING_MOVE
	_menu.hide_menu()
	var reachable := Pathfinder.compute_reachable(_manager.board, _selected.grid_position, _selected.move_budget)
	_move_targets.clear()
	for tile in reachable.keys():
		if tile != _selected.grid_position:
			_move_targets.append(tile)
	_board_view.clear_highlights()
	_board_view.set_grid_visible(true)
	_board_view.highlight_tiles(_move_targets, _MOVE_COLOR)

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
	CommandQueue.submit(WaitCommand.new(_selected))
	_after_action_committed()

# ----------------------------------------------------------------------------
# Command resolution
# ----------------------------------------------------------------------------

func _resolve_move(grid: Vector2i) -> void:
	var ok := CommandQueue.submit(MoveCommand.new(_manager.board, _selected, grid))
	_board_view.clear_highlights()
	if ok and not _selected.has_acted:
		# Await the visual move so the menu doesn't pop while the unit is mid-stride.
		var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
		if view != null:
			await view.animation_complete
		# Re-select to refresh menu (move alone doesn't end the turn — Move + Action + Face).
		if is_instance_valid(_selected) and _selected.is_alive() and not _selected.has_acted:
			_select_unit(_selected)
		else:
			_to_idle()
	else:
		_to_idle()
	_maybe_end_phase()

func _resolve_attack(target: CharacterUnit) -> void:
	CommandQueue.submit(AttackCommand.new(_manager.board, _selected, target))
	_board_view.clear_highlights()
	# Hold the menu / state transition until the attack animation resolves.
	var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
	if view != null:
		await view.animation_complete
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
	_selected = unit
	_state = State.UNIT_SELECTED
	_board_view.clear_highlights()
	_board_view.set_grid_visible(false)
	var can_move := not unit.has_acted
	var can_attack := not unit.has_acted and not _find_attack_targets(unit).is_empty()
	_menu.show_for_unit(unit, can_move, can_attack)
	if _status_panel != null:
		_status_panel.show_for_unit(unit)

func _to_unit_selected_or_idle() -> void:
	# Cancel from a targeting state pops back to the menu if the unit's still actionable;
	# otherwise drops to idle.
	_board_view.clear_highlights()
	if _selected != null and _selected.is_alive() and not _selected.has_acted:
		_select_unit(_selected)
	else:
		_to_idle()

func _to_idle() -> void:
	_state = State.IDLE
	_selected = null
	_move_targets.clear()
	_attack_targets.clear()
	_menu.hide_menu()
	if _status_panel != null:
		_status_panel.hide_panel()
	_board_view.clear_highlights()
	_board_view.set_grid_visible(false)

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
		_damage_preview.show_preview(_selected, hovered, get_viewport().get_mouse_position())

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
