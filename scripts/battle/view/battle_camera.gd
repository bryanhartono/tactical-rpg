class_name BattleCamera extends Node3D
## Camera rig with tweened preset cycling and per-preset zoom memory.
## See docs/gdd.md §6.3, §10.5 (post-T01 edits).
##
## The rig itself sits at the pivot point (move it to pan); `Pivot` rotates to set
## camera pitch; `Pivot/Camera3D` is positioned at -distance along local Z. Tweens
## between presets cross-fade rotation + distance simultaneously.

const TRANSITION_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC
const TRANSITION_EASE: Tween.EaseType = Tween.EASE_OUT

@export var settings: Array[CameraSetting] = []

var _user_distances: PackedFloat32Array = PackedFloat32Array()
var _current_index: int = 0
var _transitioning: bool = false

@onready var _pivot: Node3D = $Pivot
@onready var _camera: Camera3D = $Pivot/Camera3D

signal preset_changed(new_index: int, new_setting: CameraSetting)
signal preset_transition_complete(new_index: int)

func _ready() -> void:
	if settings.is_empty():
		push_error("BattleCamera has no presets — assign Tactical/Overview/Top-down in inspector")
		return
	_user_distances.resize(settings.size())
	for i in settings.size():
		_user_distances[i] = settings[i].initial_distance
	_apply_setting_instant(0)

# ----------------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------------

func cycle_to_next(duration: float = 0.4) -> void:
	if _transitioning or settings.is_empty():
		return
	set_setting_index((_current_index + 1) % settings.size(), duration)

func set_setting_index(index: int, duration: float = 0.4) -> void:
	if _transitioning or index == _current_index or settings.is_empty():
		return
	if index < 0 or index >= settings.size():
		return
	_transitioning = true
	_current_index = index
	_animate_to(settings[index], _user_distances[index], duration)

func focus_on(world_position: Vector3, duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", world_position, duration) \
		.set_trans(TRANSITION_TRANS).set_ease(TRANSITION_EASE)

func focus_on_unit(unit: CharacterUnit, duration: float = 0.3) -> void:
	if unit == null:
		return
	focus_on(Vector3(unit.grid_position.x, 0.0, unit.grid_position.y), duration)

func get_current_index() -> int:
	return _current_index

# ----------------------------------------------------------------------------
# Internals
# ----------------------------------------------------------------------------

func _apply_setting_instant(index: int) -> void:
	var s: CameraSetting = settings[index]
	_pivot.rotation_degrees = s.rotation_angles
	_camera.position = Vector3(0, 0, _user_distances[index])
	_current_index = index
	preset_changed.emit(index, s)

func _animate_to(setting: CameraSetting, distance: float, duration: float) -> void:
	preset_changed.emit(_current_index, setting)
	var tween := create_tween().set_parallel()
	tween.tween_property(_pivot, "rotation_degrees", setting.rotation_angles, duration) \
		.set_trans(TRANSITION_TRANS).set_ease(TRANSITION_EASE)
	tween.tween_property(_camera, "position:z", distance, duration) \
		.set_trans(TRANSITION_TRANS).set_ease(TRANSITION_EASE)
	await tween.finished
	_transitioning = false
	preset_transition_complete.emit(_current_index)
