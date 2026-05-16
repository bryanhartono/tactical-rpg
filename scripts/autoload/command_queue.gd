extends Node
## Singleton queue that accepts, validates, and executes Commands submitted by UI or AI.
## See docs/gdd.md §10.4.
##
## UI never touches Board state directly. Tests run by submitting Commands without UI.

signal command_submitted(command: Command)
signal command_executed(command: Command)
signal command_failed(command: Command, reason: String)

## Submit a command for validation + execution. Returns true on success.
## Emits command_submitted unconditionally; then either command_executed or command_failed.
## RollbackService snapshots the board before every valid command (GDD §10.4, C5).
func submit(command: Command) -> bool:
	command_submitted.emit(command)
	if not command.validate():
		command_failed.emit(command, "validation_failed")
		return false
	RollbackService.snapshot_before_command(command)
	command.prepare()
	command.execute()
	command.complete()
	command_executed.emit(command)
	return true

## Execute a command without taking a new snapshot. Use when the caller already called
## RollbackService.snapshot_before_command() manually (e.g. on unit selection), so that
## one rewind undoes the whole multi-step action.
func submit_presnapshot(command: Command) -> bool:
	command_submitted.emit(command)
	if not command.validate():
		command_failed.emit(command, "validation_failed")
		return false
	command.prepare()
	command.execute()
	command.complete()
	command_executed.emit(command)
	return true
