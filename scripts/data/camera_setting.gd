class_name CameraSetting extends Resource
## A single named camera preset (Tactical / Close / Action). See docs/gdd.md §10.5.
## Per-instance state (e.g. user_distance) lives on BattleCamera, NOT on this resource.

@export var id: int = 0
@export var display_name: String = ""
@export var min_distance: float = 5.0
@export var max_distance: float = 18.0
@export var initial_distance: float = 12.0
## Pivot rotation in degrees (x = pitch, y = yaw, z = roll).
@export var rotation_angles: Vector3 = Vector3.ZERO
@export var height_offset: float = 0.0
@export var enable_dof: bool = false
