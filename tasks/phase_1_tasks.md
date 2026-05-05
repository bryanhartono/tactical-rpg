# Phase 1 — Bare Grid Combat

> **Phase goal:** Two units on a flat grid; one moves, one attacks, HP goes down. Architecture-first: every system put in this phase is wired through the structures already defined in Phase 0 (CombatEventBus, Command, CommandQueue, Resources). No art, no polish, no edge cases — but no shortcuts that bypass the architecture either.
>
> **Estimated duration:** 1–2 weeks of focused work.
>
> **Definition of phase done:** Run the project. See a flat grid (Godot primitives only). See two units (capsules). Click one of yours, see its move range highlighted. Click a tile, the unit moves. Click an enemy in range, see a damage preview, confirm, the enemy's HP drops. When all enemy units die, "Victory" prints. When all player units die, "Defeat" prints. Phase loop transitions player → enemy → player. CombatEventBus signals fire correctly when verified by `BattleLogService`.

---

## How to read this file

- Tasks are ordered. Most have dependencies on earlier tasks; do them in order unless you have a specific reason not to.
- Each task lists **acceptance criteria** that must all be true for the task to be "done." See `CLAUDE.md` for what "done" means.
- Each task lists the **GDD / reference sections** to read before starting. Read those, not the entire GDD.
- Each task has an **autonomy note** clarifying what to do without asking vs what to surface.
- The **Phase 1 NOT-doing list** at the bottom of this file is as important as the task list. Read it before starting any task.

---

## Phase 1 design constraints (read before starting any task)

These boundaries keep Phase 1 from sprawling:

- **No art assets.** Units are `CSGCylinder3D` or `MeshInstance3D` with `CapsuleMesh`. Tiles are `MeshInstance3D` with `PlaneMesh` (or a single shared mesh). Color via `StandardMaterial3D.albedo_color`. Sprites land in Phase 2.
- **Flat terrain only.** All tiles at elevation 0. Single landform type ("plain"). No corner heights yet. Elevation lands in Phase 8.
- **One Style, one weapon category, one weapon.** Swordsman + Iron Sword (range 1, melee). No Sub weapon, no skills, no proficiency. Sub weapon lands in Phase 4, proficiency in Phase 4.
- **No facing in damage math.** All attacks compute as if from the front. The `unit_facing` field exists on the unit (used later); it's just not consulted by the damage formula yet.
- **No Bond, no Duo, no rewind, no AI archetypes.** Enemy AI is a single hardcoded "find nearest player, attack if in range, else move toward" routine. AIBehavior resources land in Phase 10.
- **No critical hits, no hit/miss roll.** All attacks hit, no crits. Hit/crit math lands in Phase 5 alongside the EXP layer.
- **No status effects.** StatusEffect resources exist (Phase 0) but nothing applies them. Phase 12.
- **The damage formula is hardcoded inline in this phase**, with a `# TODO(phase 3): extract to AttackSimulator` marker. Phase 3 extracts simulators. Inlining now is a deliberate violation of the "one place for damage math" rule that gets paid back in Phase 3 — flagged here so it's intentional, not accidental.
- **CommandQueue executes commands synchronously.** No async, no animations awaiting completion. Phase 2 introduces view animations and the command-execution-awaits-view-animation pattern.

If a task in this file appears to require something on the NOT list, you're either misreading the task or there's a gap — surface it.

---

## Prerequisites

- [ ] Phase 0 is complete and committed by the user. `docs/PROGRESS.md` shows Phase 0 ✅.
- [ ] User has confirmed they're ready to start Phase 1.

---

## Task index

| ID | Task | Depends on |
|---|---|---|
| P1-T01 | `Board` resource and `Tile` resource | (Phase 0) |
| P1-T02 | `TargetRef` helper class | T01 |
| P1-T03 | `CharacterUnit` node — gameplay-side | T01 |
| P1-T04 | `BoardView3D` node — visual-side, owns the tile meshes | T01, T03 |
| P1-T05 | `UnitView3D` node — visual-side, billboard placeholder | T03 |
| P1-T06 | Pathfinder service — BFS over `Board` for movement range | T01, T03 |
| P1-T07 | Range-shape resolver — turns `RangeShape` resources into world tiles | T01 |
| P1-T08 | One Swordsman style + one Iron Sword + one swordsman character | T01 |
| P1-T09 | One range-shape resource (range-1 melee) | T07 |
| P1-T10 | `MoveCommand` — first concrete `Command` subclass | T01, T03, T06 |
| P1-T11 | `AttackCommand` — second concrete `Command` subclass | T01, T03, T07 |
| P1-T12 | `EndTurnCommand` and `WaitCommand` | T01, T03 |
| P1-T13 | `BattleManager` phase-loop FSM | T03, T10–T12 |
| P1-T14 | Tile-input layer — mouse picks tiles and units | T04 |
| P1-T15 | Action menu UI — choose Move/Attack/Wait | T13, T14 |
| P1-T16 | Range-highlight overlay on `GridOverlay` | T04, T06, T07 |
| P1-T17 | Damage-preview popup | T11, T15 |
| P1-T18 | Hardcoded enemy AI — pick action, submit command | T13, T10–T11 |
| P1-T19 | Victory / defeat conditions and end-of-battle screen | T13 |
| P1-T20 | `BattleLogService` wires up to verify signals are firing | T13, T18 |
| P1-T21 | GUT integration tests for the slice | T10–T19 |
| P1-T22 | Phase 1 verification | All |

---

## P1-T01 — `Board` resource and `Tile` resource

**Goal:** A pure-data representation of the grid. The `Board` is the source of truth for "where are the tiles, what's on each, and how big is the playfield." It has no scene-tree presence and no rendering — `BoardView3D` (T04) renders it.

**Read first:**
- `docs/gdd.md` §5.1, §5.3, §10.1 (principle 3 — Resources for data), §10.2
- `docs/tactical_rpg_design_reference.md` §3 (Tile grid model), §9.4 (TargetPair pattern)

**Files to create:**

1. **`res://scripts/battle/board/tile.gd`** — `class_name Tile extends Resource`. Fields:
    - `position: Vector2i` — grid coordinates.
    - `landform_id: int` — references a LandformDefinition (Phase 1: always 0 = plain).
    - `corner_heights: Vector4` — defaults to `Vector4.ZERO`. Phase 8 will use these.
    - `occupant_id: int = -1` — id of the CharacterUnit currently on this tile, -1 if empty. Storing an id (not a node ref) is deliberate: it survives `Resource.duplicate(true)` snapshots in Phase 3 cleanly.
    - `effects: Array[StatusEffect]` — empty for Phase 1.

