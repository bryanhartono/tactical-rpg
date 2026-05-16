class_name StatsComponent extends RefCounted
## Holds all base and current stats for a CharacterUnit.
## Owned by CharacterUnit; never accessed directly by external systems —
## use CharacterUnit's convenience accessors instead. See GDD §10.1 Principle 2.

var max_hp: int = 0
var max_mp: int = 0        # Phase 5 MP system; placeholder 0
var current_hp: int = 0
var current_mp: int = 0    # Phase 5
var atk: int = 0
var def: int = 0
var skill: int = 0
var speed: int = 0
var luck: int = 0
var avoid: int = 0         # Composite: speed + luck / 2

func is_alive() -> bool:
	return current_hp > 0

## Apply damage, clamped to [0, max_hp]. Returns actual damage dealt.
func take_damage(amount: int) -> int:
	var old_hp := current_hp
	current_hp = max(0, current_hp - amount)
	return old_hp - current_hp

## Restore HP, clamped to max_hp. Returns actual HP restored.
func heal(amount: int) -> int:
	var old_hp := current_hp
	current_hp = min(max_hp, current_hp + amount)
	return current_hp - old_hp
