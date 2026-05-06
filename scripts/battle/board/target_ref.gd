class_name TargetRef extends RefCounted
## Lightweight (unit, grid_position) tuple used everywhere targeting and prediction
## happen. See docs/tactical_rpg_design_reference.md §9.4.
##
## RefCounted so it's cheap to allocate and free. Not a Resource — these aren't saved.
## `unit` may be null for tile-only targets (e.g. AoE center, move destination).

var unit: Node
var grid: Vector2i

func _init(p_unit: Node = null, p_grid: Vector2i = Vector2i.ZERO) -> void:
	unit = p_unit
	grid = p_grid
