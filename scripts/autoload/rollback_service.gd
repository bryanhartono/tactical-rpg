extends Node
## Snapshots Board state per action and per turn for rewind.
## See docs/gdd.md §5.12 and §10.3.
##
## Usage:
##   BattleManager calls register_board_source(board) after creating its board.
##   CommandQueue calls snapshot_before_command() inside every submit().
##   PlayerPhaseController / HUD calls rewind_last_action() on Rewind button press.

## Circular buffer of pre-command snapshots. Max size = BattleConst.rollback_free_count.
var _action_buffer: Array[Board] = []
## Per-entry unit state parallel to _action_buffer.
## Each entry: Dictionary { unit_id → { has_acted, has_moved, current_hp } }
var _unit_state_buffer: Array[Dictionary] = []
## One snapshot per turn-start. Max size = BattleConst.rollback_save_turn_count.
var _turn_snapshots: Array[Board] = []
## How many rewinds the player has used this battle.
var _rewinds_used: int = 0
## The live board to snapshot. Set by BattleManager.register_board_source().
var board_source: Board = null
## Cached ref to BattleManager for restore_board calls. Set alongside board_source.
var _battle_manager: Node = null


func _ready() -> void:
	pass

# ----------------------------------------------------------------------------
# Registration (called by BattleManager after its board is created)
# ----------------------------------------------------------------------------

## BattleManager calls this to give RollbackService a reference to the live board.
## Also stores the manager reference so restore_board can be called on rewind.
func register_board_source(manager: Node, board: Board) -> void:
	_battle_manager = manager
	board_source = board

# ----------------------------------------------------------------------------
# Snapshot API (called by CommandQueue)
# ----------------------------------------------------------------------------

## Deep-copy the live board tiles and capture per-unit state.
## If board_source is null (e.g. unit tests without BattleManager), this is a no-op.
func snapshot_before_command(_command: Command) -> void:
	if board_source == null:
		return
	var bc: BattleConst = MasterDataService.battle_const
	var snap := board_source.duplicate(true) as Board
	var unit_states: Dictionary = _capture_unit_states()
	if _action_buffer.size() >= bc.rollback_free_count:
		_action_buffer.pop_front()
		_unit_state_buffer.pop_front()
	_action_buffer.push_back(snap)
	_unit_state_buffer.push_back(unit_states)

## Deep-copy the live board as a turn-start checkpoint.
## Called by BattleManager at the top of _enter_phase(PLAYER) each round.
func snapshot_turn_start() -> void:
	if board_source == null:
		return
	var bc: BattleConst = MasterDataService.battle_const
	var snap := board_source.duplicate(true) as Board
	if _turn_snapshots.size() >= bc.rollback_save_turn_count:
		_turn_snapshots.pop_front()
	_turn_snapshots.push_back(snap)

# ----------------------------------------------------------------------------
# Rewind API
# ----------------------------------------------------------------------------

## True if the player can still rewind (has snapshots and rewinds remaining).
func can_rewind() -> bool:
	var bc: BattleConst = MasterDataService.battle_const
	return _rewinds_used < bc.rollback_free_count and _action_buffer.size() > 0

## Pop the latest pre-command snapshot and restore the board to that state,
## including unit has_acted / has_moved / current_hp.
## Does nothing if can_rewind() is false.
func rewind_last_action() -> void:
	if not can_rewind():
		return
	var snap: Board = _action_buffer.pop_back()
	var unit_states: Dictionary = _unit_state_buffer.pop_back()
	_rewinds_used += 1
	if _battle_manager != null and _battle_manager.has_method("restore_board"):
		_battle_manager.restore_board(snap)
	# Restore per-unit state (has_acted, has_moved, current_hp) after board restore.
	if board_source != null:
		_apply_unit_states(unit_states)
	CombatEventBus.rolled_back.emit(_action_buffer.size())

## How many rewinds the player has left this battle.
func rewinds_remaining() -> int:
	var bc: BattleConst = MasterDataService.battle_const
	return bc.rollback_free_count - _rewinds_used

## Number of snapshots currently in the action buffer. Used by tests.
func snapshot_count() -> int:
	return _action_buffer.size()

## Reset all state. Called at battle start and by tests for isolation.
func reset() -> void:
	_action_buffer.clear()
	_unit_state_buffer.clear()
	_turn_snapshots.clear()
	_rewinds_used = 0
	board_source = null
	_battle_manager = null

# ----------------------------------------------------------------------------
# Private helpers
# ----------------------------------------------------------------------------

func _capture_unit_states() -> Dictionary:
	var states: Dictionary = {}
	for unit_id in board_source.units:
		var u := board_source.units[unit_id] as CharacterUnit
		if u == null:
			continue
		states[unit_id] = {
			"has_acted": u.has_acted,
			"has_moved": u.has_moved,
			"current_hp": u.current_hp,
		}
	return states

func _apply_unit_states(states: Dictionary) -> void:
	for unit_id in states:
		var u := board_source.units.get(unit_id) as CharacterUnit
		if u == null:
			continue
		var s: Dictionary = states[unit_id]
		u.has_acted = s.get("has_acted", false)
		u.has_moved = s.get("has_moved", false)
		u.current_hp = s.get("current_hp", u.current_hp)
