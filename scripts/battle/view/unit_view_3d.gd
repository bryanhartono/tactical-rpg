class_name UnitView3D extends Node3D
## Visual representation of a CharacterUnit. Listens to that unit's local signals.
## Phase 1: capsule placeholder. Phase 2: pixel sprite billboard.
## See docs/gdd.md §6.1 (Phase 2 target), §10.1 (principle 4 — view subscribes to gameplay).

const PLAYER_COLOR: Color = Color(0.30, 0.55, 0.95)
const ENEMY_COLOR: Color = Color(0.90, 0.30, 0.30)
const Y_OFFSET: float = 0.5

@export var unit: CharacterUnit

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _hp_label: Label3D = $HPLabel

func _ready() -> void:
	if unit == null:
		push_error("UnitView3D has no unit assigned")
		return
	unit.moved.connect(_on_moved)
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	position = Vector3(unit.grid_position.x, Y_OFFSET, unit.grid_position.y)
	_refresh_visual()

func _refresh_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLOR if unit.is_player() else ENEMY_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	_hp_label.text = "%s\n%d/%d" % [unit.display_name, unit.current_hp, unit.max_hp]

func _on_moved(_from: Vector2i, to: Vector2i) -> void:
	# Phase 1: instant teleport. Phase 2: tween over the path.
	position = Vector3(to.x, Y_OFFSET, to.y)

func _on_hp_changed(_old_hp: int, _new_hp: int) -> void:
	_hp_label.text = "%s\n%d/%d" % [unit.display_name, unit.current_hp, unit.max_hp]

func _on_died() -> void:
	# Phase 2 will play a death animation first.
	queue_free()
