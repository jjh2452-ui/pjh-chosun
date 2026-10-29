extends RefCounted
## 적 종류별 기본 능력치. 숫자를 바꾸면 그 적이 바로 강해지거나 약해집니다.
##
##   hp               시작 체력
##   hp_growth        1분 지날 때마다 늘어나는 체력 비율 (0.5 = 1분마다 +50%)
##   speed            이동 속도
##   damage           몸으로 부딪혔을 때 피해
##   radius           크기(충돌 반지름)
##   xp               처치 시 경험치
##   knockback_resist 밀려나지 않는 정도 (0 = 잘 밀림, 1 = 전혀 안 밀림)
##   slam_damage      내려찍기 피해 (두목·보스)
##   dash_damage      돌진 피해 (호랑이·보스)
## 공격 예고 시간 같은 행동 숫자는 enemy.gd 위쪽에 있습니다.

# ===== 전체 난이도 =====
# 모든 적에게 곱해지는 배율. 쉽게 하려면 1.0으로 낮추세요.
# (상점의 영구 강화로 플레이어가 점점 강해지므로, 기본 난이도를 조금 높여 두었습니다)
const SPEED_MULT := 1.1       # 적 이동 속도 +10%
const SPEED_OFFSET := -20.0   # 모든 적 이동 속도를 이만큼 더함 (-20 = 전체적으로 20씩 느리게)
const DAMAGE_MULT := 1.2      # 적이 주는 피해 +20%
const NON_TIGER_DAMAGE_MULT := 1.1   # 호랑이를 뺀 모든 적의 피해 +10% (호랑이는 따로 2배로 올려 둠)
# 시간이 지날수록 적의 공격력이 세짐: 1분마다 +6% (5분 1.3배, 10분 1.6배). 나타나는 순간의 시간으로 정해짐
const DAMAGE_GROWTH := 0.06

const ENEMIES := {
	"bandit": {
		"name": "산적",
		"hp": 10.0, "hp_growth": 0.4, "speed": 80.0, "damage": 4.0,
		"radius": 14.0, "xp": 1, "knockback_resist": 0.0,
		"color": Color(0.55, 0.38, 0.22),
	},
	"brute": {
		"name": "힘센 산적",
		"hp": 40.0, "hp_growth": 0.35, "speed": 50.0, "damage": 9.0,
		"radius": 20.0, "xp": 3, "knockback_resist": 0.6,
		"color": Color(0.42, 0.3, 0.24),
	},
	"zombie": {
		"name": "좀비",
		"hp": 12.0, "hp_growth": 0.35, "speed": 42.0, "damage": 3.0,
		"radius": 13.0, "xp": 1, "knockback_resist": 0.0,
		"color": Color(0.55, 0.65, 0.55),
	},
	"tiger": {
		"name": "호랑이",
		"hp": 30.0, "hp_growth": 0.35, "speed": 120.0, "damage": 14.0,   # 맹수라 아프게 (예전 7 → 2배)
		"radius": 17.0, "xp": 4, "knockback_resist": 0.3,
		"dash_damage": 30.0,                                             # 돌진도 2배 (예전 15)
		"color": Color(0.92, 0.55, 0.15),
	},
	"ghost": {
		"name": "귀신",
		"hp": 16.0, "hp_growth": 0.35, "speed": 100.0, "damage": 6.0,
		"radius": 13.0, "xp": 2, "knockback_resist": 0.2,
		"color": Color(0.93, 0.94, 0.97),
	},
	"chief": {
		"name": "산적 두목",
		"hp": 350.0, "hp_growth": 0.3, "speed": 70.0, "damage": 10.0,
		"radius": 26.0, "xp": 25, "knockback_resist": 1.0,
		"slam_damage": 22.0,
		"color": Color(0.38, 0.14, 0.12),
	},
	"boss": {
		"name": "도깨비 대왕",
		"hp": 3500.0, "hp_growth": 0.0, "speed": 75.0, "damage": 14.0,
		"radius": 44.0, "xp": 0, "knockback_resist": 1.0,
		"slam_damage": 25.0, "dash_damage": 20.0,
		"color": Color(0.22, 0.36, 0.62),
	},
}
