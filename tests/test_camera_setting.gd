extends GutTest
## P2-T06 / P2-T16: validate the three camera preset .tres files load with the values
## from the revised GDD §6.3.

const _TACTICAL := "res://data/camera_settings/tactical.tres"
const _OVERVIEW := "res://data/camera_settings/overview.tres"
const _TOPDOWN := "res://data/camera_settings/topdown.tres"

func test_tactical_preset() -> void:
	var s: CameraSetting = load(_TACTICAL)
	assert_not_null(s)
	assert_eq(s.id, 1)
	assert_eq(s.display_name, "Tactical")
	assert_almost_eq(s.rotation_angles.x, -50.0, 0.01)

func test_overview_preset() -> void:
	var s: CameraSetting = load(_OVERVIEW)
	assert_not_null(s)
	assert_eq(s.id, 2)
	assert_eq(s.display_name, "Overview")
	assert_almost_eq(s.rotation_angles.x, -70.0, 0.01)

func test_topdown_preset() -> void:
	var s: CameraSetting = load(_TOPDOWN)
	assert_not_null(s)
	assert_eq(s.id, 3)
	assert_eq(s.display_name, "Top-down")
	assert_almost_eq(s.rotation_angles.x, -90.0, 0.01)

func test_preset_ids_are_unique() -> void:
	var ids := []
	for path in [_TACTICAL, _OVERVIEW, _TOPDOWN]:
		var s: CameraSetting = load(path)
		ids.append(s.id)
	assert_eq(ids.size(), 3)
	assert_true(ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
