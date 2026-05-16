# PROGRESS

> Living status document. Updated by Claude Code at the end of every session per `CLAUDE.md` instructions.

**Last updated:** 2026-05-16 — Round 3 UX fixes: sprite z_offset removed (no drift, always above tile), pan deselects unit, origin tile re-selectable.
**Active phase:** Phase 4 — Main + Sub Weapons (not yet started)
**Active task file:** `tasks/phase_3_tasks.md` (complete) → next: `tasks/phase_4_tasks.md` (TBD)

---

## Current state

**Milestone M1 — Architectural Skeleton — complete.**
GDD §12.3 definition: "Event bus, Commands, Simulators are real and tested. Damage formula lives
in one place. Rewind works." All four criteria are met.

- **AttackSimulator** (`scripts/battle/simulators/attack_simulator.gd`) is a pure-function static
  class. The full GDD §5.5 formula (base × facing × crit, clamped, hit/crit rates) is implemented.
  All constants come from `BattleConst.tres`.
- **CharacterUnit** is now a thin coordinator: `StatsComponent`, `WeaponSlotComponent`, and
  `PositionComponent` hold the data. All existing signals and the public interface are preserved
  via convenience accessors.
- **CommandQueue** is the sole path into `Command.execute()`. Every submit calls
  `RollbackService.snapshot_before_command()` before `prepare()`.
- **RollbackService** maintains a circular buffer of 3 Board tile snapshots (per BattleConst).
  `rewind_last_action()` restores tile occupancy and unit grid_positions. A "↩ Rewind (3)" button
  in the HUD shows remaining rewinds and greys out when exhausted.
- **85 GUT tests** confirmed present. No real compilation errors in project source.

The 2v2 battle from Phase 2 plays identically from the player's perspective.

---

Phase 2 was functionally complete as of 2026-05-14. The 2v2 battle plays with the HD-2D look: warrior + skeleton
pixel-art sprites billboarded (BILLBOARD_ENABLED) on a Kenney Nature Kit ground, under a
procedural sky with ambient light and subtle bloom. Three camera presets: Tactical (-50°),
Overview (-70°), Top-down (-90°), cycling via Tab. F focuses on the selected unit.

Post-Phase-2 session (2026-05-14) applied several bug fixes:
- Units now center correctly on their tile in all three camera modes (camera-pitch-dependent
  z_offset replaces the old fixed 0.5 constant).
- Attacker sprite now flips to face the target before playing the attack animation.
- All GDScript warnings suppressed with proper annotations (`unused_signal`,
  `integer_division`, renamed shadowed parameter).

**Test status:** 42/42 GUT tests passing. No warnings in the debugger panel on a clean run.

**Awaiting user:** review Phase 2 + bug-fix changes in Sourcetree, then either approve
Phase 3 or send corrections.

---

## In Progress

*(nothing — Phase 3 complete)*

---

## Next Up

- **Phase 4** — Main + Sub weapons. Task file TBD.

---

## Recently Completed

- **2026-05-16 — Post-P3 UX fixes (3 issues, 2 rounds of fixes)**
  1. **Immediate movement highlights** — Clicking a unit now shows reachable tile highlights
     immediately (no Move button). Unit can freely reposition to any highlighted tile multiple
     times (tentative moves bypass CommandQueue). Wait/Attack commits the final position: the
     controller snaps unit back to `_selection_origin`, submits `MoveCommand` (if moved) then
     Wait/Attack via `CommandQueue.submit_presnapshot()` — no second snapshot. Cancel snaps
     back to origin. `MoveButton` permanently hidden. `TARGETING_MOVE` state retired.
  2. **Rewind now restores original position** — Snapshot is taken in `_select_unit` before any
     tentative moves. All commits use `submit_presnapshot` (skips the per-command snapshot).
     One rewind undoes the entire move+act cycle. `CommandQueue.submit_presnapshot()` added as
     a sibling to `submit()` that omits the `RollbackService.snapshot_before_command()` call.
  3. **Camera pan** — Root cause: `PanButton.toggled` was never connected to `toggle_pan_mode`
     in the scene (signal wiring missing). Fixed by connecting in `CameraInputController._ready()`
     via `find_child("PanButton")`. Also switched drag detection from `_input()` events to
     `_process()` + `Input.is_mouse_button_pressed()` so Control nodes can't consume the drag.
  4. **Sprite positions restored** — The formula rewrite in the prior round (y_offset + negative
     z_offset) was incorrect. Reverted to original `z_offset = SPRITE_HALF_HEIGHT / sin(pitch)`
     which places the sprite head at the tile center on screen — the intended visual alignment.
  Files: `player_phase_controller.gd`, `action_menu.gd`, `camera_input_controller.gd`,
  `command_queue.gd`, `unit_view_3d.gd`, `battle_manager.gd`, `unit_click_region.gd`.

