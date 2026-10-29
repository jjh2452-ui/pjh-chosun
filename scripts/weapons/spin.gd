extends "res://scripts/weapons/weapon.gd"
## 무관 스킬 [회전 베기]: 몸을 한 바퀴 돌려 주변의 모든 적을 원형으로 벱니다.

const EFFECT_DURATION := 0.25

var damage := 18.0
var spin_radius := 110.0
var effect_time := 0.0


func _init() -> void:
	weapon_id = "spin"
	display_name = "회전 베기"
	set_level(1)


## 레벨마다 피해 +20%, 범위 +15, 공격 간격 -0.15초
func set_level(lv: int) -> void:
	level = lv
	damage = 18.0 * (1.0 + 0.2 * (lv - 1))
	spin_radius = 110.0 + 15.0 * (lv - 1)
	base_cooldown = 2.2 - 0.15 * (lv - 1)


func attack() -> bool:
	if player.find_nearest_enemy(spin_radius) == null:
		return false
	var dmg: float = damage * player.damage_mult
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead:
			continue
		var to_enemy: Vector2 = enemy.global_position - player.global_position
		if to_enemy.length() < spin_radius + enemy.radius:
			enemy.take_damage(dmg, to_enemy.normalized() * 2.0)
	effect_time = EFFECT_DURATION
	queue_redraw()
	main.sfx.play("slash", 0.7)
	return true


func _process(delta: float) -> void:
	super(delta)
	if effect_time > 0.0:
		effect_time -= delta
		queue_redraw()


func _draw() -> void:
	if effect_time <= 0.0:
		return
	# 한 바퀴 휘감는 두 갈래 초승달 칼자국 (붓 휘두른 모양)
	var p := 1.0 - effect_time / EFFECT_DURATION
	var fade := 1.0 - p
	draw_circle(Vector2.ZERO, spin_radius, Color(1, 1, 1, 0.08 * fade))
	var start := p * TAU * 1.5
	for k in 2:
		var a0 := start + PI * k
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			var a := a0 + PI * 0.9 * t
			outer.append(Vector2.RIGHT.rotated(a) * spin_radius)
			inner.append(Vector2.RIGHT.rotated(a) * spin_radius * (1.0 - 0.25 * sin(t * PI)))
		var band := outer.duplicate()
		for i in range(inner.size() - 1, -1, -1):
			band.append(inner[i])
		draw_colored_polygon(band, Color(0.92, 0.96, 1.0, 0.8 * fade))
		draw_polyline(outer, Color(0.1, 0.1, 0.15, 0.6 * fade), 2.0)
