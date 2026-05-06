class_name Board extends Resource
## Grid of tiles + a runtime registry of units. Pure data — BoardView3D renders it.
## See docs/gdd.md §5.1, §10.1 (principle 3), §10.2.
##
## Phase 1 owns the data model only. Mutating methods (move unit, kill unit, etc.) live
## on Commands and the Phase 3 BoardController; this resource exposes read-only queries.

@export var width: int = 0
@export var height: int = 0
## Row-major flat array of Tile resources, length width * height.
## Typed as plain Array (not Array[Tile]) to avoid Godot 4 Resource serialization edge
## cases with typed arrays of nested Resources.
@export var tiles: Array = []

## Runtime unit registry. Key: int unit_id. Value: CharacterUnit Node.
## NOT @export — populated when units register themselves with the board, not part of
## the persisted Resource. Phase 3 snapshots will handle this dict separately.
var units: Dictionary = {}

## Returns the Tile at `pos`, or null if out of bounds.
func get_tile(pos: Vector2i) -> Tile:
	if not is_in_bounds(pos):
		return null
	return tiles[pos.y * width + pos.x]

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

## Returns the CharacterUnit on `pos`, or null if the tile is empty / out of bounds.
func get_unit_at(pos: Vector2i) -> Node:
	var t := get_tile(pos)
	if t == null or t.occupant_id < 0:
		return null
	return units.get(t.occupant_id)

## Returns the in-bounds 4-cardinal neighbors of `pos`.
func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for delta in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var n: Vector2i = pos + delta
		if is_in_bounds(n):
			result.append(n)
	return result

# Self-preload so static factory functions can construct instances of this class.
# Godot 4.6's parser cannot resolve `Board` as an identifier from inside a static
# method on Board itself — the class_name registers globally only after parse finishes.
const _SelfScript: GDScript = preload("res://scripts/battle/board/board.gd")

## Builds a fresh `width x height` Board with all tiles at landform 0 and no occupants.
## Used by BattleManager to set up Phase 1's test map.
static func create_flat(p_width: int, p_height: int) -> Board:
	var b: Board = _SelfScript.new()
	b.width = p_width
	b.height = p_height
	b.tiles = []
	b.tiles.resize(p_width * p_height)
	for y in p_height:
		for x in p_width:
			var t := Tile.new()
			t.position = Vector2i(x, y)
			t.landform_id = 0
			t.occupant_id = -1
			b.tiles[y * p_width + x] = t
	return b
