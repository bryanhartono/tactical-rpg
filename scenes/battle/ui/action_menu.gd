class_name ActionMenu extends Control
## Per-unit action menu (Move / Attack / Wait / Cancel). PlayerPhaseController owns the
## state machine; this scene is just the chooser. See docs/gdd.md §4.3, §6.4.

signal move_chosen
signal attack_chosen
signal wait_chosen
signal cancel_chosen

@onready var _move_btn: Button = $Panel/Buttons/MoveButton
@onready var _attack_btn: Button = $Panel/Buttons/AttackButton
@onready var _wait_btn: Button = $Panel/Buttons/WaitButton
@onready var _cancel_btn: Button = $Panel/Buttons/CancelButton

func _ready() -> void:
	_move_btn.pressed.connect(func(): move_chosen.emit())
	_attack_btn.pressed.connect(func(): attack_chosen.emit())
	_wait_btn.pressed.connect(func(): wait_chosen.emit())
	_cancel_btn.pressed.connect(func(): cancel_chosen.emit())
	hide()

## Show the menu near `screen_pos`. `can_move` and `can_attack` toggle button availability
## based on the unit's state (already moved? any enemy in range?).
func show_for_unit(_unit: CharacterUnit, screen_pos: Vector2, can_move: bool, can_attack: bool) -> void:
	_move_btn.disabled = not can_move
	_attack_btn.disabled = not can_attack
	position = screen_pos
	show()

func hide_menu() -> void:
	hide()
