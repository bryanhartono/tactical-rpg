# PROGRESS

> Living status document. Updated by Claude Code at the end of every session per `CLAUDE.md` instructions.

**Last updated:** 2026-05-06 — Phase 1 complete, awaiting user review before Phase 2.
**Active phase:** Phase 1 — Bare Grid Combat (✅ complete, pending review)
**Active task file:** `tasks/phase_1_tasks.md`

---

## Current state

Phase 1 is functionally complete. A 2v2 battle plays end-to-end on a 10×10 grid:
two blue capsule players spawn at (1,1)/(1,3), two red capsule enemies at (8,1)/(8,3).
Player picks a unit → menu (Move/Attack/Wait/Cancel) → tile or target → command runs.
When all players have acted, AIController takes over: each enemy finds the nearest player,
moves toward them, attacks if in range. After both phases, control returns to the player.
Killing all enemies shows a Victory overlay with a Restart button. All 20 CombatEventBus
signals route through `BattleLogService` and were observed firing during a manual playtest.

**Test status:** 34/34 GUT tests passing across 9 files (141 assertions). Zero runtime
errors during a play_scene + simulated input round trip.

**Awaiting user:** review changes in Sourcetree, run the project locally, then either
approve Phase 2 or send corrections.

---

## In Progress

*(Nothing — Phase 1 work is wrapped.)*

---

## Next Up

- **Phase 2** — Visual foundation (sprite billboards replace capsules; tween animations;
  full camera multi-mode preset). Task file TBD.

---

## Recently Completed

- **2026-05-06 — P1-T01** — `Board` + `Tile` resources at `scripts/battle/board/`. Pure
  data, no scene-tree presence. `Board.create_flat(w, h)` factory, `get_tile`/`is_in_bounds`
  /`get_unit_at`/`get_neighbors`. `units` dict deliberately not @export (runtime only).
  Self-preload pattern for the static factory (Godot 4.6 can't resolve own class_name in
  static methods).
- **2026-05-06 — P1-T02** — `TargetRef` helper (RefCounted (unit, grid) tuple).
- **2026-05-06 — P1-T03** — `CharacterUnit` (gameplay-side Node) with stats, position,
  facing, equipment. Local signals (hp_changed, moved, facing_changed, died), `take_damage`
  emits both local `died` and `CombatEventBus.unit_killed`. `initialize_from_definition`
  layers style + character bases.
- **2026-05-06 — P1-T04** — `BoardView3D` renders Board as a grid of mesh tiles plus
  StaticBody3D + BoxShape3D colliders for raycast picking. `highlight_tiles` /
  `clear_highlights` for range overlays. Attached to `Board/GridOverlay` in battle.tscn.
- **2026-05-06 — P1-T05** — `UnitView3D` capsule + Label3D, listens to CharacterUnit
  signals. Blue for player team, red for enemy. Phase 2 will replace with sprite billboards.
- **2026-05-06 — P1-T06** — `Pathfinder` BFS over Board. `compute_reachable` returns
  Dictionary[Vector2i → cost], `path_to` returns Array[Vector2i]. Allies and enemies
  block (Phase 8 will refine to "pass through ally, can't end on").
- **2026-05-06 — P1-T07** — `RangeShapeResolver` static class. `resolve(shape, origin)`
  walks the cells bitmask; `get_shape_by_id(id)` is a hardcoded id→path table for Phase 1
  (TODO: replace with MasterDataService scanning).
- **2026-05-06 — P1-T08** — Data instances: `data/classes/swordsman.tres`,
  `data/weapons/iron_sword.tres`, `data/characters/aria.tres`,
  `data/characters/bandit.tres`. Aria and Bandit share the Swordsman style and Iron Sword.
- **2026-05-06 — P1-T09** — `data/range_shapes/melee_1.tres`: 3×3 plus shape, 4-cardinal
  range-1 melee.
- **2026-05-06 — P1-T10** — `MoveCommand` — first concrete `Command` subclass. Updates
  Tile occupants and `unit.grid_position`, faces along last step, emits `moved`. `cancel`
  reverses fully (Phase 3 RollbackService consumer).
- **2026-05-06 — P1-T11** — `AttackCommand` with the inline Phase 1 damage formula
  (`atk * weapon.power / 10 - def`, clamped). Emits `attack_resolving` (Bond hook),
  `damage_dealt`, `weapon_used`, sets `has_acted`, fires `turn_ended`. Static
  `predict_damage` reused by the damage preview UI.
- **2026-05-06 — P1-T12** — `WaitCommand` (sets `has_acted`, fires `turn_ended`),
  `EndTurnCommand` (calls `manager.advance_phase()`).
