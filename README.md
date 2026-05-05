# Tactical RPG

A single-player tactical RPG built in Godot 4. Grid-based combat, pixel-art chibi
sprites on 3D terrain, paired-unit ("Duo") mechanic, snapshot-based rewind.
Modeled on *Aster Tatariqus* (Studio FgG, 2023). Single-player, desktop-first.

## Documentation

Read these in order if you're new to the project:

1. [`CLAUDE.md`](CLAUDE.md) — working agreement for AI contributors and humans alike: how
   to start a session, what's authoritative, and the project's code-style preferences.
2. [`docs/gdd.md`](docs/gdd.md) — the Game Design Document. Authoritative for scope,
   mechanics, architecture, and concrete data values.
3. [`docs/tactical_rpg_design_reference.md`](docs/tactical_rpg_design_reference.md) —
   research notes on *Aster Tatariqus* and the architectural rationale behind the GDD.
   Read for the "why" behind a pattern.
4. [`tasks/phase_0_tasks.md`](tasks/phase_0_tasks.md) — current phase's concrete tickets.
   Subsequent phases each get their own task file.
5. [`AGENTS.md`](AGENTS.md) — Godot MCP toolset reference for AI contributors.

When sources conflict: the GDD wins on *what*, the reference wins on *why*.

## Status

Live status — what's done, what's in progress, what's next — lives in
[`docs/PROGRESS.md`](docs/PROGRESS.md). Read it at the start of each session.

## Engine

Godot 4 (latest stable). Primary scripting language: GDScript. Project opens at the
repo root.
