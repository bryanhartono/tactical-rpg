class_name LandformDefinition extends Resource
## Per-tile gameplay data for a terrain type. See docs/gdd.md §5.1.
## Tiles store a `landform_id`; the actual data lives on a LandformDefinition .tres
## resolved through MasterDataService.

@export var id: int = 0
@export var display_name: String = ""

## Movement cost by MoveType. Key: int (StyleDefinition.MoveType), value: int cost.
## Use -1 (or omit the key) to mark the terrain as impassable for that MoveType.
@export var move_cost_by_type: Dictionary = {}

## Whether a unit of a given MoveType can END its move on this tile.
## Key: int (StyleDefinition.MoveType), value: bool.
@export var stoppable_by_type: Dictionary = {}

@export var evasion_bonus: int = 0
@export var defense_bonus: int = 0

## Status effects applied to a unit when entering this tile.
@export var on_enter_effects: Array[StatusEffect] = []
## Status effects applied at the start of each of the unit's turns while standing on this tile.
@export var on_turn_start_effects: Array[StatusEffect] = []
