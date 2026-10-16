# Game design worksheet

A playable proof of concept for grid-based squad tactics, focused on movement, turn sequencing, and tunable unit statistics.

## 1. Concept and prototype question
- Working title: Generic Squad Tactics
- Game concept in one or two sentences: Players have a small team of elite fighters positioned on a square grid. The enemy team has a larger number of weaker fighters deployed in small groups. The player goes first, and can move their fighters and use abilities to defeat enemeies, then hopefully survive the counterattack.
- This prototype is to get basic functionality working, have characters that move around and are able to take turns, and figure out the basic statistics needed to implement the level of variety we're looking for.

## 2. Presentation and platform
- 2D or 3D: 2D pixel art
- Camera perspective and behavior: Top-down fixed camera on a scene or "room"
- Initial target: Web/HTML5 (using Godot's built in web support)
- Input devices: Mouse and Keyboard
- Visual references and the specific aspects to borrow: Shining Force
- Existing assets or permission to use placeholders: Placeholders, but clearly label any file with a suffix so I can easily sub them out later
- Audio expectations: No Audio yet

## 3. Core loop and player actions
- What the player repeatedly does: On the player turn, they will have some number of characters that they can activate in any order. When activated, the character can move up to its Move stat and/or use one Ability, in any order.
- Activation locks in one character at a time. The player must finish that character's activation before activating another unit; actions cannot be interleaved between characters.
- Each activation permits one move and one Ability (an attack for the first playable), in either order. Only moving then attacking ends activation automatically. Attacking then moving leaves the hero active until End hero turn (Space). Move-only or attack-only activations also require an explicit end. A finished character cannot activate again until the next player turn.
- Finishing an activation after moving or attacking forfeits the remaining action for that character this turn. Pressing Space or the finish/deactivate button before taking either action simply deactivates the unit without spending actions or marking it finished; it remains available to activate later in the same turn.
- Undo activation: If the character has not actually moved or used an Ability, the player may cancel its activation and choose another character without spending either action or marking the cancelled character as finished. Choosing an Ability or previewing a destination/target does not count as taking an action. Once an Ability is performed, or a move remains committed, cancellation is unavailable; the player must use or forfeit the remaining action before switching units.
- Actions and controls: The player will click on a unit to activate them, then click on a valid nearby space within their move range to move them. Separately, there will be a keyboard shortcut to choose Abilities that lets them specify which action the character should take. There should also be a keyboard command to end the turn and yield control to the opposing force.
- Movement and interaction feel: Short visual slides; enemy activations play sequentially with a brief delay. Timing is tunable and provisional.
- Example of 30–60 seconds of play: Player turn starts, clicks on the first of their characters and moves them adjacent to the enemy flank, attacking and defeating an exposed enemy. They then quickly move their other units up to form a wall, and finally move their long-range attacker behind them and use its range to strike at another exposed enemy. They end the turn and let all enemy forced go, trusting their position and superior stats to survive until next turn.

## 4. Rules and feedback
- World layout and collision behavior: No physics, movement occurs on a square grid. Only one unit can occupy a square, but units can move through one on their team.
- Movement uses orthogonal steps (up, down, left, right), with no diagonals. Each step costs one movement point. On open ground, distance is Manhattan distance: `abs(target_x - start_x) + abs(target_y - start_y)`. Obstacles require a valid path around them; movement range uses the actual traversable path length, not just the direct Manhattan distance. This movement rule is provisional and may be revisited later.
- Enemies, obstacles, or other challenges: The map is mostly open, but will have scattered obstacles that block individual squares, some just preventing passage while others blocking attacks, too. Enemies spawn in compact groups of two or three within seeded starting areas, so players can plan around small formations.
- Items, resources, scoring, or progression: Deferred beyond this first pass.
- Attack feedback: A successful attack at Manhattan distance 1 is melee and shows a brief red slash on the target. At greater distance it is ranged and shows a yellow spark travelling from attacker to target, then dissipating on impact. Ranged units cannot attack adjacent squares; all legal Ranger/Slinger attacks therefore use the travelling spark. Both teams use these effects; rejected attacks do not. Enemy activations wait for the effect to finish. Defeated target visuals remain until impact, and restarting clears all effects. No audio yet.
- Combat: For now, valid attacks are guaranteed to hit and deal damage equal to max(0, the attacker's Attack minus the target's Defense). A unit is defeated and removed when its HP reaches zero or below.
- Starting unit stats: Each player character has 10 HP and 3 Attack. Guards and the Ranger have 4 Move and 0 Defense; Hero 2 is a Knight with 3 Move and 1 Defense. Both enemy types have 5 HP, 2 Attack, and 0 Defense. The original enemy type has 2 Move; the second enemy type has 1 Move and 2 Range. Move is the maximum number of orthogonal steps along a valid path in a single move action. First-pass defaults: two player Guards and the Knight have Range 1, one player Ranger has Range 2–3, and the original enemy type (Raider) has Range 1. The second enemy type is called Slinger. These names and attack ranges are provisional.
- Enemy visual distinction: The second enemy type must be recognizable on the board by a different silhouette or marker as well as color, including when using placeholder art. Placeholder asset filenames must retain a `_placeholder` suffix before the extension.
- Enemy behavior (provisional): During the enemy turn, an enemy acts if it can make a valid attack against a player character from its current square or after moving along a valid path within its movement budget. It selects the lowest-current-HP hero it can attack this turn, then attacks in place or moves to attack that target. An enemy that sees a hero but cannot attack yet approaches a valid firing/attack position using its own Move. With no personally visible hero, it regroups toward a group member in contact; with no group contact it patrols if assigned, otherwise holds. Each enemy may move at most once and attack at most once per enemy turn. After enemy actions are resolved, control returns to the player.
- Range feedback: An active unit shows both legal movement destinations (teal) and attack squares from its current position (coral inset) while both actions remain. After moving, show only any unspent attack range; after attacking first, show only any unspent movement range. Once both actions are spent, show neither. Undo Move restores movement highlights. Clicks are contextual: clicking an enemy attempts an available attack; clicking an empty square attempts an available move. M/A change action guidance only and never prevent a valid contextual click.
- Enemy hover: Hovering any living enemy shows an orange hatched threat envelope: all attackable board squares from its current position or any legal destination within one move. Use that enemy type's Move and Range, valid paths, occupied destinations, and wall line of sight. This previews its full potential reach, not just the AI's chosen target, and remains available regardless of whose turn it is. Clear it on mouse exit or enemy removal, and refresh it when the board state changes. Keep active-unit highlights visible underneath.
- Layout stability: Enabling, hovering, pressing, or disabling action buttons changes styling only. Selecting/deactivating a unit and updating its details or action history must not move or resize the board.
- What the interface must show: Current round and team, surviving unit counts, available allies, active unit HP/Attack/Defense/Move/Range and spent actions, movement and attack highlights, action buttons/shortcuts, recent actions, and victory/defeat feedback.
- Win condition: All enemies defeated
- Loss condition: All allies defeated
- Restart behavior: Keyboard shortcut to reset the map to the start (prompts confirmation that user has to click)

## 5. First playable scope
- Required mechanics: Units placed on a board, separated into two teams. Player can distinguish their units, choose and activate them, and complete a turn. Once they pass control to the enemy, the computer acts with enemies that can attack immediately or after a valid move, with other enemies patrolling or holding according to their group, as specified in section 4.
- Number of rooms/levels, enemy types, and items: One room that takes up most of the screen, to give plenty of room to move around. Include both the original enemy type and the visually distinct second type with Range 2 and Move 1. Provisional first-pass mix: five Raiders and three Slingers on a 16 × 12 board.
- Approximate session length: 5 minutes

## 6. Acceptance criteria
Replace these prompts with observable checks for the first playable.
- [ ] Player can: Select and activate their 4 characters
- [ ] Activated characters can move: selecting a square within their Move range and change their position to it.
- [ ] Movement permits only orthogonal steps and destinations reachable within the unit's movement budget along a valid path. Blocked squares cannot be crossed; friendly units may be crossed but not used as destinations.
- [ ] A player unit can move up to 4 steps in one move action, but not 5. An original-type enemy can move up to 2 steps, but not 3; a second-type enemy can move 1 step, but not 2. Steps needed to go around obstacles count toward these limits.
- [ ] Both enemy types appear on the board and are visually distinguishable by silhouette or marker as well as color. The second type has 5 HP, 2 Attack, 2 Range, and 1 Move, and uses its own range and movement budget when deciding whether it can attack.
- [ ] A melee unit starting adjacent to an enemy can attack by clicking that enemy immediately after activation, without pressing A or moving first. A second attack is rejected, and remaining movement is still available.
- [ ] Both available ranges remain visible regardless of input mode, with only the unused action range shown after moving or attacking.
- [ ] Hovering either enemy type previews its full legal move-and-attack envelope, respects terrain and occupancy, and clears when no enemy is hovered.
- [ ] Activated characters can attack: selecting a square within their Attack range with an enemy will decrease enemy HP by max(0, the unit's Attack minus the target's Defense)
- [ ] Player characters start with 10 HP and 3 Attack; enemies start with 5 HP and 2 Attack. Valid attacks always hit and deal max(0, Attack minus target Defense) damage. The Knight has 1 Defense; other units have 0.
- [ ] Adjacent attacks from either team show a red slash at the target; longer attacks show a yellow spark travelling to and dissipating on the target. Lethal hits still show their impact, and restart removes pending effects.
- [ ] A player attack reduces a fresh enemy from 5 HP to 2 HP; a second player attack defeats and removes it. An enemy attack reduces a fresh Guard or Ranger from 10 HP to 8 HP, or the Knight from 10 HP to 9 HP.
- [ ] An enemy selects the lowest-current-HP visible hero it can attack this turn, including after moving. Equal-HP ties prefer fewer movement steps. An adjacent healthier hero does not override a weaker reachable target.
- [ ] Enemies spawn in non-overlapping groups of two or three on valid squares. The current eight-enemy setup has two mixed groups of three and one stationary pair.
- [ ] Idle patrols travel between two small highlighted areas, using at most the slowest living member's Move per unit per turn. Members that arrive early wait, and the route reverses only after all surviving members arrive.
- [ ] Patrols navigate obstacles and waiting allies without illegal moves or overlapping destinations. A genuinely blocked route waits safely. Non-patrol enemies hold when unalerted and regroup when an ally has contact.
- [ ] Perceiving a hero pauses group patrol movement; normal per-unit movement and attacks still apply. Patrol resumes when the group loses sight of all heroes. Each unit acts at most once per enemy turn.
- [ ] Matching P# badges, flags labelled P#A/P#B, and tinted areas identify each patrol and both endpoints. The current destination flag is brighter; restart generates a new formation and resets patrol state.
- [ ] Only one character can be active at a time. After it moves or attacks, the player cannot switch to another character until the activation is completed.
- [ ] A character can move then attack, or attack then move, with at most one of each per activation.
- [ ] Cancelling an activation before any move or attack allows another character to activate; the cancelled character remains available with both actions intact.
- [ ] Space deactivates an untouched unit and leaves it available with both actions intact. After moving or attacking, Space forfeits the remaining action and marks the unit finished for this turn.
- [ ] Success occurs when: All enemies are defeated and removed
- [ ] Failure occurs when: All Allies are defeated and removed
- [ ] Restart resets: Player presses a restart key and confirms intention to start over.

## 7. Decisions and open questions
- Agreed decisions: Activations are exclusive and must be completed before switching units. An untouched activation can be cancelled without penalty; after any action, the character must use or forfeit its remaining action. Space deactivates untouched units without penalty; after any action, finishing forfeits the remaining action.
- Agreed movement decision: Use Manhattan grid movement with no diagonals for now; revisit after playtesting. Attack range uses the provisional first-pass rules below.
- Agreed movement stats: Guards and the Ranger have 4 Move; the Knight has 3 Move; original-type enemies have 2 Move; second-type enemies have 1 Move.
- Agreed enemy variant: Include a visually distinct second enemy type with Range 2 and Move 1, retaining the enemy baseline of 5 HP and 2 Attack. Attack range uses the provisional first-pass rules below.
- Agreed combat decision: Guaranteed hits and damage equal to max(0, Attack minus target Defense). The Knight has 1 Defense; all other units have 0. Starting stats are 10 HP / 3 Attack for player characters and 5 HP / 2 Attack for enemies.
- Agreed enemy behavior: Prioritize the lowest-current-HP hero attackable this turn, moving first when needed. Enemies unable to attack approach visible heroes; without personal sight, they regroup toward an ally in contact, or follow their patrol/hold when the whole group lacks sight. See the Perception rules below.

## 8. Provisional implementation defaults for the first pass
These fill remaining gaps for the initial build and can be revised after playtesting.
- Attacks use Manhattan distance. Guards, the Knight, and Raiders attack at distance 1. The Ranger attacks at distances 2–3; Slingers attack at distance 2 only. Ranger/Slinger minimum attack range is 2, editable in their stat resources.
- Walls block both movement and line of sight. Crates block movement only. Units do not block shots. Line of sight uses grid traversal: shots may graze an exposed wall corner, including between units adjacent to perpendicular faces of a wall. Crossing a wall interior or squeezing diagonally between two walls remains blocked. Attack highlights, enemy targeting/threats, and Perception use this same rule.
- Board: 16 × 12 squares, four allies grouped on the left, five Raiders and three Slingers in seeded groups on the right: two patrol trios (two Raiders and one Slinger each), and a guard pair (one Raider and one Slinger). Five wall tiles and four crates are randomized each battle. Restart generates a fresh map and resets all HP/actions.
- Enemy activations use a stable order. Among visible heroes attackable this turn from the current square or after a legal move, choose the lowest current HP. Ties prefer the shortest required move, then the nearest target; remaining ties use stable unit/grid order. A weaker reachable target takes priority over an immediate attack on a healthier one.
- Controls: Click to activate/select movement destination; M selects movement guidance; A selects attack guidance; enemy clicks attack and empty-square clicks move regardless of guidance; Esc cancels an untouched activation; Space deactivates an untouched unit without penalty, or finishes a committed activation and forfeits its remaining action; E ends the team turn; R opens restart confirmation. U undoes an eligible move. Buttons mirror shortcuts. Ending a team turn forfeits all remaining player actions.
- Finishing all allies does not automatically end the team turn: E or the End team turn button yields control.
- No additional abilities, inventory, progression, audio, saving, or final art in this pass. Placeholder visual files use `_placeholder` suffixes.
- Review after playing: combat ranges and line of sight, board size/enemy mix, targeting preferences, controls, timing, and balance/session length.


## 9. Patrol groups and temporary debug markers
- Spawn formations are shuffled deterministically within each group's starting area. Current groups are 3 + 3 + 2; all units keep their agreed combat stats.
- P1 patrols between centers (8, 2) and (12, 2); P2 between (8, 9) and (12, 9), using zero-based grid coordinates. Each area consists of its center plus valid orthogonal neighbors. G3 guards around (13, 5) without a patrol route. Coordinates and group composition are provisional tuning choices.
- Patrol-only movement is capped by the slowest surviving member (currently Move 1 in mixed groups). Raiders retain Move 2 for combat. If a Slinger is defeated, its remaining Raider group can patrol at Move 2.
- Members move toward free squares in the destination area, respecting paths and occupancy. Early arrivals wait for the rest. The destination switches once all living members arrive, at the start of an enemy turn. Blocked patrols wait rather than teleport or overlap.
- A group pauses patrolling if any member sees a living hero within its own Perception and line of sight. Each spotting member attacks or approaches with its normal Move; members without sight regroup toward an ally currently in contact, using normal Move, and cover once adjacent. They still need their own Perception and line of sight to target a hero. The patrol resumes when no member sees a hero. No last-known-position memory, hearing, investigation, or shared hero vision is added. Regrouping uses the ally’s current position, not a hidden hero’s position.
- Debug visuals are temporary: matching colored P# unit badges, flags at both endpoint centers, and tinted area tiles. The destination flag is brighter. G# badges identify stationary groups. Board Inspector setting `show_patrol_debug` hides route markers without changing behavior. Completely defeated patrols no longer show markers.
- Enemy hover continues to show normal move-and-attack potential, since combat can use the unit's full movement even when its patrol pace is slower.

## 10. Enemy Perception
- Raiders have Perception 6; Slingers have Perception 8. These are Inspector-editable unit stats.
- Detection uses inclusive Manhattan distance from the enemy's current square and the same wall-blocked line of sight as attacks. Low cover and other units do not block sight. Defeated heroes are ignored.
- A red exclamation mark above an enemy indicates it currently sees at least one living hero. Refresh after movement, attacks, and restart; remove it when sight is lost. Group contact alone does not display the mark on members without their own sight.
- Only currently visible heroes can be selected for attacks or pursuit. Select the weakest hero that can be attacked this turn; attack from the current square if legal for that target, otherwise move and attack. If an attack is still out of reach, move toward a reachable attack position around obstacles, using the unit's normal Move (Raider 2, Slinger 1). Do not move onto occupied squares or through heroes.
- Prefer the visible target with the shortest reachable path to a valid attack position; ties are deterministic. Stop at a useful ranged distance rather than approaching the hero's occupied square. Blocked enemies wait safely.
- Perception does not alter attack Range, damage, movement stats, or enemy hover threat previews. Patrol speed remains capped by the slowest member only during idle patrol.
- Losing personal sight ends direct pursuit; members regroup toward an ally with current contact. When the whole group loses sight, an unalerted patrol resumes its existing route and guards hold. There is no global alert or vision sharing between members.

## 11. Minimum range and weakest-target priority
- Ranger and Slinger minimum attack range is 2, so they cannot attack orthogonally adjacent squares. Guards, the Knight, and Raiders retain minimum range 1. Attack validation, player highlights, firing-position search, and enemy threat previews all use the same minimum/maximum bounds.
- A Slinger may step away from an adjacent hero and fire at distance 2 if a legal destination exists; otherwise it cannot attack that hero. A rejected adjacent ranged attack does not spend the action or deal damage.
- Weakest means lowest current HP, not percentage HP. Enemies consider only currently visible living heroes they can legally attack during this activation, including movement, occupancy, range limits, and line of sight. Moving to a wounded hero takes precedence over hitting an adjacent healthy hero.
- When no hero can be attacked this turn, pursuit still chooses a visible target by shortest reachable path to a legal attack position. It does not ignore an available attack just to chase a weaker unreachable hero.

## 12. Knight and starting formation

- Hero 2 becomes Knight 2, with 10 HP, 3 Attack, 3 Move, Range 1, and 1 Defense. The other two melee heroes remain Guards. The Knight carries a visibly larger tower shield.
- Defense reduces each incoming attack: damage = max(0, Attack - Defense), for both melee and ranged attacks. Damage cannot become healing. The combat log shows the damage after Defense.
- All Raiders and Slingers have Attack 2. Other non-Knight units have Defense 0. Enemy targeting still uses lowest current HP, regardless of Defense.
- Starting grid coordinates (zero-based): Guard 1 at (2, 4), Knight 2 at (2, 5), Guard 3 at (2, 6), Ranger 4 at (1, 5). This centers the formation on the left with the Ranger directly behind the Knight.

## 13. Battle result screens

- Victory triggers when all enemies have been defeated; Defeat triggers when all heroes have been defeated.
- After the final attack effect finishes, show a centered modal over the dimmed board with Victory or Defeat, the number of enemies defeated, and the number of heroes lost during the battle.
- Count defeated units from both teams, including losses before the final attack. Gameplay ends at the result. The modal offers Restart game (R), which starts a new randomized battle, and Dismiss (Esc), which reveals the final board without resuming play. Dismissal persists until restart. After dismissing, R retains the restart confirmation shortcut.

## 14. Randomized battles

- Each new play, including restart from the header or result modal, chooses a fresh map seed. Explicit fixed seeds remain available in the Inspector for debugging.
- Heroes start centered on the left in the formation listed above. Five walls and four crates randomize outside the clear left staging area (columns 0–3).
- Enemy group composition remains two mixed patrol trios and one stationary mixed pair. Their starting formations and patrol endpoints randomize in separated upper-right, lower-right, and middle-right regions. Both patrol areas remain clear of walls and crates.
- Reject wall or crate placements that disconnect any walkable terrain, so terrain cannot seal off units or patrol destinations. Movement occupancy rules still apply during play.

## 15. Hero turn ending and Undo Move

- Move then attack ends the hero’s activation automatically. Attack then move does not; explicitly choose End hero turn (Space). Untouched activations can still be deactivated without being spent.
- Undo Move (button or U) is available only while the hero is active and its latest performed action was a move: move before attacking, or attack then move before ending the hero’s turn.
- Undo restores the move’s starting square and movement allowance. It preserves attack expenditure, damage, defeats, and all other battle state. The hero can choose another move. Undoing a move-only activation leaves it untouched and cancellable again.
- An attack immediately closes any earlier move’s undo window. End hero turn, end team turn, a battle result, or restart also prevents undoing an earlier move. New rounds clear move history. Enemy activation behavior is unchanged.
