class_name Skill extends Resource
## A skill is a discrete in-battle action — active attack, support, or passive.
## See docs/gdd.md §7.3.

enum Kind { ACTIVE_ATTACK, STRATAGEM, SUPPORT, CHARGE, PASSIVE }
enum TargetFilter { SELF, ALLY, ENEMY, TILE, AOE }

@export var id: int = 0
@export var name: String = ""
@export var kind: Kind = Kind.ACTIVE_ATTACK
## Free-form category id; concrete enum TBD when skill list is fleshed out.
@export var category: int = 0
@export var range_shape_id: int = 0
## Power as a multiplier on weapon damage, or as an absolute value (depending on kind).
@export var power: int = 0
## -1 = inherit from weapon. Otherwise an int matching Weapon.Element.
@export var element_override: int = -1
## -1 = inherit from weapon. Otherwise an int matching Weapon.AttackType.
@export var attack_type_override: int = -1
@export var mp_cost: int = 0
## 0 = instant. Charge skills require N turns of warm-up.
@export var charge_turns: int = 0
@export var target_filter: TargetFilter = TargetFilter.ENEMY

## Composed effects (DealDamage, Heal, ApplyStatus, ...). SkillEffect Resource hierarchy
## is defined in Phase 1+ — kept as Array[Resource] here so the stub compiles.
@export var effects: Array[Resource] = []
## Trigger condition for passive/reactive skills. Concrete Resource subclass TBD.
@export var trigger_condition: Resource
