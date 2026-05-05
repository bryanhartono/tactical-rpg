extends Node
## Selects actions for enemy units during the enemy phase.
## See docs/gdd.md §8 and §10.3.

func _ready() -> void:
	# TODO(phase 10): connect CombatEventBus.phase_started, drive ActionScorer over
	# AIBehavior weights per unit, and submit chosen Commands to CommandQueue.
	pass
