extends Node2D
## Original code-drawn attack feedback; independent of combat rules and unit lifetimes.

signal impact
signal finished
@export var slash_duration: float = 0.32
@export var burst_duration: float = 0.24
@export var projectile_pixels_per_second: float = 360.0
var source: Vector2
var target: Vector2
var melee: bool = true
var lead_in: float = 0.0
var playback_speed: float = 1.0
var elapsed: float = 0.0
var impacted: bool = false
var completed: bool = false

func travel_duration() -> float:
	return clampf(source.distance_to(target) / projectile_pixels_per_second, 0.18, 0.45)

func impact_time() -> float:
	return lead_in + (0.06 if melee else travel_duration())

func duration() -> float:
	return lead_in + (slash_duration if melee else travel_duration() + burst_duration)

func _process(delta: float) -> void:
	advance(delta * playback_speed)

func advance(seconds: float) -> void:
	if completed:
		return
	elapsed += seconds
	if not impacted and elapsed >= impact_time():
		impacted = true
		impact.emit()
	queue_redraw()
	if elapsed >= duration():
		completed = true
		finished.emit()

func _draw() -> void:
	var age := elapsed - lead_in
	if age < 0.0 or completed:
		return
	if melee:
		var progress := clampf(age / slash_duration, 0.0, 1.0)
		var alpha := 1.0 - smoothstep(0.45, 1.0, progress)
		var start := target + Vector2(-21, 19)
		var end := target + Vector2(21, -19)
		var head := start.lerp(end, minf(progress / 0.35, 1.0))
		draw_line(start, head, Color(0.65, 0.04, 0.07, alpha * 0.5), 13)
		draw_line(start, head, Color(1.0, 0.12, 0.16, alpha), 7)
		draw_line(start, head, Color(1.0, 0.67, 0.60, alpha), 2)
	else:
		var travel := travel_duration()
		if age < travel:
			var progress := age / travel
			var head := source.lerp(target, progress)
			var direction := (target - source).normalized()
			for i in range(5, 0, -1):
				var point := head - direction * minf(float(i * 5), source.distance_to(head))
				draw_rect(Rect2(point - Vector2.ONE * 2, Vector2.ONE * 4), Color(1, 0.77, 0.1, 0.55 * (1.0 - i / 6.0)))
			draw_star(head, 8, 1.0)
		else:
			var progress := clampf((age - travel) / burst_duration, 0.0, 1.0)
			var alpha := 1.0 - progress
			draw_star(target, 8 * (1.0 - progress), alpha)
			for i in range(8):
				var direction := Vector2.RIGHT.rotated(i * TAU / 8.0)
				var point := target + direction * (5 + progress * 22)
				draw_line(point, point + direction * (6 * alpha), Color(1, 0.82, 0.15, alpha), 3)

func draw_star(center: Vector2, radius: float, alpha: float) -> void:
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(1, 0.84, 0.12, alpha), 4)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(1, 0.84, 0.12, alpha), 4)
	draw_rect(Rect2(center - Vector2.ONE * 2, Vector2.ONE * 4), Color(1, 1, 0.8, alpha))