2. **`res://scripts/battle/board/board.gd`** — `class_name Board extends Resource`. Fields:
    - `width: int`, `height: int`.
    - `tiles: Array` — flat row-major `Array[Tile]` of length `width * height`. (Use `Array` not `Array[Tile]` if Godot 4 typed-array Resource serialization is finicky — flag if so.)
    - `units: Dictionary` — keyed by `int` (unit id), values are `CharacterUnit` Node references. **Note:** `units` is *not* `@export`. It's runtime-only state populated when units register themselves with the board. Snapshots in Phase 3 will need to handle the unit dict separately from the resource.

    Methods (all pure / read-only — no mutation methods yet, those go on a `BoardController` in T13):
    - `get_tile(pos: Vector2i) -> Tile` — returns the Tile at that position, or null if out of bounds.
    - `is_in_bounds(pos: Vector2i) -> bool`.
    - `get_unit_at(pos: Vector2i) -> Node` — returns the CharacterUnit on that tile, or null.
    - `get_neighbors(pos: Vector2i) -> Array[Vector2i]` — 4 cardinal neighbors that are in-bounds.

    Construction helper (static):
    - `static func create_flat(width: int, height: int) -> Board` — produces a fresh Board with all tiles at landform 0 and no occupants. Used by T13 for the test map.

**Acceptance criteria:**
- [ ] `tile.gd` and `board.gd` exist with the fields and methods above.
- [ ] All fields type-hinted, all methods type-hinted.
- [ ] `Board.create_flat(10, 10)` returns a usable Board with 100 Tile resources.
- [ ] Class-level docstrings on both.
- [ ] Project compiles, no errors.

**Autonomy note:** Proceed. If `Array[Tile]` causes serialization grief inside a `Resource`, fall back to `Array` and add a brief comment explaining why. The unit-dict-not-exported decision is deliberate — keep it.

---

## P1-T02 — `TargetRef` helper class

**Goal:** The lightweight `(unit, grid_position)` tuple used everywhere targeting and prediction happens.

**Read first:**
- `docs/tactical_rpg_design_reference.md` §9.4

**File:** `res://scripts/battle/board/target_ref.gd`

```gdscript
class_name TargetRef extends RefCounted
## Lightweight (unit, grid_position) tuple. See docs/tactical_rpg_design_reference.md §9.4.
## RefCounted so it's cheap to allocate and free. Not a Resource — these are not saved.

var unit: Node            # CharacterUnit or null (tile-only target)
var grid: Vector2i

func _init(p_unit: Node = null, p_grid: Vector2i = Vector2i.ZERO) -> void:
    unit = p_unit
    grid = p_grid
```

**Acceptance criteria:**
- [ ] File exists with `class_name TargetRef`.
- [ ] Both fields, constructor with defaults.
- [ ] Class-level docstring.

**Autonomy note:** Proceed.

---

## P1-T03 — `CharacterUnit` node — gameplay-side

**Goal:** A Node representing a unit's gameplay state. No rendering. The view is a separate node (T05) that subscribes to this node's signals.

**Read first:**
- `docs/gdd.md` §7.7, §10.1 (principle 4 — view/gameplay split), §5.5 (damage formula context)
- `docs/tactical_rpg_design_reference.md` §4 (component composition), §9.9 (`IUnitView` is purely visual)

**File:** `res://scripts/battle/units/character_unit.gd`

**Class shape (this is the Phase 1 minimum — components come incrementally):**

```gdscript
class_name CharacterUnit extends Node
## Gameplay-side unit. Tracks stats, position, facing, equipment.
## The visual representation is UnitView3D (separate node) listening to this node's signals.
## See docs/gdd.md §7.7, §10.1 (principle 4).

# --- Identity ---
@export var unit_id: int = -1              # assigned at spawn time, used as Tile.occupant_id
@export var display_name: String = ""
@export var team: int = 0                  # 0 = player, 1 = enemy. More teams later.
@export var character_definition: CharacterDefinition

# --- Position and facing ---
var grid_position: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.RIGHT      # gameplay-facing; not consulted by damage in Phase 1

# --- Stats (current). Layered: style base + character base + level growth. Phase 5 wires growth. ---
var max_hp: int = 0
var current_hp: int = 0
var atk: int = 0
var def: int = 0
var move_budget: int = 0                   # how many tile-units they can move this turn

# --- Equipment ---
var main_weapon: Weapon

# --- Turn state ---
var has_acted: bool = false                # true after they Move+Action+Face this turn

# --- Signals (local; CombatEventBus is for cross-cutting) ---
signal hp_changed(old_hp: int, new_hp: int)
signal moved(from_tile: Vector2i, to_tile: Vector2i)
signal facing_changed(new_facing: Vector2i)
signal died

# --- API ---
func is_alive() -> bool: ...
func is_player() -> bool: ...
func is_enemy() -> bool: ...
func take_damage(amount: int, source: Resource = null) -> void:
    # clamps; emits hp_changed; if alive→dead, emits died and CombatEventBus.unit_killed
    ...
func reset_for_new_turn() -> void:
    has_acted = false

func initialize_from_definition(def: CharacterDefinition) -> void:
    # Pulls base stats from def.default_style + character bases
    # Sets max_hp/current_hp/atk/def/move_budget/main_weapon
    ...
```

**Notes:**
- `CharacterUnit` is a Node, not Node3D. It has no transform. The 3D position lives on `UnitView3D`.
- Local signals (`hp_changed`, `moved`, etc.) are for the view to react to immediately. The CombatEventBus equivalents (`damage_dealt`, `unit_killed`) are for cross-cutting services (BattleLog, future Bond/EXP). Both fire — local first, then bus. Don't conflate them.
- `take_damage` is the *only* HP-mutating method. Internal stats can be poked from tests, but combat resolution always goes through `take_damage`.
- Stat layering (style base + character base) lives in `initialize_from_definition`. Don't try to do level-up math here yet — Phase 5 owns that.

**Acceptance criteria:**
- [ ] File exists with all listed fields, signals, methods.
- [ ] `take_damage` clamps HP at 0, emits `hp_changed`, emits `died` and `CombatEventBus.unit_killed` on lethal.
- [ ] `initialize_from_definition` sets all stat fields from the definition + style + main weapon.
- [ ] Project compiles.
- [ ] A trivial test (T21) can construct a CharacterUnit, deal 5 damage, see HP drop by 5.

**Autonomy note:** If you find yourself wanting a `StatsComponent` child node for cleanliness, hold off. Phase 1 keeps it inline; the component split happens in Phase 3 alongside the simulator extraction. Inlining now is a deliberate trade for shipping the slice — flagged in the `# TODO(phase 3)` comment.

---

## P1-T04 — `BoardView3D` node — visual-side, owns the tile meshes

**Goal:** A Node3D under `BattleScene/Board` that renders a Board resource as a grid of mesh tiles. Pure view layer — reads Board, never writes.

**Read first:**
- `docs/gdd.md` §10.1 (principle 4), §10.2

**File:** `res://scripts/battle/view/board_view_3d.gd`

**Behavior:**
- `set_board(board: Board) -> void` — clears children, instantiates one mesh per tile at `(x, 0, z)` world position (1 unit per tile). Uses a single shared `StandardMaterial3D` for unowned tiles.
- Method to highlight specific tiles: `highlight_tiles(tiles: Array[Vector2i], color: Color) -> void` — applies a tinted material to the matching tile meshes. Used by T16 for range overlays.
- Method to clear highlights: `clear_highlights() -> void`.
- Stores tile meshes in a Dictionary keyed by `Vector2i` for O(1) lookup.

**Visual appearance for Phase 1:**
- Tile mesh: `PlaneMesh` 1×1 unit, oriented +Y up.
- Color: muted grey (e.g. `#3a3a4a`) for default; differentiated tints for highlights (green for move, blue for move+attack, red for attack).
- A tiny gap between tiles (0.95 instead of 1.0 size, or a slight emission outline) so the grid is visually readable.

