extends GutTest
## P1-T01: Board + Tile.

func test_create_flat_size() -> void:
	var b: Board = Board.create_flat(10, 10)
	assert_eq(b.width, 10)
	assert_eq(b.height, 10)
	assert_eq(b.tiles.size(), 100)

func test_get_tile_in_and_out_of_bounds() -> void:
	var b: Board = Board.create_flat(10, 10)
	assert_not_null(b.get_tile(Vector2i(0, 0)))
	assert_not_null(b.get_tile(Vector2i(9, 9)))
	assert_null(b.get_tile(Vector2i(10, 0)))
	assert_null(b.get_tile(Vector2i(-1, 0)))

func test_get_unit_at_empty_returns_null() -> void:
	var b: Board = Board.create_flat(10, 10)
	assert_null(b.get_unit_at(Vector2i(3, 3)))

func test_get_neighbors_corner_and_center() -> void:
	var b: Board = Board.create_flat(10, 10)
	assert_eq(b.get_neighbors(Vector2i(0, 0)).size(), 2)
	assert_eq(b.get_neighbors(Vector2i(5, 5)).size(), 4)
	assert_eq(b.get_neighbors(Vector2i(9, 9)).size(), 2)

func test_each_tile_has_correct_position() -> void:
	var b: Board = Board.create_flat(5, 4)
	for y in 4:
		for x in 5:
			var t: Tile = b.get_tile(Vector2i(x, y))
			assert_eq(t.position, Vector2i(x, y))
			assert_eq(t.landform_id, 0)
			assert_eq(t.occupant_id, -1)
