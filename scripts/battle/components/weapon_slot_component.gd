class_name WeaponSlotComponent extends RefCounted
## Holds the unit's weapon slots. Phase 1/3: main weapon only.
## Sub weapon, active slot switching, and durability arrive in Phase 4.
## Owned by CharacterUnit; use CharacterUnit.main_weapon / active_weapon() from outside.

var main_weapon: Weapon
var sub_weapon: Weapon       # Phase 4
var active_slot: int = 0     # 0 = main, 1 = sub

## Returns the currently active weapon (main for Phase 3; sub support in Phase 4).
func active_weapon() -> Weapon:
	if active_slot == 1 and sub_weapon != null:
		return sub_weapon
	return main_weapon

func switch_active() -> void:
	active_slot = 1 - active_slot

## Reduce weapon durability. Phase 4 implementation; placeholder here.
func tick_durability(_weapon: Weapon, _cost: int = 1) -> void:
	pass
