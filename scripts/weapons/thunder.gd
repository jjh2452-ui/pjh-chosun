extends "res://scripts/weapons/weapon.gd"
## 진화 무기 [뇌전부(벼락)] (하드 모드, 문관): 화약탄 5 + 기계 연 5 → 화약탄이 벼락으로 바뀝니다.
## 주변의 적 여럿을 골라 하늘에서 벼락을 내리칩니다. 벼락이 떨어진 자리 주변 적도 함께 피해.

const Bolt = preload("res://scripts/devices/lightning.gd")
const RANGE := 520.0

var damage := 70.0          # 벼락을 맞은 적
var splash_damage := 30.0   # 주변 적
var splash_radius := 70.0
var strikes := 5            # 한 번에 떨어지는 벼락 수


func _init() -> void:
	weapon_id = "thunder"
	display_name = "뇌전부"
	base_cooldown = 2.2
	set_level(1)


func attack() -> bool:
	var targets: Array = []
	for enemy in main.enemy_layer.get_children():
		if not enemy.is_dead and enemy.global_position.distance_to(player.global_position) < RANGE:
			targets.append(enemy)
	if targets.is_empty():
		return false
	targets.shuffle()
	# 두목·보스가 가까이 있으면 먼저 노림
	targets.sort_custom(func(a, b): return a.radius > b.radius)
	for i in mini(strikes, targets.size()):
		var bolt = Bolt.new()
		bolt.main = main
		bolt.target = targets[i]
		bolt.damage = damage * player.damage_mult
		bolt.splash_damage = splash_damage * player.damage_mult
		bolt.splash_radius = splash_radius
		bolt.delay = i * 0.07     # 우르르 연달아 떨어지게
		bolt.position = targets[i].global_position
		main.bullet_layer.add_child(bolt)
	main.add_shake(0.2)
	return true
