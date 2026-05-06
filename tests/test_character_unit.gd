extends GutTest
## P1-T03: CharacterUnit.

func test_take_damage_reduces_hp() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var hp_before := u.current_hp
	u.take_damage(5)
	assert_eq(u.current_hp, hp_before - 5)
	u.free()

func test_take_damage_clamps_to_zero() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	u.take_damage(9999)
	assert_eq(u.current_hp, 0)
	assert_false(u.is_alive())
	u.free()

func test_take_damage_emits_died_once() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var death_count := [0]
	u.died.connect(func(): death_count[0] += 1)
	u.take_damage(9999)
	u.take_damage(5)  # second damage on dead unit should be a no-op
	assert_eq(death_count[0], 1)
	u.free()

func test_lethal_emits_unit_killed_on_bus() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	var bus_calls := [0]
	var conn := func(_a, _d, _src): bus_calls[0] += 1
	CombatEventBus.unit_killed.connect(conn)
	u.take_damage(9999)
	assert_eq(bus_calls[0], 1)
	CombatEventBus.unit_killed.disconnect(conn)
	u.free()

func test_initialize_from_definition_sets_stats() -> void:
	var u := P1TestHelpers.make_unit(1, 0, Vector2i.ZERO)
	# Aria/Swordsman base: hp=25, atk=8, def=5
	assert_eq(u.max_hp, 25)
	assert_eq(u.current_hp, 25)
	assert_eq(u.atk, 8)
	assert_eq(u.def, 5)
	assert_eq(u.move_budget, 5)  # INFANTRY
	assert_not_null(u.main_weapon)
	u.free()
