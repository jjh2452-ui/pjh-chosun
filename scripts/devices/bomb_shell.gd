extends Node2D
## 화약탄 한 발. 목표 지점까지 포물선을 그리며 날아가 폭발합니다.
## 날아가는 동안 떨어질 자리에 붉은 원으로 예고가 표시됩니다.

const FLIGHT_TIME := 0.6
const EXPLODE_TIME := 0.3
const ARC_HEIGHT := 60.0

var main
var start_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var damage := 25.0
var blast_radius := 80.0
var t := 0.0
var exploded := false


func _process(delta: float) -> void:
	t += delta
	if not exploded:
		var p := minf(t / FLIGHT_TIME, 1.0)
		position = start_pos.lerp(target_pos, p) + Vector2(0, -sin(p * PI) * ARC_HEIGHT)
		if p >= 1.0:
			_explode()
	elif t >= EXPLODE_TIME:
		queue_free()
		return
	queue_redraw()


func _explode() -> void:
	exploded = true
	t = 0.0
	position = target_pos
	main.sfx.play("boom")
	main.add_shake(0.15)
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead:
			continue
		var to_enemy: Vector2 = enemy.global_position - target_pos
		if to_enemy.length() < blast_radius + enemy.radius:
			enemy.take_damage(damage, to_enemy.normalized() * 2.0)


func _draw() -> void:
	if not exploded:
		# 떨어질 자리 예고 + 날아가는 화약탄(검은 공과 불꽃 심지)
		var mark := target_pos - position
		draw_circle(mark, blast_radius, Color(1, 0.3, 0.2, 0.08))
		draw_arc(mark, blast_radius, 0, TAU, 40, Color(1, 0.3, 0.2, 0.55), 2.0)
		# 무쇠 화약탄 + 빛 + 타들어가는 심지와 불똥
		draw_circle(Vector2.ZERO, 8.5, Color(0.05, 0.05, 0.06))
		draw_circle(Vector2.ZERO, 7.0, Color(0.16, 0.16, 0.18))
		draw_circle(Vector2(-2.5, -2.5), 2.2, Color(1, 1, 1, 0.35))
		draw_line(Vector2(3, -6), Vector2(6, -10), Color(0.55, 0.4, 0.25), 1.5)
		for i in 4:   # 불똥 별
			var a := TAU * i / 4.0 + t * 20.0
			draw_line(Vector2(6, -10), Vector2(6, -10) + Vector2.RIGHT.rotated(a) * 4.0, Color(1, 0.85, 0.3), 1.5)
	else:
		# 폭발: 붉은 불길 → 노란 섬광, 바깥으로 퍼지는 먹빛 연기
		var p := t / EXPLODE_TIME
		var fade := 1.0 - p
		var r := blast_radius * (0.5 + 0.5 * p)
		for i in 8:
			var a := TAU * i / 8.0 + 0.3
			draw_circle(Vector2.RIGHT.rotated(a) * r * 0.85, r * 0.28, Color(0.15, 0.12, 0.12, 0.45 * fade))
		draw_circle(Vector2.ZERO, r, Color(0.9, 0.25, 0.08, 0.6 * fade))
		draw_circle(Vector2.ZERO, r * 0.72, Color(1.0, 0.6, 0.15, 0.7 * fade))
		draw_circle(Vector2.ZERO, r * 0.4, Color(1.0, 0.95, 0.6, 0.85 * fade))
		draw_arc(Vector2.ZERO, r * 1.05, 0, TAU, 40, Color(1, 0.9, 0.6, fade), 3.0)
