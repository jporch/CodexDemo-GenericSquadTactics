extends SceneTree
## Render three real viewport samples for visual QA: slash, projectile, impact burst.
var main

func _initialize() -> void:
	call_deferred("run")

func prepare(ranged: bool) -> void:
	main.restart()
	var hero: Dictionary = main.battle.unit_by_id(3 if ranged else 0)
	hero.cell = Vector2i(7, 5)
	main.battle.unit_by_id(4).cell = Vector2i(9 if ranged else 8, 5)
	main.update_view()
	await create_timer(0.2).timeout
	main.on_cell_clicked(hero.cell)
	main.on_cell_clicked(main.battle.unit_by_id(4).cell)
	main.board.effects[0].set_process(false)

func capture(title: String) -> Image:
	var label := Label.new()
	label.text = title
	label.position = Vector2(320, 272)
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size", 3)
	main.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().get_region(Rect2i(320, 272, 240, 180))
	label.queue_free()
	await process_frame
	return result

func run() -> void:
	root.size = Vector2i(1280, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await prepare(false)
	var effect = main.board.effects[0]
	effect.advance(effect.lead_in + 0.13)
	var melee: Image = await capture("MELEE")
	await prepare(true)
	effect = main.board.effects[0]
	effect.advance(effect.lead_in + effect.travel_duration() * 0.5)
	var flight: Image = await capture("RANGED / FLIGHT")
	effect.advance(effect.travel_duration() * 0.5 + 0.08)
	var burst: Image = await capture("RANGED / IMPACT")
	var strip := Image.create(720, 180, false, Image.FORMAT_RGBA8)
	strip.blit_rect(melee, Rect2i(0, 0, 240, 180), Vector2i.ZERO)
	strip.blit_rect(flight, Rect2i(0, 0, 240, 180), Vector2i(240, 0))
	strip.blit_rect(burst, Rect2i(0, 0, 240, 180), Vector2i(480, 0))
	var result := strip.save_png("res://.godot/attack-effects-preview.png")
	print("Attack effects preview: ", error_string(result))
	quit(0 if result == OK else 1)
