extends GutTest
## P1-T07: RangeShapeResolver + P1-T09 melee_1 shape.

func test_melee_1_returns_4_cardinals() -> void:
	var shape: RangeShape = load("res://data/range_shapes/melee_1.tres")
	var tiles: Array[Vector2i] = RangeShapeResolver.resolve(shape, Vector2i(5, 5))
	assert_eq(tiles.size(), 4)
	assert_true(tiles.has(Vector2i(4, 5)))
	assert_true(tiles.has(Vector2i(6, 5)))
	assert_true(tiles.has(Vector2i(5, 4)))
	assert_true(tiles.has(Vector2i(5, 6)))

func test_resolve_handles_origin_at_corner() -> void:
	var shape: RangeShape = load("res://data/range_shapes/melee_1.tres")
	var tiles: Array[Vector2i] = RangeShapeResolver.resolve(shape, Vector2i(0, 0))
	# Returns absolute tiles; some may be negative — caller is responsible for bounds.
	assert_eq(tiles.size(), 4)
	assert_true(tiles.has(Vector2i(-1, 0)))
	assert_true(tiles.has(Vector2i(1, 0)))

func test_get_shape_by_id_returns_known_shape() -> void:
	var shape := RangeShapeResolver.get_shape_by_id(1)
	assert_not_null(shape)
	assert_eq(shape.id, 1)
