# Test coverage and reporting

Run `sh scripts/godot.sh check` from the project root. It imports resources, runs the three suites, checks startup for 60 headless frames, and rejects errors in their logs.

The suite totals count assertions, not independent scenarios or a measure of completeness. Parameterized invariants check every sampled item but report once per rule. Patrol failures include the seed, turn, group, or unit involved.

| Suite | Purpose |
| --- | --- |
| Battle | Activation/action order and Undo Move rules, movement and occupancy, damage/Defense, defeat, line of sight, attack/threat ranges, Perception boundaries, and AI targeting. |
| Patrol | Spawn invariants across 30 seeds, occupancy/speed/stationary guards across 40 turns, endpoint visits, blocked routes, obstacle detours, combat interruption/resumption, regrouping across four end-turn-only reproduction seeds (60 turns maximum each), group pace after a death, randomized terrain connectivity and layout variation, and fixed-seed reproduction. |
| Scene | Input-to-action wiring, layout stability and clipping, highlights/hover cleanup, turn sequencing, restart cancellation, attack effect lifecycle, and victory/defeat screens with casualty totals and replay. |

## October 2026 audit

The previous 2,136 total counted every loop iteration: the patrol suite alone contributed 1,972. These mostly repeated valuable rules across sampled data. The same 30 seeds and 40 turns remain covered, with assertions grouped by invariant and failure context retained. Repeated stat, threat-boundary, and restored-unit checks are also grouped.

Removed the battle suite's duplicate reset snapshot (the patrol snapshot includes both units and groups), a repeated distant-Slinger case (both enemy types retain explicit Perception boundary coverage), and four button-padding implementation checks (scene assertions already check actual board/button geometry during activation). Model and scene regressions remain separate where they exercise different layers, such as validating an attack versus dispatching an enemy click while movement guidance is selected.

Corrected a weak blocked-patrol check: inspecting `moved` after the player turn began could always pass because that transition resets action flags. It now compares actual positions before and after the blocked turn.

This primarily improves reporting and maintainability; the sampled simulations still run, so it does not imply a large speed improvement. Headless suites cannot establish visual quality, browser compatibility, or game balance.

For future additions, use a focused behavioral regression or an existing parameterized case. Avoid counting every unit/tile/frame as a separate success. Preserve distinct boundary cases and identify failing inputs in assertions.

Scene regressions use an explicit empty-terrain fixture so their click coordinates do not depend on map generation. Fresh-seed selection and hero placement are checked separately.

Result-button tests send mouse movement and button press/release events through the viewport, exercising GUI hit testing and input delivery. Emitting `pressed` alone would only test signal wiring. Escape dismissal is covered separately.