**Acceptance criteria:**
- [ ] File exists. Attached to `Board/GridOverlay` in `battle.tscn` (replace the placeholder Node3D).
- [ ] Calling `set_board(Board.create_flat(10, 10))` produces 100 visible tile meshes.
- [ ] `highlight_tiles([(0,0), (1,0)], Color.GREEN)` tints exactly those two tiles green.
- [ ] `clear_highlights()` reverts all to default.

**Autonomy note:** Don't go fancy on materials. The point is a readable grid, not pretty. If GDD §6.4's "yellow = AoE preview" tint isn't needed in Phase 1 (no AoE attacks yet), skip it.

---

## P1-T05 — `UnitView3D` node — visual-side, billboard placeholder

**Goal:** A Node3D that visually represents a CharacterUnit's position, color, and HP, by listening to that unit's local signals. No sprite yet — just a colored capsule.

**Read first:**
- `docs/gdd.md` §6.1 (just enough to know what Phase 2 will replace), §10.1 (principle 4)

**File:** `res://scripts/battle/view/unit_view_3d.gd`

**Class shape:**

```gdscript
class_name UnitView3D extends Node3D
## Visual representation of a CharacterUnit. Listens to that unit's local signals.
## Phase 1: capsule placeholder. Phase 2: pixel sprite billboard.
## See docs/gdd.md §6.1 for the Phase 2 target.

@export var unit: CharacterUnit  # set by spawner

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _hp_label: Label3D = $HPLabel  # debug-only HP readout

func _ready() -> void:
    if unit == null:
        push_error("UnitView3D has no unit assigned")
        return
    unit.moved.connect(_on_moved)
    unit.hp_changed.connect(_on_hp_changed)
    unit.died.connect(_on_died)
    _refresh_visual()

func _refresh_visual() -> void:
    # Color by team: blue for player, red for enemy
    # Update HP label
    ...

func _on_moved(from: Vector2i, to: Vector2i) -> void:
    # Phase 1: instant teleport. Phase 2: tween over the path.
    position = Vector3(to.x, 0.5, to.y)

func _on_hp_changed(old_hp: int, new_hp: int) -> void: ...
func _on_died() -> void:
    queue_free()  # crude; Phase 2 will play a death animation first
```

**Scene:** `res://scenes/battle/units/unit_view_3d.tscn`. Root is the `UnitView3D` script. Children:
- `Mesh: MeshInstance3D` with `CapsuleMesh` (height 1.5, radius 0.3).
- `HPLabel: Label3D` positioned above the capsule, billboard-Y enabled, pixel-size set so it reads.

**Acceptance criteria:**
- [ ] Scene + script exist.
- [ ] Connecting to a CharacterUnit and calling `unit.take_damage(5)` updates the HP label.
- [ ] Calling `unit.moved.emit(...)` repositions the capsule.
- [ ] `unit.died.emit()` removes the view from the scene.
- [ ] Player units render blue; enemy units render red.

**Autonomy note:** Capsule + Label3D is correct. Do NOT introduce Sprite3D, AnimatedSprite3D, or SpriteFrames in Phase 1 — those are Phase 2's whole point.

---

## P1-T06 — Pathfinder service — BFS over `Board` for movement range

**Goal:** A pure static class that computes "all tiles reachable by a unit with their move budget, returning per-tile distance." No A* yet — Phase 1 doesn't need destination-pathfinding, just range-discovery; A* lands when terrain costs vary in Phase 8.

**Read first:**
- `docs/gdd.md` §5.3
- `docs/tactical_rpg_design_reference.md` §3 (Movement)

**File:** `res://scripts/battle/pathfinding/pathfinder.gd`

```gdscript
class_name Pathfinder
## Pure functions for computing movement range over a Board.
## Phase 1: BFS, all tiles cost 1, no terrain or elevation. Phase 8 generalizes.

## Returns a Dictionary[Vector2i -> int] of reachable tiles and their move-cost from origin.
## Excludes tiles occupied by other units (allies block; enemies block too in Phase 1).
static func compute_reachable(board: Board, origin: Vector2i, move_budget: int) -> Dictionary: ...

## Returns the path from origin to dest as Array[Vector2i], or empty array if unreachable.
## dest must be inside compute_reachable's result for the same args.
static func path_to(board: Board, origin: Vector2i, dest: Vector2i, move_budget: int) -> Array: ...
```

