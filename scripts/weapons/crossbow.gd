extends "res://scripts/weapons/weapon.gd"
## 문관 스킬 [자동 쇠뇌]: 적이 가까이 있으면 발밑에 쇠뇌를 설치합니다.
## 설치물은 유지 시간이 지나면 사라지고, 최대 개수를 넘으면 가장 오래된 것부터 치웁니다.

const Turret = preload("res://scripts/devices/crossbow_turret.gd")
const TRIGGER_RANGE := 400.0   # 이 거리 안에 적이 있을 때만 설치

var damage := 10.0
var duration := 8.0
var max_count := 1
var turrets: Array = []


func _init() -> void:
	weapon_id = "crossbow"
	display_name = "자동 쇠뇌"
	base_cooldown = 3.5
	set_level(1)


## 레벨마다 유지 시간 +1초, 피해 +2. 2·4레벨에 최대 설치 수 +1
func set_level(lv: int) -> void:
	level = lv
	damage = 10.0 + 2.0 * (lv - 1)
	duration = 8.0 + 1.0 * (lv - 1)
	max_count = 1 + int(lv / 2.0)


func attack() -> bool:
	if player.find_nearest_enemy(TRIGGER_RANGE) == null:
		return false
	# 이미 사라진 설치물은 목록에서 정리
	turrets = turrets.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	while turrets.size() >= max_count:
		turrets[0].queue_free()
		turrets.remove_at(0)
	var turret = Turret.new()
	turret.main = main
	turret.player = player
	turret.damage = damage
	turret.duration = duration
	turret.time_left = duration
	turret.position = player.global_position
	main.device_layer.add_child(turret)
	turrets.append(turret)
	return true
