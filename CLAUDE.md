# CLAUDE.md

> Instructions for Claude Code working on this project. Read this file at the start of every session before doing anything else.

---

## What this project is

A single-player tactical RPG in Godot 4 (latest stable). Grid-based combat, pixel-art chibi sprites on 3D terrain, paired-unit ("Duo") mechanic, snapshot-based rewind. Modeled closely on *Aster Tatariqus* (Studio FgG, 2023). Single-player only at v1, desktop-first (macOS M1 + Windows).

**Primary scripting language:** GDScript only at v1. Do not use C# unless explicitly authorized.

---

## How to start each session

Follow this order, every time:

1. **Read `docs/PROGRESS.md`**. It tells you what's done, what's in progress, and what's next.
2. **Read the active phase task file** (e.g. `tasks/phase_0_tasks.md`). PROGRESS.md will name the active phase.
3. **Identify the next unblocked task** in that phase. Tasks have IDs like `P0-T03`.
4. **For that task, read the GDD and reference sections it cites** before starting work. The task file gives you specific section numbers; do not re-read the entire GDD.
5. **Begin the task.** When done, update `docs/PROGRESS.md` and report what was completed.

If `docs/PROGRESS.md` says we're between phases or you can't determine the next task, stop and ask the user.

---

## Authoritative documents

These live at the project root. Always treat them as the source of truth — do not contradict them or invent specifications.

| Document | Role | When to read |
|---|---|---|
| Document | Role | When to read |
|---|---|---|
| `docs/gdd.md` | Authoritative spec for scope, mechanics, architecture | When a task cites a §section |
| `docs/tactical_rpg_design_reference.md` | Research on Aster Tatariqus + architectural rationale | When the GDD points to it for "why" or you need a deeper pattern reference |
| `tasks/phase_X_tasks.md` | Concrete tickets for phase X | At session start when working on phase X |
| `docs/PROGRESS.md` | Living status doc | At session start, every session |
| `CLAUDE.md` | This file | At session start, every session |
| `AGENTS.md` | Godot MCP toolset reference — what tools are available and how to use them | At session start, every session |

**The GDD wins when sources conflict.** The reference document explains *why*; the GDD specifies *what*. If a pattern in the reference looks attractive but the GDD says "we're not doing that," follow the GDD.

---

## Tooling — Godot MCP server

This project has a Godot MCP server enabled. **Read `AGENTS.md` for the full tool reference.** Key points to remember:

- **Use MCP tools, not raw file writes, for Godot-specific operations.** Creating scenes goes through `create_scene` + `batch_add_nodes`. Attaching scripts goes through `attach_script`. Registering autoloads goes through `set_project_setting`. **NEVER edit `project.godot` directly** — Godot will overwrite it.
- **Use MCP tools, not bash, for Godot operations** wherever possible. The MCP tools talk directly to the Godot editor and reflect changes immediately.
- **Use plain file writes for documentation files** (`PROGRESS.md`, task files, etc.) — those aren't Godot-managed.
- **For verification, use `play_scene` + `get_game_screenshot`** rather than asking the user to verify manually. You can self-verify a lot of work.
- **`execute_editor_script` and `execute_game_script` are powerful escape hatches** when no specific tool fits — but prefer the typed tools when available.
- **MCP errors are loud and visible.** If a tool call fails, surface the error in your report rather than silently retrying with a different approach.

---

## Working autonomy

The user prefers: **do the work first, then report what was done.** Don't ask permission for every small step.

### Proceed without asking when

- Creating files specified in the active task.
- Writing code that follows the architectural patterns already established in the codebase or in GDD §10.
- Fixing obvious bugs you encounter while working on a task.
- Adding tests for code you write.
- Refactoring within a single file you're already editing.
- Making style/naming choices that match existing project conventions.

### STOP and ask first when