**Implementation notes:**
- BFS, queue-based, distance map.
- Skip tiles where `get_unit_at(pos) != null` (unless that unit is `origin`'s occupant).
- All move costs are 1 in Phase 1.
- Return Dictionary keyed by Vector2i — Godot 4 supports Vector2i as a Dictionary key.

**Acceptance criteria:**
- [ ] File exists with both methods.
- [ ] On a 10×10 empty board, `compute_reachable(board, (0,0), 3)` returns 25 tiles (the diamond around origin).
- [ ] Placing an enemy on `(2,0)` removes `(2,0)`, `(3,0)`, etc. from the result correctly.
- [ ] Test in T21 covers both methods.

**Autonomy note:** Proceed. The "allies block" rule is correct for Phase 1; Aster has more nuanced "pass through ally, can't end on" rules but those are Phase 8.

---

## P1-T07 — Range-shape resolver

**Goal:** A pure static helper that turns a `RangeShape` resource (the row-major bitmask from §7.4) plus an attacker's tile and facing into a list of world tiles.

**Read first:**
- `docs/gdd.md` §7.4

**File:** `res://scripts/battle/pathfinding/range_shape_resolver.gd`

```gdscript
class_name RangeShapeResolver

## Returns the list of world tiles covered by this range shape when fired from `origin`
## facing `facing`. Phase 1: facing is ignored (range-1 sword is symmetric); Phase 4
## adds directional shapes (lance line forward).
static func resolve(shape: RangeShape, origin: Vector2i, facing: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
    var origin_idx := shape.cells.find(101)
    assert(origin_idx >= 0, "RangeShape has no origin marker (101)")
    var num_cols := shape.num_cols
    var local_origin := Vector2i(origin_idx % num_cols, origin_idx / num_cols)
    var result: Array[Vector2i] = []
    for i in shape.cells.size():
        if shape.cells[i] == 1:
            var local := Vector2i(i % num_cols, i / num_cols)
            var offset := local - local_origin
            result.append(origin + offset)
    return result
```

**Acceptance criteria:**
- [ ] File exists.
- [ ] On a 3×3 plus-shape (origin center, 4 cardinal cells), resolves to 4 tiles around origin correctly.
- [ ] Test in T21 covers the plus-shape and the range-1 melee shape from T09.

**Autonomy note:** Proceed. Facing parameter exists for API compatibility but is unused in Phase 1 — that's deliberate, document it.

---

## P1-T08 — One Swordsman style + one Iron Sword + one swordsman character

**Goal:** Concrete data instances of the Phase 0 Resource subclasses, just enough to populate two units (one player Swordsman, one enemy "bandit" using the same Style).

**Read first:**
- `docs/gdd.md` §7.1, §7.2, §11.2

**Files to create:**

1. **`res://data/classes/swordsman.tres`** — `StyleDefinition`. Values:
    - `id: 1`, `display_name: "Swordsman"`, `move_type: INFANTRY`.
    - Base stats: `base_hp: 25, base_atk: 8, base_def: 5, base_skill: 5, base_speed: 6, base_luck: 3`.
    - Growth rates: `growth_hp: 60, growth_atk: 50, growth_def: 30, growth_skill: 40, growth_speed: 35, growth_luck: 25` (irrelevant in Phase 1, populate for future).
    - `allowed_weapon_categories: { Weapon.Category.SWORD: 0 }`.
    - `innate_skills: []`.

2. **`res://data/weapons/iron_sword.tres`** — `Weapon`. Values:
    - `id: 1001`, `name: "Iron Sword"`, `category: SWORD`, `rarity: 1`, `attack_type: SLASH`, `element: NONE`, `range_shape_id: 1`.
    - `initial_power: 5, initial_hit: 90, initial_crit: 0, initial_avoid: 0, initial_weight: 3`.
    - `limit_*` values same as `initial_*` for Phase 1 (no limit-break yet).
    - `max_durability: 30`, `limit_break_max: 0`, `granted_skill: null`.

3. **`res://data/characters/aria.tres`** — `CharacterDefinition`. Player unit.
    - `id: 1`, `display_name: "Aria"`, `default_style: <swordsman.tres>`.
    - `base_hp/atk/def/skill/speed/luck: 0` (no per-character bonus on top of style).
    - `growth_*: 0`.
    - `default_main_weapon: <iron_sword.tres>`, `default_sub_weapon: null`.
    - `bond_action_kind: ATTACK`.

4. **`res://data/characters/bandit.tres`** — `CharacterDefinition`. Enemy unit.
    - `id: 100`, `display_name: "Bandit"`, `default_style: <swordsman.tres>`, defaults same as Aria.
    - `default_main_weapon: <iron_sword.tres>`.
    - `bond_action_kind: ATTACK`.

**Acceptance criteria:**
- [ ] All four `.tres` files exist and load in the inspector with all values shown.
- [ ] No errors on project load.
- [ ] T21 test loads `aria.tres` and asserts the Style and Weapon refs are non-null.

**Autonomy note:** Proceed. The growth-rate values are placeholders that won't be exercised until Phase 5 — pick reasonable starting numbers and don't agonize.

---

## P1-T09 — One range-shape resource (range-1 melee)

**Goal:** A concrete `RangeShape.tres` for the Iron Sword's range-1 melee pattern.

**Read first:**
- `docs/gdd.md` §7.4

**File:** `res://data/range_shapes/melee_1.tres`. Values:
- `id: 1`, `name: "Melee Range 1"`.
- `num_cols: 3`.
- `cells: [-1, 1, -1, 1, 101, 1, -1, 1, -1]`. (3×3 plus shape, origin at center.)

This shape covers the 4 cardinal-adjacent tiles. Iron Sword's `range_shape_id: 1` resolves to this (T07 lookup is by id; for Phase 1 hardcode the lookup as a static table inside the resolver — or use `MasterDataService` if you've already implemented data scanning, otherwise leave a TODO).

**Acceptance criteria:**
- [ ] File exists, loads in inspector.
- [ ] T21 test asserts `RangeShapeResolver.resolve(melee_1, (5,5))` returns the 4 cardinal neighbors.
- [ ] Either a hardcoded id-to-RangeShape table exists in `RangeShapeResolver` or `MasterDataService`, with a clear `# TODO` if Phase 1's lookup is provisional.

**Autonomy note:** If `MasterDataService` is still a stub, the simplest provisional approach is a hardcoded `static func get_shape_by_id(id: int) -> RangeShape` inside the resolver that loads by path. Flag this as a `# TODO(phase 1+)` to migrate when MasterDataService scans `res://data/range_shapes/`.

---

## P1-T10 — `MoveCommand` — first concrete `Command` subclass

**Goal:** Move a unit from its current tile to a destination tile. First concrete Command — pattern for everything that follows.

**Read first:**
- `docs/gdd.md` §10.4
- Phase 0's `command.gd` base class
- `docs/tactical_rpg_design_reference.md` §9.2

**File:** `res://scripts/battle/commands/move_command.gd`

```gdscript
class_name MoveCommand extends Command
## Move a unit to a destination tile within their move budget.
## See docs/gdd.md §10.4.

var board: Board                # injected by submitter
var unit: CharacterUnit
var destination: Vector2i

# Computed in prepare():
var _path: Array = []           # Array[Vector2i]
var _origin: Vector2i

func _init(p_board: Board, p_unit: CharacterUnit, p_destination: Vector2i) -> void:
    board = p_board
    unit = p_unit
    destination = p_destination

func validate() -> bool:
    if unit == null or board == null: return false
    if unit.has_acted: return false
    if not board.is_in_bounds(destination): return false
    var reachable := Pathfinder.compute_reachable(board, unit.grid_position, unit.move_budget)
    return reachable.has(destination)

func prepare() -> void:
    _origin = unit.grid_position
    _path = Pathfinder.path_to(board, _origin, destination, unit.move_budget)

func execute() -> void:
    # Phase 1: instant. Phase 2: BoardController will tween view via signals before mutating board.
    var origin_tile := board.get_tile(_origin)
    var dest_tile := board.get_tile(destination)
    origin_tile.occupant_id = -1
    dest_tile.occupant_id = unit.unit_id
    unit.grid_position = destination
    unit.facing = _path[-1] - _path[max(_path.size() - 2, 0)] if _path.size() >= 2 else unit.facing
    unit.moved.emit(_origin, destination)

func complete() -> void:
    # No bus signal for moved in Phase 1 — local signal is sufficient.
    # If services need it later, add to CombatEventBus and emit here.
    pass

func cancel() -> void:
    # Reverse the mutation. Phase 3's RollbackService uses this.
    var origin_tile := board.get_tile(_origin)
    var dest_tile := board.get_tile(destination)
    dest_tile.occupant_id = -1
    origin_tile.occupant_id = unit.unit_id
    unit.grid_position = _origin
    unit.moved.emit(destination, _origin)
```

**Acceptance criteria:**
- [ ] File exists, all lifecycle methods overridden.
- [ ] `validate()` returns false when unit has acted, when destination out of bounds, when destination unreachable.
- [ ] `execute()` updates Tile occupants, unit's `grid_position`, and emits `moved`.
- [ ] `cancel()` reverses everything from `execute()`.
- [ ] T21 test covers happy path and `cancel()` reversal.

**Autonomy note:** The facing-from-last-step heuristic is a stand-in for Phase 1 ("you face the direction you walked"). The real "player chooses facing after acting" UX from GDD §4.3 lands in T13 / T15. Don't try to bolt it onto MoveCommand.

---

## P1-T11 — `AttackCommand` — second concrete `Command` subclass

**Goal:** A unit attacks a target unit with their main weapon. Damage formula is hardcoded *in this command's execute*, with a TODO marker pointing to Phase 3's simulator extraction.

**Read first:**
- `docs/gdd.md` §5.5 (damage formula), §10.4
- `docs/tactical_rpg_design_reference.md` §9.6 (Simulator pattern — for context on what Phase 3 will do)

