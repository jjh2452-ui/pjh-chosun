extends "res://scripts/weapons/weapon.gd"
## 진화 무기 [조총] (하드 모드, 무관): 궁술 5 + 검술 수련 4 → 활이 조총으로 바뀝니다.
## 가장 가까운 적에게 빠르고 무거운 탄환을 3연발. 탄환은 적 여럿을 꿰뚫습니다.

const RANGE := 750.0
const SPEED := 1150.0
const SHOT_GAP := 0.12     # 연발 사이 간격(초)

var damage := 55.0
var pierce := 6
var shots := 3
var shots_left := 0
var shot_timer := 0.0


func _init() -> void:
	weapon_id = "musket"
	display_name = "조총"
	base_cooldown = 1.5
	fire_pitch = 0.55        # 낮고 묵직한 총소리
	set_level(1)


func attack() -> bool:
	if player.find_nearest_enemy(RANGE) == null:
		return false
	shots_left = shots
	shot_timer = 0.0
	return true


func _process(delta: float) -> void:
	super(delta)
	if shots_left <= 0:
		return
	shot_timer -= delta
	if shot_timer > 0.0:
		return
	shot_timer = SHOT_GAP
	shots_left -= 1
	var target = player.find_nearest_enemy(RANGE)
	if target == null:
		shots_left = 0
		return
	var dir: Vector2 = (target.global_position - player.global_position).normalized()
	fire(dir, SPEED, damage * player.damage_mult, "musket", pierce)
	main.sfx.play("boom", 1.8)
	# 총구 화염과 연기
	main.spawn_fx("spark", player.global_position + dir * 22.0, Color(1.0, 0.75, 0.3), 18.0)
	main.spawn_fx("burst", player.global_position + dir * 26.0, Color(0.55, 0.55, 0.55), 9.0)
