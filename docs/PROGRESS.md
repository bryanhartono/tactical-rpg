# PROGRESS

> Living status document. Updated by Claude Code at the end of every session per `CLAUDE.md` instructions.

**Last updated:** Project kickoff — no work done yet.
**Active phase:** Phase 0 — Project Setup and Architectural Skeleton
**Active task file:** `tasks/phase_0_tasks.md`

---

## Current state

Awaiting user prerequisites (Godot project initialized, .gitignore, MCP server connected). Once user signals ready, Claude Code starts at **P0-T01**.

---

## In Progress

*(Nothing yet — Phase 0 has not started.)*

---

## Next Up

- **P0-T01** — Configure project settings for pixel-art 3D

---

## Recently Completed

*(Empty — no tasks completed yet.)*

---

## Blocked / Open Questions

These are items that need user input before Claude Code can proceed. Claude Code adds to this list when it hits a blocker; the user resolves them by editing this section directly or replying in chat.

### From the GDD §13.2 (open questions deferred from kickoff)

These were flagged in the GDD as decisions still owed. They don't block Phase 0 but will need answers by the phase listed.

| # | Question | Needed by |
|---|---|---|
| 1 | Pin to specific Godot 4.x or follow latest stable? | Phase 0 (P0-T01 picks an initial version; revisit at v1) |
| 2 | GDScript only, or GDScript + C# hybrid? | **Resolved at kickoff: GDScript only for v1.** |
| 3 | Exact damage formula tuning | Phase 5 (playtesting) |
| 4 | Save format — Resource-based vs custom | Pre-v1 |
| 5 | Multi-Style units in v1? | **Resolved at kickoff: no, post-v1.** |
| 6 | Working title and visual identity | Marketing/design track, not engineering |
| 7 | Music / SFX strategy | Post-vertical-slice |

### Project-specific blockers

*(None yet.)*

---

## Phase status overview

| Phase | Status | Task file |
|---|---|---|
| **Phase 0** — Setup and architectural skeleton | 🟡 In progress | `tasks/phase_0_tasks.md` |
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

*(Empty — no decisions logged yet.)*

When adding a decision: keep it to 2–3 sentences. If it's a big decision worthy of more, write a proper ADR in `docs/adr/` and link to it from here.

---

## Notes for the next session

This section is for Claude Code to leave breadcrumbs for itself or the user when stopping mid-task.

*(Empty.)*

---

*End of PROGRESS.md.*
