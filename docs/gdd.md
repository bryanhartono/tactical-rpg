# Game Design Document
## *[Working Title: TBD]* — Tactical RPG

| | |
|---|---|
| **Document version** | 0.1 (engineering kickoff draft) |
| **Date** | May 4, 2026 |
| **Audience** | Senior Godot developer joining the project |
| **Companion document** | `tactical_rpg_design_reference.md` — research deep-dive into Aster Tatariqus, the primary design reference |
| **Engine** | Godot 4 (latest stable at implementation time) |
| **Primary platforms** | macOS (M1 dev target), Windows desktop. Mobile considered post-vertical-slice. |
| **Primary scripting language** | GDScript |
| **Source control** | Git (host TBD) |

---

## 0. Read this first

This GDD specifies a **single-player tactical RPG** with grid combat, pixel-art-on-3D-terrain presentation, and a paired-unit ("Duo") combat mechanic. The design is closely modelled on *Aster Tatariqus* (Studio FgG / gumi, JP-only mobile, 2023–2024) — a shipped, well-architected SRPG whose source is available via decompilation. The companion reference document captures architectural patterns lifted from that source.

Three things to set expectations:

1. **This is a grid-combat-first project.** No story-mode metagame, no academy life sim, no gacha, no world map. The first 6 milestones build a tight, replayable tactical core. Story/campaign content comes later, if at all.
2. **The architectural backbone is non-negotiable.** Six principles in §10 are load-bearing for the rest of the design. They've been validated against the Aster source; deviation needs explicit discussion.
3. **The companion reference is authoritative on patterns; this GDD is authoritative on scope.** When the two conflict, this document wins.

---

## 1. Vision and pillars

### 1.1 Elevator pitch
A single-player tactical RPG with the satisfying grid combat of *Final Fantasy Tactics*, the tile-by-tile readability of pixel sprites, the kinetic camera of modern 2.5D, and a paired-unit ("Duo") mechanic that turns the genre's classic "two adjacent allies" trope into a deliberate, switchable formation.

### 1.2 Design pillars

**Pillar 1 — Every action is a decision.** No filler turns. Movement, attack target, weapon choice, facing, pair-up, separation — each has a tactical consequence the player can reason about. We earn complexity by making each layer's decision visible.

**Pillar 2 — Loadout is identity.** A unit's effective role is computed from Style × Main Weapon × Sub Weapon. A "healer" with an offensive sub-weapon is meaningfully different from one without. Players express character through equipment, not just class.

**Pillar 3 — Pixel sprites, kinetic world.** Sprites are pixel-art chibi billboards on real 3D terrain with corner-height variation. Multi-mode camera shifts framing and pitch between presets to keep the visual experience fresh without breaking the side-profile sprite convention. The contrast — flat pixel character on living 3D ground — is the visual identity.

The technique is commonly called **HD-2D** — high-definition 2D, popularized by *Octopath Traveler* and seen in *Triangle Strategy* and *Aster Tatariqus*. Sprites are crisply pixel-art (nearest-neighbor filtering, no anti-aliasing) while the world around them is smoothly-shaded 3D (linear filtering, MSAA, ambient lighting, bloom).

**Pillar 4 — Forgiving but punishing.** Three rewinds per battle (snapshot-based). Every turn matters, but a misclick or a missed math doesn't end the run. Difficulty comes from the encounter design, not from the UI.

### 1.3 Anti-pillars (what we are NOT making)
- Not a gacha. No random unit pulls, no monetization design.
- Not a roguelike. Battles are designer-authored.
- Not story-first. Narrative is scaffolding for combat scenarios; it is not the product.
- Not multiplayer. Single-player only at v1. Async PvP is a long-tail consideration, not a v1 feature.
- Not real-time. Turn-based, no time pressure inside a turn.
- Not a faithful Aster Tatariqus clone. We borrow systems and architecture; we do not copy art, characters, story, or mission content.

### 1.4 Player fantasy
"I am the commander of a small elite squad fighting outnumbered. Every battle is a puzzle: who pairs with whom, who carries which weapon, who climbs to high ground, who covers the retreat. When I win, I win because I read the field correctly."

---

## 2. Target audience and references

### 2.1 Audience
- **Primary:** SRPG genre enthusiasts familiar with *Fire Emblem*, *Final Fantasy Tactics*, *Triangle Strategy*, *Tactics Ogre*. Adults, comfortable reading numbers and managing loadouts.
- **Secondary:** Pixel-art appreciators / indie game players. May be SRPG-curious but not committed.

### 2.2 Genre references
| Game | What we take from it |
|---|---|
| *Aster Tatariqus* | Combat architecture, Duo mechanic, Bond Action, Main+Sub weapons, per-action EXP, snapshot rollback, multi-mode camera. **Primary reference.** |
| *Final Fantasy Tactics* | Facing-based damage, height system, job feel |
| *Fire Emblem* | Per-action EXP routing, weapon proficiency, Bond Action's spiritual ancestor |
| *Triangle Strategy* | Pixel sprites on 3D terrain, pacing of battles |
| *Tactics Ogre Reborn* | Modern QoL: rewind, fast forward, clean UI |

### 2.3 Out-of-scope inspirations
*Persona 5 Tactica*, *Disgaea*, *XCOM*, *Into the Breach*, *Wargroove* — all good games, deliberately not in our reference set. Each has a different design philosophy that would pull this project in conflicting directions.

---

## 3. Scope — vertical slice through v1

### 3.1 The vertical slice (target: end of Phase 6, ~6–10 weeks)

A single playable battle that demonstrates every core system:

- 6 player units deployable, 2 of which are pre-paired in a Duo at start.
- 1 enemy squad of 6–8 units with 2 distinct AI archetypes.
- Map: 20×20 grid with elevation, three terrain types (plain, forest, water/cliff), 3D environment art.
- Full Move/Attack/Skill/Duo-form/Duo-switch/Duo-release/Wait/Cancel command set.
- Bond Action (Heal + Attack variants) deterministic in Duo, probabilistic adjacent.
- Damage previews, range highlights, three rewinds.
- Camera with two presets and smooth transitions.
- One victory condition, one loss condition.

When the slice is shippable as a standalone demo, we declare Phase 6 complete and re-plan.

### 3.2 v1 (target: TBD, scope to be re-evaluated post-slice)

- 12–20 designer-authored battles forming a loose campaign.
- Roster of 12–16 unique playable units.
- 6–8 Styles (classes), 25–40 weapon variants, 30–50 skills.
- Full element / type / status systems.
- Style Board progression (post-battle character growth).
- Campaign progression (battle select screen, no overworld).
- Save/load.
- Settings, control rebinding, accessibility basics.

