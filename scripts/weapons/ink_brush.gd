extends "res://scripts/weapons/weapon.gd"
## 선비 기본 무기 [먹물 탄환]: 가장 가까운 적에게 먹물을 한 발 쏩니다. 전직하면 사라집니다.

const RANGE := 600.0
const SPEED := 450.0
var damage := 10.0


func _init() -> void:
	weapon_id = "ink_brush"
	display_name = "먹물 탄환"
	base_cooldown = 0.5


func attack() -> bool:
	var target = player.find_nearest_enemy(RANGE)
	if target == null:
		return false
	var dir: Vector2 = (target.global_position - player.global_position).normalized()
	fire(dir, SPEED, damage * player.damage_mult, "ink")
	return true
