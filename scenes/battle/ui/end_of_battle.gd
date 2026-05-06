class_name EndOfBattle extends Control
## Hides until CombatEventBus.battle_ended fires, then shows a centered Victory or Defeat
## panel with a Restart button. Pauses input while visible.
## See docs/gdd.md §9.3.

@onready var _label: Label = $Panel/VBox/Label
@onready var _restart_btn: Button = $Panel/VBox/RestartButton

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restart_btn.pressed.connect(_on_restart)
	CombatEventBus.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(result: String) -> void:
	_label.text = "Victory" if result == "victory" else ("Defeat" if result == "defeat" else "Battle Ended")
	_pause_input(true)
	show()

func _on_restart() -> void:
	_pause_input(false)
	get_tree().reload_current_scene()

func _pause_input(paused: bool) -> void:
	# Suppress player phase input + tile picking when the panel is up.
	var input_node := get_tree().root.get_node_or_null("BattleScene/TileInputController")
	if input_node and input_node.has_method("set_enabled"):
		input_node.set_enabled(not paused)
	var menu := get_tree().root.get_node_or_null("BattleScene/BattleUI/ActionMenu")
	if menu and menu.has_method("hide_menu"):
		menu.hide_menu()
