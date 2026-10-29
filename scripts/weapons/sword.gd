extends "res://scripts/weapons/weapon.gd"
## 무관 기본 무기 [검술]: 가장 가까운 적 방향으로 부채꼴 범위를 크게 베어, 범위 안의 적을 모두 공격합니다.

const EFFECT_DURATION := 0.18   # 베기 효과가 보이는 시간(초)

const TRIGGER_EXTRA := 90.0             # 베기 범위보다 이만큼 먼 적이 와도 미리 휘두름

var damage := 32.0
var slash_range := 135.0                # 베기 반지름(픽셀)
var slash_angle := deg_to_rad(120.0)    # 부채꼴 전체 각도
var slash_dir := Vector2.RIGHT
var effect_time := 0.0


func _init() -> void:
	weapon_id = "sword"
	display_name = "검술"
	base_cooldown = 0.85
	set_level(1)


## 레벨마다 피해 +25%, 베기 범위 +10%
func set_level(lv: int) -> void:
	level = lv
	damage = 32.0 * (1.0 + 0.25 * (lv - 1))
	slash_range = 135.0 * (1.0 + 0.1 * (lv - 1))


func attack() -> bool:
	# 칼이 닿을 만한 거리에 적이 있을 때만 벤다
	var target = player.find_nearest_enemy(slash_range + TRIGGER_EXTRA)
	if target == null:
		return false
	slash_dir = (target.global_position - player.global_position).normalized()
	var dmg: float = damage * player.damage_mult
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead:
			continue
		var to_enemy: Vector2 = enemy.global_position - player.global_position
		if to_enemy.length() > slash_range + enemy.radius:
			continue
		if abs(slash_dir.angle_to(to_enemy)) > slash_angle / 2.0:
			continue
		enemy.take_damage(dmg, to_enemy.normalized() * 2.0)
	effect_time = EFFECT_DURATION
	queue_redraw()
	main.sfx.play("slash")
	return true


func _process(delta: float) -> void:
	super(delta)
	if effect_time > 0.0:
		effect_time -= delta
		queue_redraw()


func _draw() -> void:
	if effect_time <= 0.0:
		return
	# 붓을 휘두른 듯한 초승달 칼자국: 가운데가 두껍고 양 끝이 가늘게. 왼쪽에서 오른쪽으로 펼쳐짐
	var p := 1.0 - effect_time / EFFECT_DURATION
	var fade := 1.0 - p
	var start := slash_dir.angle() - slash_angle / 2.0
	var end := start + slash_angle * clampf(p * 1.6, 0.15, 1.0)
	# 범위 표시 (옅은 부채꼴)
	var fan := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		fan.append(Vector2.RIGHT.rotated(lerpf(start, end, i / 12.0)) * slash_range)
	draw_colored_polygon(fan, Color(1, 1, 1, 0.08 * fade))
	# 초승달
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		var a := lerpf(start, end, t)
		var thick := 0.32 * sin(t * PI)
		outer.append(Vector2.RIGHT.rotated(a) * slash_range)
		inner.append(Vector2.RIGHT.rotated(a) * slash_range * (1.0 - thick))
	var crescent := outer.duplicate()
	for i in range(inner.size() - 1, -1, -1):
		crescent.append(inner[i])
	draw_colored_polygon(crescent, Color(0.92, 0.96, 1.0, 0.85 * fade))
	draw_polyline(outer, Color(0.1, 0.1, 0.15, 0.7 * fade), 2.0)        # 먹 테두리
	# 칼끝에서 튀는 먹점
	var tip := Vector2.RIGHT.rotated(end) * slash_range
	draw_circle(tip + Vector2.RIGHT.rotated(end + 0.4) * 8.0, 2.5 * fade, Color(0.1, 0.1, 0.15, 0.7 * fade))
	draw_circle(tip + Vector2.RIGHT.rotated(end - 0.3) * 13.0, 1.6 * fade, Color(0.1, 0.1, 0.15, 0.6 * fade))