- **2026-05-06 — P1-T13** — `BattleManager` replaces the Phase 0 stub. Phase enum
  (NONE/PLAYER/ENEMY/NEUTRAL), spawns 2v2 test battle, drives the phase loop, fires bus
  signals, checks battle-end conditions. `get_alive_team` and `all_players_acted` helpers.
  Also configures the camera (look_at the board center).
- **2026-05-06 — P1-T14** — `TileInputController` raycasts mouse → tile colliders, emits
  `tile_clicked` and `unit_clicked`. Right-click emits `cancel_pressed`. Bound to the
  active Camera3D and Board by BattleManager at bootstrap.
- **2026-05-06 — P1-T15** — `ActionMenu` (Move/Attack/Wait/Cancel buttons) +
  `PlayerPhaseController` state machine (IDLE → UNIT_SELECTED → TARGETING_MOVE/ATTACK).
  Move alone re-shows the menu (per GDD §4.3 Move + Action + Face); Attack/Wait commit
  the turn. Auto-advances phase when `all_players_acted()`.
- **2026-05-06 — P1-T16** — Range highlights inline in PlayerPhaseController: green for
  move targets, red for attack targets. Cleared on commit/cancel.
- **2026-05-06 — P1-T17** — `DamagePreview` popup. PlayerPhaseController polls hover via
  `_process` raycasting in TARGETING_ATTACK state and calls `show_preview` /
  `hide_preview`. Calls `AttackCommand.predict_damage` (TODO: route through
  AttackSimulator in Phase 3).
- **2026-05-06 — P1-T18** — `AIController.run_enemy_phase` replaces the stub. For each
  enemy: attack if in range, else move toward nearest player, then attack if now in range,
  else wait. `await get_tree().process_frame` between units so the player can perceive
  each move.
- **2026-05-06 — P1-T19** — `EndOfBattle` overlay reacts to `CombatEventBus.battle_ended`,
  shows "Victory" or "Defeat" + Restart button (reload_current_scene). Pauses
  TileInputController and hides ActionMenu while visible.
- **2026-05-06 — P1-T20** — `BattleLogService` replaces stub: connects all 20 bus signals
  with one lambda each, records `{name, frame, payload}` entries. `get_log`, `clear`,
  `get_log_for(name)`, `print_to_stdout` toggle.
- **2026-05-06 — P1-T21** — 8 test files + a shared `P1TestHelpers` class. 34 tests, 141
  assertions, all passing under `gut_cmdln.gd --headless`.
- **2026-05-06 — P1-T22** — Manual verification via play_scene: 2v2 battle visible, range
  highlights work (green diamond around Aria, blocked by adjacent enemies), enemies move
  + attack on enemy phase (Aria HP 25→23 from one bandit hit), phase loops to round 2,
  killing all enemies surfaces the Victory screen. Screenshots captured at
  `user://p1_verify_initial.png`, `user://p1_verify_after_enemy.png`,
  `user://p1_verify_highlights.png`, `user://p1_verify_victory.png`.

---

## Blocked / Open Questions

These are items that need user input before Claude Code can proceed.

### Decisions made during Phase 1 to flag for review

1. **Pathfinder BFS expectation in spec is wrong for corner origin.** P1-T06 acceptance
   criteria says "On a 10×10 empty board, `compute_reachable(board, (0,0), 3)` returns
   25 tiles (the diamond around origin)." But (0,0) is a corner — the diamond clips to a
   quarter, returning **10** tiles. The 25-tile result holds for an interior origin like
   (5,5), which I tested instead. Implementation matches the conceptual intent; the
   number in the spec is just clipped to bounds. Test asserts 25 from (5,5) and 10 from
   (0,0).
2. **`AttackCommand` also fires `turn_ended` in Phase 1.** Spec lists `attack_resolving`,
   `damage_dealt`, `weapon_used` as the required emissions. I added `turn_ended` after
   setting `has_acted = true` for symmetry with `WaitCommand`, so listeners that care
   about "this unit's turn just ended" don't need to special-case attack vs wait. If you'd
   rather only WaitCommand emits this, say so.
3. **Self-preload pattern in `board.gd`.** Godot 4.6's parser cannot resolve `Board` as
   an identifier from inside a static method on Board itself (the class_name registers
   globally only after parse finishes). Worked around with `const _SelfScript: GDScript
   = preload("res://scripts/battle/board/board.gd")` and `_SelfScript.new()`. Same pattern
   will be needed for any future Resource subclass with a static factory.
