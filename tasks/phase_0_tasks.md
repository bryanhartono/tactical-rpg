# Phase 0 — Project Setup and Architectural Skeleton

> **Phase goal:** Establish the project structure, register autoload services as empty stubs, declare the event bus signal contract, define the Command base class, and ship a battle scene that loads. No combat behavior yet — this is bones, not muscle.
>
> **Estimated duration:** 2–3 days of focused work.
>
> **Definition of phase done:** All Phase 0 tasks complete + the empty battle scene loads cleanly from a freshly cloned repo, with FPS counter showing 60 and zero errors in the console.

---

## How to read this file

- Tasks are ordered. Most have dependencies on earlier tasks; do them in order unless you have a specific reason not to.
- Each task lists **acceptance criteria** that must all be true for the task to be "done." See `CLAUDE.md` for what "done" means.
- Each task lists the **GDD / reference sections** to read before starting. Read those, not the entire GDD.
- Each task has an **autonomy note** clarifying what to do without asking vs what to surface.
- The **Phase 0 NOT-doing list** at the bottom of this file is as important as the task list. Read it before starting any task.

---

## Prerequisites (done by user before Claude Code starts)

The following must be true before Claude Code begins. The user handles these manually because Claude Code's MCP server connects to an existing Godot project — it cannot create one from nothing.

- [ ] Godot 4 project initialized at the repo root (latest stable Godot 4.x).
- [ ] `.gitignore` created at the repo root, excluding at minimum: `.godot/`, `*.import`, `export.cfg`, OS files (`.DS_Store`, `Thumbs.db`).
- [ ] Folder structure for documentation in place:
    - `CLAUDE.md`, `AGENTS.md` at root
    - `docs/gdd.md`, `docs/tactical_rpg_design_reference.md`, `docs/PROGRESS.md`
    - `tasks/phase_0_tasks.md`
- [ ] Godot MCP server is connected and verified working with the project.
- [ ] Initial git commit made by the user (pre-Claude Code work).
- [ ] User has confirmed the project opens in Godot 4 with no errors.

When all prerequisites are met, Claude Code starts at **P0-T01**.

**Important:** Claude Code does NOT make git commits, push to remote, or interact with git in any way. The user manages all version control via Sourcetree. Claude Code's job is to make changes; the user reviews and commits at appropriate intervals.

---

## Task index

| ID | Task | Depends on |
|---|---|---|
| P0-T01 | Configure project settings for pixel-art 3D | (prerequisites) |
| P0-T02 | Verify and complete the folder structure under `res://` | T01 |
| P0-T03 | Create README.md at project root | (prerequisites) |
| P0-T04 | Define core data Resource subclasses (stubs) | T02 |
| P0-T05 | Create `CombatEventBus` autoload with signal declarations | T02 |
| P0-T06 | Create `Command` base class and `CommandQueue` autoload | T02, T05 |
| P0-T07 | Create remaining autoload service stubs | T02, T05 |
| P0-T08 | Register all autoloads in project settings | T05, T06, T07 |
| P0-T09 | Create the battle scene tree skeleton | T02, T08 |
| P0-T10 | Add a debug HUD with FPS counter | T09 |
| P0-T11 | Set up GUT (testing framework) and write a sanity test | T02 |
| P0-T12 | Phase 0 verification | All |

---

## P0-T01 — Configure project settings for pixel-art 3D

**Goal:** Project-wide settings tuned for the pixel-art-on-3D-terrain visual style. Get this right early to avoid retrofitting visual artifacts later.

**Read first:**
- `docs/gdd.md` §6.1, §6.3
- `docs/tactical_rpg_design_reference.md` §2 (sprite implementation notes)

