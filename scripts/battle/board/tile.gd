class_name Tile extends Resource
## A single grid tile. Pure data — no rendering, no behavior.
## See docs/gdd.md §5.1.
##
## Phase 1: corner_heights and effects are unused; landform_id is always 0 (plain).
## occupant_id stores a unit id (not a Node ref) so Resource.duplicate(true) snapshots
## in Phase 3 work cleanly without dragging Node references along.

@export var position: Vector2i = Vector2i.ZERO
## Reference to a LandformDefinition by id. Phase 1: always 0.
@export var landform_id: int = 0
## NW, NE, SW, SE corner elevations. Slopes are linear between corners. Unused in Phase 1.
@export var corner_heights: Vector4 = Vector4.ZERO
## Id of the CharacterUnit currently on this tile, -1 if empty.
@export var occupant_id: int = -1
## Status effects active on the tile (fire/poison/fog/etc.). Empty in Phase 1.
@export var effects: Array[StatusEffect] = []
