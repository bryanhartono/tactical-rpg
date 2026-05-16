extends GutTest
## P3-T03: Verify CharacterUnit delegates to StatsComponent / WeaponSlotComponent /
## PositionComponent, and that all existing signals and the convenience accessor
## interface are preserved. See docs/gdd.md §10.1 (principle 2).
##
## Components are RefCounted — accessed directly via CharacterUnit's private vars.
## Test code may access _ vars to verify delegation without polluting the public API.

# ─────────────────────────────────────────────────────────────
# 1. Components are created and accessible after CharacterUnit.new()
# ─────────────────────────────────────────────────────────────
func test_components_exist_after_new() -> void:
	var u := CharacterUnit.new()
	assert_not_null(u._stats,        "StatsComponent should exist after new()")
	assert_not_null(u._weapon_slot,  "WeaponSlotComponent should exist after new()")
	assert_not_null(u._position_comp, "PositionComponent should exist after new()")
	u.free()

# ─────────────────────────────────────────────────────────────
# 2. Convenience accessors read from / write to the components
# ─────────────────────────────────────────────────────────────
func test_stat_accessors_delegate_to_stats_component() -> void:
	var u := CharacterUnit.new()
	u.atk = 42
	u.def = 10
	u.skill = 5
	u.luck = 3
	assert_eq(u._stats.atk, 42)
	assert_eq(u._stats.def, 10)
	assert_eq(u._stats.skill, 5)
	assert_eq(u._stats.luck, 3)
	u.free()

func test_position_accessors_delegate_to_position_component() -> void:
	var u := CharacterUnit.new()
	u.grid_position = Vector2i(3, 5)
	u.facing = Vector2i.LEFT
	u.move_budget = 7
	assert_eq(u._position_comp.grid_position, Vector2i(3, 5))
	assert_eq(u._position_comp.facing, Vector2i.LEFT)
	assert_eq(u._position_comp.move_budget, 7)
	u.free()

func test_weapon_accessor_delegates_to_weapon_slot_component() -> void:
	var u := CharacterUnit.new()
	var w := Weapon.new()
	w.initial_power = 50
	u.main_weapon = w
	assert_eq(u._weapon_slot.main_weapon, w)
	u.free()

# ─────────────────────────────────────────────────────────────
# 3. take_damage delegates to StatsComponent and emits hp_changed
# ─────────────────────────────────────────────────────────────
func test_take_damage_updates_stats_component_hp() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var hp_before := u._stats.current_hp
	u.take_damage(5)
	assert_eq(u._stats.current_hp, hp_before - 5,
			"StatsComponent.current_hp should reflect damage")
	u.free()

func test_take_damage_emits_hp_changed_signal() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var signal_fired := [false]
	u.hp_changed.connect(func(_old, _new): signal_fired[0] = true)
	u.take_damage(3)
	assert_true(signal_fired[0], "hp_changed should fire on CharacterUnit, not component")
	u.free()

# ─────────────────────────────────────────────────────────────
# 4. current_hp accessor mirrors StatsComponent.current_hp
# ─────────────────────────────────────────────────────────────
func test_current_hp_accessor_reads_stats_component() -> void:
	var u := CharacterUnit.new()
	u._stats.current_hp = 77
	assert_eq(u.current_hp, 77, "unit.current_hp should read from StatsComponent")
	u.free()

# ─────────────────────────────────────────────────────────────
# 5. initialize_from_definition populates all three components
# ─────────────────────────────────────────────────────────────
func test_initialize_from_definition_sets_all_components() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	# Aria/Swordsman: hp=25, atk=8, def=5, move=5 (INFANTRY)
	assert_eq(u._stats.max_hp, 25)
	assert_eq(u._stats.atk, 8)
	assert_eq(u._stats.def, 5)
	assert_eq(u._position_comp.move_budget, 5)
	assert_not_null(u._weapon_slot.main_weapon)
	u.free()

# ─────────────────────────────────────────────────────────────
# 6. active_weapon() delegates to WeaponSlotComponent
# ─────────────────────────────────────────────────────────────
func test_active_weapon_delegates_to_weapon_slot() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	assert_eq(u.active_weapon(), u._weapon_slot.active_weapon(),
			"active_weapon() should delegate to WeaponSlotComponent")
	u.free()
