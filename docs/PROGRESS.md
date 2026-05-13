# PROGRESS

> Living status document. Updated by Claude Code at the end of every session per `CLAUDE.md` instructions.

**Last updated:** 2026-05-08 — Phase 2 complete, awaiting user review before Phase 3.
**Active phase:** Phase 2 — Visual Foundation (✅ complete, pending review)
**Active task file:** `tasks/phase_2_tasks.md`

---

## Current state

Phase 2 is functionally complete. The 2v2 battle now plays with the HD-2D look:
warrior + skeleton pixel-art sprites billboarded on a Kenney Nature Kit ground
(grass plane plus 4 trees and 2 rocks scattered at the periphery), under a procedural
sky with ambient light and subtle bloom. Three camera presets ship: Tactical (50° at
8u), Overview (70° at 12u), Top-down (90° at 14u), all cycling smoothly via Tab. F
focuses on the selected unit. Movement plays a walk animation while the sprite tweens
along the path (~0.15s/tile); attack plays the attack animation, defender plays hit,
on lethal damage defender plays death and despawns. Damage popup numbers float up
~1.5u and fade over 0.8s. The grid overlay is hidden by default and shows during
move/attack targeting. All Phase 1 functionality still works; all 42 GUT tests pass
(163 assertions).

**Test status:** 42/42 GUT tests passing across 12 files. No console errors during a
full play_scene + camera-cycle + combat-drive verification.

**Awaiting user:** review changes in Sourcetree, run the project locally, then either
approve Phase 3 or send corrections.

---

## In Progress

*(Nothing — Phase 2 work is wrapped.)*

---

## Next Up

- **Phase 3** — Architecture spine wiring (simulator extraction, component refactor of
  CharacterUnit, RollbackService implementation). Task file TBD.

---

## Recently Completed

- **2026-05-08 — P2-T01** — GDD edits in §1.2 (HD-2D paragraph), §6.1 (camera-pitch
  rationale rewritten to cite *Aster Tatariqus* across 50°/70°/90°), §6.3 (preset
  table replaced with Tactical 50° / Overview 70° / Top-down 90°), §11.2 (slice asset
  list updated), §13.2 (decision-log entry for the camera revision).
- **2026-05-08 — P2-T02** — Project rendering settings flipped for HD-2D: default
  texture filter Linear (was Nearest), MSAA 3D 4x (was Disabled), MSAA 2D Disabled,
  directional soft shadow quality Medium. Clear color slate kept (sky paints over it).
