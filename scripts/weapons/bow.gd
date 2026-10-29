extends "res://scripts/weapons/weapon.gd"
## 무관 스킬 [궁술]: 가장 가까운 적에게 여러 적을 꿰뚫는 화살을 쏩니다.

const RANGE := 650.0
const SPEED := 620.0

var damage := 14.0
var pierce := 2      # 관통하는 적 수
var arrows := 1      # 한 번에 쏘는 화살 수


func _init() -> void:
	weapon_id = "bow"
	display_name = "궁술"
	base_cooldown = 1.1
	fire_pitch = 0.75
	set_level(1)


## 레벨마다 피해 +20%, 관통 +1. 3레벨부터 화살 2발
func set_level(lv: int) -> void:
	level = lv
	damage = 14.0 * (1.0 + 0.2 * (lv - 1))
	pierce = 1 + lv
	arrows = 1 if lv < 3 else 2


func attack() -> bool:
	var target = player.find_nearest_enemy(RANGE)
	if target == null:
		return false
	var dir: Vector2 = (target.global_position - player.global_position).normalized()
	for i in arrows:
		var offset: float = (i - (arrows - 1) / 2.0) * 0.12   # 2발이면 살짝 벌려서
		fire(dir.rotated(offset), SPEED, damage * player.damage_mult, "arrow", pierce)
	return true
