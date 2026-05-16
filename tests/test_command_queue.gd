extends GutTest
## P3-T04: CommandQueue — validates sole-execution-path contract and signal contract.
## Does NOT test RollbackService snapshot internals; those live in test_rollback_service.gd.

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
func _make_units() -> Array[CharacterUnit]:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i(5, 4))
	var bandit := P1TestHelpers.make_unit(2, 1, Vector2i(5, 5), "res://data/characters/bandit.tres")
	return [aria, bandit]

# ─────────────────────────────────────────────────────────────
# 1. Valid command: executes and emits command_executed
# ─────────────────────────────────────────────────────────────
func test_valid_command_executes() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var executed := [false]
	var conn := func(_c): executed[0] = true
	CommandQueue.command_executed.connect(conn)
	CommandQueue.submit(WaitCommand.new(aria))
	assert_true(aria.has_acted, "WaitCommand should set has_acted")
	assert_true(executed[0], "command_executed should fire")
	CommandQueue.command_executed.disconnect(conn)
	aria.free()

func test_valid_command_returns_true() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var result := CommandQueue.submit(WaitCommand.new(aria))
	assert_true(result)
	aria.free()

# ─────────────────────────────────────────────────────────────
# 2. Invalid command: emits command_failed, does NOT execute
# ─────────────────────────────────────────────────────────────
func test_invalid_command_emits_failed_and_does_not_execute() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	# has_acted=true → WaitCommand.validate() returns false
	aria.has_acted = true

	var failed := [false]
	var executed := [false]
	var fail_conn := func(_c, _r): failed[0] = true
	var exec_conn := func(_c): executed[0] = true
	CommandQueue.command_failed.connect(fail_conn)
	CommandQueue.command_executed.connect(exec_conn)

	var result := CommandQueue.submit(WaitCommand.new(aria))
	assert_false(result, "submit should return false on validation failure")
	assert_true(failed[0], "command_failed should fire")
	assert_false(executed[0], "command_executed must NOT fire on failure")
	# has_acted should remain true (command didn't execute a reset)
	assert_true(aria.has_acted)

	CommandQueue.command_failed.disconnect(fail_conn)
	CommandQueue.command_executed.disconnect(exec_conn)
	aria.free()

func test_invalid_command_returns_false() -> void:
	var aria := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	aria.has_acted = true
	var result := CommandQueue.submit(WaitCommand.new(aria))
	assert_false(result)
	aria.free()

# ─────────────────────────────────────────────────────────────
# 3. RollbackService receives a snapshot on every valid submission
# ─────────────────────────────────────────────────────────────
func test_snapshot_taken_on_valid_command() -> void:
	# Provide a real board so RollbackService.snapshot_before_command can snapshot.
	var board := Board.create_flat(5, 5)
	RollbackService.reset()
	RollbackService.board_source = board

	var aria := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var count_before := RollbackService.snapshot_count()
	CommandQueue.submit(WaitCommand.new(aria))
	assert_eq(RollbackService.snapshot_count(), count_before + 1,
			"One snapshot should be pushed per valid command")

	RollbackService.reset()
	aria.free()
	# board is a Resource — let GC manage it

func test_no_snapshot_on_invalid_command() -> void:
	var board := Board.create_flat(5, 5)
	RollbackService.reset()
	RollbackService.board_source = board

	var aria := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	aria.has_acted = true  # forces validation failure
	var count_before := RollbackService.snapshot_count()
	CommandQueue.submit(WaitCommand.new(aria))
	assert_eq(RollbackService.snapshot_count(), count_before,
			"No snapshot should be taken for an invalid command")

	RollbackService.reset()
	aria.free()
	# board is a Resource — let GC manage it
