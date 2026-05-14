# PROGRESS ARCHIVE

> Entries moved here when they age out of PROGRESS.md to keep that file readable.

---

## Phase 0 — Setup and Architectural Skeleton (🟢 Complete)

All Phase 0 tasks completed 2026-05-05.

---

## Phase 1 — Bare Grid Combat (🟢 Complete, reviewed)

- **2026-05-06 — P1-T01** — `Board` + `Tile` resources. `Board.create_flat(w, h)` factory, `get_tile`/`is_in_bounds`/`get_unit_at`/`get_neighbors`. Self-preload pattern for the static factory.
- **2026-05-06 — P1-T02** — `TargetRef` helper (RefCounted (unit, grid) tuple).
- **2026-05-06 — P1-T03** — `CharacterUnit` with stats, position, facing, equipment. Local signals, `take_damage`, `initialize_from_definition`.
- **2026-05-06 — P1-T04** — `BoardView3D` renders Board as a grid of mesh tiles plus StaticBody3D + BoxShape3D colliders for raycast picking.
- **2026-05-06 — P1-T05** — `UnitView3D` capsule + Label3D placeholder (replaced in Phase 2).
- **2026-05-06 — P1-T06** — `Pathfinder` BFS. `compute_reachable` returns Dictionary[Vector2i → cost], `path_to` returns Array[Vector2i].
- **2026-05-06 — P1-T07** — `RangeShapeResolver` static class.
- **2026-05-06 — P1-T08** — Data instances: `data/classes/swordsman.tres`, `data/weapons/iron_sword.tres`, `data/characters/aria.tres`, `data/characters/bandit.tres`.
- **2026-05-06 — P1-T09** — `data/range_shapes/melee_1.tres`: 3×3 plus shape, 4-cardinal range-1 melee.
- **2026-05-06 — P1-T10** — `MoveCommand` — updates Tile occupants and `unit.grid_position`, faces along last step, emits `moved`.
- **2026-05-06 — P1-T11** — `AttackCommand` with inline Phase 1 damage formula. Emits `attack_resolving`, `damage_dealt`, `weapon_used`, sets `has_acted`, fires `turn_ended`.
- **2026-05-06 — P1-T12** — `WaitCommand`, `EndTurnCommand`.
- **2026-05-06 — P1-T13** — `BattleManager` phase loop, 2v2 test battle, battle-end conditions.
- **2026-05-06 — P1-T14** — `TileInputController` raycasts mouse → tile colliders. Right-click emits `cancel_pressed`.
- **2026-05-06 — P1-T15** — `ActionMenu` + `PlayerPhaseController` state machine (IDLE → UNIT_SELECTED → TARGETING_MOVE/ATTACK).
- **2026-05-06 — P1-T16** — Range highlights: green for move targets, red for attack targets.
- **2026-05-06 — P1-T17** — `DamagePreview` popup polling hover in TARGETING_ATTACK state.
- **2026-05-06 — P1-T18** — `AIController.run_enemy_phase`: attack if in range, else move toward nearest player.
- **2026-05-06 — P1-T19** — `EndOfBattle` overlay reacts to `CombatEventBus.battle_ended`.
- **2026-05-06 — P1-T20** — `BattleLogService`: connects all 20 bus signals with one lambda each.
- **2026-05-06 — P1-T21** — 8 test files + `P1TestHelpers`. 34 tests, 141 assertions, all passing headless.
- **2026-05-06 — P1-T22** — Manual verification: 2v2 battle, range highlights, enemy phase, Victory screen.

### Phase 1 decisions (all approved by user)

1. Pathfinder BFS corner-origin count corrected (10 not 25). Test asserts 25 from (5,5), 10 from (0,0).
2. `AttackCommand` also fires `turn_ended` for symmetry with `WaitCommand`.
3. Self-preload pattern in `board.gd` for static factory.
4. `MoveCommand.cancel` is best-effort; real fix deferred to Phase 3 RollbackService.
5. `BattleManager` skips bootstrap when not embedded in BattleScene (test ergonomics).
6. Damage preview hover uses per-frame polling, not a hover signal.
7. `EndTurnCommand` exists but phase auto-advances via `_maybe_end_phase()`.

### Non-blocking Phase 1 observations (defer)

- Duplicate `FPSLabel2` node in `scenes/battle/battle.tscn`. Cosmetic.
- `data/weapons/iron_sword.tres` — add explicit values for `attack_type` and `element` when next touched.
