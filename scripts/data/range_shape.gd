class_name RangeShape extends Resource
## Bitmask range pattern for weapons and skills. Ported from Aster's
## RangeShapeDetail.json. See docs/gdd.md §7.4.
##
## `cells` is a row-major flat array of length num_cols × num_rows.
##   -1 = empty / not in range
##    1 = in range
##  101 = origin tile (where the actor stands)

@export var id: int = 0
@export var name: String = ""
@export var num_cols: int = 0
@export var cells: PackedInt32Array = PackedInt32Array()
