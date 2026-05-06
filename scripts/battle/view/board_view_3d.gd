class_name BoardView3D extends Node3D
## Renders a Board resource as a grid of mesh tiles. Pure view layer — reads Board,
## never writes. See docs/gdd.md §10.1 (principle 4), §10.2.
##
## Each tile is a MeshInstance3D + StaticBody3D + CollisionShape3D so the
## TileInputController (P1-T14) can raycast onto the board to convert mouse clicks
## into grid coordinates. Tile meshes are cached in `_tiles_by_pos` for O(1) highlight
## lookups.

const TILE_SIZE: float = 0.95            # < 1 leaves a small gap so the grid is readable
const TILE_THICKNESS: float = 0.05        # collision box depth; keeps the click target above y=0
const DEFAULT_COLOR: Color = Color(0.227, 0.227, 0.290)  # muted grey #3a3a4a

var _board: Board
var _tiles_by_pos: Dictionary = {}        # Vector2i -> MeshInstance3D
var _default_material: StandardMaterial3D
var _shared_mesh: PlaneMesh

func _ready() -> void:
	_default_material = _make_material(DEFAULT_COLOR)
	_shared_mesh = PlaneMesh.new()
	_shared_mesh.size = Vector2(TILE_SIZE, TILE_SIZE)

## Replace the rendered grid with a fresh layout for `board`.
func set_board(board: Board) -> void:
	_board = board
	_clear_children()
	_tiles_by_pos.clear()
	if board == null:
		return
	for y in board.height:
		for x in board.width:
			var pos := Vector2i(x, y)
			var mesh_instance := _build_tile(pos)
			add_child(mesh_instance)
			_tiles_by_pos[pos] = mesh_instance

## Tint the listed tiles with `color`. Caller is responsible for clearing first if they
## want a fresh state — successive calls overlay.
func highlight_tiles(tiles: Array, color: Color) -> void:
	var mat := _make_material(color, true)
	for raw in tiles:
		var pos: Vector2i = raw
		var mi: MeshInstance3D = _tiles_by_pos.get(pos)
		if mi != null:
			mi.material_override = mat

## Reset every tile to the default material.
func clear_highlights() -> void:
	for mi in _tiles_by_pos.values():
		(mi as MeshInstance3D).material_override = null

# ----------------------------------------------------------------------------
# Internals
# ----------------------------------------------------------------------------

func _build_tile(pos: Vector2i) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Tile_%d_%d" % [pos.x, pos.y]
	mi.mesh = _shared_mesh
	mi.material_override = null  # falls back to surface_material → default mesh material
	mi.set_surface_override_material(0, _default_material)
	mi.position = Vector3(pos.x, 0.0, pos.y)

	# Collider for raycasting from TileInputController. The body carries the grid
	# position as metadata; the controller reads it back instead of doing math on the
	# hit point (more robust once Phase 8 adds elevation).
	var body := StaticBody3D.new()
	body.set_meta("grid_pos", pos)
	# Place collider 1.0 unit so picking is generous, but keep depth small so it doesn't
	# bleed into adjacent tiles vertically.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, TILE_THICKNESS, 1.0)
	shape.shape = box
	body.add_child(shape)
	mi.add_child(body)
	return mi

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _make_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
	return m
