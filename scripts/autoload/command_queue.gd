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
func submit(command: Command) -> bool:
	command_submitted.emit(command)
	if not command.validate():
		command_failed.emit(command, "validation failed")
		return false
	command.prepare()
	command.execute()
	command.complete()
	command_executed.emit(command)
	return true
