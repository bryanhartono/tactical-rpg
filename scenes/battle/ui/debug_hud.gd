class_name DebugHUD extends Control
## Phase 0 debug overlay. Shows FPS in the top-left corner.
## Will be expanded into the real HUD in Phase 1+.

@onready var _fps_label: Label = $FPSLabel

func _process(_delta: float) -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