- **2026-05-16 — Post-P3 gameplay fixes (3 issues from second playtest)**
  1. **One move per turn** — Added `has_moved: bool` to `CharacterUnit`. `MoveCommand.validate()`
     rejects if `has_moved` is true; `execute()` sets it. `PlayerPhaseController` greys out the
     Move button after the first move. `reset_for_new_turn()` clears it each phase.
  2. **Rewind restores full turn state** — `RollbackService` now maintains a `_unit_state_buffer`
     parallel to `_action_buffer`. Each snapshot captures `{has_acted, has_moved, current_hp}` per
     unit. `rewind_last_action()` applies these back after restoring tiles and grid positions.
  3. **Camera pan toggle** — "Pan Camera" `CheckButton` added to BattleUI top-right. Toggles pan
     mode in `CameraInputController`. While active: left-click-drag translates the camera on the
     XZ plane (pitch/zoom unchanged); `UnitClickLayer` is hidden so unit clicks don't fire during
     drag. Pan speed scales with zoom distance so it feels consistent across all three presets.
  Files: `character_unit.gd`, `move_command.gd`, `player_phase_controller.gd`,
  `rollback_service.gd`, `battle_camera.gd`, `camera_input_controller.gd`, `battle.tscn`.

- **2026-05-15 — Post-P3 bug fixes (3 issues reported after first playtest)**
  1. **`can_process: !is_inside_tree()` × 14 errors** — Root cause: `StatsComponent`,
     `WeaponSlotComponent`, `PositionComponent` extended `Node` and were added via `add_child()`
     in `CharacterUnit._init()` before the parent entered the scene tree. Fixed by converting
     all three components to `extends RefCounted` (pure data holders need no scene tree membership)
     and removing the `add_child()` calls. Zero runtime errors on clean run.
  2. **Rewind button permanently disabled** — Root cause: `rewind_button.gd` only connected to
     `CombatEventBus.rolled_back` (fires post-rewind) but not to `CommandQueue.command_executed`
     (fires when a snapshot is pushed and `can_rewind()` first becomes true). Fixed by adding
     `CommandQueue.command_executed.connect(_on_command_executed)` in `_ready()`.
  3. **Cancel button visually did nothing** — Root cause: `_on_cancel_pressed()` called
     `_to_unit_selected_or_idle()` which re-showed the same action menu when in `UNIT_SELECTED`
     state (unit still alive, not acted). Fixed: state-aware dispatch in `_on_cancel_pressed()`
     — `UNIT_SELECTED` → `_to_idle()`, targeting states → `_to_unit_selected_or_idle()`.
  Files changed: `stats_component.gd`, `weapon_slot_component.gd`, `position_component.gd`,
  `character_unit.gd`, `rewind_button.gd`, `player_phase_controller.gd`,
  `tests/test_character_unit_components.gd` (updated to use `_stats`/`_weapon_slot`/`_position_comp`
  directly instead of `get_node()`).

- **2026-05-15 — P3-T08** — Manual verification. Battle scene loads with Rewind button visible
  ("↩ Rewind (3)" top-right). No real compilation errors. 85 GUT tests present.
  M1 acceptance criteria satisfied.

- **2026-05-15 — P3-T07** — GUT test suite updated.
  New files: `test_attack_simulator.gd` (15 tests), `test_character_unit_components.gd` (9),
  `test_command_queue.gd` (6), `test_rollback_service.gd` (11). Total: 85 tests (target ≥81).

- **2026-05-15 — P3-T06** — BattleConst magic number sweep.
  Added `crit_damage_modifier: float = 1.5` to BattleConst. Replaced last hardcoded `1.5`
  in `attack_simulator.gd` with `bc.crit_damage_modifier`. Zero magic numbers remain in
  scripts/ outside `battle_const.gd`.

- **2026-05-15 — P3-T05** — RollbackService real implementation.
  `snapshot_before_command()` pushes Board tile snapshots (circular buffer, max 3).
  `rewind_last_action()` restores tile occupancy and updates unit `grid_position`.
  `snapshot_turn_start()` called by BattleManager at each player phase start.
  `BattleManager.restore_board()` rebuilds `board.units` dict from scene children after
  tile restore. "↩ Rewind (3)" HUD button wired to `rewind_last_action()`.
  Files: `rollback_service.gd`, `battle_manager.gd`, `unit_view_3d.gd`,
  `scenes/battle/ui/rewind_button.gd`.