**Steps:**
1. **Texture filtering global default:** set to `Nearest` in Project Settings → Rendering → Textures → Canvas Textures → Default Texture Filter. (Important: also set Default Texture Repeat appropriately — usually Disabled.)
2. **3D filter:** under Rendering → Anti Aliasing, set MSAA 3D to **Disabled** initially. Pixel art + MSAA = blurry. We may revisit later for the terrain only.
3. **Display window:** set base resolution to 1920×1080 with stretch mode `viewport` and aspect `keep`.
4. **Default clear color:** dark slate (e.g. `#1a1a2e`) — easier on the eyes than pure black during development.
5. **Physics tick rate:** keep the default 60Hz unless there's a specific reason.
6. Confirm Godot 4's per-import override is being respected by checking that any imported texture defaults to Nearest filtering.

**Acceptance criteria:**
- [ ] Default texture filter is Nearest globally.
- [ ] MSAA 3D is Disabled.
- [ ] Window base resolution is 1920×1080.
- [ ] No errors or warnings on project load.

**Autonomy note:** Proceed without asking. If you encounter a setting where Godot 4's behavior diverges from what's described above (interface changes between versions), use your judgment and flag it in the report.

---

## P0-T02 — Verify and complete the folder structure under `res://`

**Goal:** All folders from GDD §10.7 that live under `res://` exist, even if empty. This prevents arbitrary placement decisions later. The user has already created `docs/`, `tasks/`, and root-level files outside `res://`.

**Read first:**
- `docs/gdd.md` §10.7

**Steps:**
1. Create the full folder tree from §10.7 **inside `res://`**: `addons/`, `data/` and its subfolders, `maps/`, `scenes/` and subfolders, `scripts/` and subfolders, `art/`, `audio/`, `tests/`.
2. Empty folders need a `.gdkeep` (or similar) file to be tracked by git, since git ignores empty directories.
3. Do NOT touch the project root — `docs/`, `tasks/`, `CLAUDE.md`, `AGENTS.md`, `README.md` are managed by the user.

**Acceptance criteria:**
- [ ] All folders from GDD §10.7 that are under `res://` exist.
- [ ] Each empty folder is tracked by git (via `.gdkeep` or equivalent).
- [ ] No changes made outside `res://`.

**Autonomy note:** Proceed without asking. The §10.7 list is authoritative — don't reorganize.

---

## P0-T03 — Create README.md at project root

**Goal:** A minimal README.md at the project root that points new contributors to the canonical docs in the right reading order. The user did NOT create this — Claude Code does.

**Read first:**
- `docs/gdd.md` §0
- `CLAUDE.md` overview

**Steps:**
1. Create `README.md` at the project root (NOT inside `res://`).
2. Content should include: one-line project description, a "Documentation" section listing the canonical reading order for new contributors (`CLAUDE.md` → `docs/gdd.md` → `docs/tactical_rpg_design_reference.md` → `tasks/phase_0_tasks.md`), and a "Status" line referencing `docs/PROGRESS.md`.
3. Keep it short — under 50 lines. README.md is a signpost, not a manual.

**Acceptance criteria:**
- [ ] `README.md` exists at the project root.
- [ ] Lists the docs in the canonical reading order.
- [ ] Points to `docs/PROGRESS.md` for current status.

**Autonomy note:** Proceed.

---

## P0-T04 — Define core data Resource subclasses (stubs)

**Goal:** Skeleton Resource classes for the major data types. They have field declarations matching the GDD specifications but no methods yet.

**Read first:**
- `docs/gdd.md` §5.1, §5.2, §5.7, §7.1, §7.2, §7.3, §7.4, §7.5, §7.6, §7.7, §11.1
- `CLAUDE.md` "Resources for data, Nodes for behavior" section

**Files to create** (under `res://scripts/data/`):

1. `battle_const.gd` — Resource class with the constants from GDD §11.1 as `@export` fields.
2. `landform_definition.gd` — Resource for terrain types (GDD §5.1).
3. `weapon.gd` — Resource for weapons (GDD §7.2).
4. `skill.gd` — Resource for skills (GDD §7.3).
5. `range_shape.gd` — Resource for the bitmask range patterns (GDD §7.4).
6. `style_definition.gd` — Resource for classes/Styles (GDD §7.1).
7. `character_definition.gd` — Resource for character roster entries (GDD §7.7).
8. `status_effect.gd` — Resource for status effects (GDD §7.5).
9. `ai_behavior.gd` — Resource for AI behavior weights (GDD §8.2).
10. `camera_setting.gd` — Resource for camera presets (GDD §10.5).

