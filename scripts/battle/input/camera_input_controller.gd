class_name CameraInputController extends Node
## Reads camera_cycle (Tab) and camera_focus_unit (F) input actions and forwards them
## to the BattleCamera rig. See docs/gdd.md §6.3 ("Camera input").

@export var camera_path: NodePath
@export var player_phase_path: NodePath

var _camera: BattleCamera
var _player_phase: PlayerPhaseController

func _ready() -> void:
	_camera = get_node_or_null(camera_path)
	_player_phase = get_node_or_null(player_phase_path)

func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event.is_action_pressed("camera_cycle"):
		_camera.cycle_to_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_focus_unit"):
		if _player_phase != null:
			var unit: CharacterUnit = _player_phase.get_selected_unit()
			if unit != null:
				_camera.focus_on_unit(unit)
				get_viewport().set_input_as_handled()
