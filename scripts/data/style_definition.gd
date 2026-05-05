class_name StyleDefinition extends Resource
## A "Style" is the project's name for a character class. See docs/gdd.md §7.1.
## Defines locomotion, base stats, growth rates, allowed weapons, and innate skills.

enum MoveType {
	INFANTRY,
	ADVANCED_INFANTRY,
	CAVALRY,
	ADVANCED_CAVALRY,
	FLYING,
	ADVANCED_FLYING,
	FLOATING,
	LARGE_BOSS,
}

@export var id: int = 0
@export var display_name: String = ""
@export var move_type: MoveType = MoveType.INFANTRY

# Base stats (level 1).
@export var base_hp: int = 0
@export var base_atk: int = 0
@export var base_def: int = 0
@export var base_skill: int = 0
@export var base_speed: int = 0
@export var base_luck: int = 0

# Per-level growth rates (percent chance of +1).
@export var growth_hp: int = 0
@export var growth_atk: int = 0
@export var growth_def: int = 0
@export var growth_skill: int = 0
@export var growth_speed: int = 0
@export var growth_luck: int = 0

## Allowed weapon categories with starting proficiency.
## Key: int (Weapon.Category). Value: int proficiency rank 0..5 (E..S).
@export var allowed_weapon_categories: Dictionary = {}

## Innate skills, always available regardless of equipped weapons.
@export var innate_skills: Array[Skill] = []
