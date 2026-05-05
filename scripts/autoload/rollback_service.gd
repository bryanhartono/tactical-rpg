extends Node
## Snapshots Board state per action and per turn for rewind.
## See docs/gdd.md §5.12 and §10.3.

func _ready() -> void:
	# TODO(phase 3): connect CombatEventBus.turn_started / command_executed and maintain
	# the circular snapshot buffer per GDD §5.12.
	pass
