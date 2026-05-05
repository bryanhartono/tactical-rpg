class_name CharacterDefinition extends Resource
## Roster entry for a playable or named-enemy unit. See docs/gdd.md §7.7.
## v1: each unit has a single fixed Style; multi-Style is post-v1.

enum BondActionKind { ATTACK, HEAL, GUARD }

@export var id: int = 0
@export var display_name: String = ""
@export var default_style: StyleDefinition
@export var portrait: Texture2D
@export var sprite_frames_resource: SpriteFrames

# Per-character stat baselines, layered on top of Style baselines.
@export var base_hp: int = 0
@export var base_atk: int = 0
@export var base_def: int = 0
@export var base_skill: int = 0
@export var base_speed: int = 0
@export var base_luck: int = 0

@export var growth_hp: int = 0
@export var growth_atk: int = 0
@export var growth_def: int = 0
@export var growth_skill: int = 0
@export var growth_speed: int = 0
@export var growth_luck: int = 0

@export var default_main_weapon: Weapon
@export var default_sub_weapon: Weapon
@export var bond_action_kind: BondActionKind = BondActionKind.ATTACK
