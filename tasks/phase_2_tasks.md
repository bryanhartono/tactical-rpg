# Phase 2 — Visual Foundation

> **Phase goal:** Replace Phase 1's capsule placeholders with pixel-art sprite billboards on a smooth 3D environment — the **HD-2D** look that defines this project's visual identity. Establish the camera rig with three presets matching *Aster Tatariqus*'s framing (Tactical 50° / Overview 70° / Top-down 90°). Lock in the rendering pipeline (texture filtering split: linear-for-3D, nearest-for-sprites; MSAA on terrain; outline shader on units; basic post-processing). Animate movement and combat with tweens and sprite animations. Phase 1 was bones; Phase 2 is the first time the project actually looks like a tactical RPG.
>
> **Estimated duration:** ~2 weeks of focused work. (One week longer than the GDD §12.1 estimate because Phase 2 absorbs the camera multi-mode work GDD §12.1 originally deferred to Phase 9 — moving it forward is a deliberate scope shift, see the design constraints section.)
>
> **Definition of phase done:** Run the project. See the same 2v2 battle from Phase 1, but now: warrior sprites for players, skeleton sprites for enemies, both billboarded on a Kenney Nature Kit ground with grass / trees / rocks; a tactical camera looking down at ~50°; pressing **Tab** cycles to a 70° overview, then a 90° top-down, then back, with smooth tweened transitions. Movement plays a walk animation and tweens along the path. Attacks play an attack animation; the hit target plays a hit animation; death plays a death animation before the unit despawns. Damage popup numbers float up and fade. The grid overlay is hidden by default and shown during targeting. All Phase 1 functionality still works (commands, AI, end-of-battle, tests).

---

## How to read this file

- Tasks are ordered. Most have dependencies on earlier tasks; do them in order unless you have a specific reason not to.
- Each task lists **acceptance criteria** that must all be true for the task to be "done." See `CLAUDE.md` for what "done" means.
- Each task lists the **GDD / reference sections** to read before starting. Read those, not the entire GDD.
- Each task has an **autonomy note** clarifying what to do without asking vs what to surface.
- The **Phase 2 NOT-doing list** at the bottom of this file is as important as the task list. Read it before starting any task.

---

## Phase 2 design constraints (read before starting any task)

These boundaries keep Phase 2 from sprawling.

### Visual direction: HD-2D, locked

The visual identity is **HD-2D** — pixel-art chibi sprites billboarded onto a smoothly-shaded 3D world. The reference points are *Aster Tatariqus*, *Octopath Traveler*, *Triangle Strategy*, *Live A Live (2022)*. The 3D environment uses high-poly assets with linear texture filtering, MSAA, soft shadows, ambient lighting, and bloom. The pixel sprites use nearest-neighbor filtering and stand out as flat 2D characters against the painterly 3D world. The contrast between the two is the visual identity, not an accident.

Phase 1's `BoardView3D` plain-grey-tile look was a deliberate placeholder. Phase 2 retires it (or rather: hides the grid by default and shows it on demand) in favor of a proper 3D ground.

### What changes vs Phase 1

- **Project default texture filter flips.** Phase 0 (P0-T01) set the global default to `Nearest` on the assumption of an all-pixel-art project. HD-2D needs `Linear with mipmaps` as the global default, with per-import override on every sprite PNG to use `Nearest`. P2-T02 inverts this.
- **MSAA 3D gets re-enabled.** Phase 0 disabled it for pixel-art consistency. HD-2D needs it on the terrain mesh to avoid jagged edges on Kenney's low-poly geometry. Sprites are unaffected (they're flat textures, not 3D triangles).
- **Three camera presets shipped now, not in Phase 9.** GDD §12.1 originally deferred multi-camera to Phase 9. We're moving it forward because the camera rig, signal contract, and preset-switching FSM are load-bearing for Phase 2's view animation work — building it once now is cheaper than retrofitting it later.

### What stays out of Phase 2

