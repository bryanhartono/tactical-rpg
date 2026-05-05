class_name Weapon extends Resource
## An equippable weapon. See docs/gdd.md §7.2.
## Stats interpolate between initial_X and limit_X based on current limit-break level
## (interpolation logic lives on the unit, not this resource).

enum Category { SWORD, LANCE, AXE, BOW, TOME, STAFF, DAGGER, POLEARM }
enum AttackType { SLASH, BLOW, PIERCE, SHOT, MAGIC }
enum Element { NONE, FIRE, ICE, THUNDER, WIND, LIGHT, DARK }

@export var id: int = 0
@export var name: String = ""
@export var category: Category = Category.SWORD
@export_range(1, 5) var rarity: int = 1
@export var attack_type: AttackType = AttackType.SLASH
@export var element: Element = Element.NONE
@export var range_shape_id: int = 0

# Stats — base values used at limit-break level 0.
@export var initial_power: int = 0
@export var initial_hit: int = 0
@export var initial_crit: int = 0
@export var initial_avoid: int = 0
@export var initial_weight: int = 0

# Stats — values at maximum limit-break level.
@export var limit_power: int = 0
@export var limit_hit: int = 0
@export var limit_crit: int = 0
@export var limit_avoid: int = 0
@export var limit_weight: int = 0

@export var max_durability: int = 0
@export var limit_break_max: int = 0
@export var granted_skill: Skill
