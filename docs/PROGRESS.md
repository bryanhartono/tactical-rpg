# PROGRESS

> Living status document. Updated by Claude Code at the end of every session per `CLAUDE.md` instructions.

**Last updated:** 2026-05-14 — Post-Phase-2 bug fixes and warning cleanup.
**Active phase:** Phase 2 — Visual Foundation (✅ complete, pending user review before Phase 3)
**Active task file:** `tasks/phase_2_tasks.md`

---

## Current state

Phase 2 is functionally complete. The 2v2 battle plays with the HD-2D look: warrior + skeleton
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

*(Nothing — all work is wrapped.)*

---

## Next Up

- **Phase 3** — Architecture spine wiring (simulator extraction, component refactor of
  CharacterUnit, RollbackService implementation). Task file TBD.

---

## Recently Completed

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
- **2026-05-14 — Unit Z offset is camera-pitch-dependent.** `VISUAL_Z_OFFSET` (fixed 0.5)
  replaced with `SPRITE_HALF_HEIGHT / sin(|pitch|)`. At -50° this is ≈ 1.044; at -90° it
  is 0.8. BattleManager recomputes and broadcasts on every `preset_changed` signal.

---

*End of PROGRESS.md.*