**File:** `res://scripts/battle/commands/attack_command.gd`

```gdscript
class_name AttackCommand extends Command
## Single attack with the unit's main weapon against a target unit.
## See docs/gdd.md §5.5, §10.4.
##
## Phase 1: damage formula is inlined here (intentional shortcut). Phase 3 extracts to AttackSimulator.

var board: Board
var attacker: CharacterUnit
var target: CharacterUnit

# Computed in prepare:
var _damage: int = 0
var _was_lethal: bool = false

func _init(p_board: Board, p_attacker: CharacterUnit, p_target: CharacterUnit) -> void:
    board = p_board
    attacker = p_attacker
    target = p_target

func validate() -> bool:
    if attacker == null or target == null or board == null: return false
    if attacker.has_acted: return false
    if not target.is_alive(): return false
    if attacker.team == target.team: return false
    if attacker.main_weapon == null: return false
    var shape := _resolve_shape(attacker.main_weapon.range_shape_id)
    if shape == null: return false
    var in_range := RangeShapeResolver.resolve(shape, attacker.grid_position, attacker.facing)
    return in_range.has(target.grid_position)

func prepare() -> void:
    _damage = _compute_damage(attacker, target, attacker.main_weapon)
    _was_lethal = (_damage >= target.current_hp)

func execute() -> void:
    # Emit attack_resolving for future BondActionService hook (Phase 7 will use it).
    var damage_ref: Array = [_damage]
    CombatEventBus.attack_resolving.emit(attacker, target, attacker.main_weapon, damage_ref)
    var final_damage: int = damage_ref[0]

    target.take_damage(final_damage, attacker.main_weapon)
    CombatEventBus.damage_dealt.emit(attacker, target, final_damage, attacker.main_weapon)
    CombatEventBus.weapon_used.emit(attacker, attacker.main_weapon, 0)
    attacker.has_acted = true

func cancel() -> void:
    # Phase 1: best-effort. RollbackService doesn't fully integrate until Phase 3 anyway.
    target.current_hp = min(target.current_hp + _damage, target.max_hp)
    target.hp_changed.emit(target.current_hp - _damage, target.current_hp)
    attacker.has_acted = false

# --- helpers ---

# Phase 1 damage formula: simplified from GDD §5.5.
# TODO(phase 3): extract to AttackSimulator.predict() for AI / UI preview reuse.
static func _compute_damage(atk: CharacterUnit, def: CharacterUnit, w: Weapon) -> int:
    var base: int = atk.atk * w.initial_power / 10
    var mitigated: int = base - def.def
    return clamp(mitigated, 1, 9999)

static func _resolve_shape(id: int) -> RangeShape:
    return RangeShapeResolver.get_shape_by_id(id)
```

**Notes:**
- The `attack_resolving` signal is fired even though no listener exists yet. That's correct — it's the architectural hook for Phase 7's BondActionService. Firing it now means future code inserts cleanly.
- The Phase 1 damage formula is `atk * weapon.power / 10 - def`, clamped to `[1, 9999]`. This is *not* the full GDD §5.5 formula — facing/elevation/element/type modifiers are missing. They land alongside the simulator extraction in Phase 3.
- `cancel()` is best-effort. Real rollback wiring is Phase 3's RollbackService.

**Acceptance criteria:**
- [ ] File exists. All lifecycle methods overridden.
- [ ] `validate()` rejects: attacker acted, target dead, same team, target out of range.
- [ ] `execute()` emits `attack_resolving`, `damage_dealt`, `weapon_used`. If lethal, `unit_killed` fires (via `take_damage`).
- [ ] T21 test covers happy path, lethal hit, and out-of-range rejection.

**Autonomy note:** If the formula produces zero or negative numbers in playtest because stats are too low, do *not* tweak the formula — increase the test stats. The formula is provisional anyway and Phase 3 will reshape it.

---

## P1-T12 — `EndTurnCommand` and `WaitCommand`

**Goal:** Two simple commands. `WaitCommand` ends a unit's turn without acting (Stay action from GDD §4.3). `EndTurnCommand` ends the entire phase (player chooses to skip remaining unacted units).

**Read first:**
- `docs/gdd.md` §4.3, §10.4

**Files:**

1. **`res://scripts/battle/commands/wait_command.gd`** — `class_name WaitCommand extends Command`.
    - Constructor takes `unit: CharacterUnit`.
    - `validate()`: unit must be unacted.
    - `execute()`: sets `unit.has_acted = true`. Emits `CombatEventBus.turn_ended(unit)`.
    - `cancel()`: sets `unit.has_acted = false`.

2. **`res://scripts/battle/commands/end_turn_command.gd`** — `class_name EndTurnCommand extends Command`.
    - Constructor takes `manager: BattleManager`.
    - `validate()`: phase must be player phase.
    - `execute()`: calls `manager.advance_phase()`. (BattleManager exposes this in T13.)
    - `cancel()`: not meaningfully reversible — `push_error` and document.

**Acceptance criteria:**
- [ ] Both files exist with the expected behavior.
- [ ] T21 covers WaitCommand happy path.

**Autonomy note:** Proceed.

---

## P1-T13 — `BattleManager` phase-loop FSM

**Goal:** Drive the phase state machine from GDD §4.2. Tracks current phase, current acting team, round number. Emits CombatEventBus phase signals. Spawns units from a hardcoded test setup.

**Read first:**
- `docs/gdd.md` §4.2, §4.3, §10.2

**Replace** the Phase 0 stub at `res://scenes/battle/battle_manager.gd`.

**Class shape:**

```gdscript
class_name BattleManager extends Node

enum Phase { NONE, PLAYER, ENEMY, NEUTRAL }

var board: Board
var current_phase: Phase = Phase.NONE
var round_number: int = 0
var _ai_controller_ref: Node              # AIController autoload, cached

@onready var _board_view: Node3D = get_node("../Board/GridOverlay")  # BoardView3D
@onready var _units_layer: Node3D = get_node("../Board/UnitsLayer")

signal phase_changed(new_phase: Phase, round_number: int)

func _ready() -> void:
    _ai_controller_ref = AIController
    _setup_test_battle()
    start_battle()

# --- Battle setup ---

func _setup_test_battle() -> void:
    # Build a 10x10 flat board.
    # Spawn 2 player units at (1,1) and (1,3).
    # Spawn 2 enemy units at (8,1) and (8,3).
    # Configure each via initialize_from_definition().
    ...

# --- Phase loop ---

func start_battle() -> void:
    round_number = 1
    CombatEventBus.battle_started.emit(null)  # TODO(phase 1): pass real BattleMap when authored
    _enter_phase(Phase.PLAYER)

func advance_phase() -> void:
    match current_phase:
        Phase.PLAYER:  _enter_phase(Phase.ENEMY)
        Phase.ENEMY:   _enter_phase(Phase.NEUTRAL)
        Phase.NEUTRAL: round_number += 1; _enter_phase(Phase.PLAYER)

func _enter_phase(p: Phase) -> void:
    if current_phase != Phase.NONE:
        CombatEventBus.phase_ended.emit(_phase_name(current_phase), round_number)
    current_phase = p
    var phase_name := _phase_name(p)
    CombatEventBus.phase_started.emit(phase_name, round_number)
    phase_changed.emit(p, round_number)
    _reset_turn_state(p)

    if p == Phase.ENEMY:
        _ai_controller_ref.run_enemy_phase(self)   # T18

    elif p == Phase.NEUTRAL:
        # Phase 1: nothing happens in neutral phase. Phase 8 adds terrain hazards / status ticks.
        advance_phase()

    _check_battle_end()

func _reset_turn_state(p: Phase) -> void:
    for unit in board.units.values():
        if (p == Phase.PLAYER and unit.team == 0) or (p == Phase.ENEMY and unit.team == 1):
            unit.reset_for_new_turn()

# --- End conditions ---

func _check_battle_end() -> void:
    var alive_players := 0
    var alive_enemies := 0
    for unit in board.units.values():
        if unit.is_alive():
            if unit.team == 0: alive_players += 1
            else: alive_enemies += 1
    if alive_enemies == 0:
        CombatEventBus.battle_ended.emit("victory")
    elif alive_players == 0:
        CombatEventBus.battle_ended.emit("defeat")

# --- helpers ---

static func _phase_name(p: Phase) -> String:
    match p:
        Phase.PLAYER: return "player"
        Phase.ENEMY:  return "enemy"
        Phase.NEUTRAL: return "neutral"
        _: return "none"
```