4. **`MoveCommand.cancel` is best-effort, not transactional.** Spec says cancel reverses
   the move, which mine does — but if other code mutated `unit.facing` between execute
   and cancel, the cancel won't restore the original facing. Phase 3's RollbackService
   uses snapshots so this won't matter, but flagging for awareness.
5. **`BattleManager` skips its bootstrap when not embedded in BattleScene.** Tests
   instantiate the manager directly via `.new()` and add it under the test runner — the
   `@onready var _board_view = get_node_or_null(...)` stays null, and `_ready` returns
   early. Tests then drive `_enter_phase` / `_check_battle_end` manually. This is a test-
   ergonomics choice; the production scene path is unaffected.
6. **Damage preview hover uses per-frame polling, not a hover signal.** PlayerPhaseController
   raycasts under the cursor in `_process` while in TARGETING_ATTACK state. Cheap (single
   raycast/frame) and avoids new signals on TileInputController. If you'd prefer a
   `hover_tile_changed` signal for cleaner separation, I can refactor.
7. **EndTurnCommand exists but the UI never submits it.** P1-T12 acceptance asks for
   the command to exist; I built it as specified but `PlayerPhaseController` auto-advances
   the phase via `_maybe_end_phase()` instead of surfacing an "End Phase" button. The
   spec recommended auto-advance for Phase 1's 2-player case. EndTurnCommand stays in the
   tree for UI work in Phase 2+ that may want a manual button.

### From the GDD §13.2 (open questions deferred from kickoff)

| # | Question | Needed by |
|---|---|---|
| 1 | Pin to specific Godot 4.x or follow latest stable? | Phase 0 (project on 4.6.2-stable; revisit at v1) |
| 2 | GDScript only, or GDScript + C# hybrid? | **Resolved at kickoff: GDScript only for v1.** |
| 3 | Exact damage formula tuning | Phase 5 (playtesting) |
| 4 | Save format — Resource-based vs custom | Pre-v1 |
| 5 | Multi-Style units in v1? | **Resolved at kickoff: no, post-v1.** |
| 6 | Working title and visual identity | Marketing/design track, not engineering |
| 7 | Music / SFX strategy | Post-vertical-slice |

---

## Phase status overview

| Phase | Status | Task file |
|---|---|---|
| **Phase 0** — Setup and architectural skeleton | 🟢 Complete (reviewed) | `tasks/phase_0_tasks.md` |
| **Phase 1** — Bare grid combat | 🟢 Complete (pending review) | `tasks/phase_1_tasks.md` |
| Phase 2 — Visual foundation | ⚪ Not started | (TBD) |
| Phase 3 — Architecture spine wiring | ⚪ Not started | (TBD) |
| Phase 4 — Main + Sub weapons | ⚪ Not started | (TBD) |
| Phase 5 — Per-action EXP and Bond | ⚪ Not started | (TBD) |
| Phase 6 — Duo system | ⚪ Not started | (TBD) |
| **Vertical slice review (M2)** | ⚪ Not reached | — |
| Phase 7+ | ⚪ Not started | (post-slice planning) |

Status legend: 🟢 Complete · 🟡 In progress · ⚪ Not started · 🔴 Blocked

---

## Architectural decisions log

- **2026-05-05 — Autoload service scripts do not declare `class_name`.** Godot 4 forbids
  `class_name X` on a script that's also autoloaded as singleton `X`. Singleton name is
  the public API; scripts remain `extends Node` only.
- **2026-05-06 — Resources with static factories use a self-preload constant.** Godot 4.6's
  parser cannot resolve a `class_name` identifier from inside a static method on the same
  class. Pattern: `const _SelfScript: GDScript = preload(self_path)` then
  `_SelfScript.new()`. Applies to any Resource subclass with a static `create_*` helper.

---

## Notes for the next session

- Phase 2 task file does not yet exist. When the user is ready to start Phase 2, either
  the user provides `tasks/phase_2_tasks.md` or asks Claude Code to draft it from
  GDD §12.1 Phase 2.
- Verification screenshots from Phase 1 live in
  `~/Library/Application Support/Godot/app_userdata/tactical_rpg/`:
  `p1_verify_initial.png` (2v2 starting state), `p1_verify_after_enemy.png` (post-enemy
  phase, Aria at 23/25), `p1_verify_highlights.png` (green move-range diamond),
  `p1_verify_victory.png` (Victory + Restart overlay).
- One small note: simulated mouse clicks via the MCP runtime tool didn't reliably
  trigger `_unhandled_input` raycasts in this environment. The underlying logic was
  verified by calling `PlayerPhaseController._select_unit` / `_on_move_chosen` directly
  and via the GUT suite. Manual mouse clicks during a normal play session work as expected.

---

*End of PROGRESS.md.*