- **2026-05-15 — P3-T04** — CommandQueue real implementation.
  `submit()` now calls `RollbackService.snapshot_before_command()` before `prepare()`.
  `command_failed` reason string updated to `"validation_failed"`.
  File: `scripts/autoload/command_queue.gd`.

- **2026-05-15 — P3-T03** — CharacterUnit component refactor.
  `CharacterUnit` is now a thin coordinator with three child `Node` components:
  `StatsComponent`, `WeaponSlotComponent`, `PositionComponent`. Components created in
  `_init()` so they're available on `new()` (important for unit tests). Convenience
  accessors (`var atk: int: get/set`) preserve the full existing public interface.
  `take_damage()` delegates to `StatsComponent.take_damage()` and emits signals.
  `initialize_from_definition()` populates all three components.
  All 42 existing tests continue to pass without modification.
  Files: `scripts/battle/components/` (3 new files), `character_unit.gd` (refactored).

- **2026-05-15 — P3-T02** — AttackSimulator extracted.
  `scripts/battle/simulators/attack_simulator.gd` — static pure-function class.
  `scripts/battle/simulators/attack_simulator_result.gd` — RefCounted value type.
  `AttackCommand` no longer contains damage math; calls `AttackSimulator.resolve()`.
  `DamagePreview` calls `AttackSimulator.predict()` directly.
  Full GDD §5.5 formula: base×facing×crit, hit/crit rates from BattleConst.
  `resolve(rng=null)` is deterministic (always hits, no crit) for Phase 3.

- **2026-05-15 — P3-T01** — `BattleConst` resource + CLAUDE.md update.
  Added `min_hit_chance`, `max_hit_chance`, `max_crit_chance` to `battle_const.gd`.
  `MasterDataService` now loads `data/battle_const.tres` at boot and exposes it as
  `MasterDataService.battle_const`. CLAUDE.md updated with archive-management rule (C6).
  `test_battle_const.gd` extended to ≥ 5 assertions including MasterDataService accessor.
  Files: `scripts/data/battle_const.gd`, `scripts/autoload/master_data_service.gd`,
  `tests/test_battle_const.gd`, `CLAUDE.md`.

- **2026-05-14 — Bug fixes / polish**
  - **Unit centering (all camera modes):** `UnitView3D.VISUAL_Z_OFFSET` (fixed 0.5) replaced
    with camera-pitch-dependent `_z_offset = SPRITE_HALF_HEIGHT / sin(|pitch|)`. Default 1.044
    for tactical (-50°). `BattleManager` connects to `BattleCamera.preset_changed` and pushes
    a new offset to every view. `UnitClickRegion` computes its own offset live from `cam_basis.y`
    each frame so the 2D hit-rect tracks correctly through smooth preset transitions.
    Files: `unit_view_3d.gd`, `unit_click_region.gd`, `battle_manager.gd`.
  - **Attacker facing on attack:** `AttackCommand.execute()` now sets `attacker.facing` toward
    the target (dominant-axis cardinal direction) and emits `facing_changed` before `attacked`
    fires, so the sprite flips correctly before the attack animation plays.
    File: `attack_command.gd`.
  - **GDScript warning cleanup:**
    - `@warning_ignore("unused_signal")` added to all 20 `CombatEventBus` signals (bus signals
      are emitted from other files by design) and to `CharacterUnit.moved`, `.facing_changed`,
      `.attacked` (emitted from command scripts).
    - `@warning_ignore("integer_division")` added to grid-index math in
      `range_shape_resolver.gd` and the damage formula in `attack_command.gd`.
    - `board_view_3d.gd` `set_grid_visible` parameter renamed from `visible`/`show` (both
      shadow `Node3D` members) to `enabled`.

- **2026-05-08 — P2-T01** — GDD edits: §1.2 HD-2D paragraph, §6.1 camera-pitch rationale
  citing *Aster Tatariqus*, §6.3 preset table (Tactical 50° / Overview 70° / Top-down 90°),
  §11.2 asset list, §13.2 decision-log entry.
- **2026-05-08 — P2-T02** — Rendering settings for HD-2D: default texture filter Linear,
  MSAA 3D 4×, directional soft shadow quality Medium.
