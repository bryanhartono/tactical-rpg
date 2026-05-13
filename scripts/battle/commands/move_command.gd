class_name MoveCommand extends Command
## Move a unit to a destination tile within their move budget.
## See docs/gdd.md §10.4.
##
## Phase 1 mutates Board state synchronously. Phase 2 will await BoardController →
## UnitView3D tween completion before the gameplay state mutates so the view stays
## ahead of the model briefly.

var board: Board
var unit: CharacterUnit
var destination: Vector2i

# Computed in prepare().
var _path: Array[Vector2i] = []
var _origin: Vector2i

func _init(p_board: Board, p_unit: CharacterUnit, p_destination: Vector2i) -> void:
	board = p_board
	unit = p_unit
	destination = p_destination

func validate() -> bool:
	if unit == null or board == null:
		return false
	if unit.has_acted:
		return false
	if not board.is_in_bounds(destination):
		return false
	var reachable := Pathfinder.compute_reachable(board, unit.grid_position, unit.move_budget)
	return reachable.has(destination)

func prepare() -> void:
	_origin = unit.grid_position
	_path = Pathfinder.path_to(board, _origin, destination, unit.move_budget)

func execute() -> void:
	var origin_tile := board.get_tile(_origin)
	var dest_tile := board.get_tile(destination)
	origin_tile.occupant_id = -1
	dest_tile.occupant_id = unit.unit_id
	unit.grid_position = destination
	# Stamp the path on the unit so UnitView3D (Phase 2) can walk along it.
	unit.last_move_path = _path.duplicate()
	# Face along the last step of the path.
	if _path.size() >= 2:
		unit.facing = _path[-1] - _path[-2]
		unit.facing_changed.emit(unit.facing)
	unit.moved.emit(_origin, destination)

func complete() -> void:
	# No bus signal for moved in Phase 1 — local signal is sufficient. Add to
	# CombatEventBus if a service needs it later.
	pass

func cancel() -> void:
	# Reverse the mutation. Phase 3's RollbackService consumes this.
	var origin_tile := board.get_tile(_origin)
	var dest_tile := board.get_tile(destination)
	dest_tile.occupant_id = -1
	origin_tile.occupant_id = unit.unit_id
	unit.grid_position = _origin
	unit.moved.emit(destination, _origin)
