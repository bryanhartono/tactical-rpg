class_name UnitStatusPanel extends Control
## Right-side popup that shows the selected unit's status (name + HP).
## Phase 2: just name + HP. Phase 4+ will add weapon, status effects, etc.
## See docs/gdd.md §6.4 (per-unit panel).

@onready var _name_label: Label = $Panel/VBox/NameLabel
@onready var _hp_label: Label = $Panel/VBox/HPLabel

var _bound_unit: CharacterUnit

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_for_unit(unit: CharacterUnit) -> void:
	if unit == null:
		hide_panel()
		return
	_bind(unit)
	_refresh()
	show()

func hide_panel() -> void:
	_unbind()
	hide()

# ----------------------------------------------------------------------------
# Internals
# ----------------------------------------------------------------------------

func _bind(unit: CharacterUnit) -> void:
	if _bound_unit == unit:
		return
	_unbind()
	_bound_unit = unit
	if unit != null:
		unit.hp_changed.connect(_on_hp_changed)
		unit.died.connect(_on_died)

func _unbind() -> void:
	if _bound_unit == null:
		return
	if _bound_unit.hp_changed.is_connected(_on_hp_changed):
		_bound_unit.hp_changed.disconnect(_on_hp_changed)
	if _bound_unit.died.is_connected(_on_died):
		_bound_unit.died.disconnect(_on_died)
	_bound_unit = null

func _refresh() -> void:
	if _bound_unit == null:
		return
	_name_label.text = _bound_unit.display_name
	_hp_label.text = "HP %d / %d" % [_bound_unit.current_hp, _bound_unit.max_hp]

func _on_hp_changed(_old: int, _new: int) -> void:
	_refresh()

func _on_died() -> void:
	hide_panel()
