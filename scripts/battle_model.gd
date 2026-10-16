extends RefCounted
signal attack_resolved(from_cell: Vector2i, to_cell: Vector2i, attacker_id: int, target_id: int)
## Deterministic rules independent of presentation. Occupancy always uses grid coordinates.

const DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const UNIT_STATS = {
	"guard": preload("res://resources/guard.tres"),
	"knight": preload("res://resources/knight.tres"),
	"ranger": preload("res://resources/ranger.tres"),
	"raider": preload("res://resources/raider.tres"),
	"slinger": preload("res://resources/slinger.tres"),
}
var width: int = 16
var height: int = 12
var units: Array[Dictionary] = []
var terrain: Dictionary = {} # 1 = low cover, 2 = wall
var enemy_groups: Array[Dictionary] = []
var active_id: int = -1
var team: String = "player"
var round_number: int = 1
var outcome: String = ""
var last_event: String = ""

func reset(seed_value: int = 7241) -> void:
	units.clear()
	terrain.clear()
	enemy_groups.clear()
	active_id = -1
	team = "player"
	round_number = 1
	outcome = ""
	add_unit("player", Vector2i(2, 4), "guard")
	add_unit("player", Vector2i(2, 5), "knight")
	add_unit("player", Vector2i(2, 6), "guard")
	add_unit("player", Vector2i(1, 5), "ranger")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var top := random_anchor(rng, Vector2i(8, 1), Vector2i(10, 3))
	var top_end := random_anchor(rng, Vector2i(12, 1), Vector2i(14, 3))
	var bottom := random_anchor(rng, Vector2i(8, 8), Vector2i(10, 10))
	var bottom_end := random_anchor(rng, Vector2i(12, 8), Vector2i(14, 10))
	var guard_post := random_anchor(rng, Vector2i(12, 5), Vector2i(14, 5))
	spawn_group(rng, ["raider", "raider", "slinger"], top, top_end, true)
	spawn_group(rng, ["raider", "raider", "slinger"], bottom, bottom_end, true)
	spawn_group(rng, ["raider", "slinger"], guard_post, guard_post, false)
	generate_obstacles(rng)
	last_event = "Select an ally to begin. Clear the room."

func random_anchor(rng: RandomNumberGenerator, minimum: Vector2i, maximum: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, y)
			if patrol_area(cell).size() == 5:
				candidates.append(cell)
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func generate_obstacles(rng: RandomNumberGenerator) -> void:
	# Keep the hero staging area and both endpoint areas open.
	var reserved := {}
	for group in enemy_groups:
		for anchor in group.anchors:
			for cell in patrol_area(anchor):
				reserved[cell] = true
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(4, width - 1):
			var cell := Vector2i(x, y)
			if not terrain.has(cell) and not reserved.has(cell) and at(cell).is_empty():
				candidates.append(cell)
	var count := 0
	while not candidates.is_empty() and count < 9:
		var index := rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[index]
		candidates.remove_at(index)
		terrain[cell] = 2 if count < 5 else 1
		if terrain_connected():
			count += 1
		else:
			terrain.erase(cell)

func terrain_connected() -> bool:
	# Ignore units: this checks permanent obstacles, not temporary occupancy.
	var start: Vector2i = units[0].cell
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if inside(next) and not terrain.has(next) and not visited.has(next):
				visited[next] = true
				frontier.append(next)
	return visited.size() == width * height - terrain.size()

func add_unit(side: String, cell: Vector2i, kind: String) -> Dictionary:
	var player := side == "player"
	var stats: Resource = UNIT_STATS[kind]
	var unit := {"id": units.size(), "team": side, "cell": cell, "kind": kind,
		"hp": stats.hp, "max_hp": stats.hp,
		"attack": stats.attack, "defense": stats.defense, "move": stats.move,
		"range": stats.attack_range, "min_range": stats.minimum_attack_range, "perception": stats.perception,
		"moved": false, "attacked": false, "finished": false,
		"move_origin": cell, "last_action": "",
		"group_id": -1, "name": stats.display_name + " " + str(units.size() + 1 if player else units.size() - 3)}
	units.append(unit)
	return unit

func unit_by_id(id: int) -> Dictionary:
	for unit in units:
		if unit.id == id:
			return unit
	return {}

func at(cell: Vector2i) -> Dictionary:
	for unit in units:
		if unit.cell == cell and unit.hp > 0:
			return unit
	return {}

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func paths(unit: Dictionary, budget: int = -1) -> Dictionary:
	var limit: int = unit.move if budget < 0 else budget
	var origin: Vector2i = unit.cell
	var result: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if result[cell] >= limit:
			continue
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if not inside(next) or terrain.has(next) or result.has(next):
				continue
			var occupant := at(next)
			if not occupant.is_empty() and occupant.team != unit.team:
				continue
			result[next] = result[cell] + 1
			frontier.append(next)
	return result

