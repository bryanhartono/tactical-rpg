class_name TileInputController extends Node
## Mouse → grid coordinate translator. Intersects the camera ray with the y = 0 board
## plane to determine the clicked grid cell — no physics bodies needed.
##
## Emits `tile_clicked` for every left-click on the board, plus `unit_clicked` when the
## tile is occupied. PlayerPhaseController consumes these. Right-click cancels and is
## emitted as `cancel_pressed`.
##
## `set_enabled(false)` suppresses input during enemy / animation phases.

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
	# Intersect the camera ray with the y = 0 board plane. This avoids the
	# "tall box blocks far tiles" problem that physics raycasting has at low
	# camera angles and is accurate for any flat board.
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	if direction.y >= 0.0:
		return  # Ray points up or sideways — can't hit the board.
	var t := -origin.y / direction.y
	var world_hit := origin + direction * t
	var grid := Vector2i(roundi(world_hit.x), roundi(world_hit.z))
	if not _board.is_in_bounds(grid):
		return
	tile_clicked.emit(grid)
	var unit := _board.get_unit_at(grid) as CharacterUnit
	if unit != null and unit.is_alive():
		unit_clicked.emit(unit, grid)
