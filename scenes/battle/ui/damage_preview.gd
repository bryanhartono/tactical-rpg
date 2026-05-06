class_name DamagePreview extends Control
## Hover popup shown during attack-targeting. Displays predicted damage and a
## "will-kill?" indicator. PlayerPhaseController calls show_preview / hide_preview.
##
## Phase 1 calls AttackCommand.predict_damage() directly. Phase 3 routes through
## AttackSimulator instead so AI / UI / runtime share one prediction.
## TODO(phase 3): swap predict_damage call for AttackSimulator.predict.

@onready var _label: Label = $Panel/Label

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_preview(attacker: CharacterUnit, target: CharacterUnit, screen_pos: Vector2) -> void:
	if attacker == null or target == null or attacker.main_weapon == null:
		hide_preview()
		return
	var dmg: int = AttackCommand.predict_damage(attacker, target, attacker.main_weapon)
	var will_kill: bool = dmg >= target.current_hp
	_label.text = "%s → %s\nDmg: %d\nKill: %s" % [
		attacker.display_name, target.display_name, dmg, "yes" if will_kill else "no"
	]
	# Offset so the popup doesn't sit under the cursor.
	position = screen_pos + Vector2(16, 16)
	show()

func hide_preview() -> void:
	hide()
