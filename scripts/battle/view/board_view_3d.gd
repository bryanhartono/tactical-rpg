class_name BoardView3D extends Node3D
## Renders a Board resource. Phase 2 introduces the HD-2D look:
##  - The visible ground is a single PlaneMesh (decorative props go around it).
##  - The grid is a separate translucent overlay, hidden by default.
##  - Tile-pick colliders stay (one StaticBody3D per tile, invisible) so
##    TileInputController can still raycast clicks → grid coords.
## See docs/gdd.md §10.1 (principle 4), §10.2.

const DEFAULT_GROUND_COLOR: Color = Color(0.32, 0.46, 0.22)         # mossy grass
const HIGHLIGHT_Y_OFFSET: float = 0.04                                # avoid z-fighting with ground
const GRID_LINE_COLOR: Color = Color(0.95, 0.95, 0.95, 0.18)
# Tile-pick collider depth. Tall enough to capture clicks anywhere over the sprite
# (sprite stands ~1.6u tall above the tile), so the player can click the unit's
# silhouette and still resolve to the tile they're standing on.
const TILE_PICK_HEIGHT: float = 2.5
const HIGHLIGHT_OPACITY: float = 0.55

var _board: Board
var _ground: MeshInstance3D
var _grid_overlay: MeshInstance3D
var _highlights_root: Node3D
var _colliders_root: Node3D
var _grid_visible: bool = false

# ----------------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------------

## Replace the rendered grid with a fresh layout for `board`.
func set_board(board: Board) -> void:
	_board = board
	_clear_children()
	if board == null:
		return
	_build_colliders(board)
	_build_ground(board)
	_build_grid_overlay(board)
	_build_highlights_root()
	set_grid_visible(_grid_visible)

## Show / hide the translucent grid overlay. Defaults to false; T14 toggles on
## entry to a targeting state.
func set_grid_visible(enabled: bool) -> void:
	_grid_visible = enabled
	if _grid_overlay != null:
		_grid_overlay.visible = enabled

## Tint the listed tiles with `color`. Phase 2 renders highlights as small quads
## just above the ground.
func highlight_tiles(tiles: Array, color: Color) -> void:
	if _highlights_root == null:
		return
	for raw in tiles:
		var pos: Vector2i = raw
		if _board != null and not _board.is_in_bounds(pos):
			continue
		var quad := _make_highlight_quad(pos, color)
		_highlights_root.add_child(quad)

## Reset the highlight layer.
func clear_highlights() -> void:
	if _highlights_root == null:
		return
	for child in _highlights_root.get_children():
		child.queue_free()

# ----------------------------------------------------------------------------
# Build helpers
# ----------------------------------------------------------------------------

func _build_ground(board: Board) -> void:
	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(board.width, board.height)
	_ground.mesh = mesh
	# Plane is centered on origin; shift so tile (0,0) is at world (0,0,0).
	_ground.position = Vector3((board.width - 1) * 0.5, 0.0, (board.height - 1) * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DEFAULT_GROUND_COLOR
	mat.roughness = 0.95
	mat.metallic = 0.0
	_ground.material_override = mat
	add_child(_ground)

func _build_grid_overlay(board: Board) -> void:
	_grid_overlay = MeshInstance3D.new()
	_grid_overlay.name = "GridOverlay"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(board.width, board.height)
	_grid_overlay.mesh = mesh
	_grid_overlay.position = Vector3((board.width - 1) * 0.5, HIGHLIGHT_Y_OFFSET * 0.5, (board.height - 1) * 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = _grid_shader()
	mat.set_shader_parameter("grid_color", GRID_LINE_COLOR)
	mat.set_shader_parameter("tiles_x", float(board.width))
	mat.set_shader_parameter("tiles_y", float(board.height))
	mat.set_shader_parameter("line_width", 0.04)
	_grid_overlay.material_override = mat
	add_child(_grid_overlay)

func _build_colliders(board: Board) -> void:
	_colliders_root = Node3D.new()
	_colliders_root.name = "Colliders"
	add_child(_colliders_root)
	for y in board.height:
		for x in board.width:
			var pos := Vector2i(x, y)
			var body := StaticBody3D.new()
			body.name = "Tile_%d_%d" % [x, y]
			body.set_meta("grid_pos", pos)
			# Position the body at tile centre, then offset the collider upward so the
			# pick volume spans y=0 .. y=TILE_PICK_HEIGHT. This way clicking on the
			# unit's billboard (which stands 0..~1.6u above) still hits the tile.
			body.position = Vector3(x, 0.0, y)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, TILE_PICK_HEIGHT, 1.0)
			shape.shape = box
			shape.position = Vector3(0, TILE_PICK_HEIGHT * 0.5, 0)
			body.add_child(shape)
			_colliders_root.add_child(body)

func _build_highlights_root() -> void:
	_highlights_root = Node3D.new()
	_highlights_root.name = "Highlights"
	add_child(_highlights_root)

func _make_highlight_quad(pos: Vector2i, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.95, 0.95)
	mi.mesh = mesh
	mi.position = Vector3(pos.x, HIGHLIGHT_Y_OFFSET, pos.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, HIGHLIGHT_OPACITY)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	return mi

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_ground = null
	_grid_overlay = null
	_highlights_root = null
	_colliders_root = null

# ----------------------------------------------------------------------------
# Inline grid shader (no need for a separate .gdshader file)
# ----------------------------------------------------------------------------

func _grid_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, blend_mix;

uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 0.2);
uniform float tiles_x = 10.0;
uniform float tiles_y = 10.0;
uniform float line_width = 0.04;

void fragment() {
	vec2 cell = vec2(UV.x * tiles_x, UV.y * tiles_y);
	vec2 frac = abs(fract(cell) - 0.5);
	float edge = max(step(0.5 - line_width, frac.x), step(0.5 - line_width, frac.y));
	if (edge < 0.5) {
		discard;
	}
	ALBEDO = grid_color.rgb;
	ALPHA = grid_color.a;
}
"""
	return s
