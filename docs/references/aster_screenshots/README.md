# Aster Tatariqus reference screenshots

In-game screenshots from *Aster Tatariqus* (Studio FgG / gumi, 2023), used as
visual reference for this project's HD-2D direction and camera framing.

These screenshots are **not modified or redistributed in builds**. They are
documentation only and ship with the source repository for design reference.

## What each one shows

- `camera_tactical_50deg.jpeg` — Default tactical view. Pitch ~50°, sprites at
  comfortable reading distance, grid visible. Matches our `data/camera_settings/tactical.tres`.
- `camera_overview_70deg.jpeg` — Wide battlefield overview. Pitch ~70°. Matches
  our `data/camera_settings/overview.tres`.
- `camera_topdown_90deg.jpeg` — Pure overhead. Validates that single-direction
  chibi sprites still read at 90° (justifies dropping the GDD's original
  "no top-down" rule). Matches our `data/camera_settings/topdown.tres`.

## Use

When polishing visuals (Phase 2 lighting tuning, Phase 9 camera DoF, Phase 17
final polish), compare side-by-side to these reference shots. They define
*what we're aiming at*, not *what we plan to copy*.