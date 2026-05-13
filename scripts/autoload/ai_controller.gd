extends Node
## Selects actions for enemy units during the enemy phase.
## See docs/gdd.md §8 and §10.3.
##
## Phase 1 routine: for each enemy, find nearest player; attack if in range, else move
## as close as possible and attack if now in range, else wait. No AIBehavior weights,
## no scoring, no archetypes — Phase 10 owns the smart version.
##
## Phase 2 awaits the view layer's animation_complete between commands so visuals
## actually play out before the next decision.

const _POST_ENEMY_BEAT: float = 0.3  # extra pause between enemies so it doesn't feel rushed

func _ready() -> void:
	# TODO(phase 10): replace this routine with weighted-scoring AI driven by AIBehavior
	# resources. See GDD §8.
	pass

## Drive every alive enemy through one decision, then hand control back to the manager.
func run_enemy_phase(manager) -> void:
	if manager == null or manager.battle_over:
		return
	var board: Board = manager.board
	for enemy in manager.get_alive_team(1):
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		await _act(enemy, board, manager)
		if not is_instance_valid(manager) or manager.battle_over:
			return
		await get_tree().create_timer(_POST_ENEMY_BEAT).timeout
	if is_instance_valid(manager) and not manager.battle_over:
		manager.advance_phase()

func _act(enemy: CharacterUnit, board: Board, manager) -> void:
	var nearest_player := _find_nearest_player(enemy, board)
	if nearest_player == null:
		CommandQueue.submit(WaitCommand.new(enemy))
		return

	var shape := RangeShapeResolver.get_shape_by_id(enemy.main_weapon.range_shape_id)
	if shape == null:
		CommandQueue.submit(WaitCommand.new(enemy))
		return

	# 1. Already in range? Attack.
	var attack_tiles := RangeShapeResolver.resolve(shape, enemy.grid_position, enemy.facing)
	if attack_tiles.has(nearest_player.grid_position):
		CommandQueue.submit(AttackCommand.new(board, enemy, nearest_player))
		await _await_view(manager, enemy)
		return

	# 2. Otherwise, move toward the nearest player as far as our budget allows.
	var reachable := Pathfinder.compute_reachable(board, enemy.grid_position, enemy.move_budget)
	var best_tile := enemy.grid_position
	var best_dist := _manhattan(enemy.grid_position, nearest_player.grid_position)
	for tile in reachable.keys():
		var d := _manhattan(tile, nearest_player.grid_position)
		if d < best_dist:
			best_dist = d
			best_tile = tile
	if best_tile != enemy.grid_position:
		CommandQueue.submit(MoveCommand.new(board, enemy, best_tile))
		await _await_view(manager, enemy)

	# 3. After moving, if in range now, attack. Otherwise wait.
	if not is_instance_valid(enemy) or not enemy.is_alive() \
			or not is_instance_valid(nearest_player) or not nearest_player.is_alive():
		return
	var post_attack_tiles := RangeShapeResolver.resolve(shape, enemy.grid_position, enemy.facing)
	if post_attack_tiles.has(nearest_player.grid_position) and not enemy.has_acted:
		CommandQueue.submit(AttackCommand.new(board, enemy, nearest_player))
		await _await_view(manager, enemy)
	elif not enemy.has_acted:
		CommandQueue.submit(WaitCommand.new(enemy))

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _await_view(manager, unit: CharacterUnit) -> void:
	if not is_instance_valid(manager) or not is_instance_valid(unit):
		return
	var view: UnitView3D = manager.get_view_for(unit.unit_id)
	if view != null:
		await view.animation_complete
	else:
		await get_tree().process_frame

func _find_nearest_player(enemy: CharacterUnit, board: Board) -> CharacterUnit:
	var best: CharacterUnit = null
	var best_dist: int = 0x7fffffff
	for unit in board.units.values():
		var u := unit as CharacterUnit
		if u == null or u.team != 0 or not u.is_alive():
			continue
		var d := _manhattan(enemy.grid_position, u.grid_position)
		if d < best_dist:
			best_dist = d
			best = u
	return best

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
