class_name VfxLayer extends Node3D
## Scene-scoped spawner for damage popups (and Phase 5+ EXP/level popups).
## Listens to CombatEventBus.damage_dealt; instances DamagePopup over the defender.

const _POPUP_SCENE: PackedScene = preload("res://scenes/battle/vfx/damage_popup.tscn")

func _ready() -> void:
	CombatEventBus.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(_attacker: Node, defender: Node, damage: int, _source: Resource) -> void:
	if defender == null:
		return
	var unit := defender as CharacterUnit
	if unit == null:
		return
	var pos := Vector3(unit.grid_position.x, 0.5, unit.grid_position.y)
	var popup: DamagePopup = _POPUP_SCENE.instantiate()
	add_child(popup)
	popup.setup(damage, pos)
