extends "res://scripts/weapons/hwacha.gd"
## 무관 스킬 [연속 사격]: 화살 여러 발을 빠르게 연사합니다.
## 소형 화차와 쏘는 방식이 같아서 hwacha.gd를 바탕으로 숫자와 모양만 바꿨습니다.


func _init() -> void:
	weapon_id = "rapid"
	display_name = "연속 사격"
	base_cooldown = 2.4
	arrow_speed = 650.0
	spread = 0.08
	arrow_style = "arrow"
	fire_pitch = 0.85
	set_level(1)


## 레벨마다 화살 +1발, 피해 +15%
func set_level(lv: int) -> void:
	level = lv
	shots_per_volley = 2 + lv
	damage = 8.0 * (1.0 + 0.15 * (lv - 1))