**Each file must:**
- Declare `class_name` matching the file (PascalCase).
- Extend `Resource`.
- Have `@export` fields for every property listed in the relevant GDD section.
- Use proper type hints on all fields.
- Have a class-level docstring explaining what this resource represents.
- Have NO methods yet, only field declarations. (This is intentional. Behavior comes later.)

**Also create one populated instance** to verify the resource workflow:
- `res://data/battle_const.tres` — populated with the values from GDD §11.1 table.

**Acceptance criteria:**
- [ ] All 10 Resource subclass scripts exist with field declarations.
- [ ] Every field has a type hint.
- [ ] Every field has an `@export` annotation.
- [ ] `res://data/battle_const.tres` exists and contains all values from GDD §11.1.
- [ ] Project compiles with no errors.
- [ ] In the editor, opening `battle_const.tres` shows all fields with their values in the inspector.

**Autonomy note:** If a GDD field name is ambiguous (camelCase vs snake_case, etc.), use snake_case as `CLAUDE.md` specifies. If a field's type isn't specified in the GDD, use the most natural type and flag it. Do NOT add fields not specified in the GDD.

---

## P0-T05 — Create `CombatEventBus` autoload with signal declarations

**Goal:** The central event bus exists with all signal declarations from GDD §10.3. No emitters yet, no listeners yet — just the contract.

**Read first:**
- `docs/gdd.md` §10.1 (principle 1), §10.3
- `docs/tactical_rpg_design_reference.md` §5 (per-action EXP), §9.1 (BattleCore architecture)
- `CLAUDE.md` "Signals are first-class" section

**File to create:** `res://scripts/autoload/combat_event_bus.gd`

**Required signals** (each with documented payload as a comment above the declaration):

```gdscript
## Fired when a unit's HP drops by any amount. damage > 0 always.
signal damage_dealt(attacker: CharacterUnit, defender: CharacterUnit, damage: int, source: Resource)

## Fired after damage_dealt when the defender's HP reaches 0.
signal unit_killed(attacker: CharacterUnit, defender: CharacterUnit, source: Resource)

## Fired when an ally heals another (or self-heals). amount is HP actually restored, not overheal.
signal healing_applied(healer: CharacterUnit, target: CharacterUnit, amount: int, source: Resource)

## Fired when a status effect is successfully applied (post resistance check).
signal status_applied(applier: CharacterUnit, target: CharacterUnit, status: StatusEffect)

## Fired when a status effect is removed (expired or cleared).
signal status_removed(target: CharacterUnit, status: StatusEffect)

## Fired when a weapon is used in an action. Used by ProficiencyService and durability tracking.
signal weapon_used(user: CharacterUnit, weapon: Weapon, slot: int)

## Fired when a weapon's durability hits 0 and breaks.
signal weapon_broke(user: CharacterUnit, weapon: Weapon, slot: int)

## Fired when two units form a Duo.
signal duo_formed(front: CharacterUnit, back: CharacterUnit, tile: Vector2i)

## Fired when a Duo separates back into two units.
signal duo_released(front: CharacterUnit, back: CharacterUnit, tile_front: Vector2i, tile_back: Vector2i)

## Fired when front/back roles are swapped within a Duo without dissolving it.
signal duo_switched(duo: DuoUnit)

## Fired before damage is finalized — gives BondActionService a chance to insert a bond action.
## Listeners may modify the resolved damage via the `mutable_damage_ref` array (single-element).
signal attack_resolving(attacker: CharacterUnit, defender: CharacterUnit, weapon: Weapon, mutable_damage_ref: Array)

## Fired when a Bond Action triggers. Kind is one of "attack" / "heal" / "guard".
signal bond_action_triggered(actor: CharacterUnit, beneficiary: CharacterUnit, kind: String)

## Fired at the start of each turn for the active unit.
signal turn_started(unit: CharacterUnit)

## Fired at the end of each turn for the active unit, after they've acted and set facing.
signal turn_ended(unit: CharacterUnit)

## Fired at the start of each phase. phase is one of "player" / "enemy" / "neutral".
signal phase_started(phase: String, round_number: int)

## Fired at the end of each phase.
signal phase_ended(phase: String, round_number: int)

## Fired when a battle begins.
signal battle_started(battle_map: BattleMap)

## Fired when a battle ends. result is one of "victory" / "defeat" / "abort".
signal battle_ended(result: String)

## Fired by RollbackService after a successful rewind.
signal rolled_back(snapshot_index: int)

## Fired when a unit's gameplay-facing changes. View layer listens to update facing arrow decal.
signal unit_facing_changed(unit: CharacterUnit, new_facing: Vector2i)
```

