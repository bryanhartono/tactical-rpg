class_name WaitCommand extends Command
## Stay action — end the unit's turn without acting. See docs/gdd.md §4.3, §10.4.

var unit: CharacterUnit

func _init(p_unit: CharacterUnit) -> void:
	unit = p_unit

func validate() -> bool:
	return unit != null and not unit.has_acted

func prepare() -> void:
	pass

func execute() -> void:
	unit.has_acted = true
	CombatEventBus.turn_ended.emit(unit)

func complete() -> void:
	pass

func cancel() -> void:
	unit.has_acted = false
