extends Node
## Collects every CombatEventBus signal into an in-memory log. Read-only sink.
## See docs/gdd.md §10.3.
##
## Phase 1 value: this is also the cheapest possible regression test for "are signals
## actually wired up?" through Phase 2+. Set print_to_stdout = true during manual
## playtests to see events as they fire.

@export var print_to_stdout: bool = false

var _log: Array[Dictionary] = []

func _ready() -> void:
	# One lambda per signal so the event name is captured explicitly. Signal arity
	# varies, so each handler accepts the right number of args and forwards them as a
	# payload Array.
	CombatEventBus.damage_dealt.connect(func(a, d, dmg, src): _record("damage_dealt", [a, d, dmg, src]))
	CombatEventBus.unit_killed.connect(func(a, d, src): _record("unit_killed", [a, d, src]))
	CombatEventBus.healing_applied.connect(func(h, t, amt, src): _record("healing_applied", [h, t, amt, src]))
	CombatEventBus.status_applied.connect(func(ap, t, st): _record("status_applied", [ap, t, st]))
	CombatEventBus.status_removed.connect(func(t, st): _record("status_removed", [t, st]))
	CombatEventBus.weapon_used.connect(func(u, w, slot): _record("weapon_used", [u, w, slot]))
	CombatEventBus.weapon_broke.connect(func(u, w, slot): _record("weapon_broke", [u, w, slot]))
	CombatEventBus.duo_formed.connect(func(f, b, tile): _record("duo_formed", [f, b, tile]))
	CombatEventBus.duo_released.connect(func(f, b, tf, tb): _record("duo_released", [f, b, tf, tb]))
	CombatEventBus.duo_switched.connect(func(d): _record("duo_switched", [d]))
	CombatEventBus.attack_resolving.connect(func(a, d, w, ref): _record("attack_resolving", [a, d, w, ref]))
	CombatEventBus.bond_action_triggered.connect(func(ac, ben, kind): _record("bond_action_triggered", [ac, ben, kind]))
	CombatEventBus.turn_started.connect(func(u): _record("turn_started", [u]))
	CombatEventBus.turn_ended.connect(func(u): _record("turn_ended", [u]))
	CombatEventBus.phase_started.connect(func(ph, rd): _record("phase_started", [ph, rd]))
	CombatEventBus.phase_ended.connect(func(ph, rd): _record("phase_ended", [ph, rd]))
	CombatEventBus.battle_started.connect(func(map): _record("battle_started", [map]))
	CombatEventBus.battle_ended.connect(func(result): _record("battle_ended", [result]))
	CombatEventBus.rolled_back.connect(func(idx): _record("rolled_back", [idx]))
	CombatEventBus.unit_facing_changed.connect(func(u, f): _record("unit_facing_changed", [u, f]))

func _record(event_name: String, payload: Array) -> void:
	var entry: Dictionary = {
		"name": event_name,
		"frame": Engine.get_process_frames(),
		"payload": payload,
	}
	_log.append(entry)
	if print_to_stdout:
		print("[BattleLog] %s %s" % [event_name, str(payload)])

## All recorded events, oldest first.
func get_log() -> Array:
	return _log

func clear() -> void:
	_log.clear()

## Filtered helper: returns only entries whose name matches `event_name`.
func get_log_for(event_name: String) -> Array:
	var out: Array = []
	for entry in _log:
		if entry.get("name") == event_name:
			out.append(entry)
	return out
