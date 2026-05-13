class_name UnitClickRegion extends Button
## A transparent 2D button overlaid on the unit's sprite. Tracks the unit's world
## position every frame and projects it to screen so the click area always matches
## the visible sprite — independent of camera pitch / billboard rotation.
##
## Spawned by BattleManager alongside each UnitView3D. Emits `clicked` carrying the
## unit reference; PlayerPhaseController consumes it via TileInputController.

const _SPRITE_WORLD_HEIGHT: float = 1.6   # 64px × pixel_size 0.025 (matches AnimatedSprite3D)
const _SCREEN_PADDING: float = 4.0

@export var unit: CharacterUnit
@export var camera: Camera3D

signal clicked(unit: CharacterUnit)

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	pressed.connect(_on_pressed)

func _process(_delta: float) -> void:
	if not is_instance_valid(unit) or not unit.is_alive() or camera == null:
		hide()
		return
	# A BILLBOARD_ENABLED sprite always orients its image-up axis along the camera's
	# view-up axis (and image-right along view-right). So the visible head appears at
	# feet_world + cam_up * height — projecting along world-up instead gives a wrong
	# rect at tilted camera angles.
	var feet_world := Vector3(unit.grid_position.x, 0.0, unit.grid_position.y)
	if camera.is_position_behind(feet_world):
		hide()
		return
	var cam_basis := camera.global_transform.basis
	var cam_up: Vector3 = cam_basis.y
	var cam_right: Vector3 = cam_basis.x
	var head_world: Vector3 = feet_world + cam_up * _SPRITE_WORLD_HEIGHT
	var right_world: Vector3 = feet_world + cam_right * (_SPRITE_WORLD_HEIGHT * 0.5)
	var feet_screen: Vector2 = camera.unproject_position(feet_world)
	var head_screen: Vector2 = camera.unproject_position(head_world)
	var right_screen: Vector2 = camera.unproject_position(right_world)
	var screen_height: float = max(feet_screen.distance_to(head_screen), 32.0)
	var screen_half_width: float = max(feet_screen.distance_to(right_screen), 16.0)
	var center: Vector2 = (feet_screen + head_screen) * 0.5
	var rect_size := Vector2(screen_half_width * 2.0 + _SCREEN_PADDING * 2.0,
			screen_height + _SCREEN_PADDING * 2.0)
	position = center - rect_size * 0.5
	size = rect_size
	if not visible:
		show()

func _on_pressed() -> void:
	if is_instance_valid(unit):
		clicked.emit(unit)
