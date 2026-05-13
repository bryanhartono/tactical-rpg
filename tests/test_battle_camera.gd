extends GutTest
## P2-T16: BattleCamera preset switching at instant duration.

func test_set_setting_index_updates_current() -> void:
	var rig: BattleCamera = preload("res://scripts/battle/view/battle_camera.gd").new()
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	rig.add_child(pivot)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	pivot.add_child(cam)
	rig.settings = [
		load("res://data/camera_settings/tactical.tres") as CameraSetting,
		load("res://data/camera_settings/overview.tres") as CameraSetting,
		load("res://data/camera_settings/topdown.tres") as CameraSetting,
	]
	add_child_autofree(rig)
	# _ready already fired via add_child; current index should be 0.
	assert_eq(rig.get_current_index(), 0)
	# Switch with zero duration so the tween resolves immediately.
	rig.set_setting_index(2, 0.0)
	# Allow one frame for the tween to start; we can't await across tests reliably.
	# Just check the bookkeeping fields.
	assert_eq(rig.get_current_index(), 2)
