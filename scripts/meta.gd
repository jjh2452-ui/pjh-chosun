extends RefCounted
## 회차를 넘어 남는 성장: 엽전(특수 재화)과 영구 강화.
## user://save.cfg 파일에 저장됩니다. (Windows: %APPDATA%\Godot\app_userdata\VIBE COGING\save.cfg)
## 처음부터 다시 하고 싶으면 그 파일을 지우면 됩니다.

const SAVE_PATH := "user://save.cfg"

# 영구 강화 목록. 숫자를 바꾸면 효과·최대 레벨이 바뀝니다. (효과 적용은 player.gd의 _ready)
const UPGRADES := {
	"hp": {"name": "기력 단련", "desc": "최대 체력 +10", "max": 10},
	"speed": {"name": "날랜 걸음", "desc": "이동 속도 +5%", "max": 10},
	"damage": {"name": "무예·학문 정진", "desc": "모든 무기 피해 +8%", "max": 10},
}

static var coins := 0
static var levels := {"hp": 0, "speed": 0, "damage": 0}
static var _loaded := false


static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return   # 저장 파일이 없으면 처음 시작
	coins = cfg.get_value("meta", "coins", 0)
	for id in UPGRADES:
		levels[id] = cfg.get_value("meta", id, 0)


static func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "coins", coins)
	for id in UPGRADES:
		cfg.set_value("meta", id, levels[id])
	cfg.save(SAVE_PATH)


## 다음 레벨 가격: 30, 55, 80, ... (레벨마다 25씩 비싸짐)
static func cost(id: String) -> int:
	load_data()
	return 30 + levels[id] * 25


static func is_max(id: String) -> bool:
	load_data()
	return levels[id] >= UPGRADES[id]["max"]


## 엽전이 충분하면 사고 true, 아니면 false
static func buy(id: String) -> bool:
	load_data()
	if is_max(id) or coins < cost(id):
		return false
	coins -= cost(id)
	levels[id] += 1
	save_data()
	return true


static func add_coins(amount: int) -> void:
	load_data()
	coins += amount
	save_data()


# ----- 플레이어에게 주는 효과 -----

static func hp_bonus() -> float:
	load_data()
	return 10.0 * levels["hp"]


static func speed_mult() -> float:
	load_data()
	return 1.0 + 0.05 * levels["speed"]


static func damage_mult() -> float:
	load_data()
	return 1.0 + 0.08 * levels["damage"]