- **No final art.** Placeholder sprites (32×32 from the user's provided pack) and placeholder environment (Kenney Nature Kit). When the eventual 48×48 / 64×64 chibi sprites in Aster's actual style arrive, the import pipeline + animation system + outline shader stay; only the asset references change. Don't tune visual feel for these placeholders — tune for what final art will need.
- **No facing-direction sprite variants.** GDD §6.1 specifies single-direction (east) sprites with horizontal flip for west. The placeholder strips are already single-direction.
- **No facing arrow decal.** The decal system in GDD §6.1 ("facing arrow rendered on the ground under each unit") is real Phase 2 work but is deferred to Phase 5 — the phase that actually consults gameplay-facing in the damage formula. Building the decal now would render a thing that doesn't yet matter. Phase 5 brings facing damage modifiers AND the decal together.
- **No depth-of-field or selective focus.** GDD §10.5 mentions DoF; that lands in Phase 9 alongside camera polish. Bloom + ambient light only for Phase 2.
- **No combat cinematics, no zoom-into-combat sequences.** GDD §6.2 confirms scope: combat resolution stays on the grid.
- **No animated combat feedback beyond sprite animations + damage popups.** No screen shake, no hit-stop, no particle VFX yet. Polish lands in Phase 17.
- **No sound or music.** The whole audio track is post-vertical-slice per GDD §3.3.

If a task in this file appears to require something on the NOT list, you're either misreading the task or there's a gap — surface it.

---

## Prerequisites

- [ ] Phase 1 is complete and committed by the user. `docs/PROGRESS.md` shows Phase 1 ✅.

- [ ] User has placed pre-split placeholder sprite frames at:
  - `res://art/sprites/warrior/Idle.png`
  - `res://art/sprites/warrior/Walk.png`
  - `res://art/sprites/warrior/Attack01.png`
  - `res://art/sprites/warrior/Attack02.png`
  - `res://art/sprites/warrior/Hurt.png`
  - `res://art/sprites/warrior/Death.png`
  - `res://art/sprites/skeleton/Idle.png`
  - `res://art/sprites/skeleton/Walk.png`
  - `res://art/sprites/skeleton/Attack.png`
  - `res://art/sprites/skeleton/Hurt.png`
  - `res://art/sprites/skeleton/Death.png`

  Each PNG is a horizontal strip of frames at 32×32 per frame, one animation per file (the user has pre-split the original multi-row sheets). The skeleton has a single attack animation; the warrior has two (`Attack01` is primary, `Attack02` is reserved for skill-based attacks in Phase 4+).

- [ ] User has placed the Kenney Nature Kit at `res://art/environment/kenney_nature_kit/` (whatever folder structure ships in the zip — keep their layout).

- [ ] User has confirmed they're ready to start Phase 2.

If any prerequisite is missing, **stop and ask the user to provide it before starting** (per the asset policy in `CLAUDE.md`).

---

## Task index

| ID | Task | Depends on |
|---|---|---|
| P2-T01 | Update GDD §1.2 / §6.1 / §6.3 / §10.5 to reflect HD-2D + three-preset camera | (Phase 1) |
| P2-T02 | Project rendering settings: re-enable MSAA, flip default filter to linear, configure environment | (Phase 1) |
| P2-T03 | Per-import override: sprite PNGs filter as Nearest | T01, T02 |
| P2-T04 | `WorldEnvironment` with sky, ambient, bloom; directional light | T02 |
| P2-T05 | Replace `BoardView3D` flat tiles with a Kenney ground placeholder; grid becomes a toggleable overlay | T02, T04 |
| P2-T06 | `CameraSetting` data instances for the three presets (Tactical / Overview / Top-down) | T01 |
| P2-T07 | `BattleCamera` rig — pivot + Camera3D + tween-based preset cycling, signals on mode change | T06 |
| P2-T08 | Tab key cycles camera presets; F focuses on selected unit | T07 |
| P2-T09 | `SpriteFrames` resources for warrior + skeleton from the pre-split PNGs | T03 |
| P2-T10 | `UnitView3D` rewrite: AnimatedSprite3D billboard + outline shader replaces capsule | T05, T09 |
| P2-T11 | Move animation: tween position along path, play walk during, idle after | T10 |
| P2-T12 | Attack / hit / death animations: AttackCommand awaits view animation completion | T10, T11 |
| P2-T13 | Damage popup VFX: floating number, fades over 0.8s | T12 |
| P2-T14 | Grid overlay becomes toggleable; auto-shows during targeting, hidden otherwise | T05 |
| P2-T15 | Camera focuses on the active unit on `turn_started` | T07 |
| P2-T16 | Update Phase 1 tests for the new view layer (and add 2 view-specific tests) | T10–T13 |
| P2-T17 | Phase 2 verification | All |

---

## P2-T01 — Update GDD §1.2 / §6.1 / §6.3 / §10.5

**Goal:** Bring the GDD in line with the HD-2D direction and the three-preset camera that the *Aster Tatariqus* screenshots evidence. The GDD currently has internally-inconsistent visual specs and a camera spec that contradicts the actual reference game. Fix that *before* writing any view code so Phase 2 tasks reference the corrected spec.

**Read first:**
- `docs/gdd.md` §1.2 (pillar 3), §6.1, §6.3, §10.5
- `CLAUDE.md` "Authoritative documents" — the GDD wins on *what*; if it's wrong, fix the GDD, don't code around it.

**Edits to make in `docs/gdd.md`:**

### §1.2 pillar 3 — clarify HD-2D
Existing text mentions "pixel-art chibi billboards on real 3D terrain" — leave that. **Add a sentence:**

> The technique is commonly called **HD-2D** — high-definition 2D, popularized by *Octopath Traveler* and seen in *Triangle Strategy* and *Aster Tatariqus*. Sprites are crisply pixel-art (nearest-neighbor filtering, no anti-aliasing) while the world around them is smoothly-shaded 3D (linear filtering, MSAA, ambient lighting, bloom).

### §6.1 — replace the "single-direction sprites" rationale paragraph
The current rationale ("...the camera is fixed in horizontal angle...") is partly wrong because we're now adding a top-down preset. Update the sprite-direction reasoning:

> **Direction count: 1 unique direction per state (E, side-profile), with horizontal flip for W.** No N/S sprites. *Aster Tatariqus* uses this same compromise — its sprites are side-profile flat billboards regardless of camera pitch (visible in its 50°, 70°, and 90° presets), and the chibi proportions (huge head, small body) keep them readable from any angle even though they don't show top-of-head detail. The "facing arrow decal" (§6.1) communicates gameplay-facing without needing N/S sprite variants.

The animation count and frame budget paragraphs stay as-is.

### §6.3 — replace the entire camera presets table

Replace the existing three-preset table with:

| Mode | Distance | Pitch | Use case |
|---|---|---|---|
| **Tactical** | medium-far (10–14u) | ~50° | Default — covers most of the board, sprites read clearly |
| **Overview** | far (14–18u) | ~70° | Wider battlefield view, helps with positioning + planning |
| **Top-down** | far (14–18u) | ~90° | Pure overhead, useful for unit placement and strategic overview |

Replace the "All presets use a similar moderate pitch range (30°–50°) because steeper top-down angles don't read well with side-profile-only sprites" paragraph and the "A pure top-down preset is not viable" line with:

> All three presets work with single-direction sprites because chibi proportions remain readable at any camera pitch — *Aster Tatariqus* validates this empirically. The pitch differences between presets are deliberate and large (50° → 70° → 90°), giving each mode a distinctly different feel rather than three similar ones. Players cycle via `Tab`. Each preset remembers its own zoom level (per-preset `user_distance`).

The "Camera input" subsection stays — pan / zoom / focus / cycle controls don't change.

### §10.5 — the architecture stays right, but update preset list
The architecture diagram + `CameraSetting` resource definition + API methods stay as-is. Just update any preset names mentioned in the section to match the new Tactical / Overview / Top-down trio. Drop any references to a fourth "Action" close-low preset; that one is gone.

### §13 — add a decision-log entry

Add a row to §13.2 or its decision table documenting:

> **Camera presets revised** (Phase 2 review). Original GDD specified Tactical 50° / Close 40° / Action 30°. Validated against *Aster Tatariqus* gameplay screenshots and revised to Tactical 50° / Overview 70° / Top-down 90°. The empirical evidence — Aster's chibi sprites read fine at 90° — invalidates the original "no top-down" rule. Revised three-preset set ships in Phase 2 (originally planned for Phase 9).

**Acceptance criteria:**
- [ ] All four GDD sections updated as specified.
- [ ] No stale references to "Close 40°" or "Action 30°" presets remain anywhere in the GDD.
- [ ] No stale references to "30°–50° range only" reasoning remain.
- [ ] Decision-log entry added.
- [ ] No code touched in this task — pure documentation.

**Autonomy note:** Proceed. The user has approved these specific changes. If you find another stale reference elsewhere in the GDD that needs the same treatment (e.g. §11.2's "Camera presets (2 for the slice)" line), update it to match — that's within scope. If you find a section where the GDD direction now contradicts itself in some other way, surface it.

---

## P2-T02 — Project rendering settings

**Goal:** Reconfigure the project's renderer for HD-2D. Three of the four toggles directly invert what Phase 0 set up.

**Read first:**
- `docs/gdd.md` §6.1 (post-edit, per T01)
- Phase 0's `tasks/phase_0_tasks.md` P0-T01 — for context on what's being changed
- Godot 4 docs on `Default Texture Filter`, MSAA settings, `WorldEnvironment`

**Settings to change** (use `set_project_setting`, never edit `project.godot` directly):

1. **`rendering/textures/canvas_textures/default_texture_filter`** → **`1`** (Linear). Phase 0 had this at `0` (Nearest). Per-sprite override comes in T03.
2. **`rendering/anti_aliasing/quality/msaa_3d`** → **`2`** (4x MSAA). Phase 0 had this disabled. 4x is the sensible default for low-poly Kenney terrain. Drop to 2x if performance becomes a concern on lower-end Windows.
3. **`rendering/anti_aliasing/quality/msaa_2d`** → keep `0` (Disabled). Pixel-art UI doesn't want MSAA either.
4. **`rendering/environment/defaults/default_clear_color`** → keep current slate `#1a1a2e`. The `WorldEnvironment` in T04 will draw the actual sky.
5. **`rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality`** → **`2`** (Medium). Hard shadows on chibi sprites in HD-2D look bad; we want soft.

**Acceptance criteria:**
- [ ] All five settings applied via `set_project_setting`.
- [ ] No errors on project reload.
- [ ] `project.godot` shows the new values.

**Autonomy note:** Proceed. If Godot 4.6's project setting key paths differ from what's listed (these are stable but versions move), use the equivalent and flag it in the report. If MSAA 4x crashes the editor on M1 (rare but possible with d3d12 on some configs), drop to 2x.

---

## P2-T03 — Per-import override: sprite PNGs as Nearest

**Goal:** Every PNG under `res://art/sprites/` imports with `texture_filter = NEAREST` and mipmaps off. This is what makes the sprites stay pixelated even though the global default is now linear.

**Read first:**
- Godot 4 docs on `.import` files and per-asset texture import settings.

**Steps:**

1. For each PNG in the warrior + skeleton folders (11 files total per the prerequisites list), set the import settings:
   - **Filter:** Nearest (`flags/filter=0` in the `.import` file, or the import dock UI)
   - **Mipmaps/Generate:** Off (`mipmaps/generate=false`)
   - **Fix Alpha Border:** On (`process/fix_alpha_border=true`)
   - **HDR as sRGB:** Off (`process/hdr_as_srgb=false`)
   - Reimport.

2. **Optional but recommended:** Set up a default import preset for the `art/sprites/` folder. Godot's import dock supports "Set as Default" presets per file type — only do this if it scopes to the sprites folder specifically. If it would override the global default for all PNGs project-wide (including future Kenney UI textures), skip and rely on per-file settings.

3. Verify by checking the `.import` files (text format) — each should show `flags/filter=0` and `process/fix_alpha_border=true`.

**Acceptance criteria:**
- [ ] All 11 sprite PNGs reimport with nearest filter and no mipmaps.
- [ ] In a quick `play_scene` smoke test (or a temporary Sprite3D in the editor), a sprite renders crisply and pixelated, not blurry.
- [ ] Kenney 3D models in the scene still render with smooth (linear) filtering when they arrive in T05.

**Autonomy note:** Proceed. The user has confirmed that Claude Code does the import work — they don't want to do it manually. If the `.import` file format trips up Godot's normal import flow when edited manually, use the editor UI via `execute_editor_script` or the Reimport tool. Don't commit broken `.import` files.

---

## P2-T04 — WorldEnvironment + ambient + bloom

**Goal:** A `WorldEnvironment` node configured for the HD-2D look. Sky color, ambient light strength, bloom for highlights. No DoF (Phase 9).

**Read first:**
- `docs/gdd.md` §6.1 (post-T01 edit), §10.5
- Godot 4 docs on `WorldEnvironment` and `Environment`

**Steps:**

1. Add a `WorldEnvironment` node to `BattleScene` (under the root, sibling of Board / BattleCamera / BattleManager / BattleUI).
2. Create a new `Environment` resource on it with:
   - **Background mode:** Sky
   - **Sky:** procedural `Sky` resource. Top color: warm light blue (~`#6a93c8`). Horizon color: pale (~`#b8c4cc`). Ground bottom color: dark muted green (~`#2a3a2a`). Energy multiplier: 1.0.
   - **Ambient light:** source = Sky, energy = 1.0, slight color tint. Soft fill prevents pure-black shadows on chibi sprites.
   - **Tonemap:** Filmic. Exposure 1.0, white 1.0.
   - **Glow (bloom):** enabled, intensity 0.4, strength 0.8, blend mode Soft. Subtle — bloom should make highlights pop without flooding the screen.
   - **SSAO:** disabled (too expensive for the marginal benefit at this scale).
   - **Fog:** disabled (Phase 8 may revisit per-map).
3. Add a `DirectionalLight3D` to `BattleScene` (sibling of `WorldEnvironment`) angled from upper-right, pitch ~45°, yaw ~30° off the camera. **Shadow:** enabled, with `directional_shadow_max_distance = 50` and `shadow_bias` tuned so chibi sprites don't shadow-acne.

**Acceptance criteria:**
- [ ] `WorldEnvironment` and `DirectionalLight3D` exist in `battle.tscn` and load without errors.
- [ ] Running the scene shows a sky-blue background instead of the old slate gray.
- [ ] When the Kenney ground arrives in T05, it shades naturally — not flat-shaded, not black-shadowed.
- [ ] Bloom is visible but subtle on bright surfaces.

**Autonomy note:** Proceed. Color values are starting points — tune by eye after T05/T10 land and the actual scene composition is visible. Don't agonize on exact RGB values; this is placeholder lighting too.

---

## P2-T05 — Replace BoardView3D flat tiles with Kenney ground; grid becomes overlay

**Goal:** The board's *visual* representation switches from "100 grey planes in a grid" to "a Kenney ground mesh as the world, with the grid as a translucent overlay shown on demand." Gameplay still uses `Board.tiles` as the source of truth for grid coords; the view layer just stops showing the grid by default.

**Read first:**
- `docs/gdd.md` §9.1 (visual / gameplay separation for maps)
- The Kenney Nature Kit folder structure (whatever shipped in the zip)

**Files to modify:**

1. **`scripts/battle/view/board_view_3d.gd`** — significant rewrite. Behavior changes:
    - `set_board(board)` no longer instantiates 100 plane meshes for tiles.
    - Instead: instantiate a single ground mesh covering the board area. For Phase 2, this is a `MeshInstance3D` with a `PlaneMesh` sized `width × height` units, textured with one of Kenney's grass tile textures. Simple and works.
    - Add a few decorative props: 3–6 of Kenney's tree models scattered at board corners (positions hardcoded for now; map authoring is Phase 14). Keep them outside the playable grid area so they don't visually interfere with the gameplay grid.
    - Tile picking still needs to work. Approach: keep the `StaticBody3D` + `BoxShape3D` colliders from Phase 1 (one per tile, with `grid_pos` metadata) but make them invisible — they're collision-only, not rendered. The visible grid moves to a separate `_grid_overlay_node`.

2. **New `_grid_overlay_node`:** a child `Node3D` named "GridOverlay" under `BoardView3D` containing a single shader-based grid quad. Recommend the shader approach — one quad sized `width × height` with a custom shader drawing a translucent grid pattern. Cheaper, simpler, prettier than 100 line meshes. Default visibility: hidden. T14 wires up the show-on-targeting logic.

3. **Highlight tiles still work.** `highlight_tiles(tiles, color)` and `clear_highlights()` keep their API but now render highlights as small `MeshInstance3D` quads ~0.05 units above the ground at `(x, height_y, z)`, with translucent emissive material. Pool them or recreate per call — for Phase 2 the recreation is fine; we only highlight up to ~30 tiles at once.

**Steps:**

1. Add a `Node3D` subgroup `Environment` under `Board` in `battle.tscn` (sibling of `GridOverlay` and `UnitsLayer`).
2. Place the Kenney ground inside `Environment`.
3. Place the Kenney decorative props (trees, rocks) inside `Environment`.
4. Update `BoardView3D` to manage the grid overlay separately from the ground.
5. Add `set_grid_visible(visible: bool)` method on `BoardView3D`. Default false. T14 calls it.

**Acceptance criteria:**
- [ ] Running the scene shows a green Kenney ground covering the board area, with a few trees/rocks at the periphery.
- [ ] No grey grid is visible by default.
- [ ] `set_grid_visible(true)` reveals a translucent grid; `set_grid_visible(false)` hides it.
- [ ] Tile picking via `TileInputController` still works (clicks resolve to grid coords).
- [ ] `highlight_tiles([(3,3), (4,3)], Color.GREEN)` shows green highlight quads on those tiles.
- [ ] `clear_highlights()` clears them.

**Autonomy note:** If Kenney's tile size is not exactly 1.0 world unit, scale the placement so 1 grid tile = 1.0 world unit (the gameplay assumption). Don't change the gameplay tile size to match Kenney; scale Kenney to match gameplay. If a shader-based grid overlay is too time-consuming for Phase 2, fall back to the per-tile-line approach and flag for future polish.

---

## P2-T06 — `CameraSetting` data instances

**Goal:** Three `CameraSetting.tres` resources, one per preset, populated with the values from the revised GDD §6.3.

**Read first:**
- `docs/gdd.md` §6.3 (post-T01 edit), §10.5
- `scripts/data/camera_setting.gd` — the existing Phase 0 Resource subclass

**Files to create:**

1. **`res://data/camera_settings/tactical.tres`**
    - `id: 1`, `display_name: "Tactical"`
    - `min_distance: 8.0`, `max_distance: 16.0`, `initial_distance: 12.0`
    - `rotation_angles: Vector3(-50.0, 0.0, 0.0)` — pitch 50° down (Godot uses negative-X for "looking down")
    - `height_offset: 0.0`
    - `enable_dof: false`

2. **`res://data/camera_settings/overview.tres`**
    - `id: 2`, `display_name: "Overview"`
    - `min_distance: 12.0`, `max_distance: 20.0`, `initial_distance: 16.0`
    - `rotation_angles: Vector3(-70.0, 0.0, 0.0)` — pitch 70° down
    - `height_offset: 0.0`
    - `enable_dof: false`

3. **`res://data/camera_settings/topdown.tres`**
    - `id: 3`, `display_name: "Top-down"`
    - `min_distance: 14.0`, `max_distance: 22.0`, `initial_distance: 18.0`
    - `rotation_angles: Vector3(-90.0, 0.0, 0.0)` — pitch 90° down (pure overhead)
    - `height_offset: 0.0`
    - `enable_dof: false`

**Acceptance criteria:**
- [ ] All three `.tres` files exist and load in the inspector showing the correct values.
- [ ] `id`s are 1/2/3 and unique.
- [ ] Camera resources subfolder created at `res://data/camera_settings/`.

**Autonomy note:** These are starting values. Phase 2 verification (T17) playtest may show the framing is wrong — adjust by tuning the `.tres`, not by hardcoding fallbacks in the rig. The whole point of Resource-driven data is the designer (you, the user, in playtests) iterates on `.tres` without touching code.

---

## P2-T07 — `BattleCamera` rig

**Goal:** A proper camera rig replacing Phase 1's `BattleCamera → Pivot → Camera3D` placeholder. Adds preset cycling, smooth tween transitions, signal emission on mode changes, per-preset `user_distance` memory.

**Read first:**
- `docs/gdd.md` §10.5 (the architecture diagram, post-T01 edit)
- `docs/tactical_rpg_design_reference.md` §13 (the camera datamine — the pivot rig pattern)
- `scenes/battle/battle.tscn` — the existing `BattleCamera/Pivot/Camera3D` structure

**File:** `res://scripts/battle/view/battle_camera.gd` (new) attached to the `BattleCamera` node in `battle.tscn`.

**Class shape:**

```gdscript
class_name BattleCamera extends Node3D
## Camera rig with multiple presets and tweened transitions.
## See docs/gdd.md §6.3, §10.5 (post-T01 edits).

@export var settings: Array[CameraSetting] = []
## Per-preset zoom remembered across cycles. Index matches `settings`.
var _user_distances: PackedFloat32Array = PackedFloat32Array()
var _current_index: int = 0
var _transitioning: bool = false

@onready var _pivot: Node3D = $Pivot
@onready var _camera: Camera3D = $Pivot/Camera3D

signal preset_changed(new_index: int, new_setting: CameraSetting)
signal preset_transition_complete(new_index: int)

func _ready() -> void:
    if settings.is_empty():
        push_error("BattleCamera has no presets — assign Tactical/Overview/Top-down in inspector")
        return
    _user_distances.resize(settings.size())
    for i in settings.size():
        _user_distances[i] = settings[i].initial_distance
    _apply_setting_instant(0)

# --- Public API ---

func cycle_to_next(duration := 0.4) -> void:
    if _transitioning: return
    set_setting_index((_current_index + 1) % settings.size(), duration)

func set_setting_index(index: int, duration := 0.4) -> void:
    if _transitioning or index == _current_index: return
    _transitioning = true
    _current_index = index
    _animate_to(settings[index], _user_distances[index], duration)

func focus_on(world_position: Vector3, duration := 0.3) -> void:
    var tween := create_tween()
    tween.tween_property(self, "position", world_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func focus_on_unit(unit: CharacterUnit, duration := 0.3) -> void:
    if unit == null: return
    focus_on(Vector3(unit.grid_position.x, 0.0, unit.grid_position.y), duration)

# --- Internals ---

func _apply_setting_instant(index: int) -> void:
    var s := settings[index]
    _pivot.rotation_degrees = s.rotation_angles
    _camera.position = Vector3(0, 0, -s.initial_distance)
    _user_distances[index] = s.initial_distance
    _current_index = index
    preset_changed.emit(index, s)

func _animate_to(setting: CameraSetting, distance: float, duration: float) -> void:
    var tween := create_tween().set_parallel()
    tween.tween_property(_pivot, "rotation_degrees", setting.rotation_angles, duration).set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(_camera, "position:z", -distance, duration).set_trans(Tween.TRANS_CUBIC)
    preset_changed.emit(_current_index, setting)
    await tween.finished
    _transitioning = false
    preset_transition_complete.emit(_current_index)
```

**Steps:**

1. Create `battle_camera.gd` as above.
2. Attach the script to `BattleCamera` in `battle.tscn`.
3. In the inspector, populate the `settings` array with the three `CameraSetting.tres` from T06 (Tactical at index 0).
4. Update `BattleManager._setup_camera` (currently does a hardcoded `look_at`): remove the manual look_at; instead, position the rig at the board center (its `position` is the pivot point — moving it pans the camera). The rig itself orients via `_pivot.rotation_degrees`, set by `_apply_setting_instant`.

**Acceptance criteria:**
- [ ] `BattleCamera` node has the script attached and the three settings populated.
- [ ] On scene load, the camera is at Tactical preset (50° pitch, 12u distance).
- [ ] `cycle_to_next(0.4)` smoothly transitions to Overview, then Top-down, then back.
- [ ] During a transition, calling `cycle_to_next` again is rejected (no double-tween).
- [ ] `focus_on(Vector3(5, 0, 5))` smoothly pans to that position.
- [ ] `preset_changed` and `preset_transition_complete` signals fire correctly.

**Autonomy note:** If you find the `_camera.position.z` tween produces wrong-direction motion (the camera flying through the pivot), invert the sign — Godot 4's local-Z conventions can bite. Test by calling `cycle_to_next` and watching that the camera moves *farther* away when going to the Overview preset (which has higher distance).

---

## P2-T08 — Tab cycles, F focuses

**Goal:** Bind keyboard shortcuts to the camera rig. Tab cycles presets. F focuses on the currently-selected unit (if any).

**Read first:**
- `docs/gdd.md` §6.3 ("Camera input" subsection)

**Steps:**

1. Open Project Settings → Input Map. Add two actions:
    - `camera_cycle` → bound to physical key `Tab`.
    - `camera_focus_unit` → bound to physical key `F`.
2. New file: `res://scripts/battle/input/camera_input_controller.gd`. A `Node` script attached as a child of `BattleScene`. Reads `camera_cycle` and `camera_focus_unit` actions in `_unhandled_input`. References `BattleCamera` via exported NodePath, `PlayerPhaseController` via NodePath (to read the currently-selected unit).
    - On `camera_cycle`: call `_camera.cycle_to_next()`.
    - On `camera_focus_unit`: if `_player_phase` has a selected unit, call `_camera.focus_on_unit(<that unit>)`.
3. Wire it into `battle.tscn` as a sibling of `TileInputController`.

**Acceptance criteria:**
- [ ] Pressing Tab during gameplay cycles the camera through Tactical → Overview → Top-down → Tactical.
- [ ] Pressing F during gameplay (with a unit selected via the action menu) snaps the camera to that unit.
- [ ] Pressing F with no unit selected is a no-op.

**Autonomy note:** Proceed. If `_player_phase._selected` is private (underscore prefix), expose a public `get_selected_unit() -> CharacterUnit` accessor on `PlayerPhaseController` rather than reaching into the underscore. Light refactor; matches the encapsulation conventions in `CLAUDE.md`.

---

## P2-T09 — `SpriteFrames` resources for warrior + skeleton

**Goal:** Convert the user-provided pre-split PNG strips into `SpriteFrames` Godot resources. Each strip is one animation, one direction, frames laid out left-to-right at 32×32 per frame. Much simpler than slicing multi-row sheets.

**Read first:**
- Godot 4 docs on `SpriteFrames` and `AnimatedSprite3D`
- `docs/gdd.md` §6.1

**File mapping (warrior):**

| File | Animation name | Loop? | FPS | Notes |
|---|---|---|---|---|
| `Idle.png` | `idle` | yes | 6 | Default standing |
| `Walk.png` | `walk` | yes | 10 | Plays during MoveCommand tween |
| `Attack01.png` | `attack` | no | 12 | Default attack |
| `Attack02.png` | `attack_alt` | no | 12 | Reserved for skill-based attacks (Phase 4+) |
| `Hurt.png` | `hit` | no | 10 | Animation name matches GDD §6.1 spec, file is Hurt |
| `Death.png` | `death` | no | 8 | Plays before despawn |

**File mapping (skeleton):**

| File | Animation name | Loop? | FPS | Notes |
|---|---|---|---|---|
| `Idle.png` | `idle` | yes | 6 | |
| `Walk.png` | `walk` | yes | 10 | |
| `Attack.png` | `attack` | no | 12 | Skeleton has no `attack_alt` |
| `Hurt.png` | `hit` | no | 10 | Animation name matches GDD §6.1 spec |
| `Death.png` | `death` | no | 8 | |

**Steps:**

1. For each PNG strip, determine the frame count by dividing the image width by 32. (e.g. a 192-pixel-wide PNG = 6 frames at 32px each.) Use `execute_editor_script` if needed to read the texture dimensions programmatically, or check via the import dock.
2. Create `res://art/sprites/warrior/warrior.tres` as a `SpriteFrames` resource.
3. For each warrior animation, add an entry to the SpriteFrames with the corresponding name and FPS. Then load the PNG and add each frame from a horizontal slice at `(frame_index * 32, 0, 32, 32)`. Use `AtlasTexture` for each frame so the same source PNG is reused.
4. Set the `Loop` flag on `idle` and `walk`; clear it on `attack`, `attack_alt`, `hit`, `death`.
5. Repeat for `res://art/sprites/skeleton/skeleton.tres` (no `attack_alt`).
6. Verify each animation visually by previewing it in the SpriteFrames editor inspector, OR by writing a quick test scene with an `AnimatedSprite3D` cycling through them.

**Acceptance criteria:**
- [ ] `warrior.tres` exists with 6 animations: idle, walk, attack, attack_alt, hit, death.
- [ ] `skeleton.tres` exists with 5 animations: idle, walk, attack, hit, death.
- [ ] Each animation's frames map correctly to the source PNG frames (no garbled output).
- [ ] Loop flags are correct (idle/walk loop; others one-shot).
- [ ] FPS values match the table.

**Autonomy note:** The user has done the hard pre-split work, so this should be mechanical. If a PNG's width isn't an exact multiple of 32 (suggesting a different frame size or padding), surface and ask before guessing. Don't fabricate frame counts.

---

## P2-T10 — `UnitView3D` rewrite: AnimatedSprite3D billboard + outline

**Goal:** Replace the Phase 1 `MeshInstance3D` capsule with an `AnimatedSprite3D` billboard playing the appropriate sprite animation. Add an outline shader so units pop against the grass.

**Read first:**
- `docs/gdd.md` §6.1
- `docs/tactical_rpg_design_reference.md` §2 (Godot implementation sketch — Sprite3D billboarding)
- The current `scripts/battle/view/unit_view_3d.gd`

**Files:**

1. **Rewrite `scripts/battle/view/unit_view_3d.gd`:**

```gdscript
class_name UnitView3D extends Node3D
## Visual representation of a CharacterUnit using an AnimatedSprite3D billboard.
## Phase 2: pixel sprite + outline shader. See docs/gdd.md §6.1.

const Y_OFFSET: float = 0.5  # so sprite stands on top of the ground, not embedded

@export var unit: CharacterUnit
## SpriteFrames for this unit's team. Set by the spawner (BattleManager) at instantiation.
@export var sprite_frames_resource: SpriteFrames

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var _hp_label: Label3D = $HPLabel
@onready var _shadow: Decal = $Shadow  # cheap circular shadow under the sprite

signal animation_complete

func _ready() -> void:
    if unit == null:
        push_error("UnitView3D has no unit assigned")
        return
    if sprite_frames_resource != null:
        _sprite.sprite_frames = sprite_frames_resource
    unit.moved.connect(_on_moved)
    unit.hp_changed.connect(_on_hp_changed)
    unit.died.connect(_on_died)
    unit.facing_changed.connect(_on_facing_changed)
    if unit.has_signal("attacked"):
        unit.attacked.connect(_on_attacked)
    position = Vector3(unit.grid_position.x, Y_OFFSET, unit.grid_position.y)
    _refresh_visual()
    play("idle")

func _refresh_visual() -> void:
    _hp_label.text = "%s\n%d/%d" % [unit.display_name, unit.current_hp, unit.max_hp]
    # Flip horizontally if facing west (negative X). See GDD §6.1.
    _sprite.flip_h = unit.facing.x < 0

func play(anim_name: String) -> void:
    if _sprite.sprite_frames == null:
        return
    if not _sprite.sprite_frames.has_animation(anim_name):
        push_warning("UnitView3D: missing animation '%s' on %s" % [anim_name, unit.display_name])
        return
    _sprite.play(anim_name)

# --- Signal handlers ---

func _on_moved(_from: Vector2i, to: Vector2i) -> void:
    # Phase 2 T11 implements tween + walk animation. This stub keeps Phase 1's
    # behavior so that order-of-implementation doesn't break.
    position = Vector3(to.x, Y_OFFSET, to.y)

func _on_facing_changed(_new_facing: Vector2i) -> void:
    _refresh_visual()

func _on_hp_changed(old_hp: int, new_hp: int) -> void:
    _hp_label.text = "%s\n%d/%d" % [unit.display_name, unit.current_hp, unit.max_hp]
    # T12 wires up the hit animation here.

func _on_attacked(_target) -> void:
    pass  # T12 wires up the attack animation.

func _on_died() -> void:
    # T12 wires up: play death, await completion, then queue_free.
    queue_free()
```

2. **Update `unit_view_3d.tscn`:**
    - Replace the `Mesh: MeshInstance3D` (capsule) child with `AnimatedSprite3D` named `AnimatedSprite3D`. Set `billboard = BILLBOARD_Y` (Y-axis only — no pitch tilt). Set `texture_filter = NEAREST`. Set `pixel_size = 0.03125` (so a 32×32 sprite is 1 world unit tall).
    - Keep the `HPLabel: Label3D`. Move it to ~1.5 units above origin so it sits above the sprite.
    - Add a `Shadow: Decal` child as a soft circular shadow under the sprite. Use a CC0 circle gradient texture from Kenney or a procedural one if Kenney doesn't bundle one.

3. **Update `BattleManager._spawn_unit`** to set `sprite_frames_resource` based on team:
    - Player team (0): load `res://art/sprites/warrior/warrior.tres`
    - Enemy team (1): load `res://art/sprites/skeleton/skeleton.tres`

4. **Add `signal attacked(target: CharacterUnit)` to `CharacterUnit`** (T12 will fire it from AttackCommand). Adding it now keeps T10 self-consistent.

5. **Outline shader.** Create `res://shaders/sprite_outline.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, blend_mix;

uniform sampler2D albedo : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 4.0) = 1.0;
uniform vec2 sprite_pixel_size = vec2(32.0, 32.0);

void fragment() {
    vec4 c = texture(albedo, UV);
    if (c.a > 0.5) {
        ALBEDO = c.rgb;
        ALPHA = c.a;
    } else {
        // Sample 4 cardinal neighbors at outline_thickness pixel distance.
        vec2 px = outline_thickness / sprite_pixel_size;
        float n = texture(albedo, UV + vec2(px.x, 0.0)).a
                + texture(albedo, UV + vec2(-px.x, 0.0)).a
                + texture(albedo, UV + vec2(0.0, px.y)).a
                + texture(albedo, UV + vec2(0.0, -px.y)).a;
        if (n > 0.0) {
            ALBEDO = outline_color.rgb;
            ALPHA = outline_color.a;
        } else {
            discard;
        }
    }
}
```

Apply this as a `ShaderMaterial` on `AnimatedSprite3D.material_override`. Tune `outline_thickness` to taste — `1.0` is a good starting value.

**Acceptance criteria:**
- [ ] Player unit shows the warrior idle animation, with a 1-pixel black outline.
- [ ] Enemy unit shows the skeleton idle animation, mirrored (flipped horizontally, since they face west).
- [ ] HP label is readable above each sprite.
- [ ] A subtle circular shadow is visible under each sprite.
- [ ] Sprites stay crisp (nearest filter), Kenney models stay smooth (linear filter).
- [ ] At any camera preset (Tactical / Overview / Top-down), sprites face the camera correctly (Y-billboard).
- [ ] `attacked` signal added to CharacterUnit (used by T12).

**Autonomy note:** If the outline shader produces artifacts at sprite-sheet edges (sampling into transparent regions of the AtlasTexture frame), tune by reducing `outline_thickness` or by using per-frame UV bounds. The pre-split PNGs help here — each animation is its own image, so the shader's neighbor-sampling within UV bounds is cleaner than it would be on a multi-row atlas.

---

## P2-T11 — Move animation: tween + walk

**Goal:** When a unit moves, the view tweens the sprite along the path (instead of teleporting), playing the walk animation during traversal and reverting to idle on arrival. The `MoveCommand.execute` returns synchronously as before, but the *view* takes a real-world ~0.6–1.2 seconds to play out.

**Read first:**
- The current `MoveCommand.execute` (synchronous mutation)
- The current `UnitView3D._on_moved` (instant teleport)

**The async problem.** Phase 1's command lifecycle is fully synchronous. Phase 2 introduces the **command-execution-awaits-view-animation pattern**, but only at the orchestration layer — `Command.execute` itself stays synchronous (mutates state, fires signals, done in microseconds). The *view* listens to the local `moved` signal and tweens visually. Other systems that need to wait (e.g. AI between enemy turns, or `PlayerPhaseController` re-showing the menu) `await` the new `UnitView3D.animation_complete` signal added in T10.

**Implementation:**

1. **Add a `last_move_path` field on `CharacterUnit`** (a small leak of view concerns into the gameplay node — documented in CLAUDE.md as acceptable for view-driven needs):

```gdscript
# CharacterUnit
var last_move_path: Array[Vector2i] = []
```

2. **Update `MoveCommand.execute`** to set this before emitting `moved`:

```gdscript
func execute() -> void:
    var origin_tile := board.get_tile(_origin)
    var dest_tile := board.get_tile(destination)
    origin_tile.occupant_id = -1
    dest_tile.occupant_id = unit.unit_id
    unit.grid_position = destination
    unit.last_move_path = _path.duplicate()  # NEW
    if _path.size() >= 2:
        unit.facing = _path[-1] - _path[-2]
        unit.facing_changed.emit(unit.facing)
    unit.moved.emit(_origin, destination)
```

3. **Rewrite `UnitView3D._on_moved`** to walk along the path:

```gdscript
const STEP_DURATION: float = 0.15  # seconds per tile-step

func _on_moved(_from: Vector2i, to: Vector2i) -> void:
    var path := unit.last_move_path
    if path.is_empty() or path.size() == 1:
        position = Vector3(to.x, Y_OFFSET, to.y)
        animation_complete.emit()
        return
    play("walk")
    var tween := create_tween()
    # Skip the origin (path[0]) — we're already there.
    for i in range(1, path.size()):
        var step_pos := Vector3(path[i].x, Y_OFFSET, path[i].y)
        tween.tween_property(self, "position", step_pos, STEP_DURATION).set_trans(Tween.TRANS_LINEAR)
    await tween.finished
    play("idle")
    animation_complete.emit()
```

4. **Update `PlayerPhaseController._resolve_move`** to await the view animation before re-showing the menu. Add a helper on `BattleManager` first:

```gdscript
# BattleManager — track view per unit_id at spawn time
var _views_by_unit_id: Dictionary = {}

# In _spawn_unit, after instantiating the view:
_views_by_unit_id[id] = view

func get_view_for(unit_id: int) -> UnitView3D:
    return _views_by_unit_id.get(unit_id)
```

Then update `PlayerPhaseController._resolve_move`:

```gdscript
func _resolve_move(grid: Vector2i) -> void:
    var ok := CommandQueue.submit(MoveCommand.new(_manager.board, _selected, grid))
    _board_view.clear_highlights()
    if ok and not _selected.has_acted:
        # Await the visual move so the menu doesn't pop while the unit's mid-stride.
        var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
        if view != null:
            await view.animation_complete
        _select_unit(_selected)
    else:
        _to_idle()
    _maybe_end_phase()
```

5. **Update `AIController._act`** to also await the move animation between commands:

```gdscript
# After CommandQueue.submit(MoveCommand.new(...)):
var view: UnitView3D = manager.get_view_for(enemy.unit_id)
if view != null:
    await view.animation_complete
# Then continue with the post-move attack check.
```

**Acceptance criteria:**
- [ ] When the player moves a unit, the sprite walks along the path over ~0.6–1.2 seconds (3-step paths take ~0.45s, 8-step ~1.2s), playing the walk animation, and reverts to idle on arrival.
- [ ] The action menu reappears after the visual move completes, not before.
- [ ] During the enemy phase, enemies walk one at a time — the camera doesn't visibly hang.
- [ ] All Phase 1 GUT tests still pass — they don't depend on view animation timing.
- [ ] No errors in the console.

**Autonomy note:** The `unit.last_move_path` field is a deliberate small leak of view concerns into the gameplay node. The cleaner alternative — passing the path via a custom signal payload — was considered. Either is fine; document the choice. If you find a third cleaner option that doesn't add a field to CharacterUnit, surface it.

---

## P2-T12 — Attack / hit / death animations

**Goal:** Combat plays animations. Attacker plays `attack`, defender plays `hit`, on lethal damage defender plays `death` and despawns. The view-await pattern holds the next AI step until the animations resolve.

**Read first:**
- T11's view-animation pattern
- The current `AttackCommand.execute` and `CharacterUnit.take_damage`

**Steps:**

1. **`AttackCommand.execute` fires the new `attacked` signal** before damage resolves. After the existing `attack_resolving` emit and before `take_damage`:

```gdscript
attacker.attacked.emit(target)
target.take_damage(final_damage, attacker.main_weapon)
# ...rest of the command...
```

2. **`UnitView3D._on_attacked` plays the attack animation:**

```gdscript
func _on_attacked(_target: CharacterUnit) -> void:
    play("attack")
    if _sprite.sprite_frames.has_animation("attack"):
        await _sprite.animation_finished
        if is_instance_valid(unit) and unit.is_alive():
            play("idle")
    animation_complete.emit()
```

3. **`UnitView3D._on_hp_changed` plays the hit animation on damage** (not on heal):

```gdscript
func _on_hp_changed(old_hp: int, new_hp: int) -> void:
    _hp_label.text = "%s\n%d/%d" % [unit.display_name, unit.current_hp, unit.max_hp]
    if new_hp < old_hp and new_hp > 0 and _sprite.sprite_frames.has_animation("hit"):
        play("hit")
        await _sprite.animation_finished
        if is_instance_valid(unit) and unit.is_alive():
            play("idle")
```

4. **`UnitView3D._on_died` plays the death animation before despawn:**

```gdscript
func _on_died() -> void:
    if _sprite.sprite_frames.has_animation("death"):
        play("death")
        await _sprite.animation_finished
    animation_complete.emit()
    queue_free()
```

5. **Sequencing the AI step.** In `AIController._act`, after submitting an `AttackCommand`, await the attacker's view animation:

```gdscript
# After CommandQueue.submit(AttackCommand.new(...)):
var attacker_view: UnitView3D = manager.get_view_for(enemy.unit_id)
if attacker_view != null:
    await attacker_view.animation_complete
# Add a small extra beat so consecutive enemies don't feel rushed:
await get_tree().create_timer(0.3).timeout
```

6. **Same pattern for player attacks.** Update `PlayerPhaseController._resolve_attack`:

```gdscript
func _resolve_attack(target: CharacterUnit) -> void:
    CommandQueue.submit(AttackCommand.new(_manager.board, _selected, target))
    _board_view.clear_highlights()
    var view: UnitView3D = _manager.get_view_for(_selected.unit_id)
    if view != null:
        await view.animation_complete
    _to_idle()
    _maybe_end_phase()
```

**Acceptance criteria:**
- [ ] Player attack: attacker plays attack animation, target plays hit, HP drops, both return to idle.
- [ ] If the attack is lethal, target plays death animation, then despawns. The dead sprite is gone before the next turn.
- [ ] Enemy attacks animate the same way during enemy phase.
- [ ] `BattleLogService` still receives all the right bus signals — animation timing doesn't drop events.
- [ ] All Phase 1 GUT tests still pass.

**Autonomy note:** The `attacked` signal is the cleanest way to trigger view-side attack animation without polluting the bus. If you find a cleaner way (e.g. the attacker's view listens to `damage_dealt` on the bus and filters where `attacker == self`), surface — but `attacked` keeps the local-vs-bus separation that the rest of the code uses.

---

## P2-T13 — Damage popup VFX

**Goal:** When damage is dealt, a floating number appears above the target sprite, rises a bit, fades over ~0.8s, and despawns. Standard SRPG flourish. Pure view-layer; no gameplay impact.

**Read first:**
- Godot 4 docs on `Label3D` and `Tween`

**Files:**

1. **`res://scenes/battle/vfx/damage_popup.tscn`**: a `Label3D` root with billboard-Y, font-size moderate, outline color black, no_depth_test on.
2. **`res://scenes/battle/vfx/damage_popup.gd`** (`class_name DamagePopup extends Label3D`):

```gdscript
class_name DamagePopup extends Label3D

func setup(amount: int, world_position: Vector3) -> void:
    text = str(amount)
    position = world_position + Vector3(0, 1.5, 0)
    modulate = Color.WHITE
    var tween := create_tween().set_parallel()
    tween.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
    await tween.finished
    queue_free()
```

3. **A small spawner.** Add a Node child of BattleScene named `VfxLayer`. Listens to `CombatEventBus.damage_dealt` and spawns a `DamagePopup` at the defender's world position:

```gdscript
# vfx_layer.gd
extends Node3D

func _ready() -> void:
    CombatEventBus.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(_attacker, defender: Node, damage: int, _source) -> void:
    if defender == null: return
    var unit := defender as CharacterUnit
    if unit == null: return
    var pos := Vector3(unit.grid_position.x, 0.5, unit.grid_position.y)
    var popup: DamagePopup = preload("res://scenes/battle/vfx/damage_popup.tscn").instantiate()
    add_child(popup)
    popup.setup(damage, pos)
```

Recommend the Node path over an autoload — VfxLayer is scene-scoped, Phase 5's EXP popups will reuse the same pattern, and it's cleaner to have one VfxLayer per battle.

**Acceptance criteria:**
- [ ] Damage popup appears above the target unit on each attack.
- [ ] Number floats up ~1.5 units over 0.8 seconds.
- [ ] Number fades to transparent before despawning.
- [ ] No errors when multiple popups overlap.

**Autonomy note:** Proceed.

---

## P2-T14 — Grid overlay toggleable; auto-shows during targeting

**Goal:** The grid is hidden by default during gameplay (so the world looks like the Aster screenshots — no grid lines covering the grass). When the player enters move-targeting or attack-targeting state, the grid fades in along with the highlights. When targeting ends, it fades out.

**Read first:**
- `scripts/battle/input/player_phase_controller.gd` — the state machine
- `BoardView3D.set_grid_visible` (added in T05)

**Steps:**

1. Update `PlayerPhaseController._on_move_chosen` and `_on_attack_chosen` to call `_board_view.set_grid_visible(true)` before showing highlights.
2. Update the `_board_view.clear_highlights()` calls (in `_resolve_move`, `_resolve_attack`, `_to_idle`) to also call `_board_view.set_grid_visible(false)`.
3. (Optional polish) Make `set_grid_visible` tween the grid-overlay's `material_override.albedo_color.a` rather than just toggling visible, for a soft fade.
4. (Optional polish) Add a debug toggle so the user can pin the grid always-on for development. Either an exported bool on `BoardView3D` or a key shortcut (`G`).

**Acceptance criteria:**
- [ ] On scene load, grid is hidden.
- [ ] Selecting a unit and choosing Move makes the grid visible.
- [ ] Committing the move (or canceling) hides the grid.
- [ ] Grid is also hidden during the enemy phase.
- [ ] If the optional always-on debug toggle is implemented, it works.

**Autonomy note:** Proceed.

---

## P2-T15 — Camera focuses on active unit on `turn_started`

**Goal:** When a unit's turn starts (player or enemy), the camera smoothly pans to focus on them. Phase 1 had the camera fixed; Phase 2 introduces dynamic camera-on-unit per GDD §4.3 ("camera focuses on unit").

**Read first:**
- `docs/gdd.md` §4.3
- Phase 2's `BattleCamera.focus_on_unit`

**Steps:**

1. Extend `BattleManager` (or add a small connector node — extending the manager is fine since this is a thin connection): listen to `CombatEventBus.turn_started` and call `_battle_camera.focus_on_unit(unit, 0.4)`.
2. **Only focus during enemy phase.** Player phase, the user is selecting units manually — auto-focus would fight that. Add the gating:

```gdscript
func _on_turn_started(unit: CharacterUnit) -> void:
    if current_phase == Phase.ENEMY and _battle_camera != null:
        _battle_camera.focus_on_unit(unit, 0.4)
```

**Acceptance criteria:**
- [ ] On enemy phase, the camera follows each enemy as their turn begins.
- [ ] Player phase does not auto-focus (the user controls it via F).
- [ ] Camera focus motion is smooth (cubic ease, ~0.4s).

**Autonomy note:** If "follow enemy as they act" feels too aggressive in playtest (camera bouncing between enemies), reduce to "focus only on the first enemy that acts" or add a 0.5s cooldown between focus calls. Tunable; don't over-engineer.

---

## P2-T16 — Update tests for the new view layer

**Goal:** All Phase 1 tests still pass. Add 2 tests specifically for view-layer concerns where they're testable headlessly.

**Read first:**
- `tests/test_helpers.gd` and the existing 9 Phase 1 test files

**Steps:**

1. Run the existing GUT suite. Expect: all 34 Phase 1 tests still pass. If any fail, the view-layer changes have leaked into gameplay code — fix the leak.
2. Add `tests/test_camera_setting.gd`: load each of the three `CameraSetting.tres` files; assert `id` and `display_name` are correct; assert `rotation_angles.x` is approximately -50 / -70 / -90.
3. Add `tests/test_unit_view_signals.gd`: instantiate a CharacterUnit, deal damage, verify the local `hp_changed` signal fires with correct old/new payload (so UnitView3D can react). Trivial coverage but proves the contract.
4. Optionally `tests/test_battle_camera.gd`: instantiate a `BattleCamera` standalone, populate `settings`, call `set_setting_index(1, 0.0)` (instant transition), assert `_current_index == 1`. Don't test the tween itself — too async, fragile.

**Acceptance criteria:**
- [ ] All 34 Phase 1 tests still pass.
- [ ] At least 2 new test files added.
- [ ] Total Phase 2 test count ≥ 36.

**Autonomy note:** Don't try to test sprite rendering or animation playback in headless mode — Godot's GUT can't really verify visual output. Test the data contracts (resources, signals) and trust the manual playtest in T17 for visual correctness.

---

## P2-T17 — Phase 2 verification

**Goal:** Manually playtest the slice end-to-end with the full HD-2D presentation, verify all Phase 1 functionality still works, and capture screenshots that demonstrate the visual milestone.

**Steps:**

Use MCP tools to self-verify:

1. `play_scene` to start the project.
2. `get_game_screenshot` — verify: warrior sprites for players, skeleton sprites for enemies, Kenney grass ground, trees at the periphery, sky-blue background, sun-lit. Save as `user://p2_verify_initial.png`.
3. Press Tab via `simulate_key` — `get_game_screenshot` after the transition completes. Save as `user://p2_verify_overview.png`. Camera should now show ~70° pitch.
4. Press Tab again — top-down. Save as `user://p2_verify_topdown.png`. Verify sprites still read at 90° pitch.
5. Press Tab a third time — back to tactical.
6. Click a player unit → menu → Move → click a tile → verify the unit walks (animated) and the menu reappears after.
7. Click again → Attack → enemy → verify attack animation, hit animation on target, damage popup, HP drop. Save `user://p2_verify_combat.png`.
8. Continue play to end battle. Verify victory screen still works.
9. Run all GUT tests via headless CLI — confirm all pass.
10. `get_editor_errors` — no errors.

**Verification checklist:**

- [ ] HD-2D look achieved: pixel sprites + smooth Kenney ground + soft lighting + bloom.
- [ ] All three camera presets work, transitions smooth.
- [ ] Compare final screenshots side-by-side with docs/references/aster_screenshots/ and flag any major visual deviation.
- [ ] Tab cycles, F focuses on selected unit.
- [ ] Move animation: sprite walks along path, plays walk animation.
- [ ] Attack animation: attacker plays attack, target plays hit / death, damage popup appears.
- [ ] Grid overlay hidden by default, shows during targeting.
- [ ] Camera focuses on active unit during enemy phase.
- [ ] All Phase 1 tests still pass.
- [ ] No console errors.
- [ ] `docs/PROGRESS.md` updated with Phase 2 marked complete and pending review.

**Acceptance criteria:**
- [ ] All checklist items pass.
- [ ] User notified that Phase 2 is ready for review.

**Important:** Do NOT make any git commits. The user will review changes in Sourcetree and commit at their discretion.

**Autonomy note:** Stop and report after T17. Phase 3 is a separate task file. If the visual result doesn't match the *Aster Tatariqus* reference screenshots well — sprites look weird against the grass, lighting feels off, camera framing is wrong — **flag it rather than declaring Phase 2 done**. Visual polish is iterative; better to flag a "needs another pass" than to pretend the placeholder result is the target.

---

## Phase 2 NOT-doing list

These would be scope creep. Don't do them in Phase 2 even if you "could easily."

- ❌ Final art (48×48 / 64×64 chibi sprites in Aster's actual style). Post-vertical-slice.
- ❌ Per-character art variants beyond warrior + skeleton. Phase 2 spawns 4 units total, all using these two sprite resources (warrior×2 for players, skeleton×2 for enemies).
- ❌ Facing arrow decal on the ground under units. Phase 5 (alongside facing damage modifiers).
- ❌ N/S sprite variants. Single-direction (E + flip) only, per GDD §6.1.
- ❌ Custom map / battle map authoring. Phase 14.
- ❌ Multi-tile units (Large Boss). Post-v1.
- ❌ Depth of field, screen shake, hit-stop, particle VFX. Phase 9 / Phase 17.
- ❌ Sound or music. Post-vertical-slice.
- ❌ HUD overhaul (turn counter, fast-forward, settings buttons). Phase 4 / 16.
- ❌ Camera pan via mouse-drag or WASD. Phase 9.
- ❌ Camera zoom via scroll wheel. Phase 9.
- ❌ Per-unit camera focus on player phase (only on enemy phase per T15). Phase 9 if desired.
- ❌ Snapshot rollback / rewind UI. Phase 3.
- ❌ Simulator extraction. Phase 3.
- ❌ Component refactor of CharacterUnit. Phase 3.
- ❌ Status effects, elements, types. Phases 5, 12, 13.
- ❌ Per-action EXP. Phase 5.
- ❌ Sub weapons, durability, weapon-switch. Phase 4.
- ❌ Bond, Duo, Bond Action. Phases 5, 6, 7.

If you find yourself writing code that does any of the above, stop. Leave a `# TODO(phase X)` and move on.

---

## What "Phase 2 done" looks like

When you've completed P2-T01 through P2-T17, you should have:

- A playable battle that visually approaches the *Aster Tatariqus* reference: pixel chibi sprites on a smoothly-shaded 3D world, soft lighting, gentle bloom, three camera presets cycling on Tab.
- Movement and combat animate properly. The visual layer feels like an SRPG, not a tech demo.
- The GDD has been brought in line with the actual visual direction (HD-2D explicitly named, three camera presets matching the references).
- Phase 1's gameplay still works perfectly. All tests pass.
- The architecture from Phase 1 is unchanged in shape — view-side only. CharacterUnit, Board, Commands, BattleManager, BattleLogService all unchanged in their core responsibilities. The view-await pattern (`await view.animation_complete`) is the only new orchestration mechanism. The two minor touches to gameplay code — adding `last_move_path: Array[Vector2i]` and `signal attacked(target)` to CharacterUnit — are deliberate, documented view affordances.

This is the phase that makes the project look like a real game for the first time. It also builds confidence in the architecture: the gameplay layer staying mostly untouched while the view gets a major overhaul *is the architecture working*.

If at the end of Phase 2 you find yourself wanting to start refactoring `CharacterUnit` for the simulator extraction or wiring up rollback — resist. Phase 3 is the right place. Phase 2's gift is leaving the gameplay layer alone.

---

*End of phase_2_tasks.md.*
