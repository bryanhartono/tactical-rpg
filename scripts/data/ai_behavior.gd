class_name AIBehavior extends Resource
## Tunable weights for the AIController's score-based decision making.
## See docs/gdd.md §8.2 and §8.3.

enum Role { ATTACKER, TANKER, BUFFER, HEALER, OTHER }

@export var id: int = 0
@export var display_name: String = ""
@export var role: Role = Role.ATTACKER
@export_range(0.0, 1.0) var aggression: float = 0.5
@export_range(0.0, 1.0) var self_preservation: float = 0.5
@export var prefer_low_hp_targets: float = 0.0
@export var prefer_squishy_targets: float = 0.0
@export var stay_in_pair_threshold_hp: float = 0.0
@export var prefer_high_ground: float = 0.0
@export var healer_priority: float = 0.0