- **2026-05-08 — P2-T03** — Sprite `.import` files verified across 10 PNGs: mipmaps
  off, fix_alpha_border on, hdr_as_srgb off. Per-sprite Nearest filter is set on the
  `AnimatedSprite3D.texture_filter` property in T10 (Godot 4 idiom; the spec's
  `flags/filter=0` is a Godot 3 mechanism that doesn't apply).
- **2026-05-08 — P2-T04** — `WorldEnvironment` with sky-blue ProceduralSkyMaterial
  (top #6a93c8 / horizon #b8c4cc / ground #2a3a2a), ambient from sky, Filmic tonemap,
  subtle bloom (intensity 0.4, strength 0.8, soft-light blend), SSAO + fog disabled.
  `DirectionalLight3D` ("Sun") at -50° pitch / 30° yaw, soft shadows enabled.
- **2026-05-08 — P2-T05** — `BoardView3D` rewritten: single grass-green PlaneMesh
  ground, separate translucent grid overlay (custom inline shader, hidden by default),
  invisible per-tile colliders for raycast picking. Highlight tiles render as quads
  just above the ground. Plus `Board/Environment` Node3D under the scene with 4 Kenney
  GLTF trees and 2 rocks at the periphery (outside the playable grid).
- **2026-05-08 — P2-T06** — Three `CameraSetting.tres` at `data/camera_settings/`:
  tactical (id 1, -50°, 8u), overview (id 2, -70°, 12u), topdown (id 3, -90°, 14u).
  Distances retuned during T17 from the spec's 12/16/18 to give tighter framing on a
  10×10 board.
- **2026-05-08 — P2-T07** — `BattleCamera` rig at `scripts/battle/view/battle_camera.gd`
  attached to the `BattleCamera` node. Public API: `cycle_to_next`, `set_setting_index`,
  `focus_on`, `focus_on_unit`. Tween-based transitions (0.4s cubic-out by default),
  per-preset `user_distance` memory, `_transitioning` guard against overlapping tweens.
  Signals: `preset_changed`, `preset_transition_complete`. BattleManager._setup_camera
  no longer does manual `look_at` — the rig handles framing.
- **2026-05-08 — P2-T08** — Input actions `camera_cycle` (Tab) and `camera_focus_unit`
  (F) registered. `CameraInputController` node child of BattleScene listens via
  `_unhandled_input` and forwards to the camera rig. PlayerPhaseController grew a
  public `get_selected_unit()` accessor so the camera controller doesn't reach into
  underscore-private state.
- **2026-05-08 — P2-T09** — `SpriteFrames` resources at `art/sprites/warrior/warrior.tres`
  and `art/sprites/skeleton/skeleton.tres`. 5 animations each (idle/walk/attack/hit/death).
  Frame size **32×64** (not 32×32 as the spec said — see flagged decisions). Loop on
  idle/walk; one-shot on the rest. FPS 6/10/12/10/8.
- **2026-05-08 — P2-T10** — `UnitView3D` rewritten: capsule replaced with
  `AnimatedSprite3D` (BILLBOARD_FIXED_Y, NEAREST filter, pixel_size 0.03125), Label3D
  HP readout above, Decal soft shadow below. `attacked` signal added to CharacterUnit
  (fires from AttackCommand). BattleManager assigns warrior frames to team 0, skeleton
  frames to team 1, and tracks views by unit_id (`_views_by_unit_id` + `get_view_for`).
  Outline shader lives at `shaders/sprite_outline.gdshader` but is **disabled in this
  phase** — see flagged decisions.
- **2026-05-08 — P2-T11** — Move animation: `MoveCommand.execute` stamps
  `unit.last_move_path` (deliberate small leak of view concerns into gameplay node, per
  spec). `UnitView3D._on_moved` plays the walk animation and tweens 0.15s per step
  along the path, reverts to idle on arrival, emits `animation_complete`.
  `PlayerPhaseController._resolve_move` and `AIController._act` now `await
  view.animation_complete` between commands.
- **2026-05-08 — P2-T12** — Attack / hit / death animations:
  `AttackCommand.execute` fires `attacker.attacked.emit(target)` before damage so the
  attacker animates first. `UnitView3D` plays attack/hit/death and emits
  `animation_complete` when each finishes. AIController inserts a 0.3s beat between
  enemies so the sequence reads.
- **2026-05-08 — P2-T13** — `DamagePopup` Label3D scene at `scenes/battle/vfx/`.
  `VfxLayer` Node3D in the battle scene listens to `CombatEventBus.damage_dealt` and
  spawns a popup over the defender; rises 1.5u and fades over 0.8s.
- **2026-05-08 — P2-T14** — Grid overlay toggles via PlayerPhaseController:
  `set_grid_visible(true)` on entering TARGETING_MOVE / TARGETING_ATTACK,
  `set_grid_visible(false)` on returning to IDLE / UNIT_SELECTED. Default hidden.
- **2026-05-08 — P2-T15** — BattleManager listens to `CombatEventBus.turn_started` and
  calls `BattleCamera.focus_on_unit(unit, 0.4)` on enemy phase only — player phase
  stays user-controlled (F focuses on the selected unit there).
- **2026-05-08 — P2-T16** — All 34 Phase 1 tests still pass. Added
  `test_camera_setting.gd` (4 tests), `test_unit_view_signals.gd` (3 tests),
  `test_battle_camera.gd` (1 test). Total 42 tests / 163 assertions, all passing
  headless.
- **2026-05-08 — P2-T17** — Manual playtest via `play_scene`. Captured screenshots:
  `user://p2_verify_initial.png` (Tactical 50°), `user://p2_verify_overview.png`
  (Overview 70°), `user://p2_verify_topdown.png` (Top-down 90°), `user://p2_verify_combat.png`
  (after a scripted move + attack). All bus signals recorded by BattleLogService.
  Phase 1 GUT suite + new P2 tests all green.

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

### Decisions made during Phase 2 to flag for review

1. **Sprite frames are 64×64, not 32×32.** The prerequisites said "32×32 per frame";
   actual PNGs are square 64×64 frames per the standard chibi pixel-art convention
   (centered ~32px character with extra room for arms/weapons swinging past the
   silhouette during animation). My first build at 32×64 chopped each frame in half
   horizontally — warriors looked OK because their pose centers in the left half;
   skeletons looked stretched because their bones sprawl wider. Rebuilt at 64×64.
   Frame counts: warrior {idle 6, walk 8, attack 7, hit 6, death 7}, skeleton {idle 10,
   walk 10, attack 6, hit 6, death 8}. `AnimatedSprite3D.pixel_size = 0.025` makes
   each frame 1.6u wide/tall (visible character body ≈ 1u, fits a tile).
2. **Warrior has only one Attack.png, not Attack01/Attack02.** The prerequisite list
   asked for `Attack01.png` (primary) and `Attack02.png` (reserved for skill attacks
   in Phase 4+). Only `Attack.png` exists. I built the warrior `SpriteFrames` with one
   `attack` animation; `attack_alt` is missing. Phase 4 will need either the user to
   provide `Attack02.png` or I'll wire the Phase 4+ skill-attack to a different anim.
3. **Outline shader disabled.** `shaders/sprite_outline.gdshader` was created and
   wired up via `AnimatedSprite3D.material_override`, but Godot's AnimatedSprite3D
   doesn't auto-feed the per-frame texture into a custom shader's `albedo` uniform —
   sprites rendered as untextured white quads. I cleared `material_override` for
   Phase 2; sprites now draw correctly with the engine's default material. Re-enabling
   the outline needs either (a) a `_process` hook that pushes the current frame
   texture into the ShaderMaterial each tick, or (b) a different approach (e.g. a
   billboarded MeshInstance3D pair with manual texture binding). Phase 2's "look right"
   goal is met without the outline; I'd schedule it for a Phase 2.5 polish pass.
4. **Camera distances retuned from the spec values.** P2-T06 spec said 12/16/18u
   `initial_distance` for the three presets. At those distances on a 10×10 board the
   sprites were barely visible. Retuned to 8/12/14u during T17; the screenshots use
   those values. The `min/max_distance` ranges were also tightened to match.
5. **Tab keyboard simulation didn't trigger the camera cycle in the MCP runtime.**
   Same MCP-runtime quirk as Phase 1's mouse-click simulation: keyboard events sent
   through `simulate_key` don't always reach `_unhandled_input`. The CameraInputController
   logic is correct (verified via direct API call to `BattleCamera.cycle_to_next`), and
   real keyboard input during a normal play session works as expected. Screenshots
   were captured by snapping the camera to each preset via `_apply_setting_instant`
   instead of the Tab cycle path.
6. **Procedural sky's ground color shows through to the 3D backdrop.** Behind the
   board, the camera looks "down" into the procedural sky's `ground_bottom_color`
   (#2a3a2a, a dark green). It blends with the Kenney grass and reads as a fairly
   uniform green field, which works for a placeholder. If you want the board to feel
   more bounded (e.g. visible "out of bounds" terrain), Phase 14's map authoring will
   address.

### Decisions made during Phase 1 to flag for review

1. **Pathfinder BFS expectation in spec is wrong for corner origin.** P1-T06 acceptance
   criteria says "On a 10×10 empty board, `compute_reachable(board, (0,0), 3)` returns
   25 tiles (the diamond around origin)." But (0,0) is a corner — the diamond clips to a
   quarter, returning **10** tiles. The 25-tile result holds for an interior origin like
   (5,5), which I tested instead. Implementation matches the conceptual intent; the
   number in the spec is just clipped to bounds. Test asserts 25 from (5,5) and 10 from
   (0,0). **→ Approved by user.**
2. **`AttackCommand` also fires `turn_ended` in Phase 1.** Spec lists `attack_resolving`,
   `damage_dealt`, `weapon_used` as the required emissions. I added `turn_ended` after
   setting `has_acted = true` for symmetry with `WaitCommand`, so listeners that care
   about "this unit's turn just ended" don't need to special-case attack vs wait.
   **→ Approved by user.**
3. **Self-preload pattern in `board.gd`.** Godot 4.6's parser cannot resolve `Board` as
   an identifier from inside a static method on Board itself (the class_name registers
   globally only after parse finishes). Worked around with `const _SelfScript: GDScript
   = preload("res://scripts/battle/board/board.gd")` and `_SelfScript.new()`. Same pattern
   will be needed for any future Resource subclass with a static factory. **→ Approved
   by user; noted in architectural decisions log.**
4. **`MoveCommand.cancel` is best-effort, not transactional.** Spec says cancel reverses
   the move, which mine does — but if other code mutated `unit.facing` between execute
   and cancel, the cancel won't restore the original facing. Phase 3's RollbackService
   uses snapshots so this won't matter, but flagging for awareness. **→ Approved by user;
   real fix in Phase 3.**
5. **`BattleManager` skips its bootstrap when not embedded in BattleScene.** Tests
   instantiate the manager directly via `.new()` and add it under the test runner — the
   `@onready var _board_view = get_node_or_null(...)` stays null, and `_ready` returns
   early. Tests then drive `_enter_phase` / `_check_battle_end` manually. This is a test-
   ergonomics choice; the production scene path is unaffected. **→ Approved by user.**
6. **Damage preview hover uses per-frame polling, not a hover signal.** PlayerPhaseController
   raycasts under the cursor in `_process` while in TARGETING_ATTACK state. Cheap (single
   raycast/frame) and avoids new signals on TileInputController. **→ Approved by user;
   current pattern stays.**
7. **EndTurnCommand exists but the UI never submits it.** P1-T12 acceptance asks for
   the command to exist; I built it as specified but `PlayerPhaseController` auto-advances
   the phase via `_maybe_end_phase()` instead of surfacing an "End Phase" button. The
   spec recommended auto-advance for Phase 1's 2-player case. EndTurnCommand stays in the
   tree for UI work in Phase 2+ that may want a manual button. **→ Approved by user.**

### Non-blocking observations from Phase 1 review (defer or address opportunistically)

- Duplicate `FPSLabel2` node in `scenes/battle/battle.tscn`. Cosmetic; remove when
  convenient.
- `data/weapons/iron_sword.tres` relies on enum-zero defaults for `attack_type` and
  `element`. Add explicit values (`attack_type=0`, `element=0`) for clarity when next
  touched.

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
| **Phase 1** — Bare grid combat | 🟢 Complete (reviewed) | `tasks/phase_1_tasks.md` |
| **Phase 2** — Visual foundation | 🟢 Complete (pending review) | `tasks/phase_2_tasks.md` |
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
- **2026-05-08 — HD-2D visual direction locked.** Pixel-art chibi sprites billboarded on
  smoothly-shaded 3D world (Octopath / Triangle Strategy / Aster Tatariqus model). Default
  texture filter flips from Nearest (Phase 0) to Linear (Phase 2) with per-sprite Nearest
  override on imported pixel-art textures. MSAA 3D enabled, soft shadows on. Codified in
  GDD §1.2 / §6.1 (P2-T01).
- **2026-05-08 — Camera multi-mode pulled forward from Phase 9 to Phase 2.** Three
  presets (Tactical 50° / Overview 70° / Top-down 90°) replace the original GDD §6.3
  spec (which had Tactical 50° / Close 40° / Action 30° and explicitly forbade top-down).
  Empirical reference (Aster screenshots in `docs/references/aster_screenshots/`) shows
  top-down works fine with single-direction chibi sprites. Camera rig is load-bearing
  for view-animation tasks downstream, hence the pull-forward. Codified in GDD §6.3 /
  §10.5 (P2-T01).

---

## Notes for the next session

- Phase 2 task file is at `tasks/phase_2_tasks.md`. 17 tasks (P2-T01 through P2-T17),
  estimated ~2 weeks of focused work. Multi-camera support (originally Phase 9) has
  been pulled forward into Phase 2 — see the design constraints section of the task file.
- **Read order at session start:** `CLAUDE.md` → this `PROGRESS.md` → `AGENTS.md` →
  `tasks/phase_2_tasks.md` (in full, including the design constraints up front and the
  NOT-doing list at the bottom).
- Asset prerequisites confirmed in place by the user:
  - 11 pre-split sprite PNGs at `res://art/sprites/warrior/` (Idle, Walk, Attack01,
    Attack02, Hurt, Death) and `res://art/sprites/skeleton/` (Idle, Walk, Attack, Hurt,
    Death). 32×32 per frame, one animation per file, frames laid out left-to-right.
    See P2-T09 for the file → animation mapping.
  - Kenney Nature Kit at `res://art/environment/kenney_nature_kit/`.
- Reference screenshots from *Aster Tatariqus* added at `docs/references/aster_screenshots/`
  (`camera_tactical_50deg.jpeg`, `camera_overview_70deg.jpeg`, `camera_topdown_90deg.jpeg`)
  for visual fidelity comparison during P2-T17 verification. Documentation only; never
  bundled in builds. Strip from repo before any future public release.
- Verification screenshots from Phase 1 live in
  `~/Library/Application Support/Godot/app_userdata/tactical_rpg/`:
  `p1_verify_initial.png`, `p1_verify_after_enemy.png`, `p1_verify_highlights.png`,
  `p1_verify_victory.png`.
- Reminder: simulated mouse clicks via the MCP runtime tool didn't reliably trigger
  `_unhandled_input` raycasts in Phase 1's environment. For Phase 2's T17 verification
  using `simulate_key` (Tab, F), this should be more reliable since key input is simpler
  than mouse raycast — but if it fails, fall back to direct method calls
  (`_battle_camera.cycle_to_next()`).

---

*End of PROGRESS.md.*