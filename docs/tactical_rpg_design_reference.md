# Tactical RPG Design Reference

> Distilled from Aster Tatariqus research, scoped to the systems chosen for this project. Architecture notes throughout target a Godot (latest), modular, event-driven implementation.

---

## 1. Tactical battle system (core)

The combat layer is a turn-based grid SRPG. No animated 3D skill cinematics — we keep everything in the pixel/2.5D battle view, prioritizing snappy turn pacing and information density over spectacle.

### Turn structure
- Initiative-based turn order computed from a Speed-derived stat. The simplest model: turn order is sorted by Speed each round, with ties broken by team-first then unit ID. A more advanced model uses an action-time gauge (Final Fantasy Tactics style) where each unit accumulates time-to-act based on Speed and acts when their gauge fills.
- On a unit's turn: **Move + Action + Face**. The unit chooses to move (or not), takes one action (attack / skill / item / wait), then chooses a final facing direction.
- Move-then-cancel and action-then-cancel should be supported until the player commits "End Turn." This is critical for tactical games.

### Round / phase model
- Player phase → enemy phase → neutral/environmental phase (if any) → loop.
- Or: single interleaved initiative queue if you go the action-time-gauge route. The two models are mutually exclusive — pick one and commit early; they have very different feel.

### Recommended starting choice
For your project, the round-phased model is simpler to implement and easier to balance; the action-time gauge is more interesting strategically but adds friction to the AI and animation pipelines. Start with phased; you can swap to time-gauge later if you build the turn-order subsystem cleanly behind an interface.

---

## 2. Pixel art + 2.5D presentation

### What this means
- **Sprites are 2D pixel art**, billboarded — they always face the camera. Chibi/super-deformed proportions (large head, small body) for readability at small sizes.
- **The world is 3D** — terrain is a real 3D mesh or grid map you can rotate the camera around. Pixel sprites stand on tiles; the camera moving doesn't change the sprite's facing toward the screen, but it does change which side of the unit the player perceives.
- **Per-direction sprite sets** — each unit needs at minimum 4-direction sprite sheets (N/E/S/W). Better is 8-direction. The currently-displayed direction is computed from `unit_facing - camera_yaw`, snapped to the nearest sprite slot.

### Sprite states per unit (minimum)
- Idle (looped)
- Walk (looped, used during movement)
- Attack (one-shot, plays during attack action)
- Cast / channel (one-shot, for skills)
- Hit / flinch (one-shot, plays when struck)
- Death (one-shot, ends in despawn or corpse sprite)

Optional but high-value: ready/alert, low-HP idle variant, victory pose.

