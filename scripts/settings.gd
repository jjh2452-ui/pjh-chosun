extends RefCounted
## 게임 설정: 난이도와 전체화면. 다음에 켜도 기억하도록 user://settings.cfg 에 저장합니다.
## (엽전·영구 강화는 meta.gd 의 save.cfg 에 따로 저장)

const SAVE_PATH := "user://settings.cfg"

# 난이도별 숫자. 1.0 = 노말 기준
#   enemy_hp      적 체력 배율
#   enemy_damage  적에게 맞는 피해 배율
#   spawn         적이 나오는 간격 배율 (클수록 적이 드물게 나옴)
#   xp            경험치 배율
#   coins         판이 끝날 때 받는 엽전 배율
#   evolve        무기 진화 (두 스킬을 최대로 올리면 새 무기) 가능 여부
#   player_defense / player_damage / player_move   주인공 방어력·공격력·이동 속도 배율
# 이지 = 처음 만들었던 기본 수치. 노말은 주인공이 약해지고, 하드는 거기에 적까지 강해집니다.
const DIFFICULTIES := {
	"easy": {"name": "이지", "desc": "처음 만든 기본 수치. 처음 해 보는 분께",
		"enemy_hp": 1.0, "enemy_damage": 1.0, "spawn": 1.0, "xp": 1.0, "coins": 1.0, "evolve": false,
		"player_defense": 1.0, "player_damage": 1.0, "player_move": 1.0,
		"color": Color(0.25, 0.55, 0.3)},
	"normal": {"name": "노말", "desc": "주인공 방어력 -40% · 공격력 -15% · 이동 속도 -10%, 엽전 1.2배",
		"enemy_hp": 1.0, "enemy_damage": 1.0, "spawn": 1.0, "xp": 1.0, "coins": 1.2, "evolve": false,
		"player_defense": 0.6, "player_damage": 0.85, "player_move": 0.9,
		"color": Color(0.2, 0.35, 0.65)},
	"hard": {"name": "하드", "desc": "노말보다 적이 강하고 많습니다. 대신 엽전 1.6배 + 무기 진화!",
		"enemy_hp": 1.5, "enemy_damage": 1.35, "spawn": 0.8, "xp": 1.0, "coins": 1.6, "evolve": true,
		"player_defense": 0.6, "player_damage": 0.85, "player_move": 0.9,
		"color": Color(0.62, 0.12, 0.08)},
}
const ORDER := ["easy", "normal", "hard"]

static var difficulty := "normal"
static var fullscreen := true    # 처음 켤 때는 전체화면 (F11로 창 모드)
static var _loaded := false


static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	difficulty = cfg.get_value("settings", "difficulty", "normal")
	if not DIFFICULTIES.has(difficulty):
		difficulty = "normal"
	fullscreen = cfg.get_value("settings", "fullscreen", true)


static func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


## 지금 난이도의 숫자 하나. 예) value("enemy_hp")
static func value(key: String):
	load_data()
	return DIFFICULTIES[difficulty][key]


static func set_difficulty(id: String) -> void:
	load_data()
	difficulty = id
	save_data()


## 저장된 창 모드를 적용합니다 (게임을 켤 때 한 번)
static func apply_window() -> void:
	load_data()
	_set_window(fullscreen)


## 전체화면 ↔ 창 모드 전환 (F11 / Alt+Enter)
static func toggle_fullscreen() -> void:
	load_data()
	fullscreen = not fullscreen
	_set_window(fullscreen)
	save_data()


## 에디터 안(Game 탭)에 끼워져 실행 중이면 창 크기를 바꿀 수 없음
## → 에디터 Game 탭의 ⋮ 메뉴에서 'Embed Game on Next Play'를 끄면 따로 된 창으로 실행됨
static func is_embedded() -> bool:
	return Engine.is_embedded_in_editor()


static func _set_window(full: bool) -> void:
	if DisplayServer.get_name() == "headless" or is_embedded():
		return
	if full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)   # 테두리 없는 전체화면
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
