extends RefCounted
## 레벨업 강화 목록(데이터) = 스킬 트리.
##
## 항목마다 쓰는 값:
##   name        선택지에 보이는 이름
##   desc        처음 얻을 때(또는 공통 강화) 설명
##   desc_up     이미 가진 스킬을 강화할 때 설명 (없으면 desc 사용)
##   max_level   최대 레벨. 도달하면 선택지에서 빠집니다.
##   category    "common"(공통) / "civil"(문관) / "military"(무관)
##   requires    선행 조건. 예: {"bow": 2} = 궁술 2레벨 이상이어야 등장
##   weapon      이 강화가 다루는 무기 id (scripts/weapons/ 폴더)
##   new_weapon  true면 1레벨을 고를 때 새 공격 스킬을 얻습니다 (최대 MAX_WEAPONS개)
##   evolve      하드 모드 무기 진화: {"from": 바뀌기 전 무기, "to": 새 무기, "banner": 알림 문구}
##
## 새 강화를 추가하려면 여기에 항목을 넣고, 공통 강화라면 player.gd의 apply_upgrade()에 효과를 적습니다.

const MAX_WEAPONS := 4   # 가질 수 있는 공격 스킬 최대 개수

const UPGRADES := {
	# ===== 공통 =====
	"damage": {
		"name": "진한 먹 (공격력)",
		"desc": "모든 공격 피해 +20%",
		"max_level": 5,
		"category": "common",
	},
	"attack_speed": {
		"name": "빠른 손놀림 (공격 속도)",
		"desc": "모든 공격 간격 -10%",
		"max_level": 5,
		"category": "common",
	},
	"move_speed": {
		"name": "가벼운 짚신 (이동 속도)",
		"desc": "이동 속도 +10%",
		"max_level": 5,
		"category": "common",
	},
	"max_hp": {
		"name": "인삼 보약 (최대 체력)",
		"desc": "최대 체력 +20, 체력 20 회복",
		"max_level": 5,
		"category": "common",
	},
	"pickup": {
		"name": "자석 엽전 (획득 범위)",
		"desc": "경험치 획득 범위 +30%",
		"max_level": 5,
		"category": "common",
	},
	# 한 판에 한 번 쓰는 비장의 수. 얻은 뒤 원하는 때 SPACE로 사용 (main.gd의 use_amhaeng)
	"amhaeng": {
		"name": "마패 (암행어사 출두)",
		"desc": "SPACE로 한 번 사용: 모든 일반 적 처치, 두목·보스에게 큰 피해",
		"max_level": 1,
		"category": "common",
	},

	# ===== 문관: 발명품과 설치 장치 =====
	"hwacha_up": {
		"name": "소형 화차 개량",
		"desc": "화차 화살 +1발, 피해 +15%",
		"max_level": 4,
		"category": "civil",
		"weapon": "hwacha",
	},
	"crossbow": {
		"name": "자동 쇠뇌",
		"desc": "[설치] 주변 적을 자동으로 쏘는 쇠뇌를 설치 (최대 1대, 8초 유지)",
		"desc_up": "유지 시간·피해 증가, 2·4레벨에 최대 설치 수 +1",
		"max_level": 5,
		"category": "civil",
		"weapon": "crossbow",
		"new_weapon": true,
	},
	"bomb": {
		"name": "화약탄",
		"desc": "적이 모인 곳에 화약탄을 던져 폭발 피해",
		"desc_up": "폭발 범위·피해 증가, 3·5레벨에 던지는 수 +1",
		"max_level": 5,
		"category": "civil",
		"weapon": "bomb",
		"new_weapon": true,
		"requires": {"hwacha_up": 1},
	},
	"kite": {
		"name": "기계 연",
		"desc": "주인공 주변을 도는 방패연이 닿은 적에게 피해",
		"desc_up": "피해 증가, 2·4레벨에 연 +1",
		"max_level": 5,
		"category": "civil",
		"weapon": "kite",
		"new_weapon": true,
		"requires": {"crossbow": 2},
	},

	# ===== 무관: 칼과 활 =====
	"sword_up": {
		"name": "검술 수련",
		"desc": "검술 피해 +25%, 베기 범위 +10%",
		"max_level": 4,
		"category": "military",
		"weapon": "sword",
	},
	"bow": {
		"name": "궁술",
		"desc": "가까운 적에게 관통 화살 발사 (적 2명 관통)",
		"desc_up": "피해·관통 수 증가, 3레벨부터 화살 2발",
		"max_level": 5,
		"category": "military",
		"weapon": "bow",
		"new_weapon": true,
	},
	"spin": {
		"name": "회전 베기",
		"desc": "몸을 돌려 주변 모든 적을 원형으로 베기",
		"desc_up": "피해·범위 증가, 공격 간격 감소",
		"max_level": 5,
		"category": "military",
		"weapon": "spin",
		"new_weapon": true,
		"requires": {"sword_up": 2},
	},
	"rapid": {
		"name": "연속 사격",
		"desc": "화살 여러 발을 빠르게 연사",
		"desc_up": "화살 수 +1, 피해 +15%",
		"max_level": 5,
		"category": "military",
		"weapon": "rapid",
		"new_weapon": true,
		"requires": {"bow": 2},
	},

	# ===== 무기 진화 (하드 모드 전용) =====
	# requires 의 두 스킬을 모두 최대 레벨로 올리면 레벨업 선택지 맨 앞에 나옵니다.
	# 고르면 evolve.from 무기가 evolve.to 무기로 바뀝니다. (공격 스킬 개수는 그대로)
	"musket": {
		"name": "조총 (진화)",
		"desc": "궁술이 조총으로 진화: 한 발에 적 여럿을 꿰뚫는 강력한 탄환을 3연발",
		"max_level": 1,
		"category": "military",
		"requires": {"sword_up": 4, "bow": 5},
		"evolve": {"from": "bow", "to": "musket", "banner": "활이 조총으로 바뀌었습니다!"},
	},
	"singijeon": {
		"name": "신기전 (진화)",
		"desc": "소형 화차가 신기전으로 진화: 터지는 로켓 화살을 부채꼴로 한꺼번에 발사",
		"max_level": 1,
		"category": "civil",
		"requires": {"hwacha_up": 4, "crossbow": 5},
		"evolve": {"from": "hwacha", "to": "singijeon", "banner": "화차가 신기전으로 바뀌었습니다!"},
	},
	"thunder": {
		"name": "뇌전부 (진화)",
		"desc": "화약탄이 벼락으로 진화: 하늘에서 벼락이 내리쳐 여러 적과 주변을 함께 태움",
		"max_level": 1,
		"category": "civil",
		"requires": {"bomb": 5, "kite": 5},
		"evolve": {"from": "bomb", "to": "thunder", "banner": "화약탄이 벼락으로 바뀌었습니다!"},
	},
}

