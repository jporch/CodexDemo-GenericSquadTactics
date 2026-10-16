extends SceneTree
var checks := 0
var failures := 0

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func click_control(control: Control) -> void:
	# Exercise GUI hit testing and delivery, rather than emitting Button.pressed.
	await process_frame
	await process_frame
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func reset_fixture(main: Control) -> void:
	main.restart()
	# Keep UI regressions independent of randomized maps and starting formation.
	main.battle.terrain.clear()
	for id in range(4):
		main.battle.unit_by_id(id).cell = [Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(1, 4)][id]
	main.board.clear_units()
	main.update_view()

func run() -> void:
	root.size = Vector2i(1280, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	main.randomize_map = false
	root.add_child(main)
	main.randomize_map = true
	var first_seed: int = main.map_seed
	main.restart()
	var next_seed: int = main.map_seed
	main.restart()
	expect(main.map_seed != next_seed and next_seed != first_seed and main.battle.unit_by_id(1).cell == Vector2i(2, 5), "New battles choose fresh seeds and centered hero formation")
	main.randomize_map = false
	main.map_seed = 7241
	reset_fixture(main)
	await process_frame
	await process_frame
	main.enemy_action_delay = 0.01
	main.board.effect_playback_speed = 30.0
	var original_board_rect: Rect2 = main.board.get_global_rect()
	var original_button_rect: Rect2 = main.move_button.get_global_rect()
	expect(main.detail.get_parent().get_global_rect().encloses(main.detail.get_global_rect()), "Idle details fit reserved area without clipping")
	expect(main.board.unit_nodes.size() == 12, "Scene creates all unit visuals")
	main.on_cell_clicked(Vector2i(2, 3))
	await process_frame
	await process_frame
	expect(main.board.get_global_rect() == original_board_rect, "Selecting a unit does not move or resize board")
	expect(main.move_button.get_global_rect() == original_button_rect, "Enabling buttons keeps their geometry unchanged")
	expect(main.detail.get_parent().get_global_rect().encloses(main.detail.get_global_rect()), "Active details fit reserved area without clipping")
	expect(main.battle.active_id == 0 and not main.cancel_button.disabled, "Click activates with cancellation available")
	expect(not main.board.reachable.is_empty() and not main.board.attackable.is_empty(), "Untouched unit shows both movement and attack highlights")
	var initial_moves: Array = main.board.reachable.duplicate()
	var initial_attacks: Array = main.board.attackable.duplicate()
	main.set_mode("attack")
	expect(main.board.reachable == initial_moves and main.board.attackable == initial_attacks, "Action mode does not hide either available range")
	var hover_event := InputEventMouseMotion.new()
	hover_event.position = Vector2(main.battle.unit_by_id(4).cell) * main.board.TILE + Vector2(24, 24)
	main.board._gui_input(hover_event)
	expect(not main.board.enemy_threat.is_empty(), "Hovering an enemy shows its threat envelope")
	expect(main.board.reachable == initial_moves and main.board.attackable == initial_attacks, "Enemy threat preserves active unit ranges")
	main.board.mouse_exited.emit()
	expect(main.board.enemy_threat.is_empty(), "Leaving the board clears enemy hover")
	main.board.set_hover(main.battle.unit_by_id(4).cell)
	main.board.set_hover(Vector2i.ZERO)
	expect(main.board.enemy_threat.is_empty(), "Leaving enemy clears threat overlay")
	var finish_event := InputEventAction.new()
	finish_event.action = "finish_activation"
	finish_event.pressed = true
	main._unhandled_input(finish_event)
	expect(main.battle.active_id == -1 and not main.battle.unit_by_id(0).finished, "Space action deactivates untouched unit without using it up")
	main.on_cell_clicked(Vector2i(2, 3))
	expect(main.battle.active_id == 0, "Unit can activate again after untouched Space")
	main.set_mode("attack")
	main.cancel()
	expect(main.battle.active_id == -1, "UI cancels untouched activation")
	main.on_cell_clicked(Vector2i(2, 3))
	main.on_cell_clicked(Vector2i(3, 3))
	expect(main.mode == "attack" and main.cancel_button.disabled, "Movement switches to attack and disables cancel")
	expect(main.board.reachable.is_empty() and not main.board.attackable.is_empty(), "After moving, only attack range remains")
	main.cancel()
	expect(main.mode == "attack" and main.battle.active_id == 0, "Rejected cancel preserves action mode")
	main.on_cell_clicked(Vector2i(2, 4))
	expect(main.battle.active_id == 0, "Clicking another ally cannot switch a committed activation")
	main.finish()
	expect(main.battle.active_id == -1 and main.battle.unit_by_id(0).finished, "Finish button forfeits remaining actions")
	await process_frame
	await process_frame
	expect(main.board.get_global_rect() == original_board_rect, "Finishing and updating history does not shift board")
	expect(main.log_label.get_parent().get_global_rect().encloses(main.log_label.get_global_rect()), "Action history fits reserved area without clipping")
	main.end_turn()
	await create_timer(0.3).timeout
	expect(main.battle.round_number == 2 and main.battle.team == "player", "Enemy sequence returns control to player")
	main.end_turn()
	reset_fixture(main)
	await create_timer(0.3).timeout
	expect(main.battle.round_number == 1 and main.battle.team == "player" and main.battle.active_id == -1, "Restart invalidates in-flight enemy sequence")
	expect(main.battle.units.all(func(unit): return unit.hp == unit.max_hp and not unit.finished), "Restart restores every unit’s health and availability")
	main.request_restart()
	expect(main.restart_dialog.visible, "Restart opens confirmation dialog")
	main.restart_dialog.hide()
	reset_fixture(main)
	main.battle.unit_by_id(4).cell = Vector2i(3, 3)
	main.on_cell_clicked(Vector2i(2, 3))
	main.set_mode("attack")
	main.on_cell_clicked(Vector2i(3, 3))
	expect(main.board.attackable.is_empty() and not main.board.reachable.is_empty(), "After attacking first, only movement range remains")
	main.board.set_hover(Vector2i(3, 3))
	main.battle.unit_by_id(4).hp = 0
	main.update_view()
	expect(main.board.enemy_threat.is_empty(), "Removing a hovered enemy clears stale threat")
	# Reproduce a hero advancing by the wall, being attacked, then attacking first next turn.
	reset_fixture(main)
	for unit in main.battle.units:
		if unit.id not in [0, 4]:
			unit.hp = 0
	var hero: Dictionary = main.battle.unit_by_id(0)
	var enemy: Dictionary = main.battle.unit_by_id(4)
	enemy.cell = Vector2i(7, 1)
	hero.cell = Vector2i(2, 2)
	for cell in [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4)]: main.battle.terrain[cell] = 2
	main.on_cell_clicked(hero.cell)
	main.on_cell_clicked(Vector2i(5, 1))
	main.end_turn()
	await create_timer(0.1).timeout
	expect(main.battle.round_number == 2 and hero.hp == 8, "Enemy advances by wall and attacks before turn two")
	expect(main.battle.distance(hero.cell, enemy.cell) == 1, "Enemy is adjacent at next player turn")
	main.on_cell_clicked(hero.cell)
	expect(main.mode == "move", "New activation starts with default movement guidance")
	main.on_cell_clicked(enemy.cell)
	expect(enemy.hp == 2 and hero.attacked and not hero.moved, "Click adjacent enemy attacks first without pressing A")
	expect(main.board.attackable.is_empty() and not main.board.reachable.is_empty(), "Direct attack preserves remaining movement")
	main.on_cell_clicked(enemy.cell)
	expect(enemy.hp == 2 and not hero.moved, "Repeated enemy click cannot attack twice or spend movement")
	main.on_cell_clicked(Vector2i(4, 2))
	expect(hero.cell == Vector2i(4, 2) and not hero.finished and not main.undo_button.disabled and not main.finish_button.disabled, "Attack then move keeps hero active with Undo and End hero turn enabled")
	await click_control(main.undo_button)
	expect(hero.cell == Vector2i(5, 1) and hero.attacked and not hero.moved and enemy.hp == 2 and not main.board.reachable.is_empty(), "Undo button restores move and highlights but preserves attack damage")
	main.on_cell_clicked(Vector2i(4, 2))
	await click_control(main.finish_button)
	expect(hero.finished and main.battle.active_id == -1 and main.undo_button.disabled, "End hero turn button commits attack-first move and disables Undo")
	reset_fixture(main)
	main.board.effect_playback_speed = 1.0
	enemy = main.battle.unit_by_id(4)
	enemy.cell = Vector2i(3, 3)
	enemy.hp = 2
	main.on_cell_clicked(Vector2i(2, 3))
	main.on_cell_clicked(main.battle.unit_by_id(5).cell)
	expect(main.board.effects.is_empty(), "Rejected attack produces no effect")
	main.on_cell_clicked(enemy.cell)
	var effect = main.board.effects[0]
	effect.set_process(false)
	expect(effect.melee, "Adjacent player attack produces melee slash")
	expect(enemy.hp == 0 and main.board.unit_nodes.has(enemy.id), "Lethal target remains visible until impact")
	effect.advance(0.1)
	expect(not main.board.unit_nodes.has(enemy.id), "Defeated target disappears on slash impact")
	effect.advance(1.0)
	expect(main.board.effects.is_empty() and main.board.pending_impacts.is_empty(), "Completed slash cleans up effect state")
	reset_fixture(main)
	enemy = main.battle.unit_by_id(4)
	enemy.cell = Vector2i(3, 4)
	main.on_cell_clicked(Vector2i(1, 4))
	main.on_cell_clicked(enemy.cell)
	effect = main.board.effects[0]
	effect.set_process(false)
	expect(not effect.melee and effect.source != effect.target, "Distant player attack produces travelling spark")
	effect.advance(effect.lead_in + effect.travel_duration() * 0.5)
	expect(not effect.impacted, "Ranged spark has no impact before arrival")
	effect.advance(effect.travel_duration() * 0.5 + 0.01)
	expect(effect.impacted and not effect.completed and enemy.hp == 2, "Spark dissipates after arrival without dealing duplicate damage")
	effect.advance(1.0)
	expect(main.board.effects.is_empty(), "Ranged burst cleans up after dissipating")
	reset_fixture(main)
	var slinger: Dictionary = main.battle.unit_by_id(9)
	slinger.cell = Vector2i(4, 3)
	main.battle.begin_enemy_turn()
	main.battle.enemy_action(slinger.id)
	main.update_view()
	expect(not main.board.effects[0].melee, "Enemy ranged attack also emits travelling spark")
	reset_fixture(main)
	slinger = main.battle.unit_by_id(9)
	slinger.cell = Vector2i(3, 3)
	main.battle.unit_by_id(0).hp = 1
	main.battle.begin_enemy_turn()
	main.battle.enemy_action(slinger.id)
	main.update_view()
	expect(not main.board.effects[0].melee and slinger.cell != Vector2i(3, 3), "Adjacent slinger steps away and makes a legal ranged attack")
	reset_fixture(main)
	enemy = main.battle.unit_by_id(4)
	enemy.cell = Vector2i(3, 4)
	main.on_cell_clicked(Vector2i(1, 4))
	main.on_cell_clicked(enemy.cell)
	main.board.effects[0].set_process(false)
	main.end_turn()
	reset_fixture(main)
	await create_timer(0.1).timeout
	expect(not main.board.is_animating() and main.board.pending_impacts.is_empty(), "Restart clears in-flight attack effects")
	expect(main.battle.team == "player" and main.battle.round_number == 1, "Restart cancels enemy sequence waiting for attack effect")
	# Both results are triggered by a real final attack; totals include earlier losses.
	for outcome in ["Victory", "Defeat"]:
		reset_fixture(main)
		expect(not main.result_screen.visible, "Restart hides previous result screen")
		var last_enemy: Dictionary = main.battle.unit_by_id(4)
		var last_hero: Dictionary = main.battle.unit_by_id(0)
		last_enemy.cell = Vector2i(3, 3)
		if outcome == "Victory":
			for unit in main.battle.units:
				if unit.team == "enemy" and unit.id != 4: unit.hp = 0
			main.battle.unit_by_id(1).hp = 0
			main.battle.unit_by_id(2).hp = 0
			last_enemy.hp = 2
			main.on_cell_clicked(last_hero.cell)
			main.on_cell_clicked(last_enemy.cell)
		else:
			for unit in main.battle.units:
				if unit.team == "player" and unit.id != 0: unit.hp = 0
			main.battle.unit_by_id(5).hp = 0
			main.battle.unit_by_id(6).hp = 0
			last_hero.hp = 2
			main.battle.begin_enemy_turn()
			main.battle.enemy_action(last_enemy.id)
			main.update_view()
		expect(main.battle.outcome == outcome and not main.result_screen.visible, outcome + " waits for the final attack effect")
		main.board.effects[0].set_process(false)
		main.board.effects[0].advance(2.0)
		expect(main.result_screen.visible and main.result_title.text == outcome.to_upper(), outcome + " screen appears after impact")
		var expected_summary := "All enemies defeated.\n\nEnemies defeated: 8\nHeroes lost: 2" if outcome == "Victory" else "All heroes defeated.\n\nEnemies defeated: 2\nHeroes lost: 4"
		expect(main.result_summary.text == expected_summary, outcome + " reports correct totals for both teams")
		var final_state: String = JSON.stringify(main.battle.units)
		if outcome == "Victory":
			await click_control(main.get_node("ResultScreen/Center/Panel/Content/Dismiss"))
		else:
			var dismiss_event := InputEventAction.new()
			dismiss_event.action = "cancel_activation"
			dismiss_event.pressed = true
			main._unhandled_input(dismiss_event)
		main.update_view()
		main.on_cell_clicked(last_hero.cell)
		expect(not main.result_screen.visible and main.battle.outcome == outcome and JSON.stringify(main.battle.units) == final_state and main.battle.active_id == -1, "Dismiss keeps final board unchanged and result hidden after refresh")
		# Reopen the result so Restart is exercised through the visible GUI too.
		main.result_dismissed = false
		main.update_result()
		await click_control(main.get_node("ResultScreen/Center/Panel/Content/Restart"))
		expect(not main.result_screen.visible and not main.result_dismissed and main.battle.outcome == "" and main.battle.units.all(func(unit): return unit.hp == unit.max_hp), "Restart clears result dismissal and restores battle")
	reset_fixture(main)
	var watcher: Dictionary = main.battle.unit_by_id(4)
	var blind_member: Dictionary = main.battle.unit_by_id(5)
	watcher.cell = Vector2i(7, 5)
	blind_member.cell = Vector2i(10, 5)
	main.battle.group_for(watcher).paused = true
	main.update_view()
	expect(main.board.unit_nodes[watcher.id].sees_heroes and not main.board.unit_nodes[blind_member.id].sees_heroes and not main.board.unit_nodes[0].sees_heroes, "Alert marks personal hero sight, not group contact or heroes")
	for y in range(main.battle.height): main.battle.terrain[Vector2i(6, y)] = 2
	main.update_view()
	expect(not main.board.unit_nodes[watcher.id].sees_heroes, "Wall blocking sight clears enemy alert")
	main.battle.terrain.clear()
	for unit in main.battle.units:
		if unit.team == "player": unit.cell = Vector2i(0, 0)
	main.update_view()
	expect(not main.board.unit_nodes[watcher.id].sees_heroes, "Moving heroes beyond Perception clears enemy alert")
	main.queue_free()
	await process_frame
	print("Scene suite: %d assertions, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
