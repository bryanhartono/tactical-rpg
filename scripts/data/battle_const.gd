class_name BattleConst extends Resource
## Tunable battle constants. Source: GDD §11.1 (ported from Aster's BattleConst.json
## and BattleLogicConst.json). Edit the .tres in the inspector; runtime code reads only.

# Damage clamp
@export var min_damage: int = 1
@export var max_damage: int = 9999

# Rollback / rewind
@export var rollback_save_turn_count: int = 5
@export var rollback_free_count: int = 3

# Animation
@export var fast_mode_speed: float = 3.0

# Bond accrual
@export var bond_increase_by_skill: int = 5
@export var bond_increase_by_clear: int = 5
@export var bond_decrease_by_dead: int = 40

# Element interaction (percent)
@export var element_advantage_rate: int = 30
@export var element_disadvantage_rate: int = 30

# Duo stat correction baseline
@export var double_status_adjust_value: int = 100

# Weapon weight → speed reduction coefficient
@export var load_weight_coefficient: int = 30

# Facing damage modifiers
@export var back_attack_modifier: float = 1.5
@export var side_attack_modifier: float = 1.2
@export var front_attack_modifier: float = 1.0

# Elevation damage modifiers
@export var higher_ground_modifier: float = 1.15
@export var lower_ground_modifier: float = 0.90

# Per-MoveType jump heights (max climbable elevation delta in tile-units)
@export var infantry_jump_height: int = 1
@export var cavalry_jump_height: int = 1
@export var flying_jump_height: int = 99
@export var floating_jump_height: int = 2
