class_name EndTurnCommand extends Command
## Player chooses to end the entire phase early (skip remaining unacted units).
## See docs/gdd.md §4.3, §10.4.

var manager: Node  # BattleManager — typed loosely to avoid a parse-time class cycle

func _init(p_manager: Node) -> void:
	manager = p_manager

func validate() -> bool:
	# Validates only that there's a manager. The phase-must-be-player check is owned
	# by PlayerPhaseController, which is the only thing that should ever submit this.
	return manager != null

func prepare() -> void:
	pass

func execute() -> void:
	manager.advance_phase()

func complete() -> void:
	pass

func cancel() -> void:
	# Ending a phase isn't meaningfully reversible: enemies have already acted, RNG
	# (in later phases) has been consumed. Real rollback uses turn-start snapshots
	# instead. RollbackService (Phase 3) handles this with snapshot replay.
	push_error("EndTurnCommand.cancel(): end-of-phase is not reversible; use a turn-start snapshot via RollbackService")