### 3.3 Explicitly post-v1
- Procedural battles or roguelike modes.
- New Game+.
- Difficulty modes beyond a single tuned curve.
- Steam achievements, Steamworks integration.
- Mobile port.
- Full localization beyond English.

---

## 4. Game flow

### 4.1 Top-level state machine

```
TitleScreen → MainMenu → BattleSelect → PreBattle → Battle → PostBattle → BattleSelect
                                                               └─→ MainMenu (on death)
```

For the vertical slice, only `Battle → PostBattle` is implemented. `BattleSelect` is a debug stub.

### 4.2 Battle flow

```
BattleStart
  → Deployment (player places units in deployment zones)
  → Round Loop:
      → PlayerPhase
          → for each player unit (unacted):
              → command issuance loop (move/attack/duo/etc)
          → EndPhase (auto when all units acted or player ends manually)
      → EnemyPhase
          → for each enemy unit (unacted):
              → AI selects command via AIController
      → NeutralPhase (terrain hazards, status ticks, end-of-round triggers)
      → check VictoryCondition / LossCondition
  → BattleEnd (Win or Lose)
  → PostBattle results (EXP allocation, bond gains, drops)
```

### 4.3 Per-unit turn flow

```
TurnStart
  → unit becomes the "active unit"
  → camera focuses on unit
  → command menu opens (filtered by allowed_commands flags)
  → player chooses one of: Move, Attack, Skill, SwitchWeapon, Item, Duo, ReleaseDuo, SwitchDuo, Stay
      → Move: shows reachable tiles → player picks tile → unit pathfinds to it (move budget consumed)
      → Attack: shows targetable tiles by current weapon's RangeShape → player picks target → DamagePreview shown → confirm → resolve
      → Skill: same as Attack but with skill's RangeShape and effect
      → Duo: shows adjacent allies → player picks → DuoCommand executes
      → ... etc
  → after action OR after Stay, player sets facing
  → TurnEnd: unit marked acted, signals fired, next unit
```

The menu always has a `Cancel` option that returns to the previous step (move, attack, etc) — moves are cancellable until `EndTurn` is committed.

---

## 5. Core mechanics

### 5.1 Grid and terrain

**Grid:** Square tiles. Tile size is `1.0` world units. Maps are 16×16 to 32×32 for v1.

**Tile data (per tile):**
- `landform_id` (int) — references the LandformDefinition resource.
- `corner_heights` (Vector4: NW, NE, SW, SE). Slopes between corners are linear.
- `occupant` (CharacterUnit / DuoUnit / null).
- `effects` (Array of TileEffect Resources — fire, poison, fog, etc.).

**LandformDefinition (Resource) carries per-tile gameplay data:**
- `move_cost_by_type: Dictionary[MoveType, int]` (Infantry, Cavalry, Flying, Floating, etc.)
- `stoppable_by_type: Dictionary[MoveType, bool]` — can a unit of this type END a move on this tile?
- `evasion_bonus: int`
- `defense_bonus: int`
- `on_enter_effects: Array[StatusEffect]`
- `on_turn_start_effects: Array[StatusEffect]`

**Locomotion types (8, ported from Aster):**
| Type | Mobility | Air | Notes |
|---|---|---|---|
| Infantry | 5 | no | Standard |
| Advanced Infantry | 5 | no | Higher base stats, same mobility |
| Cavalry | 7 | no | Fast on roads, slow in forests |
| Advanced Cavalry | 7 | no | |
| Flying | 6 | yes | Ignores most terrain costs |
| Advanced Flying | 6 | yes | |
| Floating | 5 | yes | Air, but infantry-speed |
| Large Boss | varies | no | Multi-tile (deferred to post-v1) |

### 5.2 Elevation

- `corner_heights` per tile (Vector4). Tiles can slope.
- Movement: pathfinder forbids edges where height delta exceeds the unit's `jump_height` stat (Infantry: 1, Cavalry: 1, Flying: ∞).
- Damage: attacking from higher ground = +15% damage; attacking up = -10%. Constants in `BattleConst`.
- Range: ranged units on higher ground get +1 effective range.
- Line of sight: tall terrain blocks LoS for ranged attacks. Implementation: simple Bresenham across grid; if any intermediate tile has `corner_heights.max() > attacker_height + 0.5`, LoS blocked.

### 5.3 Movement

- BFS / Dijkstra from unit's tile, weighted by `landform.move_cost_by_type[unit.move_type]`.
- Edges rejected if elevation delta > unit's jump height.
- Range shown as tile highlight overlay; legal end tiles distinguished from "passable but cannot stop" tiles.
- Cancelable until action committed.

### 5.4 Turn order and phase model

**Decision: phased model (player → enemy → neutral) for v1.** Action-time gauge (FFT-style) is more interesting but adds significant complexity to AI and animation timing. We can swap later if the turn-order subsystem is built behind a clean interface.

- Within a phase: units act in order of Speed stat (descending), ties broken by unit ID.
- Each unit acts once per phase, then is marked acted until next round.
- Player can choose any of their unacted units in any order during PlayerPhase.

### 5.5 Combat resolution

**The damage formula (v1 starting point — tunable):**

```
base_damage = attacker.Atk * weapon.Power / 100
mitigation = defender.Def * (1 + terrain_def_bonus)
raw = base_damage - mitigation

# Modifiers (multiplicative, applied in order):
× facing_modifier      # back: 1.5, side: 1.2, front: 1.0
× elevation_modifier   # higher: 1.15, lower: 0.90, same: 1.0
× element_modifier     # advantage: 1.30, disadvantage: 0.70, neutral: 1.0
× type_modifier        # weapon attack-type vs armor type, ±20%
× critical_modifier    # crit: 1.5, normal: 1.0
× pair_bonus           # if attacker is Duo front, +X% based on back support rank

final = clamp(raw, 1, 9999)
```

**Hit rate:**
```
hit_chance = clamp(weapon.Hit + attacker.Skill - defender.Avoid - terrain_evade_bonus, 5, 95)
```

**Crit rate:**
```
crit_chance = clamp(weapon.Critical + attacker.Skill / 4 - defender.Luck, 0, 50)
```

These constants live in `BattleConst.tres` (see §11.2). Designers tune; programmers don't touch.

### 5.6 Facing

Facing is one of 4 cardinal directions stored per unit. It updates:
- After an action (player chooses)
- After a movement (defaults to direction of last movement step)
- Never automatically during enemy turns except via the same rules

Damage modifier from `(attacker_position - defender_position)` vs `defender.facing`:
- Same direction as facing → front (1.0×)
- Perpendicular → side (1.2×)
- Opposite → back (1.5×)

Counterattack rules:
- Front: defender counterattacks if their weapon range covers attacker's tile.
- Side: counterattack hit rate halved.
- Back: no counterattack.

### 5.7 Main + Sub weapon system