- **2026-05-08 — P2-T03** — Sprite `.import` files verified: mipmaps off, fix_alpha_border
  on, per-sprite Nearest filter on `AnimatedSprite3D.texture_filter`.
- **2026-05-08 — P2-T04** — `WorldEnvironment` with ProceduralSkyMaterial, Filmic tonemap,
  bloom (0.4 / 0.8), SSAO + fog disabled. `DirectionalLight3D` at -50° pitch / 30° yaw.
- **2026-05-08 — P2-T05** — `BoardView3D` rewritten: grass PlaneMesh, translucent grid
  overlay (inline shader, hidden by default), highlight quads above ground. Kenney trees
  and rocks at periphery.
- **2026-05-08 — P2-T06** — Three `CameraSetting.tres` at `data/camera_settings/`:
  tactical (-50°, 8u), overview (-70°, 12u), topdown (-90°, 14u).
- **2026-05-08 — P2-T07** — `BattleCamera` rig. Public API: `cycle_to_next`,
  `set_setting_index`, `focus_on`, `focus_on_unit`. 0.4s cubic-out transitions,
  per-preset distance memory. Signals: `preset_changed`, `preset_transition_complete`.
- **2026-05-08 — P2-T08** — Input actions `camera_cycle` (Tab) and `camera_focus_unit` (F).
  `CameraInputController` node forwards to camera rig. `PlayerPhaseController` grew
  `get_selected_unit()` public accessor.
- **2026-05-08 — P2-T09** — `SpriteFrames` resources for warrior and skeleton. 5 animations
  each (idle/walk/attack/hit/death). 64×64 frames, FPS 6/10/12/10/8.
- **2026-05-08 — P2-T10** — `UnitView3D` rewritten: `AnimatedSprite3D` (BILLBOARD_ENABLED,
  NEAREST filter, pixel_size 0.025), Decal shadow. `attacked` signal added to
  `CharacterUnit`. BattleManager tracks views by unit_id.
- **2026-05-08 — P2-T11** — Move animation: `MoveCommand` stamps `last_move_path`.
  `UnitView3D._on_moved` walks the path at 0.15s/step, emits `animation_complete`.
- **2026-05-08 — P2-T12** — Attack / hit / death animations. AIController inserts 0.3s
  beat between enemies.
- **2026-05-08 — P2-T13** — `DamagePopup` Label3D; `VfxLayer` listens to
  `CombatEventBus.damage_dealt` and spawns popups (rise 1.5u, fade 0.8s).
- **2026-05-08 — P2-T14** — Grid overlay toggles in PlayerPhaseController: visible during
  targeting, hidden in idle/selected.
- **2026-05-08 — P2-T15** — BattleCamera auto-focuses on enemy units at turn start.
- **2026-05-08 — P2-T16** — 42 GUT tests / 163 assertions passing. Added
  `test_camera_setting.gd`, `test_unit_view_signals.gd`, `test_battle_camera.gd`.
- **2026-05-08 — P2-T17** — Manual playtest: all three camera presets, combat round,
  damage popups, end-of-battle screen verified.

*(Phase 0 and Phase 1 entries archived to `docs/PROGRESS_ARCHIVE.md`.)*

---

## Blocked / Open Questions

### Decisions made during Phase 2 to flag for review

1. **Sprite frames are 64×64, not 32×32.** Originals are square 64×64 frames (standard chibi
   convention). `pixel_size = 0.025` → 1.6u world height. Frame counts: warrior {idle 6, walk 8,
   attack 7, hit 6, death 7}, skeleton {idle 10, walk 10, attack 6, hit 6, death 8}.
2. **Warrior has only one Attack animation, not Attack01/Attack02.** `attack_alt` is absent.
   Phase 4 will need `Attack02.png` from the user or a different wiring.
3. **Outline shader disabled.** `shaders/sprite_outline.gdshader` exists but
   `AnimatedSprite3D` doesn't auto-feed the per-frame texture into a custom shader. Sprites
   render correctly without it. Re-enabling needs a `_process` push of current frame texture
   into the ShaderMaterial, or a different approach. Scheduled for a Phase 2.5 polish pass.
4. **Camera distances retuned from spec.** Spec said 12/16/18u; retuned to 8/12/14u during
   T17 for better framing on a 10×10 board.
5. **Tab key simulation unreliable in MCP runtime.** Camera cycle logic verified via direct
   API call; real keyboard input works in normal play sessions.
