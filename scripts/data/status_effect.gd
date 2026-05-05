class_name StatusEffect extends Resource
## Status effect applied to a unit. See docs/gdd.md §7.5.
## Concrete on_apply / on_turn_start / on_remove behavior is wired up in later phases;
## this stub only declares the data fields a designer would tune.

@export var id: int = 0
@export var name: String = ""
## Number of turns the effect lasts. 0 = instantaneous (e.g. one-shot heal).
@export var duration: int = 0
## Whether damage taken removes this effect (e.g. Sleep).
@export var removed_on_damage: bool = false
## Per-turn flat HP delta (positive heals, negative damages). Used by Poison etc.
@export var per_turn_hp_delta: int = 0
## Per-turn percent HP delta as a fraction (0.10 = +10%).
@export var per_turn_hp_percent_delta: float = 0.0
## If true, target loses their next turn while this effect is active.
@export var skips_turn: bool = false
