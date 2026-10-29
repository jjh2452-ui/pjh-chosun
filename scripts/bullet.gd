extends Node2D
## 날아가는 투사체(먹물 탄환, 불화살 등). 직선으로 날아가다 적에게 닿으면 피해를 줍니다.
## style에 따라 모양이 바뀌고, pierce만큼 적을 더 뚫고 지나갑니다.

var main
var velocity := Vector2.ZERO
var damage := 10.0
var radius := 6.0
var life := 1.6          # 이 시간(초)이 지나면 사라짐
var pierce := 0          # 관통 가능한 적 수 (0이면 첫 적에게 맞고 사라짐)
var style := "ink"       # "ink" = 먹물, "fire_arrow" = 화차 불화살, "arrow" = 화살, "bolt" = 쇠뇌 화살
                         # "musket" = 조총 탄환, "singijeon" = 신기전 로켓 화살
var hit_ids := []        # 이미 맞힌 적 (관통할 때 같은 적을 두 번 때리지 않도록)
var blast_damage := 0.0  # 0보다 크면 맞히거나 사라질 때 터져서 주변에 피해 (신기전)
var blast_radius := 0.0


func _ready() -> void:
	rotation = velocity.angle()


func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		_blast()
		queue_free()
		return
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead or hit_ids.has(enemy.get_instance_id()):
			continue
		var hit_dist: float = radius + enemy.radius
		if global_position.distance_squared_to(enemy.global_position) < hit_dist * hit_dist:
			enemy.take_damage(damage, velocity.normalized())
			if pierce <= 0:
				_blast()
				queue_free()
				return
			pierce -= 1
			hit_ids.append(enemy.get_instance_id())


## 신기전 화살이 터짐: 주변 적에게 피해 + 불꽃 고리
func _blast() -> void:
	if blast_damage <= 0.0:
		return
	main.spawn_fx("ring", global_position, Color(1.0, 0.55, 0.15), blast_radius * 1.5)
	main.spawn_fx("spark", global_position, Color(1.0, 0.8, 0.3), blast_radius * 0.6)
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead:
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() < blast_radius + enemy.radius:
			enemy.take_damage(blast_damage, to_enemy.normalized())


func _draw() -> void:
	# 모든 모양은 오른쪽(+x)으로 날아가는 기준. 노드가 날아가는 방향으로 회전돼 있음
	var ink := Color(0.06, 0.05, 0.07)
	var iron := Color(0.22, 0.22, 0.26)
	match style:
		"musket":
			# 조총 탄환: 뒤로 길게 끌리는 흰 궤적 + 납 탄알
			draw_line(Vector2(-34, 0), Vector2(0, 0), Color(1.0, 0.95, 0.8, 0.35), 4.0)
			draw_line(Vector2(-18, 0), Vector2(0, 0), Color(1.0, 0.9, 0.6, 0.8), 2.0)
			draw_circle(Vector2.ZERO, 4.0, Color(0.3, 0.3, 0.34))
			draw_circle(Vector2(-1, -1.2), 1.4, Color(1, 1, 1, 0.6))
		"singijeon":
			# 신기전: 긴 대나무 살 + 화약통 + 꼬리의 큰 불꽃과 연기
			draw_circle(Vector2(-30, 0), 5.0, Color(0.45, 0.42, 0.4, 0.35))
			_tri([Vector2(-30, 0), Vector2(-14, -6), Vector2(-12, 6)], Color(0.9, 0.2, 0.05, 0.75))
			_tri([Vector2(-24, 0), Vector2(-13, -4), Vector2(-12, 4)], Color(1.0, 0.6, 0.1))
			_tri([Vector2(-18, 0), Vector2(-12, -2), Vector2(-12, 2)], Color(1.0, 0.97, 0.6))
			draw_line(Vector2(-13, 0), Vector2(8, 0), Color(0.5, 0.35, 0.18), 2.2)
			draw_rect(Rect2(-6, -3, 8, 6), Color(0.65, 0.1, 0.08))           # 큰 화약 통
			draw_line(Vector2(-6, 0), Vector2(2, 0), Color(0.95, 0.8, 0.3), 1.0)   # 금빛 띠
			_tri([Vector2(13, 0), Vector2(7, -3.5), Vector2(7, 3.5)], iron)
		"fire_arrow":
			# 화차 불화살: 꼬리에서 세 겹 불꽃이 타오름
			_tri([Vector2(-26, 0), Vector2(-12, -5), Vector2(-10, 5)], Color(0.85, 0.15, 0.05, 0.7))
			_tri([Vector2(-21, 0), Vector2(-11, -3.5), Vector2(-10, 3.5)], Color(1.0, 0.55, 0.1))
			_tri([Vector2(-16, 0), Vector2(-10, -2), Vector2(-10, 2)], Color(1.0, 0.95, 0.5))
			draw_line(Vector2(-12, 0), Vector2(5, 0), Color(0.45, 0.3, 0.15), 2.0)
			draw_rect(Rect2(-5, -2.2, 5, 4.4), Color(0.6, 0.12, 0.08))          # 화약 통
			_tri([Vector2(10, 0), Vector2(4, -3.5), Vector2(4, 3.5)], iron)
		"arrow":
			# 화살: 대나무 살 + 붉은 끝 흰 깃 + 쇠촉
			draw_line(Vector2(-16, 0), Vector2(6, 0), Color(0.78, 0.65, 0.42), 2.0)
			for s in [-1.0, 1.0]:
				_tri([Vector2(-17, 0), Vector2(-11, 0), Vector2(-15, 4.5 * s)], Color(0.97, 0.96, 0.92))
				_tri([Vector2(-17, 0), Vector2(-15.5, 0), Vector2(-16.5, 4.5 * s)], Color(0.8, 0.15, 0.12))
			_tri([Vector2(12, 0), Vector2(5, -3), Vector2(5, 3)], Color(0.75, 0.75, 0.82))
			draw_line(Vector2(5, 0), Vector2(12, 0), Color(1, 1, 1, 0.6), 0.8)  # 촉의 빛
		"bolt":
			# 쇠뇌 화살: 짧고 굵은 살 + 넓은 쇠촉
			draw_line(Vector2(-9, 0), Vector2(4, 0), Color(0.35, 0.22, 0.1), 3.2)
			_tri([Vector2(-10, 0), Vector2(-6, -3), Vector2(-6, 3)], Color(0.55, 0.4, 0.22))
			_tri([Vector2(10, 0), Vector2(3, -4), Vector2(3, 4)], iron)
		_:
			# 먹물: 붓으로 찍은 먹 방울. 뒤로 가늘게 끌리는 꼬리와 튄 먹점
			_tri([Vector2(-20, 0), Vector2(-2, -radius * 0.8), Vector2(-2, radius * 0.8)], Color(ink, 0.45))
			draw_circle(Vector2(-11, 3), 1.6, Color(ink, 0.5))
			draw_circle(Vector2(-15, -2.5), 1.1, Color(ink, 0.4))
			draw_circle(Vector2.ZERO, radius, ink)
			draw_circle(Vector2(-1.5, -1.8), radius * 0.35, Color(0.4, 0.4, 0.5, 0.6))   # 먹의 윤기


func _tri(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