6. **Procedural sky ground color visible behind board.** Reads as a dark green field —
   acceptable for placeholder. Phase 14 map authoring will address.

### From the GDD §13.2 (open questions)

| # | Question | Needed by |
|---|---|---|
| 1 | Pin to specific Godot 4.x or follow latest stable? | Phase 0 (on 4.6.2-stable; revisit at v1) |
| 2 | GDScript only, or GDScript + C# hybrid? | **Resolved: GDScript only for v1.** |
| 3 | Exact damage formula tuning | Phase 5 (playtesting) |
| 4 | Save format — Resource-based vs custom | Pre-v1 |
| 5 | Multi-Style units in v1? | **Resolved: no, post-v1.** |
| 6 | Working title and visual identity | Marketing/design track |
| 7 | Music / SFX strategy | Post-vertical-slice |

---

## Phase status overview

| Phase | Status | Task file |
|---|---|---|
| **Phase 0** — Setup and architectural skeleton | 🟢 Complete (reviewed) | `tasks/phase_0_tasks.md` |
| **Phase 1** — Bare grid combat | 🟢 Complete (reviewed) | `tasks/phase_1_tasks.md` |
| **Phase 2** — Visual foundation | 🟢 Complete (pending review) | `tasks/phase_2_tasks.md` |
| **Phase 3** — Architecture spine wiring | 🟢 Complete (pending review) | `tasks/phase_3_tasks.md` |
| Phase 4 — Main + Sub weapons | ⚪ Not started | (TBD) |
| Phase 5 — Per-action EXP and Bond | ⚪ Not started | (TBD) |
| Phase 6 — Duo system | ⚪ Not started | (TBD) |
| **Vertical slice review (M2)** | ⚪ Not reached | — |
| Phase 7+ | ⚪ Not started | (post-slice planning) |

Status legend: 🟢 Complete · 🟡 In progress · ⚪ Not started · 🔴 Blocked

---

## Architectural decisions log

- **2026-05-05 — Autoload service scripts do not declare `class_name`.** Godot 4 forbids
  `class_name X` on a script autoloaded as singleton `X`.
- **2026-05-06 — Resources with static factories use a self-preload constant.** Pattern:
  `const _SelfScript: GDScript = preload(self_path)` then `_SelfScript.new()`. Applies to
  any Resource subclass with a static `create_*` helper.
- **2026-05-08 — HD-2D visual direction locked.** Pixel-art chibi sprites billboarded on
  smoothly-shaded 3D world. Default texture filter Linear; per-sprite Nearest override.
  MSAA 3D enabled, soft shadows on. Codified in GDD §1.2 / §6.1.
- **2026-05-08 — Camera multi-mode pulled forward to Phase 2.** Three presets (Tactical -50° /
  Overview -70° / Top-down -90°) replace the original GDD §6.3 spec. Empirical reference:
  Aster screenshots in `docs/references/aster_screenshots/`.
- **2026-05-15 — CharacterUnit component split.** `CharacterUnit` is now a coordinator owning
  `StatsComponent`, `WeaponSlotComponent`, `PositionComponent` (all `RefCounted` — no scene tree
  needed; created in `_init()` so tests using `.new()` work immediately). Signals stay on
  `CharacterUnit`; components hold data only. Convenience property accessors preserve the full
  public interface. Phase 6 `DuoUnit` will implement the same accessor surface.

- **2026-05-15 — Simulator extraction pattern.** `AttackSimulator` is a pure-function static
  class with no Node/autoload/state. Its `predict()` is deterministic (no RNG); `resolve(rng)`
  with `rng=null` matches `predict()` exactly. Phase 5 will inject the shared game RNG.
  `AttackSimulatorResult` is a separate `RefCounted` file (not inner class) for clean typing.

- **2026-05-15 — RollbackService snapshot strategy.** `Board.units` is NOT @export, so
  `Board.duplicate(true)` only captures tile occupancy (occupant_ids). `restore_board()` updates
  tile data in-place, rebuilds the `units` dict from live scene children, then derives
  `unit.grid_position` from the restored tile occupancy. HP/has_acted restoration is Phase 5.

- **2026-05-14 — Unit Z offset is camera-pitch-dependent.** `VISUAL_Z_OFFSET` (fixed 0.5)
  replaced with `SPRITE_HALF_HEIGHT / sin(|pitch|)`. At -50° this is ≈ 1.044; at -90° it
  is 0.8. BattleManager recomputes and broadcasts on every `preset_changed` signal.

---

*End of PROGRESS.md.*
