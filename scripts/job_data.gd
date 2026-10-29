extends RefCounted
## 전직 데이터. JOB_LEVEL에 도달하면 문관과 무관 중 하나를 고르고, 한 판 동안 유지됩니다.
## 전직 선택 화면의 설명 문구는 여기서 고치면 됩니다.

const JOB_LEVEL := 5

# 전직 전(선비)의 기본 능력치. 직업별 값은 아래 JOBS의 "max_hp", "defense"
# 기본값을 일부러 낮게 잡았습니다 → 엽전 상점 강화(체력·속도·공격)를 살수록 확실히 강해진 게 느껴지도록
const SEONBI_MAX_HP := 45.0      # 예전 60
const SEONBI_DEFENSE := 2.0      # 예전 3
const SEONBI_MOVE := 2.0
# 이동력: 실제 속도(초당 픽셀) = MOVE_BASE + 이동력 × MOVE_PER_POINT
#   → 선비 2 = 68, 무관 3 = 112, 문관 4 = 156 (모두 20씩 더 느리게)
#   참고: 산적 속도는 약 78, 호랑이는 약 122
const MOVE_BASE := -20.0
const MOVE_PER_POINT := 44.0     # 예전 50
# 모든 무기 피해에 곱하는 기본 배율 (처음 1.0 → 0.85 → 0.765 → 20% 더 낮춰 0.612). 상점 '무예·학문 정진'으로 되찾음
const BASE_DAMAGE_MULT := 0.612
# 방어력: 맞을 때마다 피해에서 이만큼 뺍니다. (최소 피해 MIN_DAMAGE는 항상 들어감)
const MIN_DAMAGE := 2.0

const JOBS := {
	"civil": {
		"name": "문관",
		"style": "발명품과 설치 장치로 많은 적을 한꺼번에 상대하고, 넓은 지역을 지키는 방어형입니다.",
		"weapons": "소형 화차 · 자동 쇠뇌 · 화약탄 · 기계 연",
		"start_weapon": "소형 화차 — 가까운 적에게 불화살 여러 발을 연속 발사",
		"start_weapon_id": "hwacha",
		"start_weapon_name": "소형 화차",
		"max_hp": 60.0,     # 예전 80
		"defense": 4.0,     # 예전 5
		"move": 4.0,
		"color": Color(0.25, 0.42, 0.75),
	},
	"military": {
		"name": "무관",
		"style": "칼과 활로 적과 직접 맞붙는 전투형입니다. 검술·궁술·혼합형으로 키울 수 있습니다.",
		"weapons": "검술 · 궁술 · 회전 베기 · 연속 사격",
		"start_weapon": "검술 — 앞쪽 부채꼴 범위를 크게 베기",
		"start_weapon_id": "sword",
		"start_weapon_name": "검술",
		"max_hp": 75.0,     # 예전 100
		"defense": 6.0,     # 예전 8
		"move": 3.0,
		"color": Color(0.72, 0.2, 0.18),
	},
}
