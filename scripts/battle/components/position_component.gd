class_name PositionComponent extends RefCounted
## Holds grid position, facing direction, and movement state for a CharacterUnit.
## Owned by CharacterUnit; use CharacterUnit's accessors from outside.

var grid_position: Vector2i = Vector2i.ZERO
## Cardinal direction the unit faces. Vector2i convention: RIGHT=(1,0) LEFT=(-1,0) etc.
var facing: Vector2i = Vector2i.RIGHT
## StyleDefinition.MoveType value. Set during initialize_from_definition.
var move_type: int = 0
## Vertical traversal height; used by Phase 8 terrain cliffs.
var jump_height: int = 1
## Remaining tile-unit movement this turn.
var move_budget: int = 0
## Last completed move path in tile coords (origin first, destination last).
## Set by MoveCommand.execute() for UnitView3D animation.
var last_move_path: Array[Vector2i] = []
