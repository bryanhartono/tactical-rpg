extends Node
## Loads and caches all .tres data resources at boot.
## See docs/gdd.md §10.3.
##
## In Phase 0 this is a stub — actual scanning of res://data/ and per-type lookup APIs
## land alongside the data they need (Phase 1 onward).

func _ready() -> void:
	# TODO(phase 0+): scan res://data/ recursively, cache by (type, id) for O(1) lookup.
	pass