**Acceptance criteria:**
- [ ] BattleManager replaces the Phase 0 stub.
- [ ] On scene load, builds a 10×10 board, spawns 4 units, transitions through phases.
- [ ] `phase_started`/`phase_ended` fire each transition.
- [ ] `battle_ended` fires with "victory" when all enemies are dead, "defeat" when all players are dead.
- [ ] Hooking up the AI happens in T18; for T13's standalone test, just verify the loop logic with a stub `AIController.run_enemy_phase` that immediately calls `manager.advance_phase()`.

**Autonomy note:** The `_ai_controller_ref` cache exists because by Phase 10 the AIController will need to do real work. For Phase 1's T18, AIController gets a `run_enemy_phase(manager)` method that drives the simple AI. If this feels awkward, the alternative is BattleManager iterating enemies itself and calling AIController per unit; either works, the former is closer to GDD §10.3's role separation.

---

## P1-T14 — Tile-input layer — mouse picks tiles and units

**Goal:** Click on a tile in the 3D viewport → know which `Vector2i` was clicked. The `BattleManager` and the Action Menu (T15) consume this.

**Read first:**
- Godot 4 docs on `Camera3D.project_ray_normal`, `PhysicsDirectSpaceState3D.intersect_ray` (or equivalent).

**Files to create:**

1. **`res://scripts/battle/input/tile_input_controller.gd`** — `class_name TileInputController extends Node`. Attach as a child of `BattleScene`.

**Behavior:**
- Listens to `_unhandled_input(event)`.
- On left-click, raycasts from the camera through the cursor into the board plane (or onto tile mesh colliders if you give the tile meshes `StaticBody3D` colliders).
- Converts hit world position to `Vector2i` grid coords.
- Emits `tile_clicked(pos: Vector2i)` and (if a unit is on that tile) `unit_clicked(unit: CharacterUnit)`.
- Has a `set_enabled(b: bool)` so the menu can suppress input during AI phase.

**Implementation approach (pick one):**
- **Approach A (collision-based):** Give each Tile mesh in T04 a `StaticBody3D` + `BoxShape3D` collider. Raycast picks the body; you can attach metadata `("grid_pos", Vector2i)` to each body and read it back. More reliable.
- **Approach B (math-based):** Project the ray to the y=0 plane, floor the (x, z) to ints. Simpler but breaks if elevation arrives in Phase 8.

Pick A. The cost is small now and pays back through Phase 8.

**Acceptance criteria:**
- [ ] Clicking on a tile in the running battle emits `tile_clicked` with the correct grid coord.
- [ ] Clicking on a unit also emits `unit_clicked`.
- [ ] T22 manual smoke-test verifies this in-game.

**Autonomy note:** The collider approach means T04 needs revision to add `StaticBody3D` + `CollisionShape3D` per tile. Either revise T04 in this task or do it cleanly here — your call. Document which.

---

## P1-T15 — Action menu UI — choose Move/Attack/Wait

**Goal:** When a player unit is clicked, show a small action menu near the unit. Buttons: Move, Attack, Wait, Cancel. Selecting Move enters move-targeting mode (T16 highlights). Selecting Attack enters attack-targeting mode. Selecting Wait submits a `WaitCommand`. Cancel returns to selection mode.

**Read first:**
- `docs/gdd.md` §4.3, §6.4

**Files to create:**

1. **`res://scenes/battle/ui/action_menu.tscn`** — `Control` with vertical layout, four buttons.
2. **`res://scenes/battle/ui/action_menu.gd`** — `class_name ActionMenu extends Control`. Signals: `move_chosen`, `attack_chosen`, `wait_chosen`, `cancel_chosen`. Methods: `show_for_unit(unit: CharacterUnit, screen_pos: Vector2)`, `hide_menu()`. Disables Attack button if no enemies in range; disables Move button if `unit.has_acted`.

3. **`res://scripts/battle/input/player_phase_controller.gd`** — `class_name PlayerPhaseController extends Node`. The state machine that drives the per-turn flow:

    - States: `IDLE` (no unit selected) → `UNIT_SELECTED` (menu shown) → `TARGETING_MOVE` → `TARGETING_ATTACK` → back to `IDLE` after action commits.
    - Listens to `TileInputController` signals and the `ActionMenu` signals.
    - Builds `MoveCommand` / `AttackCommand` / `WaitCommand` and submits to `CommandQueue`.
    - Calls `BoardView3D.highlight_tiles` for range previews (delegates to T16).

**Behavior summary:**
- Click own unit → menu appears.
- Click Move → menu hides, valid move tiles highlight green, click a green tile → MoveCommand submits → highlights clear, menu reappears (so you can still Attack/Wait).
- Click Attack → attack tiles highlight red, click a target → AttackCommand submits → highlights clear, unit's `has_acted = true`, menu auto-closes, state returns to IDLE.
- Click Wait → WaitCommand submits, unit's `has_acted = true`, state returns to IDLE.
- Click Cancel → state returns to IDLE without action.
- Right-click anywhere → state returns to IDLE without action.

**Note on phase-end:** When all player units have `has_acted`, automatically advance the phase. Or: provide an "End Phase" button somewhere on screen. Either is fine; pick one and document it. (Recommend the auto-advance so we don't need a phase-end button this phase; Phase 1 only has 2 player units so it doesn't get tedious.)

**Acceptance criteria:**
- [ ] Action menu shows when a player unit is clicked.
- [ ] Move → tile highlight → click → unit moves.
- [ ] Attack → tile highlight → click enemy → attack resolves, HP visibly drops.
- [ ] Wait → unit grays out, no other action available.
- [ ] When all player units have acted, phase auto-advances to enemy.

**Autonomy note:** UI styling is irrelevant for Phase 1. Default Godot theme is fine. The point is the state machine works.

---

## P1-T16 — Range-highlight overlay on `GridOverlay`

**Goal:** When player is targeting a move or attack, the legal tiles are visually highlighted on the board.