- A task seems to require a decision not covered in the GDD or reference. (Don't invent specs. Surface the question.)
- You think a GDD specification is wrong, missing, or contradicts itself. (The user wants to know about gaps.)
- The work would touch an architectural pattern across many files (event bus signals, autoload services, scene tree shape).
- A task could be done two equally valid ways and the choice has long-term consequences.
- You'd be removing or significantly changing existing working code outside the current task's scope.
- Adding a new dependency, library, or addon.
- Anything in `docs/gdd.md §13.2` "Open Questions" that hasn't been resolved.

### Always ask first

- Changing the scope of a task as defined in the task file.
- Skipping a task because it seems unnecessary.
- Adding a feature not in the GDD.
- Removing files, scenes, or autoloads.
- Anything involving `git` history rewriting (rebases, force pushes, etc.).

### Never do

- **Make git commits.** The user manages all version control via Sourcetree. Claude Code makes file changes; the user reviews and commits at appropriate intervals. Do not run `git commit`, `git push`, `git add`, or any other state-changing git command. Read-only commands (`git status`, `git log`) are fine for situational awareness if useful.
- **Push to a remote.** Even if asked.
- **Edit `project.godot` directly** — use the `set_project_setting` MCP tool. Godot will overwrite manual edits.
- **Modify files outside the project repo** unless the user explicitly directs you to.

---

## Code style and architecture preferences

These are user preferences that go beyond the GDD's specifications. The GDD's §10 architecture is non-negotiable; this section adds *style* on top.

### Strong, clean, modular architecture is a hard requirement

The user has explicitly stated that good architecture is a primary goal. This means:

- **Single Responsibility per class.** A class does one thing well. If a class is doing two things, split it.
- **Composition over inheritance.** Use components, not subclass trees. (GDD §10.1 principle 2.)
- **Loose coupling.** Modules know about interfaces and signals, not concrete other modules.
- **Explicit dependencies.** No global state lookups in the middle of business logic. Pass dependencies in or use the autoload services that exist for that purpose.

### Signals are first-class

The user values signals. Use them everywhere they fit:

- **Anything cross-cutting goes through `CombatEventBus`.** (GDD §10.3.) EXP, bond, achievements, audio cues, screen shake, replay logging — they all listen to the bus, never call combat code directly.
- **Local communication uses local signals.** Within a node tree, prefer signals to direct method calls when the parent doesn't need a return value.
- **Name signals as past-tense events** that have already happened: `damage_dealt`, `unit_killed`, `weapon_broke`, `duo_formed`. Not `do_damage` or `kill_unit`.
- **One signal, one event.** Don't overload a single signal with a discriminator parameter to mean different things.
- **Document signal payloads** in a comment on the signal declaration. Future-you will thank present-you.

### Resources for data, Nodes for behavior

- Anything that's "a thing you'd edit in a spreadsheet" is a `Resource` subclass: weapons, skills, classes, terrain types, AI behaviors, range shapes, camera settings.
- Anything with runtime behavior, lifecycle, or scene-tree presence is a `Node`.
- Resources have no `_process`, no signals from `_process`, no scene-tree dependence. If you find yourself wanting one of those, you actually wanted a Node.
- Resource files end `.tres` (text format) for readability and version-control friendliness. Avoid `.res` (binary) unless there's a specific reason.

### Autoloads are services, not bags of utilities

- An autoload exists when there's exactly one of something for the whole game (the event bus, the AI controller, the experience tracker).
- An autoload should not be a kitchen-sink "GameManager" with twelve unrelated methods. Each autoload has one job.
- The user's autoloads list is in GDD §10.3. Don't add a new autoload without asking.

### GDScript style

- **Indentation: tabs**, as Godot's default formatter prefers.
- **`class_name` declared on every standalone script** so types are usable elsewhere.
- **Type hints everywhere.** `func damage(amount: int) -> void`, not `func damage(amount)`. The user wants this even when it adds verbosity.
- **`@export` for inspector-editable fields**, not bare vars.
- **Snake_case for vars, methods, signals.** PascalCase for classes and Resource types.
- **Constants are SCREAMING_SNAKE_CASE.**
- **Private members prefix with `_`** by convention, even though GDScript doesn't enforce it.
- **No magic numbers.** Either named constant or `@export` field.
- **Early returns over nested ifs** for guard clauses.

### Comments

- **Class-level docstring** at the top of every script: what this class does, who owns it, who calls it.
- **Public method docstrings** when the method's purpose isn't obvious from the name and signature.
- **No comments that restate the code.** `// increment counter` above `counter += 1` is noise.
- **`# TODO(reason)` and `# FIXME(reason)` for known gaps**, never bare `# TODO`.

### Error handling

- **Validate inputs at the boundary** (public methods). Internal helpers can assume valid input.
- **Use `assert()` for invariants** that should never be violated. They're stripped from release builds.
- **Use `push_error()` for unexpected runtime conditions** that aren't bugs but shouldn't happen — bad save data, missing resource files, etc.
- **Don't swallow errors silently.** If a thing fails, the engine should know.

### Files and folders

- **One class per file.** Inner classes only when they're tightly coupled to the outer.
- **Folder structure follows GDD §10.7.** Don't reorganize without asking.
- **Scene files (`.tscn`) and their associated scripts live next to each other**, not in separate `scripts/` and `scenes/` folders for the same feature.

---

## How to update PROGRESS.md

Every session, when you finish a task, update `docs/PROGRESS.md` with:

1. Move the completed task from "In Progress" / "Next Up" to "Recently Completed."
2. If you started a new task and didn't finish, add it to "In Progress" with a brief note on where you left off.
3. If you got blocked, add the blocker under "Blocked / Open Questions" with enough context that the user can resolve it.
4. Update the "Last Updated" timestamp.
5. Keep the "Recently Completed" section to the last 10 entries; older entries can be archived to `docs/PROGRESS_ARCHIVE.md`.

Don't add commentary, only state. PROGRESS.md is a status doc, not a diary.

---

## Reporting

When you finish a session's work, report concisely:

1. **What was done** — list of completed tasks with their IDs.
2. **What was changed** — files created, modified, or deleted.
3. **What was tested** — tests run, results.
4. **What's next** — the next task ID and a one-sentence summary.
5. **What's blocked, if anything** — questions for the user.

Don't narrate your thought process unless asked. Don't restate the GDD. Don't apologize for things you got right. Be direct.

If you're confident in a decision, present it as a decision, not as a question — but flag it so the user can push back if they disagree:

> *"Implemented `CombatEventBus` with the signals listed in GDD §10.3, plus added `unit_facing_changed(unit, new_facing)` because the facing arrow decal needs to react to it. Let me know if you'd rather route that through a different signal."*

That pattern — decide, do, flag — is what the user wants.

---

## Things to remember about Godot 4

- The user is on Godot 4 (latest stable). Use modern idioms.
- `await` works on signals natively (`await unit.died`). Use this for sequencing animations and async flow rather than coroutines or callbacks.
- `Tween` is the modern animation API; `AnimationPlayer` for sprite animation; `AnimationTree` only if state machines for animation get complex.
- `Sprite3D` and `AnimatedSprite3D` for the chibi units (GDD §6.1). Set `texture_filter = NEAREST` and `pixel_size` appropriately. `billboard = BILLBOARD_Y` for billboarding only on Y axis.
- `GridMap` exists but is overkill for our flat-tile design; a custom tile data structure on a `Node3D` host is simpler and more controllable.
- `@onready var x = $Path` for node references. Don't use `get_node()` strings scattered through methods.
- Resources support `duplicate(true)` for deep copies — this is the basis of the snapshot rollback in GDD §5.12.

---

## Things to remember about Aster Tatariqus

The decompiled source lives at `https://github.com/laqieer/AT-Datamine`. We have it as a reference, not as a thing to literally copy. Three rules:

1. **Borrow patterns, not assets.** No copying their art, characters, story, mission content. We borrow architectural decisions and balance numbers.
2. **Naming is ours.** Their `Double` is our `Duo`. Their `Duel` (the combat exchange) doesn't exist as a separate concept in our project — we have no animated combat scenes, so combat resolution is just the attack action's `execute()`.
3. **The reference doc tells you which patterns are validated against their source.** When in doubt, prefer a pattern with explicit reference-doc backing over a pattern you're inventing.

---

## Asset policy

The project goes through three asset phases. Don't skip ahead.

### Phase 0 — No assets
Use Godot's built-in primitives. Capsule = unit, cube = tile, default fonts and materials. The architecture must be correct *without* art, and adding art prematurely makes refactoring harder. If a Phase 0 task seems to need an asset, you're doing something wrong — re-read the task scope.

### Phases 1–6 (vertical slice) — Placeholder assets only
Use royalty-free / CC0 assets from itch.io, Kenney.nl, OpenGameArt, or similar. **The user will provide assets when needed**, OR you should ask the user to provide them at the start of a task that requires them. Do NOT:
- Generate assets via AI tools without asking.
- Download and commit assets without the user reviewing the license.
- Spend time hunting for "the perfect asset" — placeholder is the goal.
- Start building art-related systems (animation trees, particle effects, complex shaders) before the user has provided the asset that exercises that system.

If a task requires an asset the user hasn't provided yet, **stop and surface the request**. Examples of acceptable requests:
- "Phase 2 task P2-T05 needs unit sprite sheets. Could you provide a CC0 chibi sprite pack? Direction: side-view, 4–6 frame walk cycle, 1 direction (we'll flip for the other side per GDD §6.1)."
- "Phase 6 vertical slice needs a map ground asset. A simple 30×30u stylized terrain mesh would work — Kenney's Nature Pack has options. Want to pick one or should I propose specifics?"

### Post-vertical-slice — Final assets
Out of scope for the current task files. Will be planned post-M2 review.

### Asset folder conventions
When assets do arrive, place them under `res://art/`, `res://audio/`, etc. per GDD §10.7. Maintain an `ATTRIBUTIONS.md` file at the project root listing every third-party asset with its source, license, and (if required) attribution text. Update this file every time you add a third-party asset. This is non-negotiable — license compliance matters even for placeholder use.

---

## What "done" means for a task

A task is done when:

1. The acceptance criteria in the task file are satisfied.
2. Code compiles and runs without errors.
3. Any tests for the task pass.
4. `PROGRESS.md` is updated.
5. You've reported what was done to the user.

A task is **not** done when:

- It "should work" but you haven't verified.
- The new code works but old code is broken.
- There's a TODO in the code for something the task required.
- The acceptance criteria are partially met.

If you can't fully complete a task, that's fine — surface what's blocking it and stop. Don't fudge "done."

---

## What to do if you get stuck

1. **Re-read the relevant GDD section.** Often the answer is there.
2. **Check the reference document for prior art.** Aster solved most of these problems already.
3. **Look at adjacent code in the codebase** for established patterns before inventing one.
4. **If still stuck, stop and ask.** Don't guess at architecture. The user prefers a 5-minute Q&A to a 5-day refactor.

---

*End of CLAUDE.md. Last updated: project kickoff.*
