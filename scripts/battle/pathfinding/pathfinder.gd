class_name Pathfinder
## Pure functions for computing movement range over a Board.
## See docs/gdd.md §5.3.
##
## Phase 1: BFS, all tiles cost 1, no terrain or elevation. Allies and enemies both
## block. Phase 8 generalizes to weighted-edge A* with terrain costs and pass-through-
## ally rules.

const _DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

## Returns Dictionary[Vector2i -> int] of reachable tiles and their move-cost from
## origin. Includes origin (cost 0). Excludes tiles occupied by other units. Phase 1
## blocks on both allies and enemies; the origin's own occupant does not block.
static func compute_reachable(board: Board, origin: Vector2i, move_budget: int) -> Dictionary:
	var result: Dictionary = {}
	if board == null or not board.is_in_bounds(origin) or move_budget < 0:
		return result
	var origin_unit := board.get_unit_at(origin)
	result[origin] = 0
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_cost: int = result[current]
		if current_cost >= move_budget:
			continue
		for delta in _DIRS:
			var next: Vector2i = current + delta
			if not board.is_in_bounds(next):
				continue
			if result.has(next):
				continue
			var occupant := board.get_unit_at(next)
			if occupant != null and occupant != origin_unit:
				continue
			result[next] = current_cost + 1
			queue.append(next)
	return result

## Returns the path from origin to dest as Array[Vector2i] (inclusive of both endpoints),
## or [] if dest is unreachable within `move_budget`. Standard BFS predecessor walk.
static func path_to(board: Board, origin: Vector2i, dest: Vector2i, move_budget: int) -> Array[Vector2i]:
	if board == null or not board.is_in_bounds(origin) or not board.is_in_bounds(dest):
		return []
	if origin == dest:
		return [origin] as Array[Vector2i]

	var origin_unit := board.get_unit_at(origin)
	var visited: Dictionary = {}            # Vector2i -> int cost
	var came_from: Dictionary = {}          # Vector2i -> Vector2i predecessor
	visited[origin] = 0
	var queue: Array[Vector2i] = [origin]
	var found := false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_cost: int = visited[current]
		if current == dest:
			found = true
			break
		if current_cost >= move_budget:
			continue
		for delta in _DIRS:
			var next: Vector2i = current + delta
			if not board.is_in_bounds(next):
				continue
			if visited.has(next):
				continue
			var occupant := board.get_unit_at(next)
			if occupant != null and occupant != origin_unit:
				continue
			visited[next] = current_cost + 1
			came_from[next] = current
			queue.append(next)

	if not found:
		return []
	var path: Array[Vector2i] = []
	var node: Vector2i = dest
	while node != origin:
		path.append(node)
		node = came_from[node]
	path.append(origin)
	path.reverse()
	return path
