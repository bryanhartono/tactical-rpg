extends Button
## Rewind HUD button. Calls RollbackService.rewind_last_action() and updates label.
## See docs/gdd.md §5.12.

func _ready() -> void:
	pressed.connect(_on_pressed)
	CombatEventBus.rolled_back.connect(_on_rolled_back)
	CommandQueue.command_executed.connect(_on_command_executed)
	_refresh()

func _on_pressed() -> void:
	RollbackService.rewind_last_action()

func _on_rolled_back(_idx: int) -> void:
	_refresh()

func _on_command_executed(_cmd: Command) -> void:
	_refresh()

func _refresh() -> void:
	var remaining := RollbackService.rewinds_remaining()
	text = "↩ Rewind (%d)" % remaining
	disabled = not RollbackService.can_rewind()
