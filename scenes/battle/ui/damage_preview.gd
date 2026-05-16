class_name DamagePreview extends Control
## Hover popup shown during attack-targeting. Displays predicted damage, hit %,
## crit %, and a will-kill indicator. PlayerPhaseController calls show_preview / hide_preview.
## Phase 3: routes through AttackSimulator.predict() directly.

@onready var _label: Label = $Panel/Label

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## board is optional — Phase 3 terrain bonuses are always 0, so null is safe here.
func show_preview(attacker: CharacterUnit, target: CharacterUnit,
		screen_pos: Vector2, board: Board = null) -> void:
	if attacker == null or target == null or attacker.main_weapon == null:
		hide_preview()
		return
	var bc: BattleConst = MasterDataService.battle_const
	# board may be null — terrain bonuses are Phase 8 and safely return 0 when board is null.
	var result := AttackSimulator.predict(attacker, target, attacker.main_weapon, board, bc)
	_label.text = "%s → %s\nDmg: %d  Hit: %d%%  Crit: %d%%\nKill: %s" % [
		attacker.display_name, target.display_name,
		result.expected_damage, result.hit_chance, result.crit_chance,
		"yes" if result.will_kill else "no"
	]
	position = screen_pos + Vector2(16.0, 16.0)
	show()

func hide_preview() -> void:
	hide()
