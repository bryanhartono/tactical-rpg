class_name CameraInputController extends Node
## Reads camera_cycle (Tab) and camera_focus_unit (F) input actions and forwards them
## to the BattleCamera rig. Also manages camera pan mode (drag-to-translate).
## See docs/gdd.md §6.3 ("Camera input").

@export var camera_path: NodePath
@export var player_phase_path: NodePath

var _camera: BattleCamera
var _player_phase: PlayerPhaseController
## UnitClickLayer: hidden while pan mode is active so unit clicks don't fire.
var _click_layer: Control

var _pan_mode: bool = false
var _dragging: bool = false
var _prev_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_camera = get_node_or_null(camera_path)
	_player_phase = get_node_or_null(player_phase_path)
	# CanvasLayer children are not reachable via NodePath relative traversal, so find by name.
	_click_layer = get_tree().get_root().find_child("UnitClickLayer", true, false) as Control
	# PanButton signal was not wired in the scene; connect it here so no scene edit is needed.
	var pan_btn := get_tree().get_root().find_child("PanButton", true, false) as CheckButton
	if pan_btn != null:
		pan_btn.toggled.connect(toggle_pan_mode)

# ----------------------------------------------------------------------------
# Pan mode
# ----------------------------------------------------------------------------

func toggle_pan_mode(active: bool) -> void:
	_pan_mode = active
	_dragging = false
	if _click_layer != null:
		_click_layer.visible = not _pan_mode
	if active and _player_phase != null:
		_player_phase.cancel_selection()

func is_pan_mode() -> bool:
	return _pan_mode

# ----------------------------------------------------------------------------
# Input
# ----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _camera == null or not _pan_mode:
		_dragging = false
		return
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var curr_pos := get_viewport().get_mouse_position()
	if pressed:
		if _dragging:
			_pan_camera(curr_pos - _prev_mouse_pos)
		_prev_mouse_pos = curr_pos
		_dragging = true
	else:
		_dragging = false

func _input(event: InputEvent) -> void:
	if _camera == null or _pan_mode:
		return
	_handle_normal_input(event)

func _handle_normal_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_cycle"):
		_camera.cycle_to_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_focus_unit"):
		if _player_phase != null:
			var unit: CharacterUnit = _player_phase.get_selected_unit()
			if unit != null:
				_camera.focus_on_unit(unit)
				get_viewport().set_input_as_handled()

func _pan_camera(screen_delta: Vector2) -> void:
	# Camera never yaws, so world right = +X and world forward = +Z.
	# Scale pan speed by zoom distance so it feels consistent at all presets.
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	if viewport_h <= 0.0:
		return
	var speed: float = _camera.get_distance() / viewport_h
	_camera.position.x -= screen_delta.x * speed
	_camera.position.z -= screen_delta.y * speed
