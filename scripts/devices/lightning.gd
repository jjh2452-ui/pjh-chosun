extends Node2D
## 벼락 한 줄기 (뇌전부). delay 뒤 하늘에서 지그재그 번개가 떨어져
## 맞은 적에게 큰 피해, 주변 적에게 작은 피해를 줍니다.

const FLASH_TIME := 0.28
const SKY_HEIGHT := 420.0     # 번개가 시작하는 높이 (화면 위쪽)

var main
var target                    # 노린 적 (떨어지기 전에 죽으면 그 자리에 떨어짐)
var damage := 70.0
var splash_damage := 30.0
var splash_radius := 70.0
var delay := 0.0
var t := 0.0
var struck := false
var points := PackedVector2Array()


func _process(delta: float) -> void:
	if not struck:
		delay -= delta
		if target != null and is_instance_valid(target) and not target.is_dead:
			position = target.global_position
		if delay <= 0.0:
			_strike()
		return
	t += delta
	if t >= FLASH_TIME:
		queue_free()
		return
	queue_redraw()


func _strike() -> void:
	struck = true
	# 위에서 아래로 꺾이며 내려오는 번개 모양
	var y := -SKY_HEIGHT
	var x := randf_range(-30.0, 30.0)
	points.append(Vector2(x, y))
	while y < -20.0:
		y += randf_range(35.0, 60.0)
		x = clampf(x + randf_range(-26.0, 26.0), -40.0, 40.0)
		points.append(Vector2(x * (-y / SKY_HEIGHT), minf(y, 0.0)))
	points.append(Vector2.ZERO)
	main.sfx.play("boom", 1.4)
	main.spawn_fx("ring", global_position, Color(0.7, 0.85, 1.0), splash_radius * 1.6)
	if target != null and is_instance_valid(target) and not target.is_dead:
		target.take_damage(damage)
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead or enemy == target:
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() < splash_radius + enemy.radius:
			enemy.take_damage(splash_damage, to_enemy.normalized())
	queue_redraw()


func _draw() -> void:
	if not struck:
		# 떨어지기 직전: 땅에 희미한 푸른 표시
		draw_circle(Vector2.ZERO, 10.0, Color(0.6, 0.8, 1.0, 0.35))
		return
	var a := 1.0 - t / FLASH_TIME
	# 바깥 푸른 빛 → 흰 심 (두 겹 선)
	draw_polyline(points, Color(0.45, 0.65, 1.0, 0.5 * a), 9.0)
	draw_polyline(points, Color(0.85, 0.93, 1.0, a), 4.0)
	draw_polyline(points, Color(1, 1, 1, a), 1.8)
	# 땅에 떨어진 자리: 번쩍임 + 그을음
	draw_circle(Vector2.ZERO, splash_radius * (0.5 + 0.5 * (1.0 - a)), Color(0.7, 0.85, 1.0, 0.35 * a))
	draw_circle(Vector2.ZERO, 14.0 * a + 4.0, Color(1, 1, 1, a))
