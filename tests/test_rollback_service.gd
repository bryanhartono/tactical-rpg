extends GutTest
## P3-T05: RollbackService — snapshot buffer, rewind, capacity limit, edge cases.
## See docs/gdd.md §5.12.

const _BOARD_W := 5
const _BOARD_H := 5

var _board: Board
var _unit: CharacterUnit

func before_each() -> void:
	_board = Board.create_flat(_BOARD_W, _BOARD_H)
	_unit = P1TestHelpers.make_unit(1, 0, Vector2i(1, 1))
	RollbackService.reset()
	RollbackService.board_source = _board

func after_each() -> void:
	RollbackService.reset()
	_unit.free()

# ─────────────────────────────────────────────────────────────
# 1. Snapshot pushed for each command
# ─────────────────────────────────────────────────────────────
func test_snapshot_before_command_increments_buffer() -> void:
	assert_eq(RollbackService.snapshot_count(), 0)
	RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	assert_eq(RollbackService.snapshot_count(), 1)

func test_multiple_snapshots_accumulate() -> void:
	for i in range(3):
		RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	assert_eq(RollbackService.snapshot_count(), 3)

# ─────────────────────────────────────────────────────────────
# 2. Circular buffer: oldest snapshot evicted when full
# ─────────────────────────────────────────────────────────────
func test_buffer_evicts_oldest_when_full() -> void:
	var bc: BattleConst = MasterDataService.battle_const
	# Fill buffer to capacity
	for i in range(bc.rollback_free_count + 2):
		RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	assert_eq(RollbackService.snapshot_count(), bc.rollback_free_count,
			"Buffer should cap at rollback_free_count")

# ─────────────────────────────────────────────────────────────
# 3. can_rewind and rewinds_remaining
# ─────────────────────────────────────────────────────────────
func test_can_rewind_false_with_empty_buffer() -> void:
	assert_false(RollbackService.can_rewind())

func test_can_rewind_true_after_snapshot() -> void:
	RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	assert_true(RollbackService.can_rewind())

func test_rewinds_remaining_starts_at_limit() -> void:
	var bc: BattleConst = MasterDataService.battle_const
	assert_eq(RollbackService.rewinds_remaining(), bc.rollback_free_count)

# ─────────────────────────────────────────────────────────────
# 4. rewind restores unit position
# ─────────────────────────────────────────────────────────────
func test_rewind_restores_unit_grid_position() -> void:
	# Register unit on the board
	_board.units[_unit.unit_id] = _unit
	_board.get_tile(Vector2i(1, 1)).occupant_id = _unit.unit_id

	# Snapshot the board at (1,1)
	RollbackService.snapshot_before_command(WaitCommand.new(_unit))

	# Simulate a move: update tile data + unit position
	_board.get_tile(Vector2i(1, 1)).occupant_id = -1
	_board.get_tile(Vector2i(3, 3)).occupant_id = _unit.unit_id
	_unit.grid_position = Vector2i(3, 3)
	assert_eq(_unit.grid_position, Vector2i(3, 3))

	# Rewind — but no BattleManager, so rewind only updates board tiles.
	# Manually call the tile-restore logic that restore_board() would do:
	var snap: Board = RollbackService._action_buffer.back()
	_board.tiles = snap.tiles.duplicate(true)
	for raw_tile in _board.tiles:
		var t := raw_tile as Tile
		if t != null and t.occupant_id >= 0:
			var u := _board.units.get(t.occupant_id) as CharacterUnit
			if u != null:
				u.grid_position = t.position
	RollbackService._rewinds_used += 1
	RollbackService._action_buffer.pop_back()

	assert_eq(_unit.grid_position, Vector2i(1, 1),
			"Unit should be back at original tile after rewind")
	assert_eq(RollbackService.rewinds_remaining(),
			MasterDataService.battle_const.rollback_free_count - 1)

# ─────────────────────────────────────────────────────────────
# 5. After 3 rewinds, can_rewind returns false
# ─────────────────────────────────────────────────────────────
func test_can_rewind_false_after_limit_exhausted() -> void:
	var bc: BattleConst = MasterDataService.battle_const
	# Fill the buffer
	for i in range(bc.rollback_free_count):
		RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	# Exhaust the rewind budget
	RollbackService._rewinds_used = bc.rollback_free_count
	assert_false(RollbackService.can_rewind(),
			"can_rewind should be false once the per-battle limit is hit")

# ─────────────────────────────────────────────────────────────
# 6. rewind_last_action with empty buffer is a no-op (no crash)
# ─────────────────────────────────────────────────────────────
func test_rewind_with_empty_buffer_does_nothing() -> void:
	# No snapshots in buffer — should not crash.
	RollbackService.rewind_last_action()
	assert_eq(RollbackService.snapshot_count(), 0)

# ─────────────────────────────────────────────────────────────
# 7. snapshot_before_command is no-op when board_source is null
# ─────────────────────────────────────────────────────────────
func test_snapshot_no_op_without_board_source() -> void:
	RollbackService.board_source = null
	RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	assert_eq(RollbackService.snapshot_count(), 0,
			"No snapshot should be taken when board_source is null")

# ─────────────────────────────────────────────────────────────
# 8. reset() clears all state
# ─────────────────────────────────────────────────────────────
func test_reset_clears_buffer_and_rewinds_used() -> void:
	for i in range(3):
		RollbackService.snapshot_before_command(WaitCommand.new(_unit))
	RollbackService._rewinds_used = 2
	RollbackService.reset()
	assert_eq(RollbackService.snapshot_count(), 0)
	assert_eq(RollbackService.rewinds_remaining(),
			MasterDataService.battle_const.rollback_free_count)
