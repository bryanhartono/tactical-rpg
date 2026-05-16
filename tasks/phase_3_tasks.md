# Phase 3 — Architecture Spine Wiring

> **GDD reference:** §10.1 (six principles), §10.4 (Command pattern), §10.3 (autoloads),
> §5.5 (damage formula), §5.12 (rewind / rollback), §10.9 (testing).
>
> **Milestone:** M1 — Architectural Skeleton (end of Phase 3).
> GDD definition: "Event bus, Commands, Simulators are real and tested. Damage formula
> lives in one place. Rewind works."
>
> **Scope:** Pure architecture wiring — no new gameplay features. The 2v2 battle from
> Phase 2 continues to function identically from the player's perspective. What changes
> is where logic lives and how it is connected.
>
> **NOT doing in Phase 3:**
> - ExperienceService / EXP awards (Phase 5)
> - BondService / Bond values (Phase 5)
> - ProficiencyService (Phase 5)
> - BondActionService (Phase 7)
> - SkillCommand (Phase 5/6)
> - SwitchWeaponCommand (Phase 4)
> - Duo commands (Phase 6)
> - Any new game content (maps, units, weapons)
> - UI changes beyond wiring DamagePreview to AttackSimulator
> - Facing arrow decal (Phase 5)

---

## Design constraints (read before starting any task)

### C1 — Principle 2: Component composition over inheritance
`CharacterUnit` is currently a monolith: stats, position, facing, equipment, HP — all in
one Node. Phase 3 breaks this into components. This is **non-negotiable per GDD §10.1**.
Each component is a lightweight inner-Node or Resource attached to `CharacterUnit`. The
unit itself becomes a thin coordinator; components own their domain.

Target component split (see P3-T03):
- `StatsComponent` — base stats, current HP/MP, stat derivations
- `WeaponSlotComponent` — main slot, sub slot, current active slot, durability
- `PositionComponent` — grid_position, facing, movement type, jump_height
- `CharacterUnit` (coordinator) — owns components, provides convenience accessors,
  still emits local signals

Signals on `CharacterUnit` stay on `CharacterUnit` — components may emit internal events
upward to the unit, but external listeners (views, services) always subscribe to the unit,
never to individual components. This preserves the existing Phase 1/2 signal contracts.

