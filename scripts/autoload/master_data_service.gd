extends Node
## Loads and caches all .tres data resources at boot.
## See docs/gdd.md §10.3.

var battle_const: BattleConst

func _ready() -> void:
	battle_const = load("res://data/battle_const.tres") as BattleConst
	if battle_const == null:
		push_error("MasterDataService: failed to load data/battle_const.tres")