# 모든 강화가 최대 레벨일 때 대신 나오는 선택지
const HEAL := {
	"name": "주먹밥 (회복)",
	"desc": "체력 30 회복",
	"category": "common",
}

const CATEGORY_NAMES := {"common": "공통", "civil": "문관", "military": "무관"}


## 지금 고를 수 있는 강화 id를 최대 count개 무작위로 돌려줍니다. 다음은 제외됩니다:
##  - 다른 직업의 강화 (job이 ""인 선비는 공통 강화만)
##  - 최대 레벨에 도달한 강화
##  - 선행 조건을 채우지 못한 강화
##  - 공격 스킬이 이미 MAX_WEAPONS개일 때의 새 공격 스킬
##  - 무기 진화 (evolve_on 이 false = 하드 모드가 아닐 때)
## 진화할 수 있는 무기가 있으면 그 선택지를 맨 앞에 보여줍니다.
static func pick_options(levels: Dictionary, count: int, job: String, weapon_count: int, evolve_on := false) -> Array:
	var evolutions: Array = []
	var pool: Array = []
	for id in UPGRADES:
		if not is_available(id, levels, job, weapon_count, evolve_on):
			continue
		if UPGRADES[id].has("evolve"):
			evolutions.append(id)
		else:
			pool.append(id)
	pool.shuffle()
	var result: Array = (evolutions + pool).slice(0, count)
	if result.is_empty():
		result.append("heal")
	return result


static func is_available(id: String, levels: Dictionary, job: String, weapon_count: int, evolve_on := false) -> bool:
	var data: Dictionary = UPGRADES[id]
	var cur: int = levels.get(id, 0)
	if data.has("evolve") and not evolve_on:
		return false
	if data["category"] != "common" and data["category"] != job:
		return false
	if cur >= data["max_level"]:
		return false
	var requires: Dictionary = data.get("requires", {})
	for req_id in requires:
		if levels.get(req_id, 0) < requires[req_id]:
			return false
	if data.get("new_weapon", false) and cur == 0 and weapon_count >= MAX_WEAPONS:
		return false
	return true


static func get_info(id: String) -> Dictionary:
	if id == "heal":
		return HEAL
	return UPGRADES[id]