### Godot implementation sketch
- **Sprite3D** node per unit, `billboard = enabled` (Y-axis only — you don't want pitch tilt).
- **AnimatedSprite3D** can replace Sprite3D if you prefer Godot's built-in animation-frame system; for SpriteFrames-driven workflows it's cleaner.
- **Texture filtering off** (nearest-neighbor) in import settings — this is non-negotiable for pixel art.
- **Per-direction logic**: a small script on each unit recomputes the active animation row from `(facing_quaternion · camera_forward)` each frame and feeds it to the AnimatedSprite3D.
- **Pixel-snap shader** on the camera or per-sprite to avoid sub-pixel jitter when the camera moves.

### Architecture note
Keep sprite presentation logic out of the unit's gameplay logic. A clean split:
- `UnitGameplay` node (data, stats, signals like `attack_started`, `damage_taken`, `died`).
- `UnitView3D` node listening to those signals and translating them into Sprite3D animation calls.

The view never reads gameplay state directly; it only reacts to signals. This means you can run headless tests, swap art styles, or add a debug-only "abstract" view without touching combat logic.

---

## 3. Grid combat features

### Tile grid model
- Square tiles (recommended for your scope — hex adds complexity without proportional payoff for an SRPG).
- Each tile stores: `terrain_type`, `elevation_level` (integer), `occupant` (unit ref or null), `effects` (list of terrain effects like fire, fog, mud).
- Tile size is a constant — pick one (e.g. 1.0 world units) and stick to it.

### Movement
- Movement range computed via **Dijkstra / BFS** from the unit's current tile, weighted by terrain movement cost and unit movement type (foot, mounted, flying).
- Flying units ignore terrain costs and elevation but may still respect "no-fly" tiles (indoor ceilings, etc.).
- Mounted units may be cheap on roads but expensive in forests.
- Path preview shown to player on hover; commit on click.
- Cancellable until the action is committed.

### Attack range (per weapon)
Range varies entirely by the equipped weapon, not the unit. This is critical and it ties directly into the Main + Sub weapon system below.

- Melee swords: range 1 (adjacent only).
- Spears / lances: range 1–2 in a line.
- Bows: range 2–3, often with a minimum range (can't shoot adjacent).
- Staves (heal): range 1–2.
- Magic tomes: range varies by spell tier.
- AoE skills: defined by a shape mask (cross, square, line, cone) centered on the target tile.

Implementation: every weapon resource carries a `range_pattern` — a set of tile offsets from the user's tile. The attack-targeting system queries this pattern, intersects with line-of-sight, and produces the legal target set.

### Facing
Facing matters for damage calculation and counterattacks.

- **Front attack**: normal damage, target can counterattack if able.
- **Side attack**: bonus damage (e.g. +20%), target counterattack penalty.
- **Back attack**: significant bonus damage (e.g. +50%), target cannot counterattack.

Players choose facing at the end of each unit's turn — this is a meaningful tactical decision because the AI will exploit exposed backs. A unit who has acted but is facing the wrong way is far more vulnerable.

Implementation note: facing is one of 4 cardinal directions in grid space, stored as an enum on the unit. The "side" / "back" check is `(attacker_position - defender_position)` compared against `defender_facing` — three simple cases.

### Terrain features
Terrain types that affect gameplay:

- **Plain** — neutral, default movement cost 1.
- **Forest** — +evasion, increased movement cost (e.g. 2 for foot, 3 for mounted).
- **Mountain / cliff** — impassable to most, passable only by flying.
- **Water (shallow)** — passable at high cost; many units can't enter.
- **Water (deep)** — flying-only.
- **Road** — reduced movement cost.
- **Fortress / wall** — bonus defense, possibly auto-heal at turn start.
- **Hazard tiles** (fire, poison, ice) — apply effects on entry or per turn.

Each terrain type is a data resource carrying `move_cost_by_type`, `evasion_bonus`, `defense_bonus`, `on_enter_effects`, `on_turn_start_effects`.

### Elevation
Elevation is an integer per tile. Effects:

- **Move cost** — climbing up costs more (e.g. +1 per level climbed); descending is free or +1 if descending more than 1 level (jump damage threshold optional).
- **Range** — units on higher ground get +1 effective range with ranged weapons, or alternatively get a hit/damage modifier.
- **Damage modifier** — attacking from higher ground grants +X% damage; attacking up grants -X%. Values like +15% / -10% feel meaningful without being overwhelming.
- **Line of sight** — taller terrain blocks LoS; elevation lets ranged units shoot over obstacles.
- **Movement gating** — some units have a max-jump-height stat; foot units can only step up to elevation differences of 1, while flying units ignore this entirely.

Implementation: elevation is part of the tile data. The pathfinder factors elevation differences into edge costs and rejects edges that exceed a unit's jump-height. The range/damage modifiers are applied at attack-resolution time by comparing attacker and defender tile elevation values.

---

## 4. Main + Sub weapon system

The defining loadout mechanic. Every unit equips two weapons simultaneously: a Main and a Sub. This decouples role from class and makes loadout a meaningful tactical decision.

### Rules
- Every unit has a Main slot and a Sub slot.
- Weapons are not class-locked — any class can equip any weapon (subject to proficiency rules; see below).
- The Main weapon is the default attack — basic attack uses Main.
- The Sub weapon provides an alternate attack option, accessible from the action menu.
- Skills may be tied to weapons — equipping a particular weapon may unlock a skill.
- **Weapons have durability.** Each use decreases durability by 1 (or more for special skills). At 0, the weapon breaks. Broken weapons are unequipped but may be repaired between battles.

### Why durability is the right call (and the wrong way to do it)
Durability creates resource pressure that makes weapon variety meaningful — you can't just equip the strongest weapon and forget. Players cycle through their armory.

The wrong way: durability so harsh that players hoard their good weapons and never use them. *Fire Emblem*'s pre-*Three Houses* system erred here.

The right way: durability generous enough that players use weapons freely in normal battles, but tight enough that boss/elite encounters require considering whether to spend a high-durability hit. Reasonable starting numbers: common weapons 30–40 uses, rare weapons 15–20 uses, repair cost is gold-affordable but not free.

### Proficiency (optional but recommended)
Each unit has a proficiency level per weapon category (Sword, Lance, Bow, Tome, Staff, etc.) that grows with use. Proficiency affects hit rate, crit rate, and unlocks weapon-tier access (E → D → C → B → A → S). This rewards committing a unit to a weapon type while still allowing flexibility through the Sub slot.

### Architecture note
This is a textbook component-composition pattern, perfect for modular event-driven design.

```
CharacterUnit (Node3D)
├── StatsComponent          (HP, Atk, Def, Spd, etc.)
├── ClassComponent          (job-style data: growth rates, innate skills)
├── MainWeaponComponent     (slot wrapper around a Weapon resource)
├── SubWeaponComponent      (slot wrapper around a Weapon resource)
├── ProficiencyComponent    (per-category proficiency levels)
├── StatusEffectComponent   (buffs/debuffs/conditions)
└── UnitView3D              (Sprite3D + animation, signal listener)
```

Weapons are Godot `Resource` subclasses (`Weapon.tres` files) carrying their stats, range pattern, durability, attached skills, etc. Slots emit signals on equip/unequip/break/use, and the rest of the system listens.

When the player chooses an attack, the action system asks: "which weapon — Main or Sub?" The chosen weapon's range pattern, damage formula, and durability are used. After the attack resolves, the slot emits `weapon_used`, durability decrements, and if it hits 0 the slot emits `weapon_broke` and unequips.

---

## 5. Per-action EXP system

EXP is awarded per individual action, not pooled per battle. Every meaningful contribution earns the contributing unit EXP.

### What earns EXP
- **Killing an enemy** — largest chunk. Scales with the level difference (kill someone much higher → more EXP; lower → less).
- **Hitting an enemy** without killing — small chunk per hit, scaling with damage dealt.
- **Healing an ally** — chunk scaling with HP actually restored (not overheal).
- **Buffing / debuffing** — small flat chunk per successful application.
- **Surviving a hit** without dying — optional, small chunk for tanks.

### Why this matters tactically
The player chooses who gets the kill. A kill on a low-level unit lets them catch up. A heavily under-leveled unit can be ferried up by feeding them kills. Healers don't fall behind because they earn proportional EXP from healing throughput. Every action is a growth decision.

### Architecture note — this is where the event bus pays for itself
This system is the strongest argument for an event-driven core. You don't want EXP-award logic embedded in combat resolution. Instead:

- Combat resolution emits events: `damage_dealt`, `unit_killed`, `healing_applied`, `buff_applied`.
- An `ExperienceService` autoload subscribes to those events and awards EXP via its own rules table.
- This means the EXP system can be tuned, A/B-tested, or replaced without touching combat code.
- Same pattern for: quest progression, achievements, bond/affinity tracking, tutorial triggers.

```
combat_event_bus.damage_dealt        →  ExperienceService.on_damage_dealt
combat_event_bus.unit_killed         →  ExperienceService.on_unit_killed
combat_event_bus.healing_applied     →  ExperienceService.on_healing_applied
combat_event_bus.buff_applied        →  ExperienceService.on_buff_applied
```

In Godot, this is an autoload singleton (`CombatEventBus`) with signals for every meaningful gameplay event. Every system that cares about combat outcomes — EXP, achievements, quests, sound, VFX, screen-shake, story flags — listens to that bus. Combat logic itself never knows about any of them.

This is probably the single most important architectural decision for the whole project. Get this right early and everything downstream becomes simpler.

---

## 6. Dual system

The Dual system (デュアル) is one of Aster Tatariqus's signature battle mechanics. Two units pair up to act as a single combined unit on one tile, with one taking the front-line role and one taking the back-line role. The pair can be formed and dissolved freely during a battle as the situation demands.

### Core mechanic
- Two friendly units, when adjacent, can be combined into a Dual via a "Dual" action button.
- The Dual occupies a single tile and acts as a single unit on subsequent turns.
- One unit becomes **Front-line** (前衛 / *zen'ei*), the other becomes **Back-line** (後衛 / *kōei*).
- The Dual can be **dissolved** mid-battle at any time, splitting the two units back onto adjacent tiles. Both individual action and Dual action can be switched on the fly during the battle as the player sees fit.

### Front-line vs Back-line roles

| Aspect | Front-line | Back-line |
|---|---|---|
| Combat | Performs the attacks | Does not directly attack |
| Damage taken | Takes all incoming single-target attacks | Cannot be hit by single-target attacks |
| Movement | Dual uses Front-line's movement stat | Carried along; movement stat irrelevant while paired |
| Stat bonuses | Receives stat boosts based on Back-line's support rank | Provides the support to Front-line |
| Bond Action trigger | Receives the support | **Back-line's Bond Action triggers automatically** (more on this in Section 7) |

This asymmetry is what makes Dual interesting tactically — it's not just "two units in one tile for stat boost," it's a distinct combat formation with deliberate strengths and trade-offs.

### EXP distribution while in Dual

This is one of the more nuanced parts of the system and ties directly into the per-action EXP design from Section 5:

- **Front-line**: gains full **Style EXP** (more than back), full **Weapon EXP**, and full **Weapon Proficiency** as if fighting normally.
- **Back-line**: gains **Style EXP** (less than the front), but **does NOT gain Weapon EXP or Weapon Proficiency** while in Dual.

The implication: if you want a unit to grow their weapon mastery, they must spend time as Front-line or fight individually. Back-line is for protecting fragile units, ferrying low-mobility units forward, or guaranteeing a Bond Action — not for grinding weapon levels.

### Tactical uses
The Japanese strategy guides identify four primary tactical uses for Dual:

1. **Mobility carrying** — pair a high-movement unit (cavalry, flier) as Front-line with a low-movement unit as Back-line, then dissolve later to deploy the slow unit deep into the map. This is the canonical "horse-rescue" use case.
2. **Emergency retreat / damage immunity** — when a unit is at low HP and can't reach a heal tile, Dual them as Back-line into a tank Front-line. The back unit becomes invulnerable to single-target attacks for as long as the Dual holds.
3. **Guaranteed Bond Action access** — particularly Bond Heal. In normal play, Bond Actions trigger probabilistically off adjacent allies. In Dual, the back unit's Bond Action triggers every time. This lets the player force-trigger a heal or buff at will.
4. **Stat-boosted offense** — pair a glass-cannon DPS as Front-line with a high-stat support as Back-line. The Front-line gets a stat correction based on Back-line's support rank, becoming a stronger version of itself for the duration.

### Restrictions and trade-offs (canonical)
- The two units in Dual share the actions of one unit per turn. Dual is one unit's worth of board presence, not two.
- Back-line cannot be the target of single-target attacks — but **AoE attacks may still affect both members** of a Dual depending on how the AoE is implemented (worth verifying the exact behavior; the Japanese guides imply Back-line is shielded from "敵の単体攻撃" / single-target attacks specifically).
- Back-line earns no Weapon EXP / Proficiency, so over-relying on Dual will leave units behind on weapon growth.

### Architecture note
A Dual is a meta-unit that wraps two CharacterUnit references with explicit Front/Back roles.

```
DualUnit (Node3D)
├── front_line: CharacterUnit ref
├── back_line:  CharacterUnit ref
├── DualGameplayProxy (implements the same interface as UnitGameplay)
└── (the two underlying CharacterUnits are deactivated on the grid while Dualed)
```

Key implementation points:

- **Polymorphism** — `DualUnit` and `CharacterUnit` both implement the same gameplay interface (`get_movement_range`, `take_damage`, `get_attack_options`, etc.). The combat resolver, AI, and pathfinder never branch on "is this a Dual?" They just call the interface and `DualUnit` handles role-routing internally.
- **Damage routing** — when `DualUnit.take_damage(attack)` is called, it inspects the attack: if `attack.is_single_target`, route to Front-line only; if `attack.is_aoe`, route to both. This logic lives in one place.
- **Stat aggregation** — `DualUnit.get_stats()` returns Front-line's stats with Back-line's support bonus applied. Front-line's stats remain authoritative; the proxy just composes them.
- **EXP routing** — the per-action EXP system (Section 5) needs to know who actually performed an action. When the Dual attacks, emit `damage_dealt` with `actor = front_line` (and `assist = back_line` for Bond Action contributions, see Section 7). The `ExperienceService` already handles single-actor routing; the Dual just needs to identify the right actor at emit time.
- **Form / dissolve as discrete actions** — wire `dual_formed(front, back)` and `dual_dissolved(front, back)` signals on the event bus. The grid presenter listens and updates tile occupancy; the bond system listens to track who's been Dualing with whom.

The combat system never knows whether it's hitting a single unit or a Dual — that's the polymorphism win. The damage-routing logic and stat-aggregation logic are the only Dual-specific code paths in the engine, and they live entirely inside `DualUnit`.

---

## 7. Kizuna Action (Bond Action) system

Dual doesn't stand alone — it's designed to interlock with **Kizuna Action** (キズナアクション / "Bond Action"), the ambient adjacency-based assist mechanic. Understanding both together is necessary because Dual's most powerful use is to make Kizuna Actions deterministic.

### Core mechanic (independent of Dual)
When a friendly unit is **adjacent** to another friendly unit during combat, there is a **probability** that the adjacent ally will perform a Bond Action — a free contribution to the combat. Bond Actions come in three flavors:

- **Bond Attack** — the adjacent ally throws in a follow-up attack.
- **Bond Heal** — the adjacent ally heals the active unit.
- **Bond Guard** — the adjacent ally blocks/reduces incoming damage.

The probability and the type of Bond Action depend on the unit's Style/skills and the bond rank between the two units. Higher bond rank = higher trigger rate.

### How Dual transforms Kizuna Action
This is the key interlock: **when units are in Dual state, the Back-line's Bond Action is guaranteed to trigger** instead of being probabilistic. This is the core strategic payoff of Duling — converting an RNG support effect into a deterministic one.

Concrete examples:
- A healer in Back-line of a Dual will Bond Heal **every turn**, not "sometimes."
- A guard-type unit in Back-line will Bond Guard **every incoming hit**, not "sometimes."
- A second attacker in Back-line will Bond Attack **every time the front attacks**, not "sometimes."

This is why the Japanese guides specifically highlight Bond Heal as the most game-changing use of Dual at higher difficulties.

### Architecture note
Bond Action is the mirror image of Dual: where Dual is a wrapping construct, Bond Action is a hook in the combat resolver.

```
when active_unit attacks/is_attacked:
    for adjacent_ally in active_unit.get_adjacent_allies():
        if active_unit.is_in_dual_with(adjacent_ally):
            trigger_bond_action(adjacent_ally, active_unit)   # guaranteed
        else:
            if random() < bond_action_chance(adjacent_ally, active_unit):
                trigger_bond_action(adjacent_ally, active_unit)  # probabilistic
```

In event-driven terms: the combat resolver emits `attack_resolving(attacker, defender)`. A `BondActionService` autoload listens, scans the attacker's adjacent allies (or the Dual back-line), runs the trigger check, and if it fires, dispatches a `bond_action_triggered(actor, kind)` event back into the combat resolver before damage is finalized. Bond Heal applies after damage; Bond Guard applies during damage calculation; Bond Attack queues a follow-up attack.

This is yet another reason the event bus pattern pays off — Bond Action could be added, removed, or replaced entirely without touching combat logic. It hooks in via events, modifies outcomes via events, and exits cleanly.

---

## 8. Architecture summary

The architectural backbone for this project:

**An event bus for combat events.** Single autoload singleton with signals for every meaningful gameplay moment (`damage_dealt`, `unit_killed`, `weapon_used`, `weapon_broke`, `dual_formed`, `dual_dissolved`, `bond_action_triggered`, etc.). Combat logic emits; every other system subscribes. Never reverse this dependency.

**Component composition over inheritance.** Units are aggregations of Components (`StatsComponent`, `WeaponSlotComponent`, etc.). No deep class hierarchies. Adding a new mechanic means adding a Component and listening to events.

**Resource-driven data.** Weapons, classes, terrain types, skills, Bond Actions are all Godot `Resource` subclasses (`.tres` files). No hardcoded tables. Designers can edit `.tres` files without touching code.

**View / gameplay separation.** `UnitGameplay` runs the simulation; `UnitView3D` renders it. View subscribes to gameplay signals — never the reverse. This means headless testing works, swappable art styles work, replay systems become tractable.

**Polymorphic units.** `DualUnit` and `CharacterUnit` both implement the same gameplay interface. The combat system doesn't branch on "is this a Dual?" — it just calls the interface. The Dual handles Front/Back routing internally.

**Hook services for cross-cutting concerns.** EXP, Bond Actions, achievements, and tutorial triggers are all autoload services that subscribe to combat events and either react (EXP, achievements) or feed back into combat (Bond Actions). They never live inside combat logic.

If you commit to these six principles up front, the systems above compose cleanly. Skip any of them and the codebase will fight you within a few hundred hours of work.

---

## 9. Architecture lessons from the Aster Tatariqus datamine

We now have access to the decompiled Unity / IL2CPP source via the `laqieer/AT-Datamine` repository. The decompilation gives us class structures, field layouts, method signatures, and namespace organization — but **not** method bodies (those are stripped, leaving empty stubs). That's still extremely valuable: we can see exactly how the developers organized the system, what their abstractions are, and where the boundaries between subsystems lie. Below are the most important architectural lessons, mapped to Godot equivalents.

### Naming clarification (resolved): "Double" vs "Duel"

There's a translation quirk worth nailing down before going further, because the codebase uses two terms that look similar in English but mean very different things:

| Code term | What it actually is | What players call it (EN UI) |
|---|---|---|
| **Double** (`DoubleCommand`, `ReleaseDoubleCommand`, `SwitchDoubleCommand`) | The two-units-on-one-tile pair-up mechanic | **"Dual"** button |
| **Duel** (`DuelScene`, `Duel`, `DuelActionLogic`, `DuelCommand`) | The single combat exchange (attack + counterattack + bond support sequence) | The combat resolution itself |

Both come from English loanwords in Japanese (ダブル *daburu* and デュエル *dueru*) but map to different gameplay concepts. The English-facing UI flattens "Double" → "Dual" because "Double" sounds awkward as a button label. **In our codebase we should pick one term per concept and stay consistent.** Recommendation: use **"Duo"** for the pair-up (avoids both ambiguity and the "Double" / "Dual" confusion) and **"Combat"** or **"Engagement"** for the single combat exchange. The rest of this section uses Aster's terms (Double, Duel) when referring to specific datamined files for traceability.

### Confirmed architectural patterns from the source

#### 9.1. The `BattleCore` is a composition of focused processors

The single most important file is `Battle.Process.BattleCore`. It's not a god-class — it's a pure aggregation of separately-owned processors, each with one responsibility:

```
BattleCore
├── BattleDecision           — win/lose condition checks
├── BattleLevelUpProcessor   — Style EXP and level-up handling
├── BattleSupportValueProcessor — bond/support value tracking
├── BattleWeaponProficiencyProcessor — Weapon EXP / proficiency
├── BattleAdvProcessor       — story scene / cutscene transitions
├── BattleSortieProcessor    — reinforcement spawning
├── IRollbackProcessor       — action rewind
├── BattleLogProcessor       — battle event log
├── BattleSuspendSave        — mid-battle save/resume
└── BattleTaskManager        — async task orchestration
```

This is exactly the "hook services for cross-cutting concerns" pattern we proposed in Section 8 — but validated by a shipped, complex game. **Each processor is replaceable, testable in isolation, and listens to commands rather than living inside combat logic.**

In Godot, every one of these processors maps to either an autoload singleton or a child node of a `BattleManager`. The autoload form is cleaner if there's only ever one battle at a time (which there is in an SRPG). Use a structure like:

```
BattleManager (Node)
├── BoardData (Resource)              — the source of truth for grid + units
├── ExperienceService (autoload)      — subscribes to combat events, awards EXP
├── BondService (autoload)            — subscribes to combat events, updates bonds
├── ProficiencyService (autoload)     — subscribes to weapon-use events
├── RollbackService (autoload)        — snapshots BoardData per action/turn
└── BattleLogService (autoload)       — collects events for replay/debug
```

#### 9.2. Commands are the unit of action — and they are first-class objects

The `Battle.Command` namespace contains a clean hierarchy:

```
CommandBase
└── UnitCommandBase
    ├── MoveCommand
    ├── DummyMoveCommand
    ├── StayCommand
    ├── SkillCommand (extends SkillCommandBase)
    ├── ChargeStartCommand
    ├── DoubleCommand           — pair up
    ├── ReleaseDoubleCommand    — separate
    ├── SwitchDoubleCommand     — swap front/back roles ⭐ (we missed this earlier!)
    ├── DuelCommand             — initiate combat
    ├── InteractCommand         — open chest, hit switch, use warp
    └── UseItemCommand
```

Each command implements a fixed lifecycle: `Validate() → Prepare() → ExecuteInternal() → CompleteInternal()` with a `CanceledInternal()` for rollback. This is the **Command pattern** in textbook form, with rollback support baked in. The processor services (EXP, bond, proficiency, etc.) take a `UnitCommandBase` as input and respond to it — they don't hook into combat logic, they hook into commands.

**Important new finding from the datamine: `SwitchDoubleCommand` exists as a separate command.** While in Double, you can swap which unit is Front-line and which is Back-line **without dissolving the pair**. I missed this in the gameplay research because the Japanese guides framed it as a sub-action. This is a genuine third Double-related action, not just Form / Release. Update Section 6 mentally: there are three Double commands, not two — Form, Switch, Release.

In Godot, `Command` is a `RefCounted` subclass (or a regular class). Each command is an immutable record describing an intent: "unit X moves from A to B," "unit X pairs with unit Y on tile Z." A `BattleCommandQueue` autoload accepts commands, validates them, executes them, and serializes them for the rollback service. **Do not put gameplay logic inside command-receiving UI code.** UI builds a command and submits it; the queue does the rest.

#### 9.3. CommandType is a Flags enum — menu construction becomes a bitwise check

```csharp
[Flags] enum CommandType {
    None = 0,
    AttackSkill   = 1<<1,
    SwitchWeapon  = 1<<2,
    StratagemSkill = 1<<3,
    SupportSkill  = 1<<4,
    ChargeSkill   = 1<<7,
    Double        = 1<<8,
    SwitchDouble  = 1<<9,
    ReleaseDouble = 1<<10,
    Item          = 1<<12,
    Interact      = 1<<13,
    Stay          = 1<<20,
    Cancel        = 1<<21,
    Move          = Cancel | Stay,
}
```

Notice `SwitchWeapon` is a first-class command type — confirming you can swap Main and Sub mid-turn. Notice also that menu visibility is computed by `(unit.allowed_commands & CommandType.Double) != 0`. The action menu doesn't ask the unit "can you Double?" — it iterates the Flags enum and renders a button for each set bit. **Adopt this pattern.** In Godot, an `int` with `@export_flags` provides the same expressiveness.

#### 9.4. `TargetPair = (Unit, Grid)` is the canonical addressing tuple

A surprising amount of the codebase deals in `TargetPair` objects — a lightweight struct holding `(UnitParameterData unit, GridData grid)`. This is the canonical way to refer to "this unit on this tile." Almost every targeting, range-search, and prediction operation produces or consumes `List<TargetPair>` or `TargetPair`. The `Team` class is even built on top of `TargetPair` (with a `Front` field of that type — front-line of a Double is a TargetPair).

Adopt this. In Godot, define a tiny helper:

```gdscript
class_name TargetRef
var unit: CharacterUnit
var grid: Vector2i
```

Use it everywhere a function would otherwise take both a unit and a position. It clarifies signatures and prevents the "did I pass the unit or the grid coord?" bug.

#### 9.5. The Duel (combat exchange) is a queue of typed actions

`Battle.DuelScene.Duel` is literally `Queue<IDuelAction>`. The `ActionType` enum gives us the full taxonomy of things that can happen inside a single combat exchange:

```
InitiateSkill, StatusEffect, Attack, Heal, SingleSkill, AfterSingleSkill,
Stratagem, Revive, Dead, Consume, Broken, Drain, OtherDamage, OtherHeal,
PullBack, PushBack, OverSkillOwner, SwapPosition
```

Each is a discrete `IDuelAction` that processes in order. The `Simple*` action classes (`SimpleAttack`, `SimpleHealing`, `SimpleHpDamage`, `SimpleBreakWeapon`, `SimpleDying`, etc.) are concrete implementations.

**This is the correct way to model combat exchanges.** Don't try to compute combat in one giant function. Build a list of actions to execute, then execute them in order. Bond Actions are inserted into this queue at the right position. Counterattacks are inserted. Weapon-break events are inserted. Status effects are inserted. The visualizer plays them in sequence.

In Godot, this is `Array[CombatAction]` where `CombatAction` is a discriminated union (Resource subclass with a `kind` enum). A `CombatResolver` builds the queue, then a `CombatPresenter` consumes it asynchronously, awaiting animations between actions.

#### 9.6. Simulators mirror commands for prediction (UI previews)

Parallel to the command hierarchy, there's a `Simulator` hierarchy:

```
SimulatorBase
├── MoveSimulator
├── InteractSimulator
├── StaySimulator
├── SkillSimulator
└── DuelSkillSimulator
```

Simulators take the same inputs as their corresponding commands but produce `PredictionResult` objects without mutating state. **This is what powers damage previews, move-range hover effects, and AI scoring.** The AI runs simulators to score candidate moves; the UI runs simulators to show "if you attack here, you'll deal 47 damage with 89% hit."

**Do not inline prediction logic into the command's `Execute` method.** Instead: each command class has a paired simulator. The damage formula lives in one place, called by both. In Godot:

```gdscript
class_name AttackSimulator
static func predict(attacker: CharacterUnit, defender: CharacterUnit, weapon: Weapon) -> AttackPrediction:
    # pure function, no mutation
    ...

class_name AttackCommand extends Command
func execute() -> void:
    var prediction = AttackSimulator.predict(attacker, defender, weapon)
    # apply prediction to actual state
    ...
```

This means the AI, the UI, and the executor all consult the same formula.

#### 9.7. AI is data-driven via Lua (MoonSharp)

The AI is implemented as **Lua scripts evaluated by MoonSharp**, not as hardcoded C# behavior trees. Each enemy AI personality is a `.lua` file defining an `ActionRoutine` and a `CalcScore` method. The C# `AIScript` class is essentially a Lua interpreter wrapper that exposes battle data to the script.

This is overkill for a small project but is the right call at scale: designers can author new enemy behaviors without programmer involvement, and you can hot-reload AI for tuning. For your project, the equivalent options in Godot are:

- **Simple**: Resource-driven scoring weights. Each enemy archetype is a `.tres` with weights for "prefer ranged targets," "prefer low-HP targets," etc. The AI is one C# / GDScript function consuming weights.
- **Medium**: GDScript-as-data. AI behaviors are `.gd` scripts loaded as resources, each implementing `score(unit, candidate_action) -> float`.
- **Heavy**: Embed a scripting language (Lua via gdlua, or use Godot's own Expression class) for designer-authored AI. Skip until needed.

Start with the simple option. Migrate up only when designers actually want to author AI behaviors and complain about the limits.

#### 9.8. Rollback is per-action and per-turn, snapshot-based

`BattleRollbackProcessor` keeps two parallel lists:

- `backupPerAction` — full `BoardData` snapshot after every command execution
- `backupPerTurn` — full `BoardData` snapshot at every turn start

Both lists serialize to bytes for save/resume. Rolling back is just "restore index N from the action list." The Japanese guides confirm players can rewind up to 3 times per battle, which suggests the action list is bounded (probably 3 entries on a circular buffer).

**Do this.** The naive "store deltas and replay them backwards" approach is a nightmare to debug and validate. Snapshot the full `BoardData` resource at decision points and just restore on rollback. Memory cost is low because `BoardData` is small (grid + units + flags). In Godot, `Resource.duplicate(true)` gives you a deep-copy snapshot in one call.

#### 9.9. The `IUnitView` interface is purely visual — no gameplay state

`IUnitView` only exposes view-layer methods: `Show()`, `Hide()`, `UpdateWorldPositionTo()`, `UpdateDisplayVfx()`, particle handles, position offsets. **It has zero combat logic.** Combat queries `UnitParameterData`; the view subscribes to events and updates accordingly. This is exactly the view/gameplay split we proposed in Section 2 — validated.

The `Actor` / `CharacterActor` / `ObjectActor` hierarchy on the view side parallels the gameplay-side `UnitParameterData`. Each side has its own type system; they communicate only through a thin event surface.

**Adopt this.** Your `CharacterUnit` (gameplay) should never have a reference to a `Sprite3D`. Your `UnitView3D` (view) should never read combat stats directly. They communicate via signals, full stop.

### Things from the datamine that we should NOT copy

The codebase clearly carries technical debt from a long-running mobile gacha game. Some patterns are there for reasons that don't apply to a smaller project:

- **`Battle.Adv` / `BattleAdvProcessor`** — story scene injection mid-battle. Skip unless you actually need cutscenes during fights.
- **`Battle.Arena`, `Battle.Expedition`, `Battle.StoryBattle`** — separate phase factories for different battle modes. We have one mode (story battle); don't build the abstraction until needed.
- **`Battle.Score` + score factories** — gacha-style "battle rating" output. Not needed.
- **`BattleSuspendSave`** — mid-battle pause/resume to disk. SRPG players rarely need this on desktop. Skip until you ship to mobile.
- **IL2CPP-specific concerns** — `Token`, `FieldOffset` attributes are Unity AOT artifacts. Ignore entirely; they're not part of the design.

### Recommended extensions to our existing architecture

Based on the datamine, three additions to the architecture sections above:

**1. Add a `CommandQueue` abstraction (between UI and BattleCore).** Don't let UI call gameplay methods directly. UI builds a `Command`, submits it to the queue, and observes events. This makes rollback trivial and replays free.

**2. Add a `Simulator` layer parallel to commands.** Every command type has a paired simulator that predicts the outcome without mutation. The AI, the UI tooltips, and the executor all consult simulators.

**3. Add a `DuelActionQueue` for combat resolution.** When two units engage, build a list of `CombatAction`s (attack, counterattack, bond support, weapon break, status effect, death) and execute them in order. The presenter awaits each animation; the resolver computes the next.

These three additions, on top of the six principles in Section 8, give you the same backbone Aster Tatariqus shipped with — minus the gacha and IL2CPP overhead.

### Mapping table — Aster terms to our project

| Aster Tatariqus term | Our project term | Notes |
|---|---|---|
| `BattleCore` | `BattleManager` (Node) + autoload services | Same role |
| `UnitParameterData` | `CharacterUnit` (Node) | Gameplay-side unit |
| `IUnitView` / `CharacterActor` | `UnitView3D` (Node) | View-side unit |
| `BoardData` | `Board` (Resource) | Grid + units source of truth |
| `GridData` | `Tile` (Resource) | Single tile data |
| `TargetPair` | `TargetRef` | (unit, grid_position) tuple |
| `Double` | `Duo` (proposed) | Pair-up mechanic |
| `Duel` | `Combat` (proposed) | Single attack exchange |
| `UnitCommandBase` | `Command` (RefCounted) | Action object |
| `SimulatorBase` | `Simulator` (static class) | Pure prediction |
| `IDuelAction` | `CombatAction` (Resource) | Element of a combat queue |
| `BattleSupportValueProcessor` | `BondService` (autoload) | Bond accrual |
| `BattleLevelUpProcessor` | `ExperienceService` (autoload) | Style EXP |
| `BattleWeaponProficiencyProcessor` | `ProficiencyService` (autoload) | Weapon EXP |
| `BattleRollbackProcessor` | `RollbackService` (autoload) | Snapshot-based rewind |
| `AIScript` (Lua) | `AIBehavior` (Resource) | Start with weighted scoring |

---

## 10. AI architecture — Lua scripting and what to do in Godot instead

### What Aster Tatariqus actually does

Looking at `Battle.Process.AIScript.cs`, the AI is a **MoonSharp-driven Lua interpreter wrapper**. Each AI personality is a Lua script with a fixed contract:

- A `CreateActionRoutine` function that builds candidate actions
- A `SimulateActionRoutine` that runs them in dry-run
- A `CalcScore` function that scores each candidate
- An `Execute` function that commits the chosen action
- Optional `Include` / `CreateStatic` / `Environment` symbols for shared utilities

The C# code exposes battle data (grid, units, stats) to the script via `MoonSharp.Interpreter.Script` and registered types. The data side is in `MasterData/masterdata_ai/`:

- **AIRole** — five archetypes: Attacker, Tanker, Buffer, Healer, Other (literally `アタッカー / タンカー / バッファー / ヒーラー / その他`).
- **AIType** — named personalities with descriptions like "ボス/HP>50%" (Boss / HP > 50%) and "村人" (Villager). Each links to a `scriptName` (e.g. `AITypeTest`, `AITypeMoveTest`) and an `assetBundleName` of `content_ai_aitype`. The actual Lua scripts live in that asset bundle, which is **not unpacked in this datamine** — so we have the architecture but not the script contents.
- **MoveTypeLandScore** — pathfinding scoring weights per (locomotion type, terrain landform) pair. This is what makes a flier prefer to fly over forests while a horse prefers roads.

The AI architecture is therefore: **C# engine + Lua personality scripts + JSON scoring tables.** Designers can author new enemy behaviors by writing a Lua file and a row in `AIType.json`, no programmer involvement needed. This is the right call for a long-running gacha game with hundreds of enemies and dozens of bosses needing distinct behaviors.

### Should you use Lua in Godot?

**Short answer: no, not initially.** Lua-in-Godot is possible but not free, and you don't need it yet.

The options ranked by complexity:

| Approach | Effort | When to use |
|---|---|---|
| Static AI in GDScript / C# | Low | Always start here |
| Resource-driven scoring weights | Low | When 2nd enemy archetype appears |
| GDScript scripts as Resources | Medium | When designers want to author behaviors |
| Embedded Lua via gdlua / lua-godot | High | Only if you ship to mod-friendly platforms |
| Embedded scripting via Godot's `Expression` | Low-Medium | For simple condition trees |

Lua is overkill for a small-team project. **Godot's `Expression` class can evaluate runtime-defined logic without embedding Lua at all** — it parses a string expression with variable bindings and returns a result. That's enough for "if this enemy's HP < 30%, prefer healing actions" without a real scripting language.

### Recommended starting AI architecture for Godot

A single AI service with three layers:

```
AIController (autoload)
├── AIBehavior (Resource)    — declarative weights / triggers per archetype
├── ActionScorer (static)    — scores a (unit, action, target) tuple
└── ActionRoutine (static)   — generates candidate actions for a unit
```

`AIBehavior.tres` is just data:

```
class_name AIBehavior extends Resource
@export var role: AIRole               # Attacker, Tanker, Buffer, Healer, Other
@export var aggression: float          # 0..1
@export var self_preservation: float   # 0..1
@export var prefer_high_value_targets: float
@export var prefer_low_hp_targets: float
@export var stay_in_pair_threshold_hp: float
@export var move_type_terrain_scores: Dictionary  # (move_type, terrain_id) -> float
```

`ActionScorer` is a pure function:

```
func score(unit, action, target_unit, board) -> float:
    var score = 0.0
    score += unit.behavior.aggression * predicted_damage(unit, target_unit)
    score -= unit.behavior.self_preservation * predicted_counter_damage(target_unit, unit)
    score += unit.behavior.prefer_low_hp_targets * (1.0 - target_unit.hp_ratio)
    # ...etc
    return score
```

`ActionRoutine` enumerates legal actions, scores them via `ActionScorer`, picks the highest, and submits a `Command`. This is roughly 50–100 lines of GDScript and gets you 90% of what Lua-with-MoonSharp delivers.

If later you actually need designer-authored behaviors, swap `ActionScorer` for a per-archetype script: each archetype's `.gd` file implements `score()`, loaded as a Resource. You preserve the same architecture; you just push complexity outward when there's pressure to.

### Pathfinding cost: copy this directly

The `MoveTypeLandScore.json` pattern is something to adopt unchanged. Pathfinding in an SRPG isn't just about finding the shortest route — it's about finding the route the AI **prefers**. A flying unit and a foot soldier go through the same map differently. Implement this as a 2D dictionary keyed by `(move_type, landform_type)` returning a cost multiplier. The pathfinder reads it during edge cost calculation. Done.

---

## 11. Data architecture — the MasterData lessons

The `MasterData/` folder contains **102 separate sub-folders of JSON tables**, each defining one slice of game data. This is industrial-scale data modeling. We don't need 102 — but the patterns are worth copying.

### Schema patterns confirmed from the dump

**Every record has an `ID` integer** that other tables cross-reference. Aster uses an ID space wide enough that prefixes encode category (e.g. `1101` = Class group 1, sub-class 1; `4401001` = landform tag 4, group 401, variant 001). Adopt this — readable IDs save you from constant lookup-table joins.

**`initial*` and `limit*` paired stats.** Every weapon stat has both a starting value and a max-limit-break value (`initialPower` / `limitPower`, `initialHit` / `limitHit`, etc.). The current value is interpolated based on the weapon's current limit-break level. This is the right pattern for any "level up to grow stats" system.

**Reinforce values are flat, not multiplicative.** Weapons have `initialReinforceFire`, `initialReinforceSlash`, `initialReinforcePoison` etc. — one column per element, weapon-type, and status effect. This is **wide schema design**: instead of a separate `WeaponReinforces` table joined back to `Weapon`, every reinforce value is its own column. It's repetitive but JSON-friendly, easy to spreadsheet-edit, and avoids join complexity.

**Wide vs narrow tradeoff for your project.** Wide schema is great for designer-edit-in-Excel workflows; narrow (relational) is better if you have lots of variant cases. For Godot resources, wide is usually right because `.tres` files are most readable when one Resource = one record.

### Real numbers from the game balance data

From `BattleConst.json`:

```
BattleRollbackSaveTurnCount: 5     // keep 5 turns of history for resume
BattleRollbackFreeCount:     3     // 3 free rewinds per battle (matches player guides)
BattleRollbackPaymentAmount: 100   // 4th+ rewind costs 100 gems
FastModeSpeed:               3.0   // animation speedup
IncreaseSupportValueBySkill: 5     // bond + when supporting
IncreaseSupportValueByClear: 5     // bond + when winning together
DecreaseSupportValueByDead:  40    // bond - when paired ally dies
```

From `BattleLogicConst.json`:

```
MinDamage: 1
MaxDamage: 9999
ElementAdvantageRate:    30   // +30% damage with element advantage
ElementDisadvantageRate: 30   // -30% damage with element disadvantage
DoubleStatusAdjustValue: 100  // pair stat correction baseline
LoadWeightCoefficient:   30   // weapon weight → speed reduction
```

These are starting points that Studio FgG arrived at after balancing. **Use them as defaults for our project and iterate from there** — they encode hard-won design intuition about what "feels right."

### Folder structure for `data/` in our Godot project

Don't replicate 102 folders. Start with these and split when one grows unwieldy:

```
res://data/
├── battle_const.tres            # the BattleConst + BattleLogicConst bundle
├── classes/                     # Style / Class definitions
│   ├── swordsman.tres
│   ├── knight.tres
│   └── ...
├── weapons/
│   ├── iron_sword.tres
│   └── ...
├── skills/
│   ├── slash.tres
│   └── ...
├── range_shapes/                # range pattern bitmasks
│   └── diamond_1to2.tres
├── terrain/                     # landform definitions
│   ├── plain.tres
│   ├── forest.tres
│   └── ...
├── ai_behaviors/
│   └── attacker.tres
├── characters/                  # roster (master character data)
│   └── ...
└── maps/                        # battlefield map data
    └── ...
```

### Range shapes as 2D bitmasks

This is a clean pattern from `RangeShapeDetail.json` worth lifting verbatim:

```json
{
  "groupID": 1001,
  "numCols": 3,
  "Cells": [
    -1, 1, -1,
     1, 101, 1,
    -1, 1, -1
  ]
}
```

`numCols` = grid width, `Cells` = flat row-major array. `-1` = empty, `1` = in-range, `101` = origin marker. Every attack/skill range in the game is one of these. As a Godot Resource:

```
class_name RangeShape extends Resource
@export var num_cols: int
@export var cells: PackedInt32Array

func get_offsets_from_origin() -> Array[Vector2i]:
    var origin_idx = cells.find(101)
    var origin = Vector2i(origin_idx % num_cols, origin_idx / num_cols)
    var offsets: Array[Vector2i] = []
    for i in cells.size():
        if cells[i] == 1:
            var pos = Vector2i(i % num_cols, i / num_cols)
            offsets.append(pos - origin)
    return offsets
```

Skills reference range shapes by ID; range shapes are lookup-cached at startup.

### Locomotion types: the eight Aster uses

From `Move.json`, with our recommended naming:

| Aster name (JP) | English | Mobility | Air | Notes |
|---|---|---|---|---|
| 歩兵 | Infantry | 5 | no | Standard foot soldier |
| 上級歩兵 | Advanced Infantry | 5 | no | Same mobility, higher base stats |
| 飛行 | Flying | 6 | yes | Ignores most terrain costs |
| 上級飛行 | Advanced Flying | 6 | yes | |
| 騎馬 | Cavalry | 7 | no | Fast on roads, slow in forests |
| 上級騎馬 | Advanced Cavalry | 7 | no | |
| 浮遊 | Floating | 5 | yes | Flies but at infantry speed |
| 大型ボス | Large Boss | (varies) | no | Multi-tile units |

The `isAir` flag matters because air units can pass over water/cliff that ground units can't. `Large Boss` is a hint that **the engine supports multi-tile units** (a unit occupying e.g. 2×2 grid tiles). Our project may or may not need this; defer until you have a clear use case.

---

## 12. The FieldMap format — how their battle maps are stored

Each map is a folder with a master YAML file plus per-mission variants. Looking at `FieldMap/content_bg_field_201000000_map/201000000.yml`:

### The map schema

```yaml
field_name: "Bgf_S0100_00_00"
width: 42                # grid width in tiles
height: 42               # grid height in tiles
movable_width: 42        # playable subset width
movable_height: 42       # playable subset height
map_chip_scale: false

# The 3D ground mesh — usually one big FBX
ground:
  - x: 0
    y: 0
    name: Bgf_S0100_00_00
    full_name: Field/Bgf_S0100_00_00/fbx/Bgf_S0100_00_00.fbx/Bgf_S0100_00_00
    height: 0

# Decorative scenery placed by tile coordinate
objects:
  - x: 23
    y: 39
    rotate: 0
    name: Bgf_S0100_00_Uobj_Bushe_A
    full_name: Uobj/Large/Bgf_S0100_00/Bushe/fbx/Bgf_S0100_00_Uobj_Bushe.fbx/Bgf_S0100_00_Uobj_Bushe_A
  # ...thousands of these

# Per-tile landform ID — a flat width × height array
attributes: [4401001, 4401001, 1103001, 1103002, ...]

# Per-tile combat-scene background — also flat width × height
duel_scenes: [101000011, 101000011, 101000011, ...]

# Per-tile elevation — 4 corner heights per tile (1764 entries for 42×42)
heights:
  - [0.000000, 0.000000, 0.000000, 0.000000]
  - [0.000000, 0.000000, 0.000000, 0.000000]
  # ...
```

### Key observations

**One mesh, many overlays.** The 3D world is a single FBX (the `ground` entry) for the artist to author in their DCC tool of choice. The grid logic is overlaid via the `attributes` array — gameplay doesn't care what the mesh looks like, it cares which landform ID each tile is. **This is the right separation:** artists build pretty 3D environments; designers paint landform IDs over the grid.

**Four corner heights per tile.** `heights[i]` is `[h_NW, h_NE, h_SW, h_SE]`. This lets tiles slope smoothly between neighbors — exactly how Final Fantasy Tactics modeled terrain. The `groundOffset` in landform data may stack on top of this for "this tile sits 0.5m higher than its grid corners suggest" cases.

**Duel scenes per tile.** Combat backdrops are looked up per attacker-tile, so when you fight on a forest tile, the close-up combat backdrop is forest-themed; on a cobblestone tile, it's cobblestone. We're skipping animated combat, so we ignore this column — but the pattern of "per-tile metadata that drives presentation" is worth keeping in mind.

**Multiple YAML variants per map folder.** A single battlefield has a base `<map_id>.yml` plus per-mission variants like `11010101.yml`, `11010104.yml`. The variants likely override unit start positions, reinforcements, victory conditions, and possibly small tile changes per mission — same battlefield, different scenarios.

### How to do this in Godot

You don't need YAML. Godot's `Resource` system + scene editor is better than YAML for visual editing, and you can still serialize to JSON/YAML if you want external tooling.

```
class_name BattleMap extends Resource
@export var field_name: String
@export var width: int
@export var height: int
@export var ground_scene: PackedScene             # the 3D environment mesh
@export var attributes: PackedInt32Array          # width * height landform IDs
@export var heights: Array                        # width * height tuples of [NW,NE,SW,SE]
@export var scenery_objects: Array[SceneryPlacement]
@export var deployment_zones: Array[Vector2i]     # where players place units
@export var enemy_placements: Array[EnemyPlacement]
@export var victory_conditions: Array[VictoryCondition]
```

Authoring workflow: build the 3D environment as a normal Godot scene, then run a custom in-editor tool ("Battle Map Painter") that lets you paint landform IDs and corner heights onto the grid overlay, saving to the `BattleMap.tres`. **Mission variants** are separate `BattleMap.tres` files that reference the same `ground_scene` but override placements/conditions.

Implementation of the painter is moderate effort — you can lift the design straight from any tile-painter tutorial and just have it write to the resource fields.

---

## 13. The camera system — multi-mode + smooth transitions

You specifically wanted this implemented because it's a major UX feature. The datamine gives us the full design.

### The architecture (from `CameraDirector.cs` and `MapViewCamera.cs`)

```
CameraDirector (Node)
├── MainUiCamera                           # 2D overlay camera (UI)
├── List<MapViewCameraSetting>             # the camera mode presets
├── MapViewCamera (the active camera)
│   ├── PoR (Point of Rotation) — pivot Transform
│   ├── rotationRoot — child Transform that holds the camera at distance
│   ├── mapGridCamera — renders the 3D world
│   ├── mapUiCamera — renders battle UI in screen space
│   ├── moveLerp / rotateLerp / distanceLerp — smooth animation curves
│   └── min/max position clamps
├── InputControllCamera2D — pan/zoom gesture handler
├── DoFController — depth of field
└── IOnSwitchCameraSettingHandler — listener for mode changes
```

**The key is the pivot rig.** The camera doesn't fly freely — it orbits a `PoR` (Point of Rotation) at a fixed `distance`. When you "move the camera," you actually move the PoR; when you rotate, you rotate the PoR; when you zoom, you change the distance. This makes camera behavior trivially predictable and constrains the camera to a sensible motion envelope.

### The CameraSetting struct (the key data type)

```
struct MapViewCameraSetting {
    int Id;
    float MaxDistance;       // farthest zoom
    float MinDistance;       // closest zoom
    float InitialDistance;   // default zoom on activation
    float UserDistance;      // last user-chosen zoom (per-setting!)
    Vector3 RotationAngles;  // pitch/yaw/roll in degrees
    float HeightOffset;      // pivot vertical offset
    bool RequireSideCover;   // whether to render side-cover billboards
}
```

**Each preset is a complete camera configuration.** The user cycles through presets via `SetNextMapViewCameraSetting(duration)` or jumps directly via `SetSpecifiedMapViewCameraSetting(index, duration)`. The `duration` parameter triggers a smooth lerp between configurations — switching modes isn't a hard cut, it's an animated transition.

**`UserDistance` is per-preset.** This is a subtle but excellent UX detail: each camera mode remembers its own zoom level. If you zoomed in on the tactical-overhead view, then switched to the close-action view (which has its own zoom level), then switched back to overhead, you're back at your zoomed-in setting. Don't lose this when you implement.

**`RequireSideCover` is a hint** — when the camera goes low/horizontal (close-action mode), flat 2D billboards may be needed to hide the edges of the 3D world that would otherwise be visible. Most projects don't need this; mention it in case you go for a really horizontal camera angle.

### Suggested camera modes for our project

Based on Aster's likely setup and SRPG conventions:

| Mode | Distance | Pitch | Use case |
|---|---|---|---|
| **Tactical** | far | 60–70° | Default — see most of the map |
| **Close** | medium | 45° | Closer view, focuses on action area |
| **Action** | near | 25–35° | Cinematic angle, low to the ground |
| **Top-down** | far | 90° | Pure overhead, useful for placement and overview |

Four presets is generous; three is plenty. Players cycle with `Tab` or `V` (or button on touch).

### Camera input — the `InputControllCamera2D` FSM

The input handler is a four-state finite state machine:

```
None → Move → Zoom → Ignore
```

- **None**: no touch / mouse held.
- **Move**: single touch dragging — pan the PoR.
- **Zoom**: pinch gesture (or scroll wheel) — change distance.
- **Ignore**: input is over UI / blocked area; suppress camera input until released.

The `MoveDeadZoneTouchDistance` static field prevents micro-jitter from being treated as drags. The `PointerEventData` integration with Unity's EventSystem means UI interactions don't accidentally pan the camera — when the touch is over a button, the FSM goes to `Ignore`.

### Godot implementation sketch

```
BattleCamera (Node3D) — the rig
├── Pivot (Node3D) — the PoR
│   └── Camera3D (child at -distance on local Z) — actual camera
├── settings: Array[CameraSetting] — exported list of presets
├── current_setting_index: int
└── input_phase: enum { NONE, MOVE, ZOOM, IGNORE }

func cycle_to_next_setting(duration: float = 0.4):
    current_setting_index = (current_setting_index + 1) % settings.size()
    _animate_to(settings[current_setting_index], duration)

func _animate_to(setting: CameraSetting, duration: float):
    var tween = create_tween().set_parallel()
    tween.tween_property(pivot, "rotation", setting.rotation_angles, duration)
    tween.tween_property(camera, "position:z", -setting.user_distance, duration)
    # ...etc

signal camera_mode_changed(new_index: int)
signal camera_position_changed(new_position: Vector3)
signal camera_distance_changed(new_distance: float)
```

The signals are critical — they let other systems (UI, AI, audio, VFX) react to camera changes without polling.

### What about depth of field?

`DoFController` exists in the codebase. Mobile post-process DoF is expensive but adds a lot of "premium" feel — selectively blur the background to keep focus on the active unit. In Godot 4, `WorldEnvironment` with DoF settings handles this; toggle it per camera mode (probably only enabled in close/action modes, off in tactical mode for clarity).

---

## 14. Other patterns from the datamine worth adopting

A few smaller patterns I noticed that don't deserve their own section but are worth flagging:

### `IStepUpdate` is a single-threaded tick interface

Many classes in `Battle/` implement `IStepUpdate` with a `Step(float delta)` method. Aster runs its battle simulation on a manual tick rather than per-`Update()` Unity callback. This means the simulation can be paused, fast-forwarded (`FastModeSpeed: 3.0` from the const data), or stepped one action at a time for debugging.

In Godot, the equivalent is having `BattleManager` drive its own tick rather than relying on `_process(delta)`. Subsystems have a `step(delta)` method; `BattleManager._process(delta)` calls each subsystem's `step()` with a possibly-scaled delta. Flipping a `time_scale` variable globally speeds up or pauses the entire battle without touching individual systems. The Animation playback then needs to scale animation speed based on `BattleManager.time_scale`.

### Element system — six elements with chain interactions

From `Weapon.json`'s reinforce fields: **Fire, Ice, Thunder, Wind, Light, Dark.** Six elements. The `BattleElementChain.json` table likely defines advantage relationships. With `ElementAdvantageRate: 30` from the consts, an element-advantaged attack deals +30% damage and an element-disadvantaged attack deals -30%. Standard FF-style rock-paper-scissors elements; copy directly.

There's also a separate axis of physical types: **Slash, Blow, Pierce, Shot, Magic** — these are weapon attack types that interact with armor types. So the damage formula has two correction layers stacked: element advantage AND physical-type-vs-armor.

### Status effect taxonomy

The reinforce fields in `Weapon.json` enumerate the full status effect set: **Provocation, Confusion, ShakenUp, Charmed, Berserk, Burned, Sleep, Paralysis, Poison, DeadlyPoison, Bleeding, Dazzlement, Darkness, Petrifaction.** This is more than most SRPGs use. For our project, start with maybe 4–6 statuses (Poison, Sleep, Paralysis, Burn, plus whatever your design demands). Each is a `StatusEffect` Resource with on-apply, per-turn-tick, and on-remove hooks.

### `Barrier` system — HP shields are first-class

`Battle.Unit.Barrier` and `BarrierContainer` are dedicated systems for HP shields. Barriers absorb damage before HP, can have their own duration, can have element/type-specific resistance. This is the right architecture if shields are meaningful in your design — not a stat modifier on HP, but a parallel pool that the damage routing layer drains first.

### `Hate` system — threat / aggro tracking

`Battle.Data.Hate` is referenced. AI uses hate-tracking to decide whom to attack — units that have damaged this AI unit recently are higher-priority targets than fresh ones. Standard MMO/RPG aggro pattern. Optional but cheap; helps make AI feel coherent rather than random.

### Cysharp UniTask for async

Aster uses Cysharp.Threading.Tasks (UniTask) for async control flow — cleaner than coroutines. In Godot you have `await` on signals natively; same idea, no library needed. The pattern of `await battle.PlayAttackAnimation(); await battle.PlayDamagePopup(); await battle.PlayDeathAnimation();` is the right way to chain combat presentation.

---

## 15. Roadmap — what to build first

Based on everything we've covered, here's a suggested implementation order. Each step delivers a working slice; you can stop at any step and have something playable.

**Phase 1 — Bare grid combat (1–2 weeks)**
- `Board` resource (grid + landforms, no elevation yet).
- `CharacterUnit` and `UnitView3D` separated from day one.
- One Style, one weapon, basic `MoveCommand` and `AttackCommand`.
- Phase model: PlayerPhase → EnemyPhase loop.
- Hardcoded damage formula for now; will refactor into Simulator later.

**Phase 2 — Visual foundation (1 week)**
- Pixel sprites (Sprite3D billboards) on a 3D ground mesh.
- Camera rig with one preset; smooth pan/zoom.
- Tile highlighting for movement and attack ranges.

**Phase 3 — Architecture spine (1–2 weeks)**
- Extract `CombatEventBus` autoload.
- Extract `Command` base class and `CommandQueue`.
- Extract `Simulator` static functions paralleling each Command.
- Wire `ExperienceService`, `RollbackService` as listeners.
- Damage previews on hover (uses Simulator).

**Phase 4 — Main + Sub weapons (1 week)**
- `WeaponSlot` components (main, sub).
- `SwitchWeaponCommand`.
- Durability tracking via `weapon_used` events.
- `RangeShape` resources, lookup at attack time.

**Phase 5 — Per-action EXP and Bond (1 week)**
- EXP from kill, hit, heal, buff events.
- Bond values per character pair, `BondService`.
- Style EXP vs Weapon EXP separation.

**Phase 6 — Duo system (1–2 weeks)**
- `DuoUnit` polymorphic wrapper.
- `DoubleCommand`, `SwitchDoubleCommand`, `ReleaseDoubleCommand`.
- Damage routing with single-target / AoE distinction.
- Front-line / Back-line stat aggregation.

**Phase 7 — Bond Action (Kizuna) system (1 week)**
- `BondAction` Resource (Attack / Heal / Guard variants).
- `BondActionService` listening for `attack_resolving` events.
- Probabilistic for adjacent allies; deterministic for Duo back-line.

**Phase 8 — Terrain and elevation (1 week)**
- Landform IDs per tile, `BattleLandCorrect` table.
- 4-corner heights per tile.
- Terrain effects (forest evasion, road speed, hazard tiles).
- Elevation modifiers on damage, range, and pathfinding.

**Phase 9 — Multiple camera modes (3–5 days)**
- `CameraSetting` Resources, list on the camera rig.
- Cycle / direct selection with smooth tween.
- Per-setting `UserDistance` memory.

**Phase 10 — AI and rollback polish (1–2 weeks)**
- `AIBehavior` Resources with weights.
- `ActionScorer` and `ActionRoutine` for enemies.
- Snapshot-based rollback; integrate with UI (rewind button).

**Phase 11+ — Content and depth**
- Style Board / progression nodes.
- Skills with custom range shapes.
- Status effects.
- Element / type damage layers.
- Bigger maps, scripted battles, victory variants.

By Phase 6 you have something genuinely playable that's close to Aster Tatariqus's tactical core. Phases 7–10 add the depth that distinguishes the genre. Phases 11+ are content that scales over the project's lifetime.
