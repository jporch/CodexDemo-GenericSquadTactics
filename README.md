# Generic Squad Tactics

A playable, single-room tactics proof of concept in Godot 4.7.2 / GDScript. Four stronger allies face eight enemies on a 16 × 12 grid. Win by defeating every enemy; lose if all allies fall.

The initial proof of concept is complete: this is a demonstration of the core mechanics, with placeholder visuals and provisional balance.

## Play in your browser

The HTML5 build lives in `builds/web/` (generated, not tracked in Git). After cloning, install Godot and its matching Web export templates, then run from the project directory:

```sh
sh scripts/godot.sh export
sh scripts/godot.sh serve
```

Open **http://127.0.0.1:8060**. Keep that terminal running. Opening the HTML file directly is not supported. The build uses single-threaded WebGL 2 with the Compatibility renderer. Browser keyboard input requires the game canvas to have focus; click it first. Keyboard shortcuts work alongside the on-screen buttons.

To rebuild after changing source:

```sh
sh scripts/godot.sh export
```

Matching **Godot 4.7.2 Web export templates** are installed on this machine. On another machine, install the matching templates through Godot's export template manager before exporting. Refresh the browser after rebuilding; restarting a battle alone does not load changed source files.

## Run or edit in Godot

```sh
sh scripts/godot.sh run
sh scripts/godot.sh editor
```

Or import `project.godot` in Godot, open `scenes/main.tscn`, and press F5 to run the project. Local engine path: `/Applications/Godot.app/Contents/MacOS/Godot`. Verified version: `4.7.2.stable.official.ed1daf0bf`. Set `GODOT_BIN` if the executable moves. Git and Python 3 (for the local server) are available. No plugins, C#/.NET, or external art dependencies are required.

## Controls and turn rules

| Input | Action |
| --- | --- |
| Click an available ally | Activate that unit |
| Click a highlighted empty tile | Move (M optionally selects movement guidance) |
| Click an enemy in range | Attack (A optionally selects attack guidance) |
| Esc | Cancel an activation only before moving or attacking |
| Space | Deactivate an untouched unit; otherwise End hero turn and forfeit any remaining action |
| U | Undo the active hero’s latest move, only when no attack followed it |
| E | End the whole team's turn, forfeiting remaining actions |
| R | Request restart; confirm in the dialog to start a fresh randomized map |

Only one ally can be active at a time. Move and attack in either order, once each. Moving automatically selects attack mode; attacking first automatically selects move mode. Moving then attacking automatically ends the hero’s turn. Attacking then moving keeps the hero active until End hero turn (Space). Move-only and attack-only turns also require an explicit end. Undo Move (U) restores the latest move’s starting square and movement allowance if no attack followed that move; it never reverses attacks or damage. You may move again after undoing. After undoing a move-only activation, cancellation is available again. Untouched activations can be cancelled with Esc or deactivated with Space without penalty; the unit remains available later in the same turn. Finished allies dim and show an `x` until the next player turn.

An active unit shows teal movement tiles and coral inset attack squares together while both actions are ready. After acting, only the unused action range remains. Clicks follow their target: enemy clicks attack and empty-square clicks move, regardless of the M/A guidance selection. Range, line of sight, and remaining actions are always checked. Hover an enemy to see orange hatched squares it could attack now or after one legal move, accounting for its stats, terrain, line of sight, and occupied destinations. This is its full potential reach, not a prediction of which target it will choose.

Rangers and Slingers cannot attack adjacent squares: the Ranger attacks at distances 2–3 and the Slinger at distance 2. Guards, the Knight, and Raiders attack at distance 1. A Slinger may step away before firing. Hover threats include movement, so a square adjacent to its current position may still be threatened if it can first reposition.

Movement is orthogonal and costs one point per square. Allies can be crossed but cannot share a destination; enemies cannot be crossed. Stone walls block movement and shots. Crates block movement but permit shots. Attacks use Manhattan range, guaranteed hits, and damage equal to max(0, Attack minus target Defense). The combat log shows damage after Defense. Shots may pass around exposed wall corners, including between units adjacent to perpendicular faces. Wall interiors and diagonal gaps between two walls still block shots. This line-of-sight rule also applies to enemy Perception. Units do not block shots.

| Type | Count | HP | Attack | Defense | Move | Range |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Guard | 2 | 10 | 3 | 0 | 4 | 1 |
| Knight | 1 | 10 | 3 | 1 | 3 | 1 |
| Ranger | 1 | 10 | 3 | 0 | 4 | 2–3 |
| Raider | 5 | 5 | 2 | 0 | 2 | 1 |
| Slinger | 3 | 5 | 2 | 0 | 1 | 2 |

Hero 2 is the Knight, recognizable by a tall tower shield. The heroes start centered on the left, with the Ranger directly behind the Knight. Enemy hits deal 1 damage to the Knight and 2 to other heroes.

Enemies attack the lowest-current-HP visible hero they can hit this turn, moving first if needed. Equal-HP ties prefer the shortest required move. A healthier immediate target does not override a weaker reachable one. When an attack is not yet possible, enemies approach heroes they can see within Perception. Members without personal sight regroup toward allies in contact; wholly unalerted groups patrol and guards hold position. Raiders have a shield and coral coloring; Slingers have a bow silhouette, violet coloring, and an R marker.

## Patrols and debug flags

The eight enemies spawn in three compact, seeded groups:

- **P1 and P2:** each has two Raiders and one Slinger, patrolling between its A and B areas.
- **G3:** a Raider/Slinger guard pair that holds while no hero is visible.

Flags and tinted tiles mark both patrol areas; matching P# badges identify members. The brighter flag is the current destination. Members that arrive early wait, and all surviving members must reach the area before the group reverses direction. Mixed groups patrol at Move 1, the slowest member's pace. Combat retains the normal Move stats; a group pauses its patrol while any member sees a hero, then resumes after losing sight. Spotting members approach with their own normal Move; members without sight regroup toward an ally who currently sees a hero, using normal Move. They cover once adjacent, and still need their own sight before attacking. Defeating the slower member lets surviving Raiders patrol at Move 2.

The current patrol centers and composition are defined by `spawn_group` calls in `scripts/battle_model.gd`. Each area is a center plus its walkable orthogonal neighbors. These debug markers can be hidden using the Board node's `show_patrol_debug` Inspector setting. They do not block movement or attacks.

## Enemy Perception

Raiders see **6 squares** and Slingers see **8 squares**, measured by Manhattan distance, including the boundary. Walls block sight; crates and units do not. Enemies attack visible heroes when possible, otherwise approach a reachable attack position using their own Move. Ranged units approach firing range rather than trying to occupy the hero's square. Without personal sight, they regroup toward an ally in contact; if the whole group loses sight, they resume patrol or hold. There is no shared vision or remembered target location yet.

Tune Perception in `resources/raider.tres` and `resources/slinger.tres` through the Inspector. The sidebar lists it as Per. Attack Range and hover threat areas remain separate from Perception.

A red **!** over an enemy means it currently sees a living hero within its own Perception and line of sight. The mark disappears when it loses sight; regrouping toward an alerted ally alone does not show it.

## Attack feedback

Adjacent attacks show a red slash on the target. Attacks from farther away send a yellow spark from attacker to target, followed by a small dissipating burst. Both teams use these effects; ranged units cannot make adjacent attacks. Enemy actions wait for their effects to finish. Defeated unit visuals remain until impact; restarting clears effects. Combat still resolves deterministically with no audio.

## Tuning and source

- `resources/*.tres`: unit stats editable in Godot's Inspector.
- `scenes/main.tscn`: layout, controls, randomization toggle, map seed, and enemy action delay.
- `scripts/battle_model.gd`: rules, pathfinding, terrain, deterministic enemy placement, and AI.
- `scripts/main.gd`: input and turn presentation.
- `scripts/board_placeholder.gd`: original code-drawn placeholder board.
- `scenes/attack_effect_placeholder.tscn` / `scripts/attack_effect_placeholder.gd`: slash and spark feedback, with Inspector-editable timings.
- `scenes/unit_placeholder.tscn` / `scripts/unit_placeholder.gd`: replaceable pixel character visuals.
- `DESIGN.md`: agreed rules and provisional first-pass choices.
- `AGENTS.md`: working instructions for Codex.

Every new battle and restart chooses a fresh seed, randomizing five walls, four crates, enemy positions, and patrol endpoints. Heroes start in the middle left with the Ranger behind the Knight. Spawn/endpoint areas stay clear and all walkable terrain stays connected. For reproducible debugging, disable Randomize Map on Main and set Map Seed in the Inspector. See `assets/README.md` for visual replacement guidance.

## Validation

```sh
sh scripts/godot.sh check
```

Runs resource import, battle-rule, patrol, and scene integration assertions, and a 60-iteration headless startup. Patrol checks cover multiple spawn seeds, round trips, group pacing, obstacles, combat interruption, and restart state. Scene checks cover UI activation, action-mode changes, enemy turn completion, and resetting during pending enemy actions. The script also fails on errors recorded in the check logs under `.godot/logs/`.

Totals report assertions, not distinct test scenarios. Repeated seed/unit/turn samples are grouped by rule while retaining failure context. See [the test coverage audit](tests/README.md) for coverage, consolidation decisions, and guidance for new checks.

Verified locally: the rules and scene assertions pass, resource import and headless startup complete without errors, and the HTML5 build loads in the Codex in-app browser. Browser playtesting covered activation/cancellation, movement, locking after an action, turn transitions, enemy move-and-attack, player attack damage, and confirmed restart. Cross-browser testing and full-match balance remain open.

To render a three-panel visual sample of the slash, spark in flight, and impact burst, run `sh scripts/godot.sh preview-effects`. The image is saved to `.godot/attack-effects-preview.png`.

For manual playtesting, verify highlights and readability, move and attack in both orders, cancel untouched activations, finish committed ones, end turns, and confirm/cancel restart. Headless checks do not verify visuals, input feel, or browser compatibility.

## Battle results

Defeat every enemy to win; losing every hero ends the battle in defeat. After the final hit animation, a modal over the dimmed board shows **Enemies defeated** and **Heroes lost** for that battle. Choose **Restart game [R]** to start a fresh randomized battle or **Dismiss [Esc]** to inspect the final board. Dismissing does not resume gameplay. After dismissal, use the header Restart button or R to open the restart confirmation.

## Current limits

Placeholder art, one basic attack per unit, one scenario, and no audio, inventory, progression, or saving. Balance and session length need playtesting. Attack ranges, targeting tie-breaks, map mix, controls, and line-of-sight rules are provisional defaults recorded in the design.
