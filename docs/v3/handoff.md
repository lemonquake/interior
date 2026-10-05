# Interior v0.3 — Overhaul Handoff (in progress)

Branch: `polish-v0.3` (from `main` at 5e245ff). Contract: `docs/v3/contract.md`.

## Owner requests

1. "game look atrocious. polish it and completely improve the physics allowing objects to really roll over and
   realistically move. Do not make that messy interior design like in the reference. Overall SIGNIFICANT
   IMPROVEMENT. Then build the EXE and APK." (2026-10-05)
2. "Send screenshots as you make changes so I can follow, also write this in the handoff." (2026-10-05)
   - Every component saves real renders to `work/v3/<component>/screens/NN-<what>.png` (contract §11) and lists
     them in its own handoff.
   - The orchestrator watches those folders and forwards new screenshots to the owner as they appear.
   - Baseline sent: `work/v3/screens/00-before-v0.2.jpg` (current v0.2 look).

## Plan

| Phase | Work | Status |
|---|---|---|
| 0 | Engine switch (Jolt, physics interpolation, Forward+ desktop / Compatibility Android), contract | Done (91bac2a, 3041956) |
| 1 | Foundation, 7 parallel worktrees: design brief + layout, Blender→Godot asset pipeline, physics + interaction, UI, pets habitat, lighting, audio | Running |
| 2 | Asset builds (6 groups: arch, living, tvwall, corner, kitchen, toys_decor) with blind visual review | Pending |
| 3 | Integration of the new room, cross-system tests, visual/physics review and fixes | Pending |
| 4 | Windows EXE + Android APK builds, smoke tests, release notes | Pending |

## Screenshots sent to the owner

| File | What it shows |
|---|---|
| `work/v3/screens/00-before-v0.2.jpg` | Baseline: current v0.2 captures |