Every unit has two weapon slots:
- **Main** — used by basic Attack action by default.
- **Sub** — accessible via SwitchWeapon command (free action, no turn cost the first time per turn).

**Both weapons:**
- Are not class-locked. Any Style can equip any weapon (subject to proficiency).
- Have independent durability counters (`current_durability` / `max_durability`).
- Have their own RangeShape, Power, Hit, Crit, Weight, element, attack-type.
- May grant a skill while equipped (`weapon.granted_skill`).
- Decrease durability by 1 per use (some skills cost more).
- At 0 durability, weapon is `broken`: stays equipped but does 1 damage and grants no bonuses. Repaired at base for gold.

**Switching weapons mid-turn** is its own command (`SwitchWeaponCommand`) — `CommandType.SwitchWeapon` flag. The first switch in a turn is free; subsequent switches (rare) cost the unit's action.

**Proficiency** (E → D → C → B → A → S) is per (unit × weapon category). Grows with use of that weapon category. Affects:
- Hit rate bonus per rank.
- Critical rate bonus per rank.
- Required for using high-rarity weapons.

### 5.8 Per-action EXP

EXP is awarded per individual contribution, not pooled per battle. Sources:
- **Kill** — large base chunk, scaled by level delta (+ for higher-level kill, − for lower).
- **Hit without kill** — small chunk scaled by damage dealt.
- **Heal applied** — chunk scaled by HP actually restored (overheal = 0).
- **Buff/debuff applied** — small flat chunk per success.
- **Surviving a hit** — optional small chunk for tank-role units.

EXP comes in two flavors:
- **Style EXP** — character class progression.
- **Weapon EXP** — weapon proficiency in the used weapon's category.

When in Duo: Front-line gets full Style + full Weapon EXP. Back-line gets reduced Style EXP, **zero Weapon EXP**.

### 5.9 Duo system (pair-up)

> Implementation reference: `Battle.Command.DoubleCommand`, `ReleaseDoubleCommand`, `SwitchDoubleCommand` in the Aster source. Renamed to "Duo" in our project to disambiguate from the unrelated combat exchange ("Duel" in their code).

Two adjacent allied units can merge into a single combined unit on one tile.

**Three commands:**
- `DuoFormCommand(actor, partner_target, target_tile)` — actor moves to partner's tile (or vice versa), unit becomes a Duo.
- `DuoSwitchCommand(duo)` — swap which side is Front/Back **without dissolving**.
- `DuoReleaseCommand(duo, release_tile)` — Back-line steps to an adjacent tile; both become independent again.

