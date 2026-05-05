class_name Command extends RefCounted
## Base class for all player and AI actions in battle.
## Lifecycle: validate() -> prepare() -> execute() -> complete(), with cancel() for rollback.
## See docs/gdd.md §10.4.
##
## Subclasses live in res://scripts/battle/commands/ and are constructed by UI or AI,
## then submitted to CommandQueue. UI never calls Board methods directly.

## Returns true if this command can legally execute given current board state.
## Override in subclasses. Must not mutate state.
func validate() -> bool:
	return false

## Gather any resolution data (e.g. compute pathfinding). Called after validate, before execute.
## Override in subclasses.
func prepare() -> void:
	pass

## Apply effects to game state. Called after prepare. Must emit appropriate
## CombatEventBus signals. Override in subclasses.
func execute() -> void:
	push_error("Command.execute() not overridden")

## Post-effect cleanup. Called after execute completes successfully.
## Override in subclasses.
func complete() -> void:
	pass

## Rollback this command's effects. Called by RollbackService.
## Override in subclasses.
func cancel() -> void:
	push_error("Command.cancel() not overridden")
