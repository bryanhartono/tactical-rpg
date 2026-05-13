class_name TileInputController extends Node
## Mouse → grid coordinate translator. Raycasts from the active Camera3D through the
## cursor onto the tile colliders set up by BoardView3D (see P1-T04).
##
## Emits `tile_clicked` for every left-click on the board, plus `unit_clicked` when the
## tile is occupied. PlayerPhaseController consumes these. Right-click cancels and is
## emitted as `cancel_pressed`.
##
## `set_enabled(false)` suppresses input during enemy / animation phases.

const _RAY_LENGTH: float = 100.0

@export var board_path: NodePath
@export var camera_path: NodePath

var _board: Board
var _camera: Camera3D
var _enabled: bool = true

signal tile_clicked(grid_pos: Vector2i)
signal unit_clicked(unit: CharacterUnit, grid_pos: Vector2i)
signal cancel_pressed

# Set by BattleManager so we can resolve grid → unit lookups.
func bind(board: Board, camera: Camera3D) -> void:
	_board = board
	_camera = camera

func set_enabled(b: bool) -> void:
	_enabled = b

## Forward a click that originated from a 2D unit region (UnitClickRegion). Keeps
## PlayerPhaseController's listener surface to a single signal regardless of whether
## the click came from a sprite-overlay button or a 3D tile raycast.
func emit_unit_click(unit: CharacterUnit) -> void:
	if not _enabled or unit == null:
		return
	tile_clicked.emit(unit.grid_position)
	unit_clicked.emit(unit, unit.grid_position)

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or _camera == null or _board == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_pressed.emit()

func _handle_left_click(screen_pos: Vector2) -> void:
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * _RAY_LENGTH)
	query.collide_with_bodies = true
	# Also pick UnitView3D ClickAreas so the player can click on the sprite itself,
	# not just the underlying ground. The unit's Area3D carries `unit_id` metadata;
	# the tile's StaticBody3D carries `grid_pos`. Whichever the ray hits first wins.
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider == null:
		return
	# Sprite-area click → resolve to the unit and its tile.
	if collider.has_meta("unit_id"):
		var unit_id: int = collider.get_meta("unit_id")
		var unit := _board.units.get(unit_id) as CharacterUnit
		if unit != null and unit.is_alive():
			tile_clicked.emit(unit.grid_position)
			unit_clicked.emit(unit, unit.grid_position)
		return
	# Plain tile click.
	if collider.has_meta("grid_pos"):
		var grid: Vector2i = collider.get_meta("grid_pos")
		tile_clicked.emit(grid)
		var unit := _board.get_unit_at(grid)
		if unit != null:
			unit_clicked.emit(unit, grid)