**Read first:** GDD §6.4 (range highlights paragraph).

**Steps:**
- This task is implemented by `PlayerPhaseController` (T15) calling `BoardView3D.highlight_tiles(tiles, color)` from T04.
- Move-targeting: green for reachable tiles.
- Attack-targeting: red for tiles with valid targets.
- On state exit (action committed or canceled), call `clear_highlights()`.

If T04's highlight method needs a multi-color or layered version (e.g. green underneath, red on top of move-then-attack reach), enhance T04 here rather than hacking around it. Move-then-attack overlay (blue per GDD §6.4) is *not* required in Phase 1 — just move-only and attack-only.

**Acceptance criteria:**
- [ ] When player chooses Move, exactly the reachable tiles glow green.
- [ ] When player chooses Attack, tiles containing in-range enemies glow red.
- [ ] Highlights clear on action commit or cancel.

**Autonomy note:** Proceed.

---

## P1-T17 — Damage-preview popup

**Goal:** Hovering an enemy in attack-targeting mode shows a small popup near the cursor with predicted damage and "will kill?" indicator.

**Read first:** GDD §6.4 (damage preview paragraph).

**File:** `res://scenes/battle/ui/damage_preview.tscn` + `damage_preview.gd`. A small `Control` showing:
- Predicted damage: `<num>`.
- `Will kill: yes/no`.

The prediction calls `AttackCommand._compute_damage` directly (it's a static helper) — the same formula as execution. Phase 3 splits this out into `AttackSimulator.predict()` so the UI and the AI both consume one source of truth.

**Acceptance criteria:**
- [ ] Hovering an enemy while in attack-targeting state shows the popup with the predicted damage from `_compute_damage`.
- [ ] Popup hides when no longer hovering or when state exits.

**Autonomy note:** If the static-method-call coupling between the UI and the Command bothers you, that's correct architectural instinct — but Phase 3 is the right place to fix it, not Phase 1. Leave a `# TODO(phase 3)` and move on.

---

## P1-T18 — Hardcoded enemy AI — pick action, submit command

**Goal:** During enemy phase, every enemy unit picks an action (move + attack if possible, else move toward nearest player) and submits commands. No AIBehavior resources, no scoring, no archetypes.

**Read first:** GDD §8 — to know what Phase 1 is *not* doing. The simple Phase 1 AI is closer to a "default behavior fallback" than what §8 describes.

**File:** Replace the stub at `res://scripts/autoload/ai_controller.gd`.

**Behavior:**

```gdscript
extends Node

func run_enemy_phase(manager: BattleManager) -> void:
    var board := manager.board
    var enemies := _get_alive_team(board, 1)
    for enemy in enemies:
        if not is_instance_valid(enemy) or not enemy.is_alive(): continue
        _act(enemy, board)
        await get_tree().process_frame  # yield so the player can perceive turns
    manager.advance_phase()

func _act(enemy: CharacterUnit, board: Board) -> void:
    var nearest_player := _find_nearest_player(enemy, board)
    if nearest_player == null:
        # No targets; just wait.
        CommandQueue.submit(WaitCommand.new(enemy))
        return

    # 1. If already in attack range, attack.
    var shape := RangeShapeResolver.get_shape_by_id(enemy.main_weapon.range_shape_id)
    var attack_tiles := RangeShapeResolver.resolve(shape, enemy.grid_position, enemy.facing)
    if attack_tiles.has(nearest_player.grid_position):
        CommandQueue.submit(AttackCommand.new(board, enemy, nearest_player))
        return

    # 2. Otherwise, move as close as we can to nearest_player.
    var reachable := Pathfinder.compute_reachable(board, enemy.grid_position, enemy.move_budget)
    var best_tile := enemy.grid_position
    var best_dist := _manhattan(enemy.grid_position, nearest_player.grid_position)
    for tile in reachable.keys():
        var d := _manhattan(tile, nearest_player.grid_position)
        if d < best_dist:
            best_dist = d
            best_tile = tile
    if best_tile != enemy.grid_position:
        CommandQueue.submit(MoveCommand.new(board, enemy, best_tile))

    # 3. After moving, if NOW in range, attack.
    var post_attack_tiles := RangeShapeResolver.resolve(shape, enemy.grid_position, enemy.facing)
    if post_attack_tiles.has(nearest_player.grid_position) and not enemy.has_acted:
        CommandQueue.submit(AttackCommand.new(board, enemy, nearest_player))
    elif not enemy.has_acted:
        CommandQueue.submit(WaitCommand.new(enemy))

# helpers: _get_alive_team, _find_nearest_player, _manhattan
```

**Notes:**
- The `await get_tree().process_frame` between enemies is so the player can visually perceive each enemy's actions. Phase 2 will replace this with awaiting view animation completion.
- Move-then-attack within a single turn is supported by checking `has_acted` between commands — `MoveCommand` does NOT set `has_acted = true`, only `AttackCommand` and `WaitCommand` do. That's correct per GDD §4.3 ("Move + Action + Face").

**Acceptance criteria:**
- [ ] During enemy phase, enemies move toward player units.
- [ ] If an enemy is in range, they attack.
- [ ] If they can move into range, they do, then attack.
- [ ] If neither possible, they wait.
- [ ] Phase auto-advances to player when all enemies have acted.

**Autonomy note:** Resist adding more sophistication — this is deliberately stupid AI. Phase 10 owns the smart version.

---

## P1-T19 — Victory / defeat conditions and end-of-battle screen

**Goal:** When `CombatEventBus.battle_ended` fires, freeze input and show a simple end-of-battle overlay ("Victory" or "Defeat") with a Restart button that reloads the scene.

**Read first:** GDD §9.3 (victory conditions).

**Files:**
- `res://scenes/battle/ui/end_of_battle.tscn` + `.gd`. Initially hidden. Shows when `CombatEventBus.battle_ended` fires.

**Behavior:**
- Pause input on TileInputController and ActionMenu.
- Show a centered panel with "Victory" or "Defeat" text and a Restart button.
- Restart reloads the current scene (`get_tree().reload_current_scene()`).

**Acceptance criteria:**
- [ ] Killing all enemies shows Victory.
- [ ] Letting all players die shows Defeat.
- [ ] Restart returns to a fresh battle.

**Autonomy note:** Proceed. Phase 1's victory condition is hardcoded in BattleManager (T13's `_check_battle_end`); the full GDD §9.3 condition system lands when maps are authored (Phase 14+).

---

## P1-T20 — `BattleLogService` wires up to verify signals are firing

**Goal:** Replace the BattleLogService stub from Phase 0 with a working listener that records every CombatEventBus signal into an in-memory log. Phase 1's value: it's a debugging tool that proves the architecture is wired correctly.

**Read first:** GDD §10.3.

**File:** Replace `res://scripts/autoload/battle_log_service.gd`.

**Behavior:**
- On `_ready()`, connect to every CombatEventBus signal.
- Each handler appends a timestamped entry to a `_log: Array[Dictionary]` field.
- Add a method `get_log() -> Array` for tests / debug.
- Add a method `clear() -> void`.
- Add an `@export var print_to_stdout: bool = false` — when true, every event also `print()`s. Helpful during Phase 1 manual playtest.

