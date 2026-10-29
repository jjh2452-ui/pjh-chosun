extends "res://scripts/weapons/weapon.gd"
## 문관 기본 무기 [소형 화차]: 가까운 적을 향해 불화살 여러 발을 짧은 간격으로 연속 발사합니다.
## (무관의 [연속 사격]도 이 파일을 바탕으로 만들어집니다.)

const RANGE := 550.0
const SHOT_GAP := 0.08      # 연속 발사 사이 간격(초)

var damage := 7.0           # 화살 한 발의 피해
var shots_per_volley := 4   # 한 번에 쏘는 화살 수
var arrow_speed := 520.0
var spread := 0.18          # 화살이 흩어지는 정도(라디안, 약 10도)
var arrow_style := "fire_arrow"
var shots_left := 0
var shot_timer := 0.0
var aim_dir := Vector2.RIGHT


func _init() -> void:
	weapon_id = "hwacha"
	display_name = "소형 화차"
	base_cooldown = 1.3
	fire_pitch = 1.3
	set_level(1)


## 레벨마다 화살 +1발, 피해 +15%
func set_level(lv: int) -> void:
	level = lv
	shots_per_volley = 3 + lv
	damage = 7.0 * (1.0 + 0.15 * (lv - 1))


func attack() -> bool:
	var target = player.find_nearest_enemy(RANGE)
	if target == null:
		return false
	aim_dir = (target.global_position - player.global_position).normalized()
	shots_left = shots_per_volley
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
	# 쏠 때마다 가장 가까운 적을 다시 조준 (없으면 처음 방향 유지)
	var target = player.find_nearest_enemy(RANGE)
	if target != null:
		aim_dir = (target.global_position - player.global_position).normalized()
	var dir := aim_dir.rotated(randf_range(-spread, spread))
	fire(dir, arrow_speed, damage * player.damage_mult, arrow_style)