**Front / Back asymmetry:**
| Aspect | Front | Back |
|---|---|---|
| Attacks | Yes (uses Front's weapons) | No |
| Takes single-target hits | Yes | **No, immune** |
| Takes AoE hits | Yes | Yes (both members hit by AoE) |
| Movement | Uses Front's movement | Carried |
| Stat boost | Receives correction based on Back's support rank | Provides the correction |
| Bond Action | Receives Back's Bond Action (deterministic, every relevant trigger) | Triggers their Bond Action |

**Stat correction formula:**
```
front_atk_in_duo = front.Atk + (back.Atk * back.support_rank * 0.01 * DoubleStatusAdjustValue / 100)
```
Where `DoubleStatusAdjustValue = 100` from `BattleConst`. Tunable.

**EXP routing while Duo'd:** see §5.8.

### 5.10 Bond Action (Kizuna)

Adjacent allies trigger free support actions during combat. Three flavors:
- **Bond Attack** — adjacent ally throws a follow-up attack after the main attack lands.
- **Bond Heal** — adjacent ally heals the active unit (post-damage).
- **Bond Guard** — adjacent ally absorbs/reduces incoming damage (during damage calc).

**Trigger rules:**
- Adjacent (non-Duo): probabilistic based on `bond_value` between the two units. Formula: `chance = 0.2 + bond_value / max_bond * 0.6`.
- In Duo: **Back-line's Bond Action triggers deterministically** every relevant attack.

A unit's Bond Action type is determined by their Style and equipped skills (a Cleric has Bond Heal, an Archer has Bond Attack, a Knight has Bond Guard, etc.). This is data, not code.

### 5.11 Bond values

Per-pair counter, accrued over time:
- +5 when units act in support of each other (attack the same enemy, Duo together, etc.).
- +5 when units win a battle while paired.
- −40 when one of a pair dies. (Pair dynamics matter; loss of partner is severe.)

Bond drives Bond Action probability (§5.10) and unlocks per-pair dialogue / supports (post-v1 content).

### 5.12 Rewind / rollback

- Up to **3 free rewinds per battle**, configurable in `BattleConst`.
- Each rewind restores the full board state to the snapshot taken at the start of the rewound action.
- Snapshots are full `Board.duplicate(true)` calls, kept in a circular buffer of size = 3.
- Additionally, one snapshot per turn-start is kept for the "rewind to start of turn" UI.
- After 3 rewinds in a battle, button is disabled (no premium-currency purchase in our project).

---

## 6. Combat presentation

### 6.1 Sprite system (units)

**Style:** Chibi/SD pixel sprites, billboarded onto the 3D terrain. **Single-direction sprites** (side view, "east-facing") with horizontal flip for west. This matches Aster Tatariqus's actual approach (verified against gameplay screenshots) and is the most aggressive sprite-cost reduction available without going to fully abstract iconography.

**Animation states (minimum per unit):**
- Idle (looped)
- Walk (looped, 4–6 frames)
- Attack (one-shot, ends on idle)
- Cast / channel (one-shot)
- Hit / flinch (one-shot)
- Death (one-shot, despawns)
- Victory pose (one-shot, post-battle)

**Direction count: 1 unique direction per state (E, side-profile), with horizontal flip for W.** No N/S sprites. *Aster Tatariqus* uses this same compromise — its sprites are side-profile flat billboards regardless of camera pitch (visible in its 50°, 70°, and 90° presets), and the chibi proportions (huge head, small body) keep them readable from any angle even though they don't show top-of-head detail. The "facing arrow decal" (§6.1) communicates gameplay-facing without needing N/S sprite variants. Player units conventionally face east; enemy units conventionally face west (rendered as flipped E sprites). When a unit's gameplay-facing changes (after movement, after action), the visual sprite flips accordingly.

**Visual facing vs gameplay facing.** Because we only have side-profile sprites, the visual sprite cannot show all four cardinal facings. Gameplay facing (used for damage modifiers, see §5.6) is tracked separately on the unit and visualized via a **facing arrow decal** rendered on the ground under the unit, pointing in the gameplay-facing direction. The sprite itself only flips left/right based on whether the gameplay facing has an east or west component. This is the same compromise Aster ships with.

**Animation count per unit:** 7 states × 1 direction = **7 unique animations per unit**. With ~12 frames average per animation, that's ~85 frames per character. Across 12 v1 units = ~1,000 unique frames total. This is roughly 1/3 the production cost of a 3-direction approach and 1/8 of an 8-direction approach. Tractable for a single artist working part-time.

### 6.2 No animated combat cinematics

Confirmed scope decision: combat resolution stays in the tactical view. No "zoom into close-up combat sequence" like Fire Emblem or Aster. All combat actions play on the grid:
- Attacker plays attack animation in place.
- Hit effects (damage popup, particle, screen shake) on the defender tile.
- Defender plays hit animation; on death, plays death animation and despawns.
- Bond Action triggers a small VFX on the supporting unit + their action plays inline.

This is a meaningful scope reduction vs Aster — no `DuelScene` rendering layer, no separate combat camera, no battle backgrounds. It also keeps battles fast.

### 6.3 Camera system

Multi-mode camera with smooth transitions between presets. See §10.5 for architecture.

**Camera presets for v1 (3 modes):**

| Mode | Distance | Pitch | Use case |
|---|---|---|---|
| **Tactical** | medium-far (10–14u) | ~50° | Default — covers most of the board, sprites read clearly |
| **Overview** | far (14–18u) | ~70° | Wider battlefield view, helps with positioning + planning |
| **Top-down** | far (14–18u) | ~90° | Pure overhead, useful for unit placement and strategic overview |

All three presets work with single-direction sprites because chibi proportions remain readable at any camera pitch — *Aster Tatariqus* validates this empirically. The pitch differences between presets are deliberate and large (50° → 70° → 90°), giving each mode a distinctly different feel rather than three similar ones. Players cycle via `Tab`. Each preset remembers its own zoom level (per-preset `user_distance`).

**Camera input:**
- Pan: middle-mouse drag, WASD, edge-scroll (off by default), or two-finger drag on touch.
- Zoom: scroll wheel, pinch.
- **No yaw rotation.** Camera horizontal angle is fixed within a preset; preset cycling (Tab) is the only way to change angle. This locks all units to side-profile rendering and enables the single-direction sprite scheme in §6.1.
- Focus: F to snap to currently selected unit.
- Cycle preset: Tab.

### 6.4 UI

**Persistent overlays:**
- Top-left: turn counter, current phase indicator.
- Top-right: rewind button (with remaining count), settings, fast-forward toggle.
- Bottom-center: action menu (when a unit is selected).
- Bottom-left: selected unit panel (HP, MP, status, Main/Sub weapons).
- Bottom-right: targeted unit panel (when targeting an enemy).

**Damage preview** appears between action selection and confirmation. Shows: predicted damage range, hit %, crit %, "will kill?" indicator, expected counterattack.

**Range highlights** during targeting: green = movement reachable, blue = movement-then-attack reachable, red = direct attack range, yellow = AoE preview.

**Tile inspector** on hover (no click): shows tile's terrain type, elevation, occupant (if any), active effects.

---

## 7. Content systems

### 7.1 Styles (classes)

Style is the closest concept to "class" in this project's design.

A Style defines:
- Base stats and growth rates (per-level stat gains).
- Locomotion type (Infantry / Cavalry / Flying / etc).
- Allowed weapon categories with starting proficiency.
- Innate skills (always-on, regardless of weapons equipped).
- A **Style Board** — node-based progression tree unlocked over levels (post-v1 detail).

**Vertical slice Styles (6, ported and renamed from Aster's archetypes):**
1. Swordsman (Infantry, Sword main)
2. Knight (Advanced Infantry, Lance main, high Def)
3. Mage (Infantry, Tome main)
4. Cleric (Infantry, Staff main, healing innate)
5. Archer (Infantry, Bow main)
6. Pegasus Knight (Flying, Lance main)

Three more for v1: Cavalier, Berserker, Dark Mage.

### 7.2 Weapons

Categories (8): Sword, Lance, Axe, Bow, Tome, Staff, Dagger, Polearm.

Each weapon (Resource, `Weapon.tres`) carries:
```
id: int
name: String
category: WeaponCategory
rarity: int (1–5)
attack_type: AttackType (Slash/Blow/Pierce/Shot/Magic)
element: Element (None/Fire/Ice/Thunder/Wind/Light/Dark)
range_shape_id: int (references RangeShape table)
initial_power: int
initial_hit: int
initial_crit: int
initial_avoid: int
initial_weight: int
max_durability: int
granted_skill: Skill (optional)
limit_break_max: int
# limit_X equivalents for max-out values
```

Stats interpolate between `initial_X` and `limit_X` based on weapon's current limit-break level.

**v1 target: 25–40 weapons**, starting from 6–8 in the vertical slice (one Main, one Sub option for each starting unit).

### 7.3 Skills

A Skill (Resource) defines a specific action — usually triggered by attacking, but may be passive or activated.

```
id: int
name: String
kind: SkillKind (ActiveAttack / Stratagem / Support / Charge / Passive)
category: SkillCategory
range_shape_id: int
power: int (multiplier on weapon damage, or absolute)
element_override: Element (optional)
attack_type_override: AttackType (optional)
mp_cost: int
charge_turns: int (0 = instant)
target_filter: TargetFilter (Self/Ally/Enemy/Tile/AoE)
effects: Array[SkillEffect]
trigger_condition: TriggerCondition (for passive/reactive skills)
```

**SkillEffect** is a discriminated union: `DealDamage`, `Heal`, `ApplyStatus`, `RemoveStatus`, `MoveTarget`, `Teleport`, etc. Composing simple effects covers most skill designs.

### 7.4 Range shapes

Ported directly from Aster's `RangeShapeDetail.json` pattern.

```
class_name RangeShape extends Resource
@export var num_cols: int
@export var cells: PackedInt32Array
# Cells: row-major flat array
# -1 = empty, 1 = in-range, 101 = origin
```

Examples for v1:
- Sword (range 1): single tile in front (or 4-adjacent, design TBD).
- Lance (range 1–2): line of two tiles in front.
- Bow (range 2–3): diamond ring at distance 2–3.
- Staff (range 1–2 ally-only): adjacent + one-step diamond.
- AoE explosion: 3×3 centered on target.

### 7.5 Status effects

v1 set (6 statuses):
- **Poison** — −10% HP per turn for 3 turns.
- **Sleep** — skip turn, removed on damage taken or after 2 turns.
- **Paralysis** — skip turn, fixed 2-turn duration, NOT removed by damage.
- **Burn** — flat damage per turn, +5% damage taken from Fire.
- **Provoke** — must target the provoker if in range.
- **Heal-over-time** — +10% HP per turn for 3 turns.

Each status is a Resource with `on_apply`, `on_turn_start`, `on_turn_end`, `on_remove`, and a duration.

### 7.6 Elements and types

**Elements (6):** Fire, Ice, Thunder, Wind, Light, Dark.

Element interactions: rock-paper-scissors style. Fire > Ice > Thunder > Wind > Fire (loop), and Light ↔ Dark mutually advantaged. ±30% damage on advantage / disadvantage. Stored as a static table.

**Attack types (5):** Slash, Blow, Pierce, Shot, Magic. **Armor types (3):** Light, Heavy, Magical.

The attack-type × armor-type table is a 5×3 multiplier grid: e.g. Pierce vs Heavy = 1.2, Blow vs Heavy = 1.0, Magic vs Magical = 0.7. Authored as data, ±20% range.

### 7.7 Units (the roster)

A unit (the playable character) is distinct from a Style — units choose which Style they use. For v1 simplicity, **a unit has one fixed Style**; multi-Style units are post-v1.

Per-unit data (`CharacterDefinition.tres`):
```
id: int
display_name: String
default_style: Style
portrait: Texture2D
sprite_frames_resource: SpriteFrames
voice_set: AudioStreamCollection (post-v1)
base_stats: BaseStats
growth_rates: GrowthRates
default_main_weapon: Weapon
default_sub_weapon: Weapon
bond_action_kind: BondActionKind (Attack/Heal/Guard)
narrative_role: enum (post-v1: Lead/Companion/Boss)
```

**Vertical slice cast: 6 player units, 1–2 named enemy units.** v1 target: 12–16 player units.

---

## 8. AI

### 8.1 AI architecture (decision: weighted-scoring, NOT scripted)

We are explicitly NOT embedding Lua. Aster's MoonSharp+Lua approach is overkill for our scope. See §10.7 of the reference document for full reasoning.

Instead: a single `AIController` autoload + `AIBehavior` Resources + a static `ActionScorer`.

```
AIController
  for each enemy unit on enemy phase:
    behavior = unit.ai_behavior   # AIBehavior resource
    candidates = ActionRoutine.generate_candidates(unit, board)
    scored = candidates.map(c => (c, ActionScorer.score(unit, c, board, behavior)))
    best = scored.max_by_score()
    submit(best)
```

### 8.2 AIBehavior resource

```
class_name AIBehavior extends Resource
@export var role: AIRole          # Attacker / Tanker / Buffer / Healer / Other
@export var aggression: float     # 0..1
@export var self_preservation: float  # 0..1
@export var prefer_low_hp_targets: float
@export var prefer_squishy_targets: float
@export var stay_in_pair_threshold_hp: float
@export var prefer_high_ground: float
# … add more weights as needed
```

### 8.3 ActionScorer (the heart of the AI)

A pure function `score(unit, action, board, behavior) -> float`. Implementation is roughly:

```gdscript
func score(unit, action, board, behavior) -> float:
    var s = 0.0
    if action is AttackAction:
        var pred = AttackSimulator.predict(unit, action.target, action.weapon, board)
        s += behavior.aggression * pred.expected_damage
        s -= behavior.self_preservation * pred.expected_counter_damage
        s += behavior.prefer_low_hp_targets * (1.0 - action.target.hp_ratio)
        if action.target.role == "healer":
            s += behavior.prefer_squishy_targets * 50
    elif action is HealAction:
        var pred = HealSimulator.predict(unit, action.target, action.skill, board)
        s += behavior.healer_priority * pred.expected_heal
    # … etc
    return s
```

Tunable from outside the codebase; designers iterate on weights.

### 8.4 Vertical slice AI requirements

Two archetypes:
- **Aggressive Melee** — closes distance, prioritizes lowest-HP enemy in range. Aggression 0.8, self-preservation 0.2.
- **Cautious Ranged** — keeps distance, prioritizes squishy targets, retreats below 30% HP. Aggression 0.5, self-preservation 0.7.

v1 target: 5–6 archetypes (add Tank, Healer, Buffer, Boss-with-phases).

### 8.5 What the AI does NOT need to do (v1)
- No Duo formation by AI (enemies don't pair up).
- No coordinated team strategy. Each unit scores independently.
- No memory across turns (no "remember the last unit that hit me" beyond hate value).
- No predictive modeling of player. Greedy single-turn lookahead.

These are fair simplifications for a campaign-style SRPG. Smart-feeling AI comes from good behavior tuning and varied archetypes, not from minimax.

---

## 9. Maps and battles

### 9.1 Map authoring workflow

1. Artist builds the 3D environment as a Godot scene (`field_xxx.tscn`). This is the visual layer only — no gameplay data.
2. Designer opens the Battle Map Painter tool (custom in-editor plugin, see §10.6).
3. Painter overlays a grid on the 3D scene and lets the designer:
   - Paint landform IDs per tile.
   - Adjust corner heights per tile.
   - Place deployment zones for the player.
   - Place enemy units (with their Style, level, AI behavior, equipped weapons).
   - Define victory / loss conditions.
   - Define turn-X reinforcements (post-v1).
4. Painter saves a `BattleMap.tres` resource referencing the visual scene.

### 9.2 BattleMap resource

```
class_name BattleMap extends Resource
@export var id: int
@export var display_name: String
@export var width: int
@export var height: int
@export var ground_scene: PackedScene
@export var attributes: PackedInt32Array       # width * height landform IDs
@export var corner_heights: Array              # width * height Vector4s
@export var scenery_objects: Array[SceneryPlacement]   # decorative props (gameplay-irrelevant)
@export var deployment_zones: Array[Vector2i]
@export var enemy_placements: Array[EnemyPlacement]
@export var victory_conditions: Array[VictoryCondition]
@export var loss_conditions: Array[LossCondition]
@export var turn_events: Array[TurnEvent]      # reinforcements, dialogue triggers
@export var bgm: AudioStream
```

### 9.3 Victory and loss conditions

Each `VictoryCondition` / `LossCondition` is a small `Resource` subclass. v1 set:
- `RouteAllEnemies` — defeat all enemy units.
- `DefeatBoss` — specific named enemy must die.
- `SurviveTurns` — last N turns.
- `ReachTile` — any player unit reaches a target tile.
- `AllPlayerUnitsDead` (loss).
- `TargetUnitDies` (loss — protect the VIP).
- `TurnLimitExceeded` (loss).

Multiple conditions OR'd within victory and loss; any condition met ends the battle.

### 9.4 Vertical slice map specifics

- 20×20 grid.
- Three terrain types: plain, forest, water (impassable to non-flyers).
- One bridge crossing the water — a chokepoint.
- Two elevation tiers: ground level (height 0) and a small hill in the center (height 2).
- Player deployment in NW corner (3×3 area).
- 6–8 enemies pre-placed: 4 melee, 2 ranged, possibly 1 stronger "captain" near the hill.
- Victory: rout all enemies. Loss: all player units dead.

---

## 10. Architecture

> **For senior dev:** This section specifies the architectural decisions. The companion reference document explains the *why* behind each, with line-level code references to the Aster source.

### 10.1 Six load-bearing principles

These are non-negotiable. Any deviation requires explicit discussion.

1. **Event bus for combat events.** Single autoload (`CombatEventBus`) with signals for every meaningful gameplay moment. Combat logic emits; other systems subscribe. Never reverse this dependency.
2. **Component composition over inheritance.** Units are aggregations of components (`StatsComponent`, `WeaponSlotComponent`, etc.). No deep class hierarchies.
3. **Resource-driven data.** Weapons, classes, terrain, skills, AI behaviors, range shapes — all `.tres` Resources. No hardcoded tables in code.
4. **View / gameplay separation.** `CharacterUnit` is gameplay; `UnitView3D` is rendering. View subscribes to gameplay signals; the reverse is forbidden.
5. **Polymorphic units.** `DuoUnit` and `CharacterUnit` implement the same gameplay interface. Combat code never branches on "is this a Duo?"
6. **Hook services for cross-cutting concerns.** EXP, Bond, Proficiency, Rollback are autoload services that subscribe to combat events. They never live inside combat logic.

### 10.2 Top-level scene tree (in-battle)

```
BattleScene (Node)
├── Board (Node3D)
│   ├── GroundScene (instanced from BattleMap.ground_scene)
│   ├── GridOverlay (Node3D — debug grid lines, tile highlights)
│   └── UnitsLayer (Node3D — parent for all CharacterUnit / DuoUnit nodes)
├── BattleCamera (Node3D — see §10.5)
├── BattleManager (Node — drives the FSM and ticks subsystems)
├── CommandQueue (Node — accepts and executes Commands)
├── BattleUI (CanvasLayer)
│   ├── ActionMenu
│   ├── UnitPanel
│   ├── DamagePreview
│   ├── HUD (turn count, rewind, settings)
│   └── …
└── Autoloads (always present, see §10.3)
```

### 10.3 Autoloads (services)

| Autoload | Purpose | Listens to | Emits |
|---|---|---|---|
| `CombatEventBus` | Central pub/sub for combat events | (none) | All combat events |
| `ExperienceService` | Awards Style/Weapon EXP per action | bus | `level_up`, `proficiency_gained` |
| `BondService` | Tracks per-pair bond values | bus | `bond_changed`, `bond_rank_up` |
| `ProficiencyService` | Tracks per-(unit × weapon-category) proficiency | bus | `proficiency_changed` |
| `BondActionService` | Triggers Bond Actions on attack-resolving | bus | `bond_action_triggered` |
| `RollbackService` | Snapshots Board per action and per turn | bus, turn-start signal | `rolled_back` |
| `BattleLogService` | Collects events for replay/debug | bus | (none — read-only sink) |
| `AIController` | Selects actions for enemy units on enemy phase | phase signals | (submits Commands) |
| `MasterDataService` | Loads and caches all `.tres` data resources at boot | (none) | (none) |

### 10.4 The Command pattern

Every player or AI action is a `Command` (a `RefCounted` subclass). Commands have a strict lifecycle:

```
Command
  validate() -> bool          # can this command legally execute?
  prepare()  -> void          # gather resolution data (e.g. compute path)
  execute()  -> void          # apply effects to Board state
  complete() -> void          # post-effect cleanup, emit completion event
  cancel()   -> void          # rollback (used by RollbackService)
```

**Commands enumerated for v1:**
- `MoveCommand`
- `AttackCommand`
- `SkillCommand`
- `SwitchWeaponCommand`
- `DuoFormCommand`
- `DuoSwitchCommand`
- `DuoReleaseCommand`
- `UseItemCommand` (post-vertical-slice)
- `WaitCommand` (a.k.a. Stay)
- `EndTurnCommand`

UI never calls Board methods directly. UI builds a Command, submits to `CommandQueue`, which validates and executes. Tests run by submitting Commands directly without UI.

### 10.5 Camera architecture

```
BattleCamera (Node3D — the rig)
├── Pivot (Node3D — Point of Rotation)
│   └── Camera3D (positioned at -distance along local Z)
├── settings: Array[CameraSetting]
├── current_index: int
├── input_phase: enum { NONE, MOVE, ZOOM, IGNORE }
└── signals:
    - camera_mode_changed(new_index)
    - camera_position_changed(world_pos)
    - camera_distance_changed(distance)
```

```
class_name CameraSetting extends Resource
@export var id: int
@export var display_name: String
@export var min_distance: float
@export var max_distance: float
@export var initial_distance: float
@export var rotation_angles: Vector3
@export var height_offset: float
@export var enable_dof: bool
# user_distance is per-instance state, not on the resource
```

API:
```gdscript
func cycle_to_next_setting(duration := 0.4) -> void
func set_setting_index(index: int, duration := 0.4) -> void
func focus_on(world_position: Vector3, duration := 0.3) -> void
func focus_on_unit(unit: CharacterUnit, duration := 0.3) -> void
```

Per-preset `user_distance` is remembered across cycles. Camera input goes through a small FSM (`InputControllCamera2D` equivalent in Aster).

### 10.6 Tooling — Battle Map Painter

A Godot editor plugin. Scope:
- Activate when a `BattleMap.tres` is selected.
- Overlays a grid in the 3D viewport on the referenced `ground_scene`.
- Tools (toolbar):
  - Paint Landform — click/drag to set landform IDs.
  - Edit Heights — per-corner height editing with mouse drag.
  - Place Deployment — drag to add/remove deployment tiles.
  - Place Enemy — opens a popup to configure enemy placement.
  - Test Pathfind — visualizes legal moves from a tile for a chosen MoveType.
- Saves changes to the underlying `.tres`.

This is meaningful tooling effort but pays back enormously in iteration speed. **Estimated 2 weeks of focused work** to get a usable v1 of the painter; defer until Phase 4 when designers have something to paint onto.

### 10.7 Folder layout (proposed)

```
res://
├── addons/
│   └── battle_map_painter/        # editor plugin
├── data/                          # all .tres game data
│   ├── battle_const.tres
│   ├── classes/
│   ├── weapons/
│   ├── skills/
│   ├── range_shapes/
│   ├── terrain/
│   ├── ai_behaviors/
│   ├── characters/
│   ├── elements_table.tres
│   └── attack_armor_table.tres
├── maps/                          # BattleMap.tres + their visual scenes
│   ├── slice_01/
│   │   ├── slice_01.tres
│   │   ├── slice_01_ground.tscn
│   │   └── ...
├── scenes/
│   ├── battle/
│   │   ├── battle.tscn
│   │   ├── battle_camera.tscn
│   │   └── ...
│   ├── units/
│   ├── ui/
│   └── meta/                      # title, menus
├── scripts/
│   ├── autoload/                  # the services
│   ├── battle/
│   │   ├── commands/
│   │   ├── simulators/
│   │   ├── components/
│   │   └── ...
│   ├── data/                      # Resource subclasses
│   ├── ai/
│   └── util/
├── art/
│   ├── sprites/                   # SpriteFrames per character
│   ├── portraits/
│   ├── tiles/                     # tile decals if any
│   └── vfx/
├── audio/
│   ├── bgm/
│   ├── sfx/
│   └── voice/
└── tests/                         # GUT tests
```

### 10.8 Naming conventions

- Classes: `PascalCase` (`CharacterUnit`, `BattleMap`).
- Methods, vars, signals: `snake_case` (`take_damage`, `current_hp`, `unit_killed`).
- Constants: `SCREAMING_SNAKE_CASE`.
- Files: `snake_case.gd`, `snake_case.tres`, `snake_case.tscn`.
- Resources: `<thing>.tres` (e.g. `iron_sword.tres`).
- Scenes: `<thing>.tscn` (e.g. `battle_camera.tscn`).
- Aster's `Double` mechanic is **renamed to `Duo`** throughout our codebase — disambiguates from `Duel` (the unrelated combat-exchange concept in Aster's source). Their `Duel` concept is folded into our combat resolution, no separate name needed since we don't have animated combat scenes.

### 10.9 Testing

- **Unit tests** via [GUT](https://github.com/bitwes/Gut): for Simulators, damage formula, pathfinder, RangeShape resolution, BondService accrual, EXP routing.
- **Integration tests:** scripted Command sequences against a deterministic test board, asserting end state.
- **Visual / playtest:** manual.
- **No CI in v1.** Developer runs tests locally before pushing. CI added post-vertical-slice.

### 10.10 Performance budget

For desktop (M1, mid-range Windows):
- Target 60 FPS with up to 30 sprites on screen + the 3D environment.
- Pixel sprites are cheap; the budget is dominated by the 3D environment art.
- Pathfinding with up to 32×32 grids and multiple unit types — must complete in <16ms; a single Dijkstra at this size is tens of microseconds, so this is comfortable.
- Damage previews update on hover at 60 FPS — Simulators must be pure functions, no allocation in the hot path.

Mobile post-v1: budget shrinks; revisit then.

---

## 11. Data — concrete starting values

### 11.1 Tunable constants (`battle_const.tres`)

Direct port from Aster's `BattleConst.json` and `BattleLogicConst.json`. Use these as starting defaults; iterate from playtesting.

| Constant | Value | Notes |
|---|---|---|
| `min_damage` | 1 | Damage floor |
| `max_damage` | 9999 | Damage cap |
| `rollback_save_turn_count` | 5 | Turns of history kept |
| `rollback_free_count` | 3 | Per-battle free rewinds |
| `fast_mode_speed` | 3.0 | Animation speedup multiplier |
| `bond_increase_by_skill` | 5 | Bond + when supporting |
| `bond_increase_by_clear` | 5 | Bond + on shared victory |
| `bond_decrease_by_dead` | 40 | Bond − when paired ally dies |
| `element_advantage_rate` | 30 | +30% on element advantage |
| `element_disadvantage_rate` | 30 | −30% on element disadvantage |
| `double_status_adjust_value` | 100 | Duo stat correction baseline |
| `load_weight_coefficient` | 30 | Weapon weight → speed reduction |
| `back_attack_modifier` | 1.5 | Damage × from behind |
| `side_attack_modifier` | 1.2 | Damage × from the side |
| `front_attack_modifier` | 1.0 | Damage × from the front |
| `higher_ground_modifier` | 1.15 | Damage × attacking down |
| `lower_ground_modifier` | 0.90 | Damage × attacking up |
| `infantry_jump_height` | 1 | Max climbable elevation delta |
| `cavalry_jump_height` | 1 | |
| `flying_jump_height` | 99 | Effectively unlimited |
| `floating_jump_height` | 2 | Mid-tier |

### 11.2 Vertical slice asset list

**Characters (sprites + portraits + voice — voice deferred):**
- Aria (Swordsman, Lead, Bond Attack)
- Reni (Cleric, Bond Heal)
- Garrett (Knight, Bond Guard)
- Vesper (Mage, Bond Attack)
- Theo (Archer, Bond Attack)
- Lyra (Pegasus Knight, Bond Heal)
- Generic Bandit (×4–5, sprite reuse OK)
- Generic Bowman (×2)
- Captain (named boss for the slice)

**Weapons (12 for the slice):**
- Iron Sword, Steel Sword (Aria)
- Heal Staff, Recover Staff (Reni)
- Iron Lance, Steel Lance (Garrett, Lyra)
- Fire Tome, Thunder Tome (Vesper)
- Iron Bow, Steel Bow (Theo)
- Bandit's Axe, Bandit's Bow (enemies)

**Skills (6 for the slice):**
- Slash (sword basic)
- Thrust (lance basic)
- Heal (staff)
- Fireball (tome, AoE)
- Power Shot (bow, single high-damage)
- Charge (knight innate, +damage on first attack each battle)

**Status effects (3 for the slice):** Poison, Sleep, Heal-over-time. Other 3 in §7.5 are v1.

**Range shapes (8 for the slice):** in-front-1, line-2, diamond-1, diamond-2-3, ally-diamond-1-2, AoE-3x3, self-only, line-3.

**Terrains (4 for the slice):** Plain, Forest, Water (impassable to non-fly), Cliff (impassable to non-fly).

**Camera presets (3 for the slice):** Tactical (default), Overview, Top-down — all three ship in Phase 2.

**Visual facing indicator:** 1 simple arrow decal asset (rendered on the ground under each unit), tinted by team color. Used because side-profile-only sprites cannot show all four cardinal facings (see §6.1).

---

## 12. Roadmap

### 12.1 Phases (vertical slice)

| Phase | Focus | Est. duration | Definition of done |
|---|---|---|---|
| **0** | Project setup, repo, Godot template, basic scene tree | 2–3 days | Empty battle scene loads, FPS counter shows 60 |
| **1** | Bare grid combat | 1–2 weeks | Two units on a flat grid, one can move and hit the other, HP goes down |
| **2** | Visual foundation | 1 week | Pixel sprites billboard correctly, one camera preset, tile highlights |
| **3** | Architecture spine | 1–2 weeks | Event bus, Commands, Simulators, ExperienceService, RollbackService all wired |
| **4** | Main + Sub weapons | 1 week | Both slots equipped per unit; SwitchWeapon command; durability ticks; one weapon breaks |
| **5** | Per-action EXP and Bond | 1 week | Kill awards EXP to killer; heal awards EXP to healer; Bond values change after battle |
| **6** | Duo system | 1–2 weeks | DuoForm, DuoSwitch, DuoRelease commands work; Front takes hits, Back is immune to ST; AoE hits both |
| **6.5** | **Vertical slice review** | a few days | Playable demo battle; project re-plans v1 from here |

**Estimated total: 7–11 weeks of focused full-time work for the vertical slice.** Add 50% for part-time / context-switching reality. Good time to bring in a senior is start of Phase 1; or earlier (Phase 0) if they own architectural decisions.

### 12.2 v1 phases (post-slice, scope to be confirmed)

| Phase | Focus | Est. duration |
|---|---|---|
| 7 | Bond Action (Kizuna) system | 1 week |
| 8 | Terrain and elevation full integration | 1 week |
| 9 | Add the third camera mode (Close) with smooth cycling | 2–3 days |
| 10 | AI behavior expansion + rollback polish | 1–2 weeks |
| 11 | Style Board / progression | 1–2 weeks |
| 12 | Skill system depth (status effects, conditional triggers) | 2 weeks |
| 13 | Element / type damage layers fully tuned | 1 week |
| 14 | Battle Map Painter editor plugin v1 | 2 weeks |
| 15 | Map authoring (12–20 battles) | content-dependent |
| 16 | Save/load, settings, controls | 1–2 weeks |
| 17 | Polish, sound, music integration | content-dependent |
| 18 | v1 release candidate | TBD |

### 12.3 Milestones / deliverables

| Milestone | What ships |
|---|---|
| **M1 — Architectural skeleton** (end of Phase 3) | Event bus, Commands, Simulators are real and tested. Damage formula lives in one place. Rewind works. |
| **M2 — Vertical slice** (end of Phase 6) | One playable battle from start to victory. Demonstrates every core system. |
| **M3 — Combat depth** (end of Phase 10) | All AI archetypes, Bond Action, full terrain/elevation. Gameplay is feature-complete for a single battle. |
| **M4 — Authoring pipeline** (end of Phase 14) | Battle Map Painter shipped. Designer can author a battle without programmer help. |
| **M5 — v1 Release** (end of Phase 18) | All v1 content, polish, save system. Shippable. |

---

## 13. Risks and open questions

### 13.1 Risks

**R1 — Pixel art pipeline scaling.** 1 unique direction × 7 animation states × 12+ units = ~85 unique animations in v1, ~1,000 frames total. Single-direction sprites with horizontal flip is the most aggressive reduction available. Sprite production is still meaningful work but is now sustainable for a single artist. Mitigation: lock the chibi style early, establish a consistent skeleton/proportions, consider AI-assisted tools for first-pass animation (with human cleanup). The *actual* risk shifts: with side-profile-only sprites, attack animations need extra care because the player sees every attack from the same angle, so visual variety has to come from VFX, weapon poses, and timing rather than camera angle.

**R2 — Battle Map Painter tooling debt.** If we author maps without the painter (raw `.tres` editing), workflow is painful and slows content. If we build the painter too early, we've over-invested before knowing what authors actually need. Mitigation: hand-author 1–2 maps in raw .tres first to build empathy, THEN build the painter targeting the friction points discovered.

**R3 — AI tuning is non-trivial.** Weighted-scoring AI feels generic if weights are wrong. Mitigation: invest in fast iteration tooling (in-game console for adjusting AIBehavior weights at runtime, replay system that re-runs deterministic AI with new weights). 

**R4 — Scope creep into "but Aster has X."** Aster Tatariqus has many features (Style Board, Reincarnation, Stratagem, Charge skills, Barrier system, Hate, full status taxonomy). Each is interesting; not all are necessary. Mitigation: this GDD is the boundary. New features need GDD-amend discussions, not casual additions.

**R5 — Pixel sprite + 3D shader interaction.** Y-axis billboarding plus pixel art plus camera transitions can produce subtle artifacts (sub-pixel jitter, MSAA blur, depth fighting). Mitigation: address texture filtering, MSAA, and pixel snapping early in Phase 2; test specifically at the three planned camera presets and during preset transitions.

### 13.2 Open questions

These are decisions still owed before or during early implementation. Senior dev's input welcome on each.

1. **Engine version policy.** Pin to a specific Godot 4.x or follow latest? Recommend: pin to current stable at Phase 1 start; review at v1 RC.
2. **GDScript only, or GDScript + C# hybrid?** GDScript is faster for iteration; C# is faster at runtime. Recommend: GDScript only for v1; profile and selectively port hot paths to C# only if profiling shows need.
3. **Exact damage formula tuning.** §5.5 is a starting point; needs playtesting in Phase 5+ to find the curves that make encounters feel right. No commitment to ±1% accuracy from Aster's formula.
4. **Save format.** Resource-based save (Godot's `ResourceSaver`) or JSON / custom binary? Recommend: Resource for prototyping, evaluate before v1 — `.tres` saves are debuggable but human-readable plaintext, which players can edit.
5. **Multi-Style units** (one character can change Style). v1 says no. Could be added late; depends on design value during playtests.
6. **Working title and visual identity.** Out of scope for engineering kickoff; design/marketing track.
7. **Music / SFX strategy.** Royalty-free library for vertical slice; commissioned post-slice. Composer not yet engaged.

#### Resolved during implementation

- **Camera presets revised** (Phase 2 review). Original GDD specified Tactical 50° / Close 40° / Action 30°. Validated against *Aster Tatariqus* gameplay screenshots and revised to Tactical 50° / Overview 70° / Top-down 90°. The empirical evidence — Aster's chibi sprites read fine at 90° — invalidates the original "no top-down" rule. Revised three-preset set ships in Phase 2 (originally planned for Phase 9).

### 13.3 Things explicitly DEFERRED (not cut, not in v1)
- Story / narrative scenes between battles.
- Multi-tile units (Large Boss).
- Mobile port.
- Localization beyond English text.
- Modding support.
- Steam / itch.io infrastructure.
- Action-time-gauge turn order.
- Player-controlled camera rotation (any kind).

---

## 14. References

- **Companion document:** `tactical_rpg_design_reference.md` — research deep-dive into Aster Tatariqus, including full architectural analysis of the decompiled source. **Read this alongside the GDD; it is the authoritative reference for the *why* behind decisions in §10.**
- **Decompiled source:** [`laqieer/AT-Datamine`](https://github.com/laqieer/AT-Datamine) on GitHub. Battle code in `Assembly-CSharp/Battle/`. MasterData JSON in `MasterData/`.
- **Aster Tatariqus resources** (for design intent):
  - Official site: `at.fg-games.co.jp/en/` (archived via Wayback)
  - Battle System guide (TerIA, YouTube): `youtube.com/watch?v=qocPBDJmSxU`
  - Japanese strategy wikis (linked in the reference document)

---

*End of GDD v0.1.*

*Next document: implementation kickoff briefing covering Phase 0–1 first-week tasks and pair-programming session schedule.*