**Acceptance criteria:**
- [ ] All 20 signals connected (the same set declared in CombatEventBus).
- [ ] After playing a turn, `BattleLogService.get_log()` shows entries for `phase_started`, `damage_dealt`, etc., with the right payloads.
- [ ] T21 includes a test asserting that an `AttackCommand.execute()` produces a `damage_dealt` entry in the log.
- [ ] When `print_to_stdout = true`, console shows the events as they fire.

**Autonomy note:** Phase 1 is the right time to do this because the architecture is in place and we now have signals actually firing. It's also the cheapest possible regression test for "is the bus actually being used" through all of Phase 2+.

---

## P1-T21 — GUT integration tests for the slice

**Goal:** A handful of tests that prove the core flow works without touching the UI. These run headless and act as a regression net.

**Read first:** GDD §10.9.

**Files to create** under `res://tests/`:

1. **`test_board.gd`** — Board.create_flat returns the right shape; get_tile bounds-check works; get_unit_at works.
2. **`test_pathfinder.gd`** — empty board, BFS from origin with budget 3 returns expected tiles; obstacle blocks correctly.
3. **`test_range_shape_resolver.gd`** — melee_1 from (5,5) returns the 4 cardinal neighbors.
4. **`test_character_unit.gd`** — `take_damage(5)` reduces HP by 5; lethal damage emits `died` and `CombatEventBus.unit_killed`.
5. **`test_move_command.gd`** — happy path, validate-rejects-out-of-range, cancel reverses.
6. **`test_attack_command.gd`** — happy path emits the right bus signals; lethal hit triggers `unit_killed`; out-of-range rejects.
7. **`test_phase_loop.gd`** — spawn 1 player + 1 enemy, walk through phase transitions, assert phase signals fire in order.
8. **`test_battle_log_service.gd`** — submit an AttackCommand, assert log contains the expected entries.

**Acceptance criteria:**
- [ ] All 8 tests written and pass.
- [ ] Tests can be run via the existing GUT CLI (per Phase 0's working command).
- [ ] Total Phase 1 test count >= 20 individual assertions.

**Autonomy note:** Use a setup helper (`before_each`) per test file to reduce boilerplate. The Phase 0 `test_battle_const.gd` test stays.

---

## P1-T22 — Phase 1 verification

**Goal:** Manually playtest the slice end-to-end and verify all acceptance criteria from earlier tasks are still true after integration.

**Steps:**

Use MCP tools to self-verify:

1. `play_scene` to start the project.
2. `get_game_screenshot` to confirm: 10×10 grid visible, 2 blue capsules (players) and 2 red capsules (enemies) in opposite corners.
3. `simulate_mouse_click` on a player unit — verify menu appears (`get_game_screenshot`).
4. Click Move, click a tile in range — verify unit moves and HP labels are intact.
5. Click another player unit, Attack a nearby enemy — verify HP drops on the enemy.
6. Walk through enemy phase — verify enemies move and attack.
7. Continue until victory or defeat — verify end-of-battle screen.
8. Restart — verify fresh battle.
9. `get_editor_errors` — confirm no errors.
10. Run all GUT tests via the headless CLI — confirm all pass.

**Verification checklist:**

- [ ] Two player units and two enemy units spawn correctly.
- [ ] Player can click own unit → menu → Move → tile → unit moves.
- [ ] Player can Attack → enemy → enemy HP drops.
- [ ] Damage preview shows on attack-target hover.
- [ ] When all player units have acted, enemy phase begins.
- [ ] Enemies move toward and attack player units.
- [ ] Phase advances back to player after all enemies act.
- [ ] Killing all enemies shows Victory.
- [ ] All GUT tests pass.
- [ ] No console errors.
- [ ] `BattleLogService` log shows all expected events when inspected via `execute_game_script`.
- [ ] `docs/PROGRESS.md` updated with Phase 1 marked complete and pending review.

**Acceptance criteria:**
- [ ] All checklist items pass.
- [ ] User notified that Phase 1 is ready for review.

**Important:** Do NOT make any git commits. The user will review changes in Sourcetree and commit at their discretion.

**Autonomy note:** Stop and report after T22. Phase 2 is a separate task file.

---

## Phase 1 NOT-doing list

These would be scope creep. Don't do them in Phase 1 even if you "could easily."

- ❌ Pixel sprites or animated sprites. Phase 2.
- ❌ Camera system / multi-mode camera. Phase 2 (single tactical preset) and Phase 9 (full multi-mode).
- ❌ Move animations (tweening unit position). Phase 2.
- ❌ Attack/hit/death animations. Phase 2.
- ❌ Sub weapons or `SwitchWeaponCommand`. Phase 4.
- ❌ Weapon durability tracking. Phase 4.
- ❌ Skills, status effects, elements, or types. Phases 5, 12, 13.
- ❌ Per-action EXP. Phase 5.
- ❌ Bond, Bond Action. Phases 5, 7.
- ❌ Duo / DoubleCommand / SwitchDoubleCommand / ReleaseDoubleCommand. Phase 6.
- ❌ Snapshot rollback / rewind UI. Phase 3.
- ❌ Simulator extraction (`AttackSimulator`, etc.). Phase 3.
- ❌ Component refactor of `CharacterUnit`. Phase 3.
- ❌ Terrain types beyond plain. Phase 8.
- ❌ Elevation. Phase 8.
- ❌ Hit/miss rolls or critical hits. Phase 5.
- ❌ Facing-based damage modifiers. Phase 5 (alongside hit/crit).
- ❌ Counterattacks. Phase 5.
- ❌ AIBehavior weighted scoring or multiple archetypes. Phase 10.
- ❌ Battle Map Painter or any map authoring tool. Phase 14.
- ❌ Save/load. Phase 16.
- ❌ Settings menu. Phase 16.
- ❌ Title screen, main menu, battle select. Out of scope until post-vertical-slice.
- ❌ Story / narrative. Out of scope for v1.

If you find yourself writing code that does any of the above, stop. The right move is to leave a `# TODO(phase X)` and move on.

---

## What "Phase 1 done" looks like

When you've completed P1-T01 through P1-T22, you should have:

- A playable, headless-testable, single-battle slice. Two player capsules, two enemy capsules, a flat grid.
- Click your unit → menu → Move → unit moves. Click your unit → Attack → preview → confirm → enemy HP drops.
- Enemies do something on enemy phase (move and attack).
- Battle ends with Victory or Defeat. Restart works.
- 20+ assertions across 8 GUT test files passing.
- BattleLogService records every combat event — proving the bus is wired.
- All architecture from Phase 0 is now actually carrying load: CombatEventBus signals fire, Commands flow through CommandQueue, Resources drive the data.

This is the first phase where the project visibly does something. It's also the phase that proves the architecture works under real load. From here, Phases 2 onward layer presentation (Phase 2), then proper architecture cleanup (Phase 3 — simulators, components, rollback), then features.

If at the end of Phase 1 you find yourself wanting to refactor `CharacterUnit` or extract simulators *before* moving to Phase 2 — resist. Phase 2 needs the gameplay layer stable so the visual layer has something solid to bind to. Phase 3 is when the cleanup happens, and doing it before Phase 2 means doing it twice.

---

*End of phase_1_tasks.md.*
