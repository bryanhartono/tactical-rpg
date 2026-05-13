class_name ActionMenu extends Control
## Per-unit action menu (Move / Attack / Wait / Cancel). Phase-2 redesign: lives in
## a fixed bottom-right HUD position (anchored in the scene), not over the unit.
## Aster Tatariqus does this — see docs/gdd.md §6.4 / reference screenshots.

signal move_chosen
signal attack_chosen
signal wait_chosen
signal cancel_chosen

@onready var _move_btn: Button = $Panel/Buttons/MoveButton
@onready var _attack_btn: Button = $Panel/Buttons/AttackButton
@onready var _wait_btn: Button = $Panel/Buttons/WaitButton
@onready var _cancel_btn: Button = $Panel/Buttons/CancelButton

func _ready() -> void:
	_move_btn.pressed.connect(_on_move_pressed)
	_attack_btn.pressed.connect(_on_attack_pressed)
	_wait_btn.pressed.connect(_on_wait_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	hide()

## Show the menu for `unit`. Position is fixed (anchored in the scene) — no screen_pos
## argument any more. `can_move` / `can_attack` toggle button availability.
func show_for_unit(_unit: CharacterUnit, can_move: bool, can_attack: bool) -> void:
	_move_btn.disabled = not can_move
	_attack_btn.disabled = not can_attack
	show()

func hide_menu() -> void:
	hide()

func _on_move_pressed() -> void:
	move_chosen.emit()

func _on_attack_pressed() -> void:
	attack_chosen.emit()

func _on_wait_pressed() -> void:
	wait_chosen.emit()

func _on_cancel_pressed() -> void:
	cancel_chosen.emit()
