class_name RangeShapeResolver
## Pure functions that turn RangeShape resources (the row-major bitmask from §7.4) into
## a list of world tiles given an origin (and eventually a facing).
## See docs/gdd.md §7.4.

# Phase-1 hardcoded id → path lookup. Replace with MasterDataService scanning of
# res://data/range_shapes/ once that service is implemented.
# TODO(phase 1+): migrate to MasterDataService.get_range_shape(id).
const _SHAPE_PATHS: Dictionary = {
	1: "res://data/range_shapes/melee_1.tres",
}

## Returns the list of world tiles covered by `shape` when fired from `origin` facing
## `facing`. Phase 1: facing is ignored (range-1 sword is symmetric). Phase 4 will use
## `facing` for directional shapes (e.g. lance line forward).
static func resolve(shape: RangeShape, origin: Vector2i, _facing: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if shape == null or shape.num_cols <= 0:
		return result
	var origin_idx := shape.cells.find(101)
	assert(origin_idx >= 0, "RangeShape has no origin marker (101)")
	if origin_idx < 0:
		return result
	var num_cols := shape.num_cols
	@warning_ignore("integer_division")
	var local_origin := Vector2i(origin_idx % num_cols, origin_idx / num_cols)
	for i in shape.cells.size():
		if shape.cells[i] == 1:
			@warning_ignore("integer_division")
			var local := Vector2i(i % num_cols, i / num_cols)
			var offset := local - local_origin
			result.append(origin + offset)
	return result

## Lookup helper. Phase 1 uses a hardcoded id → path map (see _SHAPE_PATHS).
## Returns null if the id is unknown.
static func get_shape_by_id(id: int) -> RangeShape:
	var path: String = _SHAPE_PATHS.get(id, "")
	if path == "":
		push_error("RangeShapeResolver: no shape registered for id %d" % id)
		return null
	return load(path) as RangeShape
