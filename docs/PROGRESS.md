# PROGRESS

> Living status document. Updated by Claude Code at the end of every session per `CLAUDE.md` instructions.

**Last updated:** 2026-05-05 — Phase 0 complete, awaiting user review before Phase 1.
**Active phase:** Phase 0 — Project Setup and Architectural Skeleton (✅ complete, ✅ reviewed)
**Active task file:** `tasks/phase_1_tasks.md`

---

## Current state

Phase 0 implementation is complete. All P0-T01 through P0-T12 tasks done. Project loads
the empty battle scene cleanly with all 10 game autoloads, no console errors, FPS counter
visible top-left, GUT sanity test passing 3/3.

**Awaiting user:** review the changes in Sourcetree, run the project locally, then either
approve Phase 1 or send corrections.

---

## In Progress

*(Nothing — Phase 0 work is wrapped.)*

---

## Next Up

- **Phase 1** — Bare grid combat (task file uploaded; see GDD §12.1).

---

## Recently Completed

- **2026-05-05 — P0-T01** — Project settings tuned for pixel-art 3D. Default texture
  filter = Nearest, MSAA 3D = Disabled, viewport 1920×1080 with stretch `viewport`/`keep`,
  clear color slate `#1a1a2e`.
- **2026-05-05 — P0-T02** — Folder tree from GDD §10.7 created under `res://`. Empty
  leaves marked with `.gdkeep` for git.
- **2026-05-05 — P0-T03** — `README.md` at project root, with the canonical doc reading
  order.
- **2026-05-05 — P0-T04** — 10 Resource subclasses under `res://scripts/data/`
  (battle_const, range_shape, status_effect, ai_behavior, camera_setting,
  landform_definition, skill, weapon, style_definition, character_definition). Plus
  populated `res://data/battle_const.tres` matching GDD §11.1.
- **2026-05-05 — P0-T05** — `CombatEventBus` autoload with all 20 signals from the §10.3
  contract (the criteria says "19" but the spec list contains 20 — flagged below).
- **2026-05-05 — P0-T06** — `Command` base class (`RefCounted`) at
  `scripts/battle/commands/command.gd`, plus `CommandQueue` autoload with `submit()`.
- **2026-05-05 — P0-T07** — 8 service stubs (MasterDataService, ExperienceService,
  BondService, ProficiencyService, BondActionService, RollbackService, BattleLogService,
  AIController). Each has a class-level docstring, an empty `_ready()` and a
  `# TODO(phase X)` marker.
- **2026-05-05 — P0-T08** — All 10 game autoloads registered in correct order
  (MasterDataService → CombatEventBus → CommandQueue → ExperienceService → BondService →
  ProficiencyService → BondActionService → RollbackService → BattleLogService →
  AIController). MCP tooling autoloads remain ahead of these in `project.godot` but don't
  conflict — flagged below.
- **2026-05-05 — P0-T09** — `res://scenes/battle/battle.tscn` matching GDD §10.2
  (BattleScene → Board / BattleCamera→Pivot→Camera3D / BattleManager / BattleUI). Both
  `_ready()` print messages fire on play. Set as project main scene.
- **2026-05-05 — P0-T10** — `debug_hud.tscn` with FPS Label, instanced under `BattleUI`.
  FPS reads ~1500–1600 on M1 Pro (uncapped, well above the 60 FPS budget).
- **2026-05-05 — P0-T11** — GUT 9.6.0 installed at `res://addons/gut/`, plugin enabled.
  Sanity test `tests/test_battle_const.gd` passes 3/3 via headless CLI.
- **2026-05-05 — P0-T12** — Verification checklist run; project plays cleanly, no console
  errors, screenshot captured at `user://phase0_final.png`.

---

## Blocked / Open Questions

These are items that need user input before Claude Code can proceed. Claude Code adds to this list when it hits a blocker; the user resolves them by editing this section directly or replying in chat.

### Decisions made during Phase 0 to flag for review

1. **CombatEventBus signal count: 20, not 19.** The P0-T05 acceptance criteria says "All
   19 signals listed above are declared" but the spec block enumerates 20 (counting
   `unit_facing_changed`). Implemented all 20. If the criteria number was authoritative,
   tell me which signal to drop.
2. **Service stubs do NOT carry `class_name`.** Godot 4 forbids a script having a
   `class_name` X when X is also the name of an autoload singleton ("hides an autoload
   singleton"). The P0-T07 spec said "Have `class_name`," but combining that with T08's
   "use the class name as the autoload name" produces a parse error in Godot 4. I dropped
   `class_name` from the 8 service stubs (consistent with the spec's own
   `combat_event_bus.gd` and `command_queue.gd` examples, which also have no
   `class_name`). The autoload singleton name is the public API.
3. **MCP autoloads precede game autoloads in `project.godot`.** The pre-existing
   `MCPScreenshot`, `MCPInputService`, `MCPGameInspector` autoloads (Godot MCP tooling)
   stay ahead of the game autoloads in `project.godot`. They don't reference any game
   state during their `_ready()`, so the load order requirement (MasterDataService →
   bus → queue → services → AIController) is preserved among the *game* autoloads. If
   you want the MCP autoloads moved to the bottom, say so.
4. **Type hints on bus signals use `Node` / `Resource` placeholders.** `CharacterUnit`,
   `DuoUnit`, `BattleMap` don't exist yet, so their parameters in `CombatEventBus`
   signals are typed as `Node` (or `Resource` for BattleMap). Doc comments describe the
   intended class. Tightening pass scheduled when those classes land in Phase 1+.

### From the GDD §13.2 (open questions deferred from kickoff)

These were flagged in the GDD as decisions still owed. They don't block Phase 0 but will need answers by the phase listed.

| # | Question | Needed by |
|---|---|---|
| 1 | Pin to specific Godot 4.x or follow latest stable? | Phase 0 (project is on 4.6.2-stable; revisit at v1) |
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
| **Phase 0** — Setup and architectural skeleton | 🟢 Complete (pending review) | `tasks/phase_0_tasks.md` |
| Phase 1 — Bare grid combat | ⚪ Not started | (TBD) |
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

Decisions made during implementation that aren't already in the GDD. Format: short statement, date, who decided.

- **2026-05-05 — Autoload service scripts do not declare `class_name`.** Reason: in
  Godot 4, a `class_name X` on a script that's also autoloaded as singleton `X` produces
  a "hides an autoload singleton" parse error. Singleton name is the public API; scripts
  remain `extends Node` only. Decided by Claude Code.

When adding a decision: keep it to 2–3 sentences. If it's a big decision worthy of more, write a proper ADR in `docs/adr/` and link to it from here.

---

## Notes for the next session

This section is for Claude Code to leave breadcrumbs for itself or the user when stopping mid-task.

- Phase 1 task file does not yet exist. When the user is ready to start Phase 1, either
  the user provides `tasks/phase_1_tasks.md` or asks Claude Code to draft it from the
  GDD §12.1 Phase 1 description.
- A `phase0_final.png` screenshot is in the user data dir for the project (path:
  `~/Library/Application Support/Godot/app_userdata/tactical_rpg/phase0_final.png`)
  showing the empty battle scene with FPS counter as proof of life.

---

*End of PROGRESS.md.*
