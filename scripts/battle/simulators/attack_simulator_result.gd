class_name AttackSimulatorResult extends RefCounted
## Value type returned by AttackSimulator.predict() and .resolve().
## See docs/gdd.md §5.5.

## Base expected damage (non-crit, assuming hit). 0 if the attack misses.
var expected_damage: int = 0
## Hit probability as a percentage [min_hit_chance .. max_hit_chance].
var hit_chance: int = 0
## Crit probability as a percentage [0 .. max_crit_chance].
var crit_chance: int = 0
## True when expected_damage >= defender.current_hp.
var will_kill: bool = false
## Expected counter-attack damage. Phase 3: always 0 (no counter).
var counter_damage: int = 0
## Counter hit chance. Phase 3: always 0.
var counter_hit_chance: int = 0
