class_name P1TestHelpers
## Shared helpers for Phase 1 GUT tests. Builds boards and units without going through
## the BattleManager scene (so tests stay isolated and fast).

const _ARIA_PATH := "res://data/characters/aria.tres"
const _BANDIT_PATH := "res://data/characters/bandit.tres"

static func make_unit(unit_id: int, team: int, grid: Vector2i, def_path: String = _ARIA_PATH) -> CharacterUnit:
	var cd: CharacterDefinition = load(def_path)
	var u := CharacterUnit.new()
	u.unit_id = unit_id
	u.team = team
	u.initialize_from_definition(cd)
	u.grid_position = grid
	return u

static func register(board: Board, unit: CharacterUnit) -> void:
	board.units[unit.unit_id] = unit
	board.get_tile(unit.grid_position).occupant_id = unit.unit_id

static func make_board_with_units(width: int, height: int, units: Array[CharacterUnit]) -> Board:
	var b: Board = Board.create_flat(width, height)
	for u in units:
		register(b, u)
	return b
