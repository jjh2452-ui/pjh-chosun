extends "res://scripts/weapons/weapon.gd"
## 문관 스킬 [기계 연]: 방패연이 주인공 주변을 계속 돌며, 닿은 적에게 피해를 줍니다.
## 같은 적은 HIT_INTERVAL초에 한 번만 맞습니다.

const ORBIT_RADIUS := 95.0
const ROT_SPEED := 2.6        # 초당 회전(라디안)
const KITE_RADIUS := 13.0     # 연의 충돌 크기
const HIT_INTERVAL := 0.5

var damage := 8.0
var kite_count := 1
var angle := 0.0
var hit_cooldowns := {}       # 적 id → 다시 맞을 수 있을 때까지 남은 시간


func _init() -> void:
	weapon_id = "kite"
	display_name = "기계 연"
	set_level(1)


## 레벨마다 피해 +25%. 2·4레벨에 연 +1
func set_level(lv: int) -> void:
	level = lv
	damage = 8.0 * (1.0 + 0.25 * (lv - 1))
	kite_count = 1 + int(lv / 2.0)


# 쿨타임 없이 항상 돌기 때문에 weapon.gd의 _process를 쓰지 않습니다.
func _process(delta: float) -> void:
	angle = fmod(angle + ROT_SPEED * delta, TAU)
	for key in hit_cooldowns.keys():
		hit_cooldowns[key] -= delta
		if hit_cooldowns[key] <= 0.0:
			hit_cooldowns.erase(key)
	for i in kite_count:
		var kite_pos: Vector2 = player.global_position + _offset(i)
		for enemy in main.enemy_layer.get_children():
			if enemy.is_dead:
				continue
			var key: int = enemy.get_instance_id()
			if hit_cooldowns.has(key):
				continue
			var hit_dist: float = KITE_RADIUS + enemy.radius
			if kite_pos.distance_squared_to(enemy.global_position) < hit_dist * hit_dist:
				hit_cooldowns[key] = HIT_INTERVAL
				enemy.take_damage(damage * player.damage_mult, (enemy.global_position - player.global_position).normalized())
	queue_redraw()


func _offset(i: int) -> Vector2:
	return Vector2.RIGHT.rotated(angle + TAU * i / kite_count) * ORBIT_RADIUS


func _draw() -> void:
	var ink := Color(0.25, 0.18, 0.12)
	for i in kite_count:
		var pos := _offset(i)
		var a := angle + TAU * i / kite_count
		var behind := Vector2.DOWN.rotated(a + PI)   # 도는 방향의 반대쪽 = 꼬리가 날리는 쪽
		draw_line(Vector2.ZERO, pos, Color(1, 1, 1, 0.25), 1.0)   # 연줄
		# 꼬리 두 가닥: 물결치며 뒤로 날림
		for s in [-1.0, 1.0]:
			var tail := PackedVector2Array()
			for k in 6:
				var d := behind * (12.0 + k * 5.0)
				tail.append(pos + Vector2(s * 6.0, 10) + d + behind.orthogonal() * sin(k * 1.3 + angle * 6.0) * 2.5)
			draw_polyline(tail, Color(0.85, 0.2, 0.15) if s < 0 else Color(0.2, 0.35, 0.7), 1.8)
		# 방패연: 한지 + 대나무 살 + 가운데 방구멍 + 위쪽 꼭지(태극)
		var rect := Rect2(pos - Vector2(10, 12), Vector2(20, 24))
		draw_rect(rect, Color(0.97, 0.94, 0.85))
		draw_line(rect.position, rect.end, Color(ink, 0.5), 1.0)
		draw_line(rect.position + Vector2(20, 0), rect.position + Vector2(0, 24), Color(ink, 0.5), 1.0)
		draw_line(pos + Vector2(0, -12), pos + Vector2(0, 12), Color(ink, 0.5), 1.0)
		draw_circle(pos + Vector2(0, 2), 4.0, Color(0.35, 0.45, 0.28, 0.7))       # 방구멍 (아래 풀밭이 비침)
		draw_arc(pos + Vector2(0, 2), 4.0, 0, TAU, 12, Color(ink, 0.6), 1.0)
		draw_circle(pos + Vector2(0, -6), 4.0, Color(0.85, 0.2, 0.15))            # 꼭지: 태극 (빨강 위, 파랑 아래)
		draw_arc(pos + Vector2(0, -6), 2.0, 0, PI, 8, Color(0.2, 0.35, 0.7), 4.0)
		draw_rect(rect, ink, false, 1.5)
