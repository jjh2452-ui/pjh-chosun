extends "res://scripts/weapons/weapon.gd"
## 진화 무기 [신기전] (하드 모드, 문관): 소형 화차 5 + 자동 쇠뇌 5 → 화차가 신기전으로 바뀝니다.
## 로켓 화살을 부채꼴로 한꺼번에 쏘고, 화살은 적에게 맞거나 멀리 날아가면 터져서 주변까지 태웁니다.

const RANGE := 600.0
const SHOT_GAP := 0.03     # 한 번에 쏟아지듯 아주 짧은 간격

var damage := 16.0         # 화살이 직접 맞힌 피해
var blast_damage := 22.0   # 터질 때 주변 피해
var blast_radius := 55.0
var rockets := 12
var fan := 0.9             # 부채꼴 전체 각도(라디안, 약 50도)
var shots_left := 0
var shot_timer := 0.0
var aim_dir := Vector2.RIGHT


func _init() -> void:
	weapon_id = "singijeon"
	display_name = "신기전"
	base_cooldown = 1.8
	fire_pitch = 1.5
	set_level(1)


func attack() -> bool:
	var target = player.find_nearest_enemy(RANGE)
	if target == null:
		return false
	aim_dir = (target.global_position - player.global_position).normalized()
	shots_left = rockets
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
	# 부채꼴 왼쪽 끝부터 오른쪽 끝까지 차례로
	var t := 1.0 - float(shots_left) / maxf(1.0, rockets - 1.0)
	var dir := aim_dir.rotated(lerpf(-fan / 2.0, fan / 2.0, t) + randf_range(-0.04, 0.04))
	var p = Projectile.new()
	p.main = main
	p.velocity = dir * randf_range(520.0, 600.0)
	p.damage = damage * player.damage_mult
	p.style = "singijeon"
	p.blast_damage = blast_damage * player.damage_mult
	p.blast_radius = blast_radius
	p.life = 1.1
	p.position = player.global_position
	main.bullet_layer.add_child(p)
	if shots_left % 3 == 0:
		main.sfx.play("shoot", fire_pitch)
