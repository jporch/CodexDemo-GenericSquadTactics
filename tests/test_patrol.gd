extends SceneTree
const Battle = preload("res://scripts/battle_model.gd")
var checks := 0
var failures := 0

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

# Sample every seed/unit/turn, but count each invariant once. Keep contexts for failures.
func record(condition: bool, issues: Array, context: String) -> void:
	if not condition:
		issues.append(context)

func expect_clean(issues: Array, description: String) -> void:
	expect(issues.is_empty(), description + (" — " + "; ".join(issues) if not issues.is_empty() else ""))

func turn(game: RefCounted) -> void:
	game.begin_enemy_turn()
	for unit in game.units:
		if unit.team == "enemy":
			game.enemy_action(unit.id)
	game.begin_player_turn()

func isolated_group() -> RefCounted:
	var game := Battle.new()
	game.add_unit("player", Vector2i(15, 11), "guard")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	game.spawn_group(rng, ["raider", "slinger"], Vector2i(3, 3), Vector2i(7, 3), true)
	return game

func _initialize() -> void:
	var game := Battle.new()
	var spawn_issues := {"counts": [], "occupancy": [], "types": [], "size": [], "speed": [], "cluster": [], "membership": [], "terrain counts": [], "connectivity": [], "open endpoints": []}
	var wall_layouts := {}
	var crate_layouts := {}
	var enemy_layouts := {}
	for seed_value in range(30):
		game.reset(seed_value)
		record(game.units.size() == 12 and game.enemy_groups.size() == 3, spawn_issues.counts, "seed %d" % seed_value)
		var walls: Array = game.terrain.keys().filter(func(cell): return game.terrain[cell] == 2)
		var crates: Array = game.terrain.keys().filter(func(cell): return game.terrain[cell] == 1)
		crates.sort()
		crate_layouts[str(crates)] = true
		walls.sort()
		wall_layouts[str(walls)] = true
		enemy_layouts[str(game.units.slice(4).map(func(unit): return unit.cell))] = true
		record(walls.size() == 5 and crates.size() == 4 and game.terrain.size() == 9, spawn_issues["terrain counts"], "seed %d" % seed_value)
		var navigation := Battle.new()
		navigation.terrain = game.terrain.duplicate()
		var probe: Dictionary = navigation.add_unit("player", game.units[0].cell, "guard")
		var reachable: Dictionary = navigation.paths(probe, game.width * game.height)
		record(reachable.size() == game.width * game.height - game.terrain.size(), spawn_issues.connectivity, "seed %d" % seed_value)
		var occupied := {}
		var raiders := 0
		var slingers := 0
		for unit in game.units:
			record(game.inside(unit.cell) and not game.terrain.has(unit.cell) and not occupied.has(unit.cell), spawn_issues.occupancy, "seed %d / unit %d at %s" % [seed_value, unit.id, unit.cell])
			occupied[unit.cell] = true
			if unit.kind == "raider": raiders += 1
			if unit.kind == "slinger": slingers += 1
		record(raiders == 5 and slingers == 3, spawn_issues.types, "seed %d" % seed_value)
		for group in game.enemy_groups:
			record(group.members.size() in [2, 3], spawn_issues.size, "seed %d / group %d" % [seed_value, group.id])
			record(game.patrol_speed(group) == 1, spawn_issues.speed, "seed %d / group %d" % [seed_value, group.id])
			for anchor in group.anchors:
				record(game.patrol_area(anchor).size() == 5, spawn_issues["open endpoints"], "seed %d / group %d" % [seed_value, group.id])
			for unit in game.living_members(group):
				record(unit.cell in game.patrol_area(group.anchors[0]), spawn_issues.cluster, "seed %d / group %d / unit %d" % [seed_value, group.id, unit.id])
				record(game.group_for(unit).id == group.id, spawn_issues.membership, "seed %d / group %d / unit %d" % [seed_value, group.id, unit.id])
	for property in spawn_issues:
		expect_clean(spawn_issues[property], "Spawn invariant across 30 seeds: " + property)
	expect(wall_layouts.size() > 1 and crate_layouts.size() > 1 and enemy_layouts.size() > 1, "Different seeds vary walls, crates, and enemy positions")
	game.reset(7241)
	var initial := JSON.stringify([game.units, game.enemy_groups, game.terrain])
	turn(game)
	game.reset(7241)
	expect(JSON.stringify([game.units, game.enemy_groups, game.terrain]) == initial, "Explicit seed reproduces units, terrain, routes, and state")
	for unit in game.units:
		if unit.team == "enemy": unit.perception = 0 # Isolate idle-route behavior from detection.
	var visits := {0: {0: false, 1: false}, 1: {0: false, 1: false}}
	var patrol_issues := {"occupancy": [], "speed": [], "stationary guards": []}
	for iteration in range(40):
		var previous := {}
		for unit in game.units:
			previous[unit.id] = unit.cell
		turn(game)
		var occupied := {}
		for unit in game.units:
			record(game.inside(unit.cell) and not occupied.has(unit.cell) and not game.terrain.has(unit.cell), patrol_issues.occupancy, "turn %d / unit %d at %s" % [iteration + 1, unit.id, unit.cell])
			occupied[unit.cell] = true
			if unit.team == "enemy":
				record(game.distance(previous[unit.id], unit.cell) <= 1, patrol_issues.speed, "turn %d / unit %d" % [iteration + 1, unit.id])
		for group in game.enemy_groups:
			if not group.patrol:
				for unit in game.living_members(group):
					record(unit.cell == previous[unit.id], patrol_issues["stationary guards"], "turn %d / unit %d" % [iteration + 1, unit.id])
				continue
			for index in range(2):
				var all_inside := true
				for unit in game.living_members(group):
					if not unit.cell in game.patrol_area(group.anchors[index]): all_inside = false
				if all_inside: visits[group.id][index] = true
	for property in patrol_issues:
		expect_clean(patrol_issues[property], "Patrol invariant across 40 turns: " + property)
	expect(visits.values().all(func(endpoints): return endpoints[0] and endpoints[1]), "Every patrol reaches both endpoint areas over repeated turns")
	game = isolated_group()
	var group: Dictionary = game.enemy_groups[0]
	for y in range(game.height): game.terrain[Vector2i(5, y)] = 2
	var blocked_positions: Array = game.living_members(group).map(func(unit): return unit.cell)
	turn(game)
	expect(game.living_members(group).map(func(unit): return unit.cell) == blocked_positions, "Unreachable patrol destination leaves every member in place")
	expect(group.waypoint == 1, "Blocked patrol does not falsely mark destination reached")
	game = isolated_group()
	group = game.enemy_groups[0]
	for y in range(2, 5): game.terrain[Vector2i(5, y)] = 2
	var arrived := false
	for iteration in range(24):
		turn(game)
		if group.waypoint == 0: arrived = true
	expect(arrived, "Patrol finds a valid detour around obstacles")
	game = isolated_group()
	group = game.enemy_groups[0]
	var hero: Dictionary = game.units[0]
	var raider: Dictionary = game.units[1]
	var slinger: Dictionary = game.units[2]
	hero.cell = Vector2i(1, 3)
	raider.cell = Vector2i(2, 3)
	slinger.cell = Vector2i(5, 3)
	turn(game)
	expect(hero.hp == 8, "Patrol member deals normal damage when combat interrupts its route")
	expect(group.paused and slinger.cell == Vector2i(4, 3), "Visible hero interrupts patrol and draws a non-attacking slinger closer")
	hero.cell = Vector2i(15, 11)
	turn(game)
	expect(not group.paused and slinger.cell == Vector2i(5, 3), "Patrol resumes when the group loses sight of all heroes")
	slinger.hp = 0
	expect(game.patrol_speed(group) == 2 and raider.move == 2, "Slow member death updates group pace without altering combat stats")
	game = isolated_group()
	hero = game.units[0]
	raider = game.units[1]
	slinger = game.units[2]
	hero.cell = Vector2i(1, 3)
	raider.cell = Vector2i(4, 3)
	slinger.cell = Vector2i(5, 4)
	turn(game)
	expect(hero.hp == 8 and raider.cell == Vector2i(2, 3), "Combat movement retains Raider Move 2 in a mixed group")
	# The longer-sighted Slinger draws off; blind Raiders must follow their ally.
	game = isolated_group()
	group = game.enemy_groups[0]
	hero = game.units[0]
	raider = game.units[1]
	slinger = game.units[2]
	hero.cell = Vector2i(1, 5)
	raider.cell = Vector2i(9, 5)
	slinger.cell = Vector2i(8, 5)
	game.begin_enemy_turn()
	game.enemy_action(slinger.id)
	var separation: int = game.distance(raider.cell, slinger.cell)
	expect(group.paused and game.visible_heroes(raider).is_empty(), "Slinger contact pauses patrol while Raider still lacks sight")
	expect(game.enemy_action(raider.id) and game.distance(raider.cell, slinger.cell) < separation and not raider.attacked and hero.hp == 10, "Blind Raider regroups toward fighting Slinger without attacking unseen hero")
	game.begin_player_turn()
	hero.cell = Vector2i(15, 11)
	game.begin_enemy_turn()
	expect(not group.paused, "Losing contact clears regrouping and resumes patrol")
	# Exercise actual end-turn behavior (Perception enabled), not just idle routes.
	var regroup_failures := []
	for seed_value in [2, 3, 4, 6]:
		game.reset(seed_value)
		var regrouped := false
		for iteration in range(60):
			if game.outcome != "": break
			game.begin_enemy_turn()
			for unit in game.units:
				if unit.team != "enemy": continue
				var before: Vector2i = unit.cell
				var blind: bool = game.visible_heroes(unit).is_empty()
				var moved: bool = game.enemy_action(unit.id)
				if blind and moved and game.last_event.contains("regroups"):
					regrouped = true
					record(game.distance(before, unit.cell) <= unit.move and not unit.attacked, regroup_failures, "seed %d / unit %d" % [seed_value, unit.id])
			game.begin_player_turn()
		# These are known reproduction maps where at least one group gets contact.
		record(regrouped, regroup_failures, "No regroup on reproduction seed %d" % seed_value)
	expect_clean(regroup_failures, "End-turn-only reproduction maps regroup using normal Move without blind attacks")
	print("Patrol suite: %d assertions, %d failures (30 spawn seeds; 40 idle patrol turns; 4 contact scenarios up to 60 turns)" % [checks, failures])
	quit(0 if failures == 0 else 1)