**Notes:**
- The class is otherwise empty — no methods.
- Forward-reference types like `CharacterUnit`, `DuoUnit`, `BattleMap` will not exist yet. Either declare them as `Node` for now (with a TODO to tighten) or use forward declarations / string type hints. Pick one approach and apply consistently — flag your choice.
- `mutable_damage_ref: Array` is a workaround for GDScript not having ref types — listeners modify `arr[0]` to influence damage. This is the simplest pattern; if you find a cleaner one in Godot 4 idioms, propose it.

**Acceptance criteria:**
- [ ] File exists at `res://scripts/autoload/combat_event_bus.gd`.
- [ ] All 19 signals listed above are declared.
- [ ] Each signal has a docstring comment above it.
- [ ] Each signal has typed parameters.
- [ ] Project compiles with no errors.

**Autonomy note:** If you think a signal is missing from the list above (e.g. you start implementing later phases and discover a gap), surface it before adding. The signal list is part of the architectural contract — additions need explicit approval.

---

## P0-T06 — Create `Command` base class and `CommandQueue` autoload

**Goal:** The Command pattern's structural skeleton. Base class exists with the lifecycle methods declared. Queue exists and can validate/execute Commands. No concrete Command subclasses yet.

**Read first:**
- `docs/gdd.md` §10.4 (commands list and lifecycle)
- `docs/tactical_rpg_design_reference.md` §9.2 (Aster's command pattern reference)

**Files to create:**

1. **`res://scripts/battle/commands/command.gd`** — base class.

```gdscript
class_name Command extends RefCounted
## Base class for all player and AI actions in battle.
## Lifecycle: validate() -> prepare() -> execute() -> complete(), with cancel() for rollback.
## See docs/gdd.md §10.4.

## Returns true if this command can legally execute given current board state.
## Override in subclasses. Must not mutate state.
func validate() -> bool:
    return false

## Gather any resolution data (e.g. compute pathfinding). Called after validate, before execute.
## Override in subclasses.
func prepare() -> void:
    pass

## Apply effects to game state. Called after prepare. Must emit appropriate CombatEventBus signals.
## Override in subclasses.
func execute() -> void:
    push_error("Command.execute() not overridden")

## Post-effect cleanup. Called after execute completes successfully.
## Override in subclasses.
func complete() -> void:
    pass

## Rollback this command's effects. Called by RollbackService.
## Override in subclasses.
func cancel() -> void:
    push_error("Command.cancel() not overridden")
```

2. **`res://scripts/autoload/command_queue.gd`** — the queue autoload.

```gdscript
extends Node
## Singleton queue that accepts, validates, and executes Commands submitted by UI or AI.
## See docs/gdd.md §10.4.

signal command_submitted(command: Command)
signal command_executed(command: Command)
signal command_failed(command: Command, reason: String)

func submit(command: Command) -> bool:
    command_submitted.emit(command)
    if not command.validate():
        command_failed.emit(command, "validation failed")
        return false
    command.prepare()
    command.execute()
    command.complete()
    command_executed.emit(command)
    return true
```

**Acceptance criteria:**
- [ ] `command.gd` exists with the lifecycle methods.
- [ ] `command_queue.gd` exists with `submit()` method.
- [ ] Both files have class-level docstrings.
- [ ] No concrete Command subclasses yet (those come in Phase 1).
- [ ] Project compiles with no errors.

**Autonomy note:** Proceed without asking. If `RefCounted` vs `Resource` for the Command base feels like the wrong choice in retrospect, surface it — but `RefCounted` is the right answer (Commands are throwaway, don't need editor instances, and shouldn't be saved).

---

## P0-T07 — Create remaining autoload service stubs

**Goal:** Empty service classes for every autoload listed in GDD §10.3. Each compiles, has a class-level docstring, and connects to no signals yet (those connections come in later phases).

**Read first:**
- `docs/gdd.md` §10.3 (full autoload table)

**Files to create** (under `res://scripts/autoload/`):

| File | Class name | Purpose (one line, used as docstring) |
|---|---|---|
| `experience_service.gd` | `ExperienceService` | Awards Style and Weapon EXP per combat action. Listens to CombatEventBus. |
| `bond_service.gd` | `BondService` | Tracks per-pair bond values. Listens to CombatEventBus. |
| `proficiency_service.gd` | `ProficiencyService` | Tracks per-(unit × weapon-category) proficiency. Listens to CombatEventBus. |
| `bond_action_service.gd` | `BondActionService` | Triggers Bond Actions on attack-resolving events. Listens to CombatEventBus. |
| `rollback_service.gd` | `RollbackService` | Snapshots Board state per action and per turn for rewind. |
| `battle_log_service.gd` | `BattleLogService` | Collects all battle events for replay/debug. Read-only sink. |
| `ai_controller.gd` | `AIController` | Selects actions for enemy units during enemy phase. |
| `master_data_service.gd` | `MasterDataService` | Loads and caches all .tres data resources at boot. |

**Each stub class must:**
- Extend `Node`.
- Have `class_name`.
- Have a class-level docstring matching the table.
- Have an empty `_ready()` method with a `# TODO(phase X): wire up signal handlers` comment indicating which later phase will populate it. (Phases per GDD §12.1: ExperienceService = Phase 5, BondService = Phase 5, ProficiencyService = Phase 4, BondActionService = Phase 7, RollbackService = Phase 3, BattleLogService = Phase 3, AIController = Phase 10, MasterDataService = Phase 0 — but only as stub for now, real loading in T08.)

**Acceptance criteria:**
- [ ] All 8 service stubs exist.
- [ ] Each has its class-level docstring.
- [ ] Each has a `# TODO(phase X)` marker.
- [ ] Project compiles with no errors.

**Autonomy note:** Proceed. These are stubs only — resist the urge to start implementing them. Phase 0 ends when the skeleton is in place; Phase 3 is when most of these come alive.

---

## P0-T08 — Register all autoloads in project settings

**Goal:** Every autoload from §10.3 is registered and accessible from anywhere as a singleton.

**Read first:**
- `docs/gdd.md` §10.3
- `AGENTS.md` "Common Pitfalls" — the project.godot rule

**Steps:**
1. Use the `set_project_setting` MCP tool (or the Godot editor's AutoLoad UI) to register each autoload created in T05–T07. **Do NOT edit `project.godot` directly** — the editor will overwrite it. Use the class name (PascalCase) as the autoload name (so accessing it is `CombatEventBus.damage_dealt.emit(...)`).

**Required registrations** (in this order):
- `MasterDataService` → `res://scripts/autoload/master_data_service.gd`
- `CombatEventBus` → `res://scripts/autoload/combat_event_bus.gd`
- `CommandQueue` → `res://scripts/autoload/command_queue.gd`
- `ExperienceService` → `res://scripts/autoload/experience_service.gd`
- `BondService` → `res://scripts/autoload/bond_service.gd`
- `ProficiencyService` → `res://scripts/autoload/proficiency_service.gd`
- `BondActionService` → `res://scripts/autoload/bond_action_service.gd`
- `RollbackService` → `res://scripts/autoload/rollback_service.gd`
- `BattleLogService` → `res://scripts/autoload/battle_log_service.gd`
- `AIController` → `res://scripts/autoload/ai_controller.gd`

The order matters: `MasterDataService` first so other services can pull data from it; `CombatEventBus` and `CommandQueue` next so services can connect to their signals during their `_ready()`.

**Acceptance criteria:**
- [ ] All 10 autoloads are registered with correct names and paths.
- [ ] Order in `project.godot` matches above (MasterDataService first, AIController last).
- [ ] Running the project shows no autoload errors in the console.
- [ ] In the Godot debugger or via a test script, `CombatEventBus`, `CommandQueue`, etc. are all accessible globally.

**Autonomy note:** Proceed.

---

## P0-T09 — Create the battle scene tree skeleton

**Goal:** A `battle.tscn` scene that loads, has the scene structure from GDD §10.2, and can be run from the Godot editor without errors.

**Read first:**
- `docs/gdd.md` §10.2
- `AGENTS.md` "Workflow Patterns" — Building a scene from scratch

**Steps:**

1. Use `create_scene` to create `res://scenes/battle/battle.tscn`. Then use `batch_add_nodes` to add the structure from §10.2:

```
BattleScene (Node)
├── Board (Node3D)
│   ├── GridOverlay (Node3D)  # empty for now
│   └── UnitsLayer (Node3D)   # empty for now
├── BattleCamera (Node3D)
│   ├── Pivot (Node3D)
│   │   └── Camera3D (positioned at -10 along local Z)
├── BattleManager (Node)
└── BattleUI (CanvasLayer)
```

(The `GroundScene` instance under Board is omitted for now — no map yet.)

2. Create `res://scenes/battle/battle.gd` attached to the root, with a stub `_ready()`:

```gdscript
class_name BattleScene extends Node
## Root node of an in-battle scene. Owns the Board, Camera, Manager, and UI.
## See docs/gdd.md §10.2.

func _ready() -> void:
    print("BattleScene ready")
```

3. Create `res://scenes/battle/battle_manager.gd` attached to BattleManager:

```gdscript
class_name BattleManager extends Node
## Drives the battle's phase state machine and ticks subsystems.
## See docs/gdd.md §4.2.

func _ready() -> void:
    print("BattleManager ready (no battle logic yet — Phase 0 stub)")
```

4. Set `battle.tscn` as the project's main scene (Project Settings → Run → Main Scene).

**Acceptance criteria:**
- [ ] `battle.tscn` exists and matches the §10.2 structure.
- [ ] Running the project loads `battle.tscn` and prints both `_ready` messages.
- [ ] No errors in the console.
- [ ] Camera3D has a clear background (the slate from T02).

**Autonomy note:** Proceed. Don't add gameplay yet — this is a skeleton.

---

## P0-T10 — Add a debug HUD with FPS counter

**Goal:** A simple HUD overlay shows FPS in the corner. Used in T12 to verify the 60 FPS performance budget. Will be expanded into the real HUD in Phase 1+.

**Read first:**
- `docs/gdd.md` §6.4 (UI overview, for context only)

**Steps:**
1. Create `res://scenes/battle/ui/debug_hud.tscn` with a `Label` showing FPS, anchored to top-left.
2. Create `res://scenes/battle/ui/debug_hud.gd` updating the label every `_process`.
3. Add `debug_hud.tscn` as a child of `BattleUI` in `battle.tscn`.

**Acceptance criteria:**
- [ ] FPS counter visible in top-left when running the project.
- [ ] FPS reads ~60 on the dev machine (M1 MacBook Pro).
- [ ] No console errors.

**Autonomy note:** Proceed. Don't fancy-up the HUD — `Engine.get_frames_per_second()` in a label is enough.

---

## P0-T11 — Set up GUT (testing framework) and write a sanity test

**Goal:** GUT installed, configured, and one passing test exists. This proves the test infrastructure works and creates a template for future tests.

**Read first:**
- `docs/gdd.md` §10.9 (testing strategy)

**Steps:**
1. Add GUT as a Godot addon (via the Asset Library inside Godot, or by cloning the GUT repo to `res://addons/gut/`).
2. Enable the GUT addon in Project Settings → Plugins.
3. Create `res://tests/` folder structure if not already present from T03.
4. Write a sanity test: `res://tests/test_battle_const.gd`. The test loads `res://data/battle_const.tres` and asserts that `min_damage == 1` and `rollback_free_count == 3`. This both verifies GUT works and that the resource from T04 loaded correctly.
5. Run the test via the GUT panel; verify it passes.

**Acceptance criteria:**
- [ ] GUT addon installed and enabled.
- [ ] At least one test exists at `res://tests/test_battle_const.gd`.
- [ ] Test passes when run.
- [ ] GUT panel is accessible in the Godot editor.

**Autonomy note:** Proceed. If GUT installation has friction (Asset Library version mismatch, etc.), surface it — don't substitute a different testing framework without asking.

---

## P0-T12 — Phase 0 verification

**Goal:** Confirm Phase 0 is genuinely complete by running through a verification checklist.

**Read first:**
- `AGENTS.md` "Runtime Tools" — you'll use `play_scene`, `get_game_screenshot`, `stop_scene` here

**Steps:**

Walk through each item below. For each, verify it works and check it off. **Use MCP tools to self-verify wherever possible** — `play_scene` to run the project, `get_game_screenshot` to capture the empty battle scene with FPS counter, `get_editor_errors` to check for warnings. Don't ask the user to verify things you can verify yourself.

**Verification checklist:**

- [ ] All folders from GDD §10.7 that are under `res://` exist.
- [ ] All 10 Resource subclass scripts (T04) compile.
- [ ] `res://data/battle_const.tres` loads in inspector and shows correct values.
- [ ] All 10 autoloads (T05–T07) are registered and load without errors.
- [ ] `CombatEventBus` has all 19 signals declared.
- [ ] `Command` base class compiles; `CommandQueue.submit()` exists.
- [ ] Running the project shows the empty battle scene with FPS counter at ~60.
- [ ] GUT panel works; sanity test passes.
- [ ] `README.md` exists at the project root.
- [ ] `docs/PROGRESS.md` updated with Phase 0 marked complete and ready for user review.

**Acceptance criteria:**
- [ ] All checklist items pass.
- [ ] User has been notified that Phase 0 is ready for review.

**Important:** Do NOT make any git commits. The user will review the changes in Sourcetree, run the project locally, and commit at their discretion.

**Autonomy note:** Stop and report after T12 regardless. Phase 1 is a separate task file.

---

## Phase 0 NOT-doing list

These would be scope creep. Don't do them in Phase 0 even if you "could easily."

- ❌ Implement any concrete `Command` subclasses (`MoveCommand`, etc.). Phase 1.
- ❌ Implement actual signal emitters or listeners in autoloads. Phases 1–7 each wire up specific listeners.
- ❌ Create any unit / character scenes. Phase 1.
- ❌ Add a tile system or grid logic. Phase 1.
- ❌ Implement the damage formula. Phase 1.
- ❌ Add multiple camera presets. Phase 9.
- ❌ Author battle maps. Phase 14+.
- ❌ Create art assets, sprites, or 3D models. Asset production is a parallel track, not in Phase 0.
- ❌ Set up CI/CD. Post-vertical-slice (per GDD §10.9).
- ❌ Optimize anything. Premature optimization is its own anti-pattern; the architecture *is* the optimization.

If you find yourself writing code that does any of the above, stop. The right move is to leave a `# TODO(phase X)` and move on.

---

## What "Phase 0 done" looks like

When you've completed P0-T01 through P0-T12, you should have:

- A Godot 4 project that opens, runs, shows an empty 3D scene with an FPS counter.
- All folders, autoloads, and Resource classes in place — but doing nothing.
- Tests infrastructure ready and one passing test.
- A `docs/PROGRESS.md` showing Phase 0 complete and Phase 1 ready to start.
- A clean commit history.

This is the right kind of unimpressive — you'll have spent 2–3 days and the game does nothing visible. But every Phase 1 task starts from a position where the architecture is already in place, and that pays off compoundingly across the rest of the project.

---

*End of phase_0_tasks.md.*
