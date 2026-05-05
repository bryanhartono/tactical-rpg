extends Node
## Central pub/sub for combat events. Single autoload (singleton).
## See docs/gdd.md §10.1 (principle 1) and §10.3.
##
## Combat code emits; everyone else subscribes. Never reverse this dependency.
##
## # Type tightening TODO
## CharacterUnit, DuoUnit, and BattleMap don't exist as classes yet (Phase 1+). Their
## payload parameters here are typed as `Node` / `Resource` so the bus compiles in
## Phase 0. When those classes land, tighten the parameter types in one pass.

# ---------------------------------------------------------------------------
# Damage and lifecycle
# ---------------------------------------------------------------------------

## Fired when a unit's HP drops by any amount. damage > 0 always.
## attacker / defender are CharacterUnit (Node). source is the originating Weapon, Skill,
## StatusEffect, or other Resource.
signal damage_dealt(attacker: Node, defender: Node, damage: int, source: Resource)

## Fired after damage_dealt when the defender's HP reaches 0.
signal unit_killed(attacker: Node, defender: Node, source: Resource)

## Fired when an ally heals another (or self-heals). amount is HP actually restored,
## not overheal.
signal healing_applied(healer: Node, target: Node, amount: int, source: Resource)

## Fired when a status effect is successfully applied (post resistance check).
signal status_applied(applier: Node, target: Node, status: StatusEffect)

## Fired when a status effect is removed (expired or cleared).
signal status_removed(target: Node, status: StatusEffect)

# ---------------------------------------------------------------------------
# Weapons
# ---------------------------------------------------------------------------

## Fired when a weapon is used in an action. Used by ProficiencyService and durability
## tracking. slot is 0 for Main, 1 for Sub.
signal weapon_used(user: Node, weapon: Weapon, slot: int)

## Fired when a weapon's durability hits 0 and breaks.
signal weapon_broke(user: Node, weapon: Weapon, slot: int)

# ---------------------------------------------------------------------------
# Duo
# ---------------------------------------------------------------------------

## Fired when two units form a Duo. tile is the merged unit's resulting tile.
signal duo_formed(front: Node, back: Node, tile: Vector2i)

## Fired when a Duo separates back into two units.
signal duo_released(front: Node, back: Node, tile_front: Vector2i, tile_back: Vector2i)

## Fired when front/back roles are swapped within a Duo without dissolving it.
## duo is the DuoUnit (Node).
signal duo_switched(duo: Node)

# ---------------------------------------------------------------------------
# Bond / mid-resolution hooks
# ---------------------------------------------------------------------------

## Fired before damage is finalized — gives BondActionService a chance to insert a
## bond action and listeners a chance to mutate the resolved damage via
## `mutable_damage_ref` (a single-element Array used as a poor-man's ref). See GDD §10.3
## footnote.
signal attack_resolving(attacker: Node, defender: Node, weapon: Weapon, mutable_damage_ref: Array)

## Fired when a Bond Action triggers. kind is one of "attack" / "heal" / "guard".
signal bond_action_triggered(actor: Node, beneficiary: Node, kind: String)

# ---------------------------------------------------------------------------
# Turn / phase / battle lifecycle
# ---------------------------------------------------------------------------

## Fired at the start of each turn for the active unit.
signal turn_started(unit: Node)

## Fired at the end of each turn for the active unit, after they've acted and set facing.
signal turn_ended(unit: Node)

## Fired at the start of each phase. phase is one of "player" / "enemy" / "neutral".
signal phase_started(phase: String, round_number: int)

## Fired at the end of each phase.
signal phase_ended(phase: String, round_number: int)

## Fired when a battle begins. battle_map is a BattleMap (Resource — see GDD §9.2).
signal battle_started(battle_map: Resource)

## Fired when a battle ends. result is one of "victory" / "defeat" / "abort".
signal battle_ended(result: String)

# ---------------------------------------------------------------------------
# Rollback and view
# ---------------------------------------------------------------------------

## Fired by RollbackService after a successful rewind.
signal rolled_back(snapshot_index: int)

## Fired when a unit's gameplay-facing changes. The view layer listens to update
## the facing arrow decal (see GDD §6.1).
signal unit_facing_changed(unit: Node, new_facing: Vector2i)
