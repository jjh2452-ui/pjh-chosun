extends Node2D
## 자동 쇠뇌 설치물. 놓인 자리에서 정해진 시간 동안 주변 적에게 쇠뇌 화살을 쏘고 사라집니다.
## 바깥 테두리의 노란 고리가 남은 유지 시간을 보여줍니다.

const Projectile = preload("res://scripts/bullet.gd")
const RANGE := 320.0
const FIRE_INTERVAL := 0.6
const BOLT_SPEED := 600.0

var main
var player
var damage := 10.0
var duration := 8.0
var time_left := 8.0
var fire_timer := 0.0
var aim := Vector2.RIGHT


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		var target = _find_target()
		if target != null:
			aim = (target.global_position - global_position).normalized()
			_fire()
			fire_timer = FIRE_INTERVAL * player.cooldown_mult
	queue_redraw()


func _find_target():
	var nearest = null
	var best := RANGE * RANGE
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead:
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest


func _fire() -> void:
	var p = Projectile.new()
	p.main = main
	p.velocity = aim * BOLT_SPEED
	p.damage = damage * player.damage_mult
	p.style = "bolt"
	p.position = global_position
	main.bullet_layer.add_child(p)
	main.sfx.play("shoot", 0.6)


func _draw() -> void:
	# 받침대
	draw_rect(Rect2(-11, -11, 22, 22), Color(0.45, 0.3, 0.16))
	draw_rect(Rect2(-11, -11, 22, 22), Color(0.25, 0.15, 0.06), false, 2.0)
	# 쇠뇌: 조준 방향의 몸통 + 좌우로 벌어진 활
	var side := aim.orthogonal()
	draw_line(-aim * 6.0, aim * 14.0, Color(0.3, 0.2, 0.1), 4.0)
	draw_polyline(PackedVector2Array([aim * 4.0 + side * 12.0, aim * 11.0, aim * 4.0 - side * 12.0]), Color(0.15, 0.1, 0.05), 3.0)
	# 남은 유지 시간
	var ratio := time_left / duration
	draw_arc(Vector2.ZERO, 18.0, -PI / 2, -PI / 2 + TAU * ratio, 32, Color(1.0, 0.85, 0.3, 0.8), 2.0)