func destinations(unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in paths(unit):
		if cell != unit.cell and at(cell).is_empty():
			result.append(cell)
	return result

func line_clear(from: Vector2i, to: Vector2i) -> bool:
	# A ray may graze an exposed corner, but cannot squeeze between two walls.
	var delta := to - from
	var nx := absi(delta.x)
	var ny := absi(delta.y)
	var step_x := signi(delta.x)
	var step_y := signi(delta.y)
	var ix := 0
	var iy := 0
	var cell := from
	while ix < nx or iy < ny:
		var comparison := (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if comparison == 0:
			if terrain.get(cell + Vector2i(step_x, 0), 0) == 2 and terrain.get(cell + Vector2i(0, step_y), 0) == 2:
				return false
			cell += Vector2i(step_x, step_y)
			ix += 1
			iy += 1
		elif comparison < 0:
			cell.x += step_x
			ix += 1
		else:
			cell.y += step_y
			iy += 1
		if terrain.get(cell, 0) == 2:
			return false
	return true

func in_attack_range(unit: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	var separation := distance(from, to)
	return separation >= unit.min_range and separation <= unit.range

func can_hit(unit: Dictionary, target: Dictionary, from: Vector2i) -> bool:
	return unit.hp > 0 and target.hp > 0 and unit.team != target.team and in_attack_range(unit, from, target.cell) and line_clear(from, target.cell)

func attack_cells(unit: Dictionary, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(maxi(0, origin.y - unit.range), mini(height, origin.y + unit.range + 1)):
		for x in range(maxi(0, origin.x - unit.range), mini(width, origin.x + unit.range + 1)):
			var cell := Vector2i(x, y)
			if not terrain.has(cell) and in_attack_range(unit, origin, cell) and line_clear(origin, cell):
				result.append(cell)
	return result

func threat_cells(unit: Dictionary) -> Array[Vector2i]:
	# Full move + attack envelope, rather than the one target the AI will choose.
	var origins: Array[Vector2i] = [unit.cell]
	origins.append_array(destinations(unit))
	var unique: Dictionary = {}
	for origin in origins:
		for cell in attack_cells(unit, origin):
			unique[cell] = true
	var result: Array[Vector2i] = []
	for cell in unique:
		result.append(cell)
	return result

func activate(id: int) -> bool:
	if team != "player" or outcome != "" or active_id != -1:
		return false
	var unit := unit_by_id(id)
	if unit.is_empty() or unit.team != "player" or unit.hp <= 0 or unit.finished:
		return false
	active_id = id
	last_event = unit.name + " activated. Move or attack first."
	return true

func cancel_activation() -> bool:
	var unit := unit_by_id(active_id)
	if team != "player" or unit.is_empty() or unit.moved or unit.attacked:
		return false
	active_id = -1
	last_event = "Activation cancelled. No actions spent."
	return true

func finish_activation() -> bool:
	if team != "player" or active_id == -1 or outcome != "":
		return false
	var unit := unit_by_id(active_id)
	if not unit.moved and not unit.attacked:
		return cancel_activation()
	unit.finished = true
	active_id = -1
	last_event = unit.name + " finished. Remaining actions forfeited."
	return true

func move_active(cell: Vector2i) -> bool:
	var unit := unit_by_id(active_id)
	if team != "player" or outcome != "" or unit.is_empty() or unit.moved or not cell in destinations(unit):
		return false
	unit.move_origin = unit.cell
	unit.cell = cell
	unit.moved = true
	unit.last_action = "move"
	last_event = unit.name + " moved."
	return true

func can_undo_move() -> bool:
	var unit := unit_by_id(active_id)
	return team == "player" and outcome == "" and not unit.is_empty() and unit.moved and unit.last_action == "move" and at(unit.move_origin).is_empty()

func undo_move() -> bool:
	if not can_undo_move():
		return false
	var unit := unit_by_id(active_id)
	unit.cell = unit.move_origin
	unit.moved = false
	unit.last_action = "attack" if unit.attacked else ""
	last_event = unit.name + " undid its move."
	return true

func attack_active(target_id: int) -> bool:
	var unit := unit_by_id(active_id)
	var target := unit_by_id(target_id)
	if team != "player" or outcome != "" or unit.is_empty() or target.is_empty() or unit.attacked or not can_hit(unit, target, unit.cell):
		return false
	unit.attacked = true
	unit.last_action = "attack"
	deal_damage(unit, target)
	complete_if_spent(unit)
	return true

func complete_if_spent(unit: Dictionary) -> void:
	if unit.moved and unit.attacked:
		unit.finished = true
		active_id = -1

func deal_damage(unit: Dictionary, target: Dictionary) -> void:
	var damage: int = maxi(0, unit.attack - target.defense)
	target.hp = maxi(0, target.hp - damage)
	last_event = "%s hit %s for %d." % [unit.name, target.name, damage]
	if target.hp == 0:
		last_event += " Defeated!"
	check_outcome()
	attack_resolved.emit(unit.cell, target.cell, unit.id, target.id)

func check_outcome() -> void:
	var allies := 0
	var enemies := 0
	for unit in units:
		if unit.hp > 0:
			if unit.team == "player":
				allies += 1
			else:
				enemies += 1
	if enemies == 0 or allies == 0:
		outcome = "Victory" if enemies == 0 else "Defeat"
		active_id = -1

func begin_enemy_turn() -> bool:
	if team != "player" or outcome != "":
		return false
	if active_id != -1:
		finish_activation()
	for unit in units:
		if unit.team == "player":
			unit.finished = true
	team = "enemy"
	prepare_patrols()
	last_event = "Enemy turn. Unused player actions forfeited."
	return true

func attack_plan(enemy: Dictionary) -> Dictionary:
	# Lowest current HP among heroes attackable this turn, even if moving is needed.
	var positions: Array[Vector2i] = [enemy.cell]
	positions.append_array(destinations(enemy))
	var costs := paths(enemy)
	var best_cost := 10000
	var best_distance := 10000
	var best_hp := 10000
	var result: Dictionary = {}
	var targets := visible_heroes(enemy)
	for cell in positions:
		for target in targets:
			if not can_hit(enemy, target, cell):
				continue
			var cost: int = costs[cell]
			var separation := distance(enemy.cell, target.cell)
			if target.hp < best_hp or (target.hp == best_hp and (cost < best_cost or (cost == best_cost and separation < best_distance))):
				best_hp = target.hp
				best_cost = cost
				best_distance = separation
				result = {"target_id": target.id, "destination": cell}
	return result

func enemy_action(id: int) -> bool:
	var enemy := unit_by_id(id)
	if team != "enemy" or outcome != "" or enemy.is_empty() or enemy.team != "enemy" or enemy.hp <= 0 or enemy.finished:
		return false
	enemy.finished = true
	var plan := attack_plan(enemy)
	var group := group_for(enemy)
	if plan.is_empty():
		var visible := visible_heroes(enemy)
		if not visible.is_empty():
			if not group.is_empty():
				group.paused = true
			return approach_hero(enemy, visible)
		if not group.is_empty() and group.patrol and not group.paused:
			return patrol_move(enemy, group)
		if not group.is_empty() and group.paused:
			return regroup(enemy, group)
		last_event = enemy.name + " holds position."
		return false
	if not group.is_empty():
		group.paused = true
	enemy.moved = plan.destination != enemy.cell
	enemy.cell = plan.destination
	enemy.attacked = true
	deal_damage(enemy, unit_by_id(plan.target_id))
	return true

func patrol_area(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var cell: Vector2i = center + offset
		if inside(cell) and not terrain.has(cell):
			cells.append(cell)
	return cells

func spawn_group(rng: RandomNumberGenerator, kinds: Array, first: Vector2i, second: Vector2i, patrol: bool) -> void:
	var id := enemy_groups.size()
	var group := {"id": id, "members": [], "anchors": [first, second], "waypoint": 1, "patrol": patrol, "paused": false,
		"color": [Color("79b7ff"), Color("cfa0f7"), Color("b4c1c9")][id % 3]}
	var cells := patrol_area(first)
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary := cells[i]
		cells[i] = cells[j]
		cells[j] = temporary
	for kind in kinds:
		while not cells.is_empty() and not at(cells.back()).is_empty():
			cells.pop_back()
		if cells.is_empty():
			push_error("Enemy spawn area has insufficient free cells")
			break
		var unit := add_unit("enemy", cells.pop_back(), kind)
		unit.group_id = id
		unit["group_color"] = group.color
		unit["group_patrol"] = patrol
		group.members.append(unit.id)
	enemy_groups.append(group)

func group_for(unit: Dictionary) -> Dictionary:
	var id: int = unit.get("group_id", -1)
	return enemy_groups[id] if id >= 0 and id < enemy_groups.size() else {}

func living_members(group: Dictionary) -> Array[Dictionary]:
	var members: Array[Dictionary] = []
	for id in group.members:
		var unit := unit_by_id(id)
		if not unit.is_empty() and unit.hp > 0:
			members.append(unit)
	return members

func patrol_speed(group: Dictionary) -> int:
	var speed := 10000
	for unit in living_members(group):
		speed = mini(speed, unit.move)
	return 0 if speed == 10000 else speed

func prepare_patrols() -> void:
	for group in enemy_groups:
		group.paused = false
		var members := living_members(group)
		for unit in members:
			if not visible_heroes(unit).is_empty():
				group.paused = true
		if not group.patrol or group.paused or members.is_empty():
			continue
		var area := patrol_area(group.anchors[group.waypoint])
		var arrived := true
		for unit in members:
			if not unit.cell in area:
				arrived = false
		if arrived:
			group.waypoint = 1 - group.waypoint

func patrol_move(enemy: Dictionary, group: Dictionary) -> bool:
	var area := patrol_area(group.anchors[group.waypoint])
	if enemy.cell in area:
		last_event = enemy.name + " waits for its patrol group."
		return false
	var destination: Vector2i = move_toward_cells(enemy, area, patrol_speed(group)).destination
	if destination == enemy.cell:
		last_event = enemy.name + " waits: patrol path blocked."
		return false
	enemy.cell = destination
	enemy.moved = true
	last_event = "%s patrols toward P%d%s (Move %d)." % [enemy.name, group.id + 1, "A" if group.waypoint == 0 else "B", patrol_speed(group)]
	return true

func visible_heroes(enemy: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if enemy.hp <= 0:
		return result
	for target in units:
		if target.team == "player" and target.hp > 0 and distance(enemy.cell, target.cell) <= enemy.perception and line_clear(enemy.cell, target.cell):
			result.append(target)
	return result

func regroup(enemy: Dictionary, group: Dictionary) -> bool:
	# Follow allies in contact, without borrowing their vision or hero targets.
	var goals: Array[Vector2i] = []
	for member in living_members(group):
		if member.id == enemy.id or visible_heroes(member).is_empty():
			continue
		if distance(enemy.cell, member.cell) == 1:
			last_event = enemy.name + " covers its nearby fighting ally."
			return false
		for direction in DIRECTIONS:
			var cell: Vector2i = member.cell + direction
			if inside(cell) and not terrain.has(cell) and at(cell).is_empty() and not cell in goals:
				goals.append(cell)
	var destination: Vector2i = move_toward_cells(enemy, goals, enemy.move).destination
	if destination == enemy.cell:
		last_event = enemy.name + " waits for a regrouping path."
		return false
	enemy.cell = destination
	enemy.moved = true
	last_event = enemy.name + " regroups toward its fighting allies."
	return true

func approach_hero(enemy: Dictionary, targets: Array[Dictionary]) -> bool:
	var best_plan: Dictionary = {}
	var best_distance := 10000
	for target in targets:
		var goals: Array[Vector2i] = []
		for y in range(maxi(0, target.cell.y - enemy.range), mini(height, target.cell.y + enemy.range + 1)):
			for x in range(maxi(0, target.cell.x - enemy.range), mini(width, target.cell.x + enemy.range + 1)):
				var cell := Vector2i(x, y)
				if not terrain.has(cell) and can_hit(enemy, target, cell) and at(cell).is_empty():
					goals.append(cell)
		var plan := move_toward_cells(enemy, goals, enemy.move)
		if plan.path_distance < best_distance:
			best_plan = plan
			best_distance = plan.path_distance
			best_plan["target_name"] = target.name
	if best_plan.is_empty() or best_plan.destination == enemy.cell:
		last_event = enemy.name + " sees a hero but cannot advance."
		return false
	enemy.cell = best_plan.destination
	enemy.moved = true
	last_event = enemy.name + " advances toward " + best_plan.target_name + "."
	return true

func move_toward_cells(enemy: Dictionary, goals: Array[Vector2i], budget: int) -> Dictionary:
	# Plan around occupied squares so a one-step patrol doesn't repeatedly choose
	# a route through a teammate it cannot stop on. Local movement still permits
	# crossing allies when the full move can finish on an empty square.
	var remaining: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for cell in goals:
		if at(cell).is_empty():
			remaining[cell] = 0
			frontier.append(cell)
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if not inside(next) or terrain.has(next) or remaining.has(next):
				continue
			var occupant := at(next)
			if not occupant.is_empty() and occupant.id != enemy.id:
				continue
			remaining[next] = remaining[cell] + 1
			frontier.append(next)
	var costs := paths(enemy, budget)
	var destination: Vector2i = enemy.cell
	var best: int = remaining.get(enemy.cell, 10000)
	var best_cost := 0
	for cell in costs:
		if not at(cell).is_empty():
			continue
		var score: int = remaining.get(cell, 10000)
		if score < best or (score == best and costs[cell] < best_cost):
			destination = cell
			best = score
			best_cost = costs[cell]
	return {"destination": destination, "path_distance": remaining.get(enemy.cell, 10000)}

func begin_player_turn() -> void:
	if outcome != "" or team != "enemy":
		return
	round_number += 1
	team = "player"
	active_id = -1
	for unit in units:
		unit.moved = false
		unit.attacked = false
		unit.finished = false
		unit.move_origin = unit.cell
		unit.last_action = ""
	last_event = "New turn. Select an ally."
