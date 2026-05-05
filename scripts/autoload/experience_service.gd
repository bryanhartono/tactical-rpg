extends Node
## Awards Style and Weapon EXP per combat action. Listens to CombatEventBus.
## See docs/gdd.md §5.8 and §10.3.

func _ready() -> void:
	# TODO(phase 5): connect CombatEventBus.damage_dealt / unit_killed / healing_applied
	# / status_applied and route per-action EXP via the rules in GDD §5.8.
	pass
