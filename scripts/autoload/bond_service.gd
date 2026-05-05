extends Node
## Tracks per-pair bond values. Listens to CombatEventBus.
## See docs/gdd.md §5.11 and §10.3.

func _ready() -> void:
	# TODO(phase 5): connect CombatEventBus.unit_killed / duo_formed / battle_ended and
	# accrue per-pair bond per the rules in GDD §5.11.
	pass