### C2 — Simulators are pure functions
`AttackSimulator` (and later `HealSimulator`, `ActionScorer`) are **static GDScript
classes** — no node, no autoload, no state. They take inputs, return a result struct, and
allocate nothing in the hot path (GDD §10.10: "Simulators must be pure functions, no
allocation in the hot path").

`AttackSimulatorResult` is a small inner class / value type:
```gdscript
class AttackSimulatorResult:
    var expected_damage: int
    var hit_chance: int       # 0–100
    var crit_chance: int      # 0–100
    var will_kill: bool
    var counter_damage: int   # expected damage from counterattack (0 if none)
    var counter_hit_chance: int
```

### C3 — RollbackService uses Board.duplicate(true)
GDD §5.12 specifies: "Snapshots are full `Board.duplicate(true)` calls, kept in a
circular buffer of size = 3." The rollback buffer holds snapshots at **action granularity**
(one per Command.execute), with an additional snapshot at each **turn-start**. On rewind,
the service replaces `BattleManager`'s live board reference and notifies views to rebuild.

`rollback_free_count = 3` from `BattleConst.tres` (§11.1). After 3 rewinds the button
is disabled for the remainder of the battle.

### C4 — BattleConst.tres must exist before formula work
The damage formula constants (back_attack_modifier, higher_ground_modifier, etc.) live in
`data/battle_const.tres` (a `BattleConst` Resource). Any code that references a tunable
constant must read from this resource, not hardcode the value. P3-T01 creates this
resource before any simulator or formula task.

### C5 — CommandQueue is the single submission path
GDD §10.4: "UI never calls Board methods directly. UI builds a Command, submits to
`CommandQueue`, which validates and executes." `CommandQueue` currently exists as a stub
from Phase 0. Phase 3 makes it real: it validates, executes, and notifies
`RollbackService` to snapshot before each execution.

### C6 — CLAUDE.md update is task P3-T01's first action
Before any code: add a single line to `CLAUDE.md` under the archive-management section:
> "The user manages PROGRESS_ARCHIVE.md manually. Do not move entries to the archive yourself."

---

## Tasks

---

### P3-T01 — BattleConst resource + CLAUDE.md update

**What:**
1. Add one line to `CLAUDE.md` (see Constraint C6 above). Do this first, before any
   other work in Phase 3.
2. Create `scripts/data/battle_const.gd` — a `Resource` subclass with `@export` fields
   for every tunable constant in GDD §11.1 that the damage formula and rollback system
   need in Phase 3. At minimum:

```gdscript
class_name BattleConst extends Resource

# Damage formula
@export var min_damage: int = 1
@export var max_damage: int = 9999
@export var back_attack_modifier: float = 1.5
@export var side_attack_modifier: float = 1.2
@export var front_attack_modifier: float = 1.0
@export var higher_ground_modifier: float = 1.15
@export var lower_ground_modifier: float = 0.90

# Hit / crit
@export var min_hit_chance: int = 5
@export var max_hit_chance: int = 95
@export var max_crit_chance: int = 50

# Rollback
@export var rollback_save_turn_count: int = 5
@export var rollback_free_count: int = 3
```

3. Save `data/battle_const.tres` with the above default values.
4. Register `battle_const.tres` in `MasterDataService` so it is loaded at boot and
   accessible as `MasterDataService.battle_const`.

**Acceptance criteria:**
- `CLAUDE.md` contains the archive-management line.
- `data/battle_const.tres` loads without error.
- `MasterDataService.battle_const` returns the resource in a GUT test.
- All existing 42 tests still pass.

---

### P3-T02 — AttackSimulator extracted from AttackCommand

**What:**
Extract the damage formula from `AttackCommand` into `scripts/battle/simulators/attack_simulator.gd`.

`AttackSimulator` is a **static class** (no `extends Node`, no instantiation). Its public
API:

```gdscript
class_name AttackSimulator

static func predict(
    attacker: CharacterUnit,
    defender: CharacterUnit,
    weapon: WeaponDefinition,
    board: Board,
    battle_const: BattleConst
) -> AttackSimulatorResult:
    ...

static func resolve(
    attacker: CharacterUnit,
    defender: CharacterUnit,
    weapon: WeaponDefinition,
    board: Board,
    battle_const: BattleConst,
    rng: RandomNumberGenerator
) -> AttackSimulatorResult:
    # Same as predict but rolls hit/crit using rng
    ...
```

The **full damage formula from GDD §5.5** (not the Phase 1 placeholder):
```
base_damage = attacker.Atk * weapon.power / 100
mitigation  = defender.Def * (1 + terrain_def_bonus)
raw         = base_damage - mitigation

× facing_modifier      # from BattleConst; computed from attacker pos vs defender facing
× elevation_modifier   # from BattleConst; placeholder 1.0 until Phase 8 terrain
× element_modifier     # placeholder 1.0 until Phase 5/13 element system
× type_modifier        # placeholder 1.0 until Phase 5/13
× critical_modifier    # 1.5 if crit, 1.0 otherwise
× pair_bonus           # placeholder 1.0 until Phase 6 Duo

final = clamp(raw, battle_const.min_damage, battle_const.max_damage)
```

**Hit rate (GDD §5.5):**
```
hit_chance = clamp(weapon.hit + attacker.Skill - defender.Avoid - terrain_evade_bonus,
                   battle_const.min_hit_chance, battle_const.max_hit_chance)
```

**Crit rate (GDD §5.5):**
```
crit_chance = clamp(weapon.crit + attacker.Skill / 4 - defender.Luck,
                    0, battle_const.max_crit_chance)
```

Terrain bonuses: read from the defender's tile's `LandformDefinition` if available;
default 0 if terrain system not yet wired (fine for Phase 3).

**Facing modifier** (GDD §5.6): compute from `(attacker.grid_position - defender.grid_position)`
vs `defender.facing`. Use the dominant-axis cardinal direction. Back (opposite) → 1.5×,
side (perpendicular) → 1.2×, front (same) → 1.0×. Read multipliers from `battle_const`.

`AttackCommand.execute()` calls `AttackSimulator.resolve(...)` instead of the inline
formula. `AttackCommand.predict_damage` static method is removed; callers migrate to
`AttackSimulator.predict(...)`.

`DamagePreview` calls `AttackSimulator.predict(...)` directly (no longer goes through
`AttackCommand`). This resolves the Phase 1 T-17 TODO.

**Acceptance criteria:**
- `AttackSimulator` is a static class with no `extends Node` or instance state.
- `AttackCommand` contains no damage formula. It calls `AttackSimulator.resolve`.
- `DamagePreview` calls `AttackSimulator.predict` directly.
- `AttackCommand.predict_damage` static method is gone.
- GUT: `test_attack_simulator.gd` with ≥ 10 assertions covering:
  - Base damage calculation correct for known inputs
  - Facing modifiers (front / side / back) applied correctly
  - Crit path produces 1.5× damage
  - Hit chance clamped to [5, 95]
  - All values read from BattleConst (mutate battle_const in test; result should change)
- All existing 42 tests still pass.

---

### P3-T03 — CharacterUnit component refactor

**What:**
Split `CharacterUnit` into components per GDD §10.1 Principle 2. This is the most
structurally significant task in Phase 3.

**Three inner-node components** (lightweight `Node` subclasses, added as children of
`CharacterUnit` in `_ready`):

**`StatsComponent` (`scripts/battle/components/stats_component.gd`):**
```gdscript
class_name StatsComponent extends Node
# Base stats (set from CharacterDefinition)
var max_hp: int
var max_mp: int
var atk: int
var def: int
var skill: int       # hit rate / crit rate contributor
var speed: int
var luck: int
var avoid: int
# Current state
var current_hp: int
var current_mp: int
# Methods
func take_damage(amount: int) -> int   # returns actual damage dealt
func heal(amount: int) -> int          # returns actual HP restored
func is_alive() -> bool
```

**`WeaponSlotComponent` (`scripts/battle/components/weapon_slot_component.gd`):**
```gdscript
class_name WeaponSlotComponent extends Node
var main_weapon: WeaponDefinition
var sub_weapon: WeaponDefinition
var active_slot: int   # 0 = main, 1 = sub
func active_weapon() -> WeaponDefinition
func switch_active() -> void
func tick_durability(weapon: WeaponDefinition, cost: int = 1) -> void
```

**`PositionComponent` (`scripts/battle/components/position_component.gd`):**
```gdscript
class_name PositionComponent extends Node
var grid_position: Vector2i
var facing: int    # 0=N 1=E 2=S 3=W  (same enum as before)
var move_type: int
var jump_height: int
var move_budget: int        # remaining moves this turn
var last_move_path: Array[Vector2i]
```

**`CharacterUnit` (coordinator, `scripts/battle/character_unit.gd`):**
- Adds the three components in `_ready`.
- Keeps all existing **signals** on the unit itself (not components):
  `hp_changed`, `moved`, `facing_changed`, `died`, `attacked`.
- Provides **convenience accessors** that delegate to components:
  `var current_hp: int: get: return stats.current_hp`
  `var grid_position: Vector2i: get: return position_comp.grid_position`
  etc.
- `take_damage` on the unit delegates to `stats.take_damage`, then emits `hp_changed`
  and conditionally `died` + `CombatEventBus.unit_killed` — same external contract as
  before.
- `initialize_from_definition` populates all three components from the
  `CharacterDefinition` resource.

**External callers** (`AttackCommand`, `MoveCommand`, `AIController`, `AttackSimulator`,
`Pathfinder`, tests) reference `unit.current_hp`, `unit.grid_position`, `unit.facing`,
`unit.atk`, `unit.def`, `unit.active_weapon()` etc. — these all still work through the
convenience accessors. No caller changes are needed if accessors are complete.

**Important:** `DuoUnit` (Phase 6) will implement the same accessor surface. No
`is CharacterUnit` checks anywhere in combat logic — this enforces GDD §10.1 Principle 5.

**Acceptance criteria:**
- `CharacterUnit` has no stat fields directly — all delegated to `StatsComponent`.
- No weapon fields directly — delegated to `WeaponSlotComponent`.
- No position/facing/path fields directly — delegated to `PositionComponent`.
- All Phase 1/2 signals still emitted from `CharacterUnit`, not from components.
- All existing 42 tests still pass without modification to test files
  (the convenience accessors preserve the contract).
- GUT: `test_character_unit_components.gd` with ≥ 8 assertions:
  - `take_damage` on unit delegates to stats and emits `hp_changed`
  - `unit.current_hp` reflects `stats.current_hp`
  - `unit.active_weapon()` delegates to `weapon_slot`
  - `initialize_from_definition` sets all three components correctly

---

### P3-T04 — CommandQueue real implementation

**What:**
`CommandQueue` exists from Phase 0 as a stub. Make it real per GDD §10.4.

```gdscript
class_name CommandQueue extends Node

signal command_executed(command: Command)
signal command_failed(command: Command, reason: String)

func submit(command: Command) -> bool:
    if not command.validate():
        command_failed.emit(command, "validation_failed")
        return false
    RollbackService.snapshot_before_command(command)
    command.prepare()
    command.execute()
    command.complete()
    command_executed.emit(command)
    return true
```

Key points:
- `submit` is synchronous in Phase 3. Async queuing (for animation wait) is handled
  upstream by callers using `await` on view signals — `CommandQueue` does not await.
- `RollbackService.snapshot_before_command(command)` is called inside submit, before
  `command.prepare()`. This is the canonical snapshot point.
- `BattleManager` and `PlayerPhaseController` submit all commands via `CommandQueue`.
  Direct `command.execute()` calls in those files are replaced with `queue.submit(command)`.
- `AIController` also submits via `CommandQueue`.

**Acceptance criteria:**
- `CommandQueue.submit` is the only call path into `Command.execute` in the entire
  codebase (grep for `\.execute()` — only `CommandQueue` may call it).
- `RollbackService.snapshot_before_command` is called inside `submit` before `prepare`.
- GUT: `test_command_queue.gd` with ≥ 6 assertions:
  - Valid command executes and emits `command_executed`
  - Invalid command (validate returns false) emits `command_failed` and does not execute
  - `RollbackService` receives a snapshot call on every valid submission
- All existing 42 tests still pass.

---

### P3-T05 — RollbackService real implementation

**What:**
Implement `RollbackService` per GDD §5.12.

```gdscript
# scripts/autoload/rollback_service.gd
# (already registered as autoload from Phase 0 — make it real)

var _action_buffer: Array[Board]   # circular, max size = battle_const.rollback_free_count
var _turn_snapshots: Array[Board]  # one per turn-start, max = rollback_save_turn_count
var _rewinds_used: int = 0
var _battle_const: BattleConst

signal rolled_back(to_turn: int)

func snapshot_before_command(command: Command) -> void:
    # Deep-copy the live board and push to _action_buffer (circular)
    var snap = BattleManager.board.duplicate(true)
    if _action_buffer.size() >= _battle_const.rollback_free_count:
        _action_buffer.pop_front()
    _action_buffer.push_back(snap)

func snapshot_turn_start() -> void:
    # Called by BattleManager at the start of each player phase
    var snap = BattleManager.board.duplicate(true)
    if _turn_snapshots.size() >= _battle_const.rollback_save_turn_count:
        _turn_snapshots.pop_front()
    _turn_snapshots.push_back(snap)

func can_rewind() -> bool:
    return _rewinds_used < _battle_const.rollback_free_count \
           and _action_buffer.size() > 0

func rewind_last_action() -> void:
    if not can_rewind():
        return
    var snap: Board = _action_buffer.pop_back()
    _rewinds_used += 1
    BattleManager.restore_board(snap)
    CombatEventBus.rolled_back.emit()

func rewinds_remaining() -> int:
    return _battle_const.rollback_free_count - _rewinds_used

func reset() -> void:
    _action_buffer.clear()
    _turn_snapshots.clear()
    _rewinds_used = 0
```

**`BattleManager.restore_board(snap: Board)`:**
- Replaces `_board` with the snapshot.
- Re-wires `TileInputController` and `Pathfinder` to the new board reference.
- Calls `UnitView3D` refresh on all units (reposition views to match restored state).
- Emits `CombatEventBus.rolled_back`.

**`BattleManager`** calls `RollbackService.snapshot_turn_start()` at the top of
`_enter_phase(PLAYER)` each round.

**CombatEventBus** gets a new signal: `rolled_back()`. `BattleLogService` connects to it.

**Rewind button** (HUD): wire a placeholder button ("Rewind", top-right area) to
`RollbackService.rewind_last_action()`. Show remaining count from
`RollbackService.rewinds_remaining()`. Grey out when `can_rewind()` is false. Full HUD
polish is Phase 17; this is just the functional wire-up.

**Acceptance criteria:**
- `RollbackService.snapshot_before_command` is called on every `CommandQueue.submit`.
- After a `MoveCommand` executes and `rewind_last_action` is called, the unit is back
  on its original tile and `_rewinds_used == 1`.
- After 3 rewinds, `can_rewind()` returns false.
- `rewind_last_action` when buffer is empty does nothing (no crash).
- A rewind button exists in the HUD showing remaining count; clicking it calls
  `rewind_last_action`.
- GUT: `test_rollback_service.gd` with ≥ 10 assertions covering the above cases.
- `MoveCommand.cancel()` is still present (used internally if needed) but the canonical
  undo path is `RollbackService.rewind_last_action` — not direct cancel calls.
- All existing 42 tests still pass.

---

### P3-T06 — BattleConst wired into damage formula

**What:**
Audit every hardcoded combat constant in the codebase and replace with a reference to
`MasterDataService.battle_const`. This is a sweep task — no new logic, just replacing
magic numbers.

Files to sweep:
- `attack_simulator.gd` — already uses `battle_const` param (P3-T02); verify no
  leftover hardcoded values
- `attack_command.gd` — should now have no formula code at all (P3-T02); verify
- `ai_controller.gd` — any hardcoded damage estimates
- `pathfinder.gd` — any hardcoded movement cost defaults
- `battle_manager.gd` — any hardcoded phase or round constants

**Add to `BattleConst`** anything discovered during the sweep that isn't already there.
Update `data/battle_const.tres` with the value.

**Acceptance criteria:**
- `grep -rn "1\.5\|1\.2\|1\.15\|0\.90\|9999" scripts/` returns no results
  (the specific magic numbers from the damage formula are gone).
- All constants live in `battle_const.tres`.
- All existing tests still pass.

---

### P3-T07 — Update GUT test suite

**What:**
Bring the test suite up to date to cover all Phase 3 work. Phase 3 adds significant new
code paths that need coverage.

**New test files:**
- `test_attack_simulator.gd` — already specified in P3-T02 (≥ 10 assertions)
- `test_character_unit_components.gd` — already specified in P3-T03 (≥ 8 assertions)
- `test_command_queue.gd` — already specified in P3-T04 (≥ 6 assertions)
- `test_rollback_service.gd` — already specified in P3-T05 (≥ 10 assertions)
- `test_battle_const.gd` — simple: resource loads, MasterDataService.battle_const is
  not null, key fields have expected default values (≥ 5 assertions)

**Update existing test files:**
- `test_attack_command.gd` — remove any assertions that tested the old inline formula;
  replace with assertions that `AttackCommand` calls into `AttackSimulator` (verify via
  a test double or by inspecting side effects).
- `test_character_unit.gd` — update if any assertions directly accessed fields that
  are now on components (they should still pass via accessors, but verify).
- Any test that called `AttackCommand.predict_damage` must migrate to
  `AttackSimulator.predict`.

**Target test count:** ≥ 81 tests passing (42 existing + ~39 new). Exact count may vary;
document the final count in PROGRESS.md.

**Acceptance criteria:**
- All tests pass headless under `gut_cmdln.gd --headless`.
- New tests cover every public method on `AttackSimulator`, `CommandQueue`, and
  `RollbackService`.
- No test calls `AttackCommand.predict_damage` (method is deleted).

---

### P3-T08 — Manual verification and PROGRESS.md update

**What:**
Verify Phase 3 work end-to-end via a manual play session, then update docs.

**Verification checklist:**
1. Launch the battle scene. Confirm 2v2 battle plays identically to Phase 2 from the
   player's perspective.
2. Move a unit. Use the **Rewind button**: unit returns to original tile, rewind counter
   decrements.
3. Perform 3 rewinds. Confirm Rewind button becomes greyed out on the 4th attempt.
4. Open DamagePreview by hovering over an enemy in attack-targeting mode. Confirm the
   preview shows hit %, crit %, expected damage — values are now coming from
   `AttackSimulator.predict`, not from `AttackCommand.predict_damage`.
5. Check the debugger panel: **zero GDScript warnings or errors** on a clean run.
6. In the Godot profiler, trigger a DamagePreview hover at 60 FPS for 5 seconds.
   Confirm no frame spikes caused by `AttackSimulator.predict` (it is a pure function
   and should be negligible).
7. Run all GUT tests headless. Confirm ≥ 81 passing, 0 failing.

**PROGRESS.md updates:**
- Header: active phase → Phase 3 complete, pending review.
- "Current state": describe M1 (Architectural Skeleton) achieved.
- "Recently Completed": one entry per task (P3-T01 through P3-T08).
- "Phase status overview": Phase 3 → 🟢 Complete (pending review).
- "Architectural decisions log": add entries for component split and simulator extraction.
- "Notes for the next session": point at Phase 4.

**Acceptance criteria:**
- All 8 verification checklist items pass.
- PROGRESS.md reflects Phase 3 complete.
- Zero errors or warnings in the Godot debugger on a clean run.

---

## Phase 3 — task summary

| Task | What | Key deliverable |
|---|---|---|
| P3-T01 | BattleConst resource + CLAUDE.md line | `data/battle_const.tres`, CLAUDE.md updated |
| P3-T02 | AttackSimulator extracted | `scripts/battle/simulators/attack_simulator.gd` |
| P3-T03 | CharacterUnit component refactor | StatsComponent, WeaponSlotComponent, PositionComponent |
| P3-T04 | CommandQueue real implementation | `CommandQueue.submit` is the sole execute path |
| P3-T05 | RollbackService real implementation | Snapshot + rewind works, 3-per-battle limit |
| P3-T06 | BattleConst sweep | Zero hardcoded combat constants in code |
| P3-T07 | GUT test suite update | ≥ 81 tests passing |
| P3-T08 | Manual verification + PROGRESS.md | M1 checklist passes, docs updated |

**Estimated duration:** 1–2 weeks (GDD §12.1).

**M1 definition of done (GDD §12.3):**
> "Event bus, Commands, Simulators are real and tested. Damage formula lives in one place. Rewind works."

All four criteria are met when P3-T08 passes.
