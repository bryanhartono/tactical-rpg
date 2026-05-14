class_name UnitView3D extends Node3D
## Visual representation of a CharacterUnit using an AnimatedSprite3D billboard.
## Phase 2 (post-redesign): pixel sprite anchored at FEET so the character stands
## centered on its tile from any camera angle. HP / name now live in a right-side
## UI panel (UnitStatusPanel), not above the sprite. See docs/gdd.md §6.1, §6.4.

const STEP_DURATION: float = 0.15  # seconds per tile-step in the move tween
## Half the sprite's world-space height (64 px × pixel_size 0.025). Used by BattleManager
## and UnitClickRegion to compute the camera-pitch-dependent Z offset.
const SPRITE_HALF_HEIGHT: float = 0.8

## Computed from the active camera's pitch: SPRITE_HALF_HEIGHT / sin(|pitch|).
## BattleManager pushes a new value whenever the camera preset changes.
## Default matches the first (tactical, -50°) preset.
var _z_offset: float = 1.044

@export var unit: CharacterUnit
@export var sprite_frames_resource: SpriteFrames

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D
# Shadow Decal is in the scene but doesn't need a script reference — it follows the
# parent's transform automatically.

## Emitted when the latest play()-driven animation (move walk, attack, hit, death)
## finishes. PlayerPhaseController and AIController await this between commands.
signal animation_complete

## Called by BattleManager when the active camera preset changes. Repositions the unit
## to keep its sprite center projected onto its tile center from the new angle.
func apply_z_offset(z: float) -> void:
	_z_offset = z
	if is_instance_valid(unit):
		position = Vector3(unit.grid_position.x, 0.0, unit.grid_position.y + _z_offset)

func _ready() -> void:
	if unit == null:
		push_error("UnitView3D has no unit assigned")
		return
	if sprite_frames_resource != null:
		_sprite.sprite_frames = sprite_frames_resource
	unit.moved.connect(_on_moved)
	unit.hp_changed.connect(_on_hp_changed)
	unit.died.connect(_on_died)
	unit.facing_changed.connect(_on_facing_changed)
	unit.attacked.connect(_on_attacked)
	position = Vector3(unit.grid_position.x, 0.0, unit.grid_position.y + _z_offset)
	_refresh_visual()
	play("idle")

func _refresh_visual() -> void:
	# Flip horizontally if facing west (negative X). See GDD §6.1.
	_sprite.flip_h = unit.facing.x < 0

func play(anim_name: String) -> void:
	if _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim_name):
		push_warning("UnitView3D: missing animation '%s' on %s" % [anim_name, unit.display_name])
		return
	_sprite.play(anim_name)

# ----------------------------------------------------------------------------
# Signal handlers
# ----------------------------------------------------------------------------

func _on_moved(_from: Vector2i, _to: Vector2i) -> void:
	var path := unit.last_move_path
	if path.is_empty() or path.size() == 1:
		position = Vector3(_to.x, 0.0, _to.y + _z_offset)
		animation_complete.emit()
		return
	play("walk")
	var tween := create_tween()
	for i in range(1, path.size()):
		var step_pos := Vector3(path[i].x, 0.0, path[i].y + _z_offset)
		tween.tween_property(self, "position", step_pos, STEP_DURATION).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if is_instance_valid(unit) and unit.is_alive():
		play("idle")
	animation_complete.emit()

func _on_facing_changed(_new_facing: Vector2i) -> void:
	_refresh_visual()

func _on_hp_changed(old_hp: int, new_hp: int) -> void:
	# Hit animation only on damage and only if the unit's still alive — death is
	# handled by _on_died. The HP label is gone; UnitStatusPanel listens directly to
	# the unit's hp_changed signal for the on-screen number.
	if new_hp < old_hp and new_hp > 0 and _sprite.sprite_frames != null \
			and _sprite.sprite_frames.has_animation("hit"):
		play("hit")
		await _sprite.animation_finished
		if is_instance_valid(unit) and unit.is_alive():
			play("idle")

func _on_attacked(_target: CharacterUnit) -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("attack"):
		play("attack")
		await _sprite.animation_finished
		if is_instance_valid(unit) and unit.is_alive():
			play("idle")
	animation_complete.emit()

func _on_died() -> void:
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("death"):
		play("death")
		await _sprite.animation_finished
	animation_complete.emit()
	queue_free()
