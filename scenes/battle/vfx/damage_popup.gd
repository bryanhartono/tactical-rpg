class_name DamagePopup extends Label3D
## Floating damage number. Spawned by VfxLayer in response to
## CombatEventBus.damage_dealt; rises ~1.5 world units over 0.8s and fades.

const RISE_DISTANCE: float = 1.5
const TOTAL_DURATION: float = 0.8
const FADE_DELAY: float = 0.2

func setup(amount: int, world_position: Vector3) -> void:
	text = str(amount)
	position = world_position + Vector3(0, 1.5, 0)
	modulate = Color.WHITE
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position", position + Vector3(0, RISE_DISTANCE, 0), TOTAL_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, TOTAL_DURATION - FADE_DELAY) \
		.set_delay(FADE_DELAY)
	await tween.finished
	queue_free()
