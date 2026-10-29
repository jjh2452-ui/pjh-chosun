extends "res://scripts/weapons/weapon.gd"
## 문관 스킬 [화약탄]: 적이 가장 많이 모인 곳을 골라 화약탄을 던집니다.

const Shell = preload("res://scripts/devices/bomb_shell.gd")
const RANGE := 450.0
const CLUSTER_RADIUS := 90.0   # 이 거리 안의 적 수로 '모인 정도'를 잽니다

var damage := 25.0
var blast_radius := 80.0
var bombs := 1


func _init() -> void:
	weapon_id = "bomb"
	display_name = "화약탄"
	base_cooldown = 3.0
	set_level(1)


## 레벨마다 피해 +25%, 폭발 범위 +10. 3·5레벨에 던지는 수 +1
func set_level(lv: int) -> void:
	level = lv
	damage = 25.0 * (1.0 + 0.25 * (lv - 1))
	blast_radius = 80.0 + 10.0 * (lv - 1)
	bombs = 1 + int((lv - 1) / 2.0)


func attack() -> bool:
	var thrown := false
	for i in bombs:
		var target = _find_cluster()
		if target == null:
			break
		var shell = Shell.new()
		shell.main = main
		shell.start_pos = player.global_position
		shell.target_pos = target
		shell.damage = damage * player.damage_mult
		shell.blast_radius = blast_radius
		shell.position = player.global_position
		main.bullet_layer.add_child(shell)
		thrown = true
	return thrown


## 사거리 안의 적 몇 마리를 무작위로 골라, 주변에 적이 가장 많은 적의 위치를 돌려줍니다.
func _find_cluster():
	var enemies: Array = []
	for enemy in main.enemy_layer.get_children():
		if not enemy.is_dead and enemy.global_position.distance_to(player.global_position) < RANGE:
			enemies.append(enemy)
	if enemies.is_empty():
		return null
	enemies.shuffle()
	var best_pos: Vector2 = enemies[0].global_position
	var best_count := -1
	for candidate in enemies.slice(0, 12):
		var count := 0
		for other in enemies:
			if candidate.global_position.distance_to(other.global_position) < CLUSTER_RADIUS:
				count += 1
		if count > best_count:
			best_count = count
			best_pos = candidate.global_position
	return best_pos
