extends Node2D
## 게임 전체를 관리합니다: 적 생성과 시간표, 경험치와 레벨업, 타격감(소리·효과·흔들림),
## 승리·게임 오버와 재시작.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const XpOrbScript = preload("res://scripts/xp_orb.gd")
const GroundScript = preload("res://scripts/ground.gd")
const HudScript = preload("res://scripts/hud.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const FxScript = preload("res://scripts/fx.gd")
const UpgradeData = preload("res://scripts/upgrade_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const Meta = preload("res://scripts/meta.gd")
const Settings = preload("res://scripts/settings.gd")

# ===== 난이도 조절용 숫자 =====
# 이지·노말·하드에 따른 배율은 settings.gd 의 DIFFICULTIES 에 있습니다.
const SPAWN_DISTANCE := 750.0        # 플레이어로부터 이 거리(화면 밖)에서 적이 나타남
const MAX_ENEMIES := 300             # 평소 등장으로 채우는 최대 적 수
const HARD_MAX_ENEMIES := 400        # 좀비 무리·소환까지 합친 절대 최대 수
const START_SPAWN_INTERVAL := 1.2    # 시작할 때 적이 나오는 간격(초)
const MIN_SPAWN_INTERVAL := 0.3      # 가장 빨라졌을 때의 간격(초)
const FOOD_HEAL := 30.0              # 주먹밥 회복량
const BRUTE_FOOD_CHANCE := 0.04      # 힘센 산적이 주먹밥을 떨어뜨릴 확률 (두목은 항상)

# ===== 시간표 (초 단위. 60 = 1분) =====
const HORDE_FIRST := 120.0           # 좀비 무리 첫 등장
const HORDE_INTERVAL := 25.0         # 좀비 무리 간격
const ELITE_FIRST := 180.0           # 산적 두목 첫 등장
const ELITE_INTERVAL := 90.0         # 산적 두목 등장 간격
const GHOST_FIRST := 300.0           # 귀신 첫 등장 (5분)
const BOSS_TIME := 480.0             # 최종 보스 등장 (8분)
const GAME_LENGTH := 600.0           # 한 판 길이 (10분). 이때까지 보스를 못 잡으면 게임 종료
const DEBUG_START_TIME := 0.0        # 테스트용: 이 시간(초)부터 시작. 예) 470 → 보스 직전부터

# ===== 타격감 =====
const SHOW_DAMAGE_NUMBERS := true    # 피해 숫자 표시
const SCREEN_SHAKE := 1.0            # 화면 흔들림 세기 (0 = 끄기)
const MAX_FX := 220                  # 동시에 보이는 효과 최대 수 (많으면 느려짐)

# 이 시간이 되면 화면에 알림 문구를 띄웁니다
const ANNOUNCEMENTS := [
	[60.0, "힘센 산적이 나타나기 시작합니다"],
	[120.0, "좀비 무리가 몰려옵니다!"],
	[180.0, "산적 두목 출현! 붉은 원이 차오르면 밖으로 피하세요"],
	[240.0, "호랑이 출몰! 노란 선이 보이면 옆으로 피하세요"],
	[GHOST_FIRST, "귀신이 나타났다! 다른 적 사이를 뚫고 일렁이며 다가옵니다"],
	[BOSS_TIME, "도깨비 대왕이 나타났다! 10:00 전에 처치하면 승리!"],
	[GAME_LENGTH - 30.0, "30초 남았습니다!"],
]

static var skip_title := false   # 재시작할 때는 타이틀 화면을 건너뜀
static var window_applied := false   # 저장된 전체화면 설정은 게임을 켤 때 한 번만 적용

var player
var hud
var sfx
var camera: Camera2D
var orb_layer: Node2D      # 그리는 순서: 바닥 → 구슬 → 설치물 → 적 → 플레이어 → 탄환 → 효과
var device_layer: Node2D   # 자동 쇠뇌 같은 설치물
var enemy_layer: Node2D
var bullet_layer: Node2D
var fx_layer: Node2D

var elapsed := 0.0         # 생존 시간(초)
var spawn_timer := 0.0
var level := 1
var xp := 0
var kills := 0
var pending_level_ups := 0
var is_game_over := false

var next_horde_time := HORDE_FIRST
var next_elite_time := ELITE_FIRST
var horde_count := 0
var announce_index := 0
var boss = null            # 등장한 보스 (HUD 체력바용)

var chiefs_killed := 0     # 엽전 계산용
var coins_earned := 0      # 이번 판에 번 엽전 (결과 화면 표시용)

var shake := 0.0           # 화면 흔들림 (0~1)
var pickup_combo := 0      # 구슬을 연속으로 주우면 소리가 점점 높아짐
var last_pickup_time := 0.0


func _ready() -> void:
	_setup_input()
	if not window_applied:
		window_applied = true
		Settings.apply_window()
	elapsed = DEBUG_START_TIME
	while next_horde_time < elapsed:
		next_horde_time += HORDE_INTERVAL
	while next_elite_time < elapsed:
		next_elite_time += ELITE_INTERVAL
	while announce_index < ANNOUNCEMENTS.size() - 1 and ANNOUNCEMENTS[announce_index][0] < elapsed:
		announce_index += 1

	sfx = SfxScript.new()
	add_child(sfx)

	var ground = GroundScript.new()
	add_child(ground)
	orb_layer = Node2D.new()
	add_child(orb_layer)
	device_layer = Node2D.new()
	add_child(device_layer)
	enemy_layer = Node2D.new()
	enemy_layer.y_sort_enabled = true   # 아래쪽(앞쪽)에 있는 적이 위에 그려지도록
	add_child(enemy_layer)

	player = PlayerScript.new()
	player.main = self
	player.died.connect(_on_player_died)
	add_child(player)
	ground.target = player

	camera = Camera2D.new()
	player.add_child(camera)

	bullet_layer = Node2D.new()
	add_child(bullet_layer)
	fx_layer = Node2D.new()
	add_child(fx_layer)

	hud = HudScript.new()
	hud.main = self
	add_child(hud)

	if not skip_title:
		get_tree().paused = true
		hud.show_title()
	_bake_enemy_art()


## 적 그림 굽기: 적 종류·자세(다리 3장면, 무기 치켜듦)마다 한 번씩 그려서 이미지로 저장합니다.
## 이후 적들은 이 이미지를 붙여 보여주기만 하므로 수백 마리여도 가볍습니다.
## (한 번 구우면 재시작해도 다시 굽지 않음)
func _bake_enemy_art() -> void:
	if not EnemyScript.baked.is_empty():
		return
	var cell := Vector2i(320, 320)
	var jobs: Array = []   # [이름, 종류, 다리, 치켜듦]
	for t in EnemyScript.DRAW_SCALE:
		var poses := [false, true] if (t == "chief" or t == "boss") else [false]
		for raised in poses:
			for swing in [-1.0, 0.0, 1.0]:
				jobs.append([EnemyScript.bake_key_of(t, swing, raised), t, swing, raised])
	var cols := 8
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(cols * cell.x, int(ceil(jobs.size() / float(cols))) * cell.y)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(vp)
	for i in jobs.size():
		var e = EnemyScript.new()
		e.setup(jobs[i][1], 0.0)
		e.baking = true
		e.bake_swing = jobs[i][2]
		e.bake_raised = jobs[i][3]
		e.position = Vector2((i % cols) * cell.x, (i / cols) * cell.y) + EnemyScript.BAKE_ANCHOR
		vp.add_child(e)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		for i in jobs.size():
			var region := Rect2i(Vector2i((i % cols) * cell.x, (i / cols) * cell.y), cell)
			EnemyScript.baked[jobs[i][0]] = ImageTexture.create_from_image(img.get_region(region))
	vp.queue_free()


## 타이틀 화면에서 아무 키나 누르면 hud.gd가 호출합니다.
func start_game() -> void:
	skip_title = true
	player.apply_meta()   # 타이틀 상점에서 방금 산 강화 반영
	get_tree().paused = false


## WASD와 방향키를 이동 키로 등록합니다.
func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	_update_shake(delta)
	if is_game_over:
		return
	elapsed += delta
	if elapsed >= GAME_LENGTH:
		elapsed = GAME_LENGTH
		_end_game("timeout")   # 10분이 되면 끝
		return
	_update_spawning(delta)
	_update_events()


## 평소 등장: 시간이 지날수록 더 자주, 더 많이, 더 다양한 적이 나옵니다.
func _update_spawning(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var minutes := elapsed / 60.0
	spawn_timer = max(MIN_SPAWN_INTERVAL, START_SPAWN_INTERVAL - minutes * 0.15) * Settings.value("spawn")
	var count := 1 + int(minutes / 2.0)
	if boss != null:
		count = max(1, count / 2)   # 보스전에는 잡몹을 줄여서 보스에 집중
	for i in count:
		if enemy_layer.get_child_count() >= MAX_ENEMIES:
			return
		var angle := randf() * TAU
		spawn_enemy_at(_pick_type(minutes), player.global_position + Vector2.RIGHT.rotated(angle) * SPAWN_DISTANCE)


## 시간대별로 나올 수 있는 적과 그 비율(가중치). 숫자가 클수록 자주 나옵니다.
func _pick_type(minutes: float) -> String:
	var weights := {"bandit": 10}
	if minutes >= 1.0:
		weights["brute"] = 2
	if minutes >= 4.0:
		weights["tiger"] = 2
	if elapsed >= GHOST_FIRST:
		weights["ghost"] = 3
	if minutes >= 6.0:
		weights["brute"] = 4
		weights["tiger"] = 3
	var total := 0
	for t in weights:
		total += weights[t]
	var roll := randi() % total
	for t in weights:
		roll -= weights[t]
		if roll < 0:
			return t
	return "bandit"


## 정해진 시각에 일어나는 일: 알림, 좀비 무리, 산적 두목, 최종 보스
func _update_events() -> void:
	if announce_index < ANNOUNCEMENTS.size() and elapsed >= ANNOUNCEMENTS[announce_index][0]:
		hud.show_banner(ANNOUNCEMENTS[announce_index][1])
		announce_index += 1
	if elapsed >= next_horde_time:
		next_horde_time += HORDE_INTERVAL
		_spawn_horde()
	if elapsed >= next_elite_time and boss == null:
		next_elite_time += ELITE_INTERVAL
		var angle := randf() * TAU
		spawn_enemy_at("chief", player.global_position + Vector2.RIGHT.rotated(angle) * SPAWN_DISTANCE)
		sfx.play("warn", 0.6)
		if elapsed > ELITE_FIRST + 1.0:
			hud.show_banner("산적 두목이 다시 나타났다!")
	if elapsed >= BOSS_TIME and boss == null and not is_game_over:
		boss = spawn_enemy_at("boss", player.global_position + Vector2(0, -SPAWN_DISTANCE * 0.8))
		sfx.play("gong")
		add_shake(0.6)


## 좀비 무리: 홀수 번째는 사방을 둘러싸는 원, 짝수 번째는 한쪽에서 몰려오는 벽
func _spawn_horde() -> void:
	horde_count += 1
	var minutes := elapsed / 60.0
	var n := 8 + int(minutes * 2.0)
	var dist := SPAWN_DISTANCE * 0.85
	var side := randf() * TAU
	for i in n:
		var angle: float
		if horde_count % 2 == 1:
			angle = TAU * i / n
		else:
			angle = side + (float(i) / n - 0.5) * 1.4
		spawn_enemy_at("zombie", player.global_position + Vector2.RIGHT.rotated(angle) * dist)


## 원하는 종류의 적을 원하는 위치에 만듭니다. (보스의 좀비 소환도 이 함수를 씁니다)
## 적이 너무 많으면(HARD_MAX_ENEMIES) 보스와 두목 말고는 만들지 않습니다. → 게임이 느려지는 것 방지
func spawn_enemy_at(type: String, pos: Vector2):
	if type != "boss" and type != "chief" and enemy_layer.get_child_count() >= HARD_MAX_ENEMIES:
		return null
	var enemy = EnemyScript.new()
	enemy.main = self
	enemy.target = player
	enemy.setup(type, elapsed / 60.0)
	# 난이도: 적 체력과 적에게 맞는 피해
	var hp_mult: float = Settings.value("enemy_hp")
	var dmg_mult: float = Settings.value("enemy_damage")
	enemy.max_hp *= hp_mult
	enemy.hp = enemy.max_hp
	enemy.contact_damage *= dmg_mult
	enemy.slam_damage *= dmg_mult
	enemy.dash_damage *= dmg_mult
	enemy.position = pos
	enemy_layer.add_child.call_deferred(enemy)
	return enemy


# ===== 타격감: 소리, 효과, 화면 흔들림 =====

## 적이 맞을 때마다 enemy.gd가 호출합니다.
func on_enemy_hit(enemy, amount: float) -> void:
	sfx.play("hit")
	if SHOW_DAMAGE_NUMBERS:
		var big := amount >= 40.0
		spawn_fx("number", enemy.global_position + Vector2(randf_range(-8, 8), -enemy.radius),
			Color(1.0, 0.85, 0.3) if big else Color.WHITE, 22.0 if big else 16.0, str(int(round(amount))))
	spawn_fx("spark", enemy.global_position, Color(1.0, 0.95, 0.7), enemy.radius + 6.0)


## 적이 죽으면 enemy.gd가 호출합니다. 먹물이 번지고, 경험치 구슬(가끔 주먹밥)을 떨어뜨립니다.
func on_enemy_killed(enemy) -> void:
	kills += 1
	spawn_fx("burst", enemy.global_position, Color(0.08, 0.06, 0.06), enemy.radius * 1.3, "", true)
	sfx.play("pop", 1.4 - minf(enemy.radius, 44.0) / 60.0)
	if enemy == boss:
		add_shake(1.0)
		_end_game("victory")
		return
	if enemy.type == "chief":
		chiefs_killed += 1
		add_shake(0.4)
	_drop(enemy.global_position, "xp", enemy.xp_value)
	if enemy.type == "chief" or (enemy.type == "brute" and randf() < BRUTE_FOOD_CHANCE):
		_drop(enemy.global_position + Vector2(20, 0), "food", 0)


func _drop(pos: Vector2, kind: String, value: int) -> void:
	var orb = XpOrbScript.new()
	orb.main = self
	orb.kind = kind
	orb.value = value
	orb.position = pos
	orb_layer.add_child.call_deferred(orb)


## 암행어사 출두! (마패가 있을 때 SPACE를 누르면 hud.gd가 호출)
## 일반 적은 모두 쓰러지고, 산적 두목은 최대 체력의 35%, 도깨비 대왕은 12% 피해를 입습니다.
const AMHAENG_CHIEF_RATIO := 0.35
const AMHAENG_BOSS_RATIO := 0.12

func use_amhaeng() -> void:
	if not player.has_mapae or is_game_over:
		return
	player.has_mapae = false
	hud.show_amhaeng()
	sfx.play("gong")
	sfx.play("boom", 0.6)
	add_shake(1.0)
	spawn_fx("ring", player.global_position, Color(1.0, 0.85, 0.3), 700.0, "", true)
	for enemy in enemy_layer.get_children():
		if enemy.is_dead:
			continue
		match enemy.type:
			"boss":
				enemy.take_damage(enemy.max_hp * AMHAENG_BOSS_RATIO)
			"chief":
				enemy.take_damage(enemy.max_hp * AMHAENG_CHIEF_RATIO)
			_:
				enemy.take_damage(enemy.hp + 1.0)


## 플레이어가 맞으면 player.gd가 호출합니다.
func on_player_hurt(amount: float) -> void:
	sfx.play("hurt")
	add_shake(0.25 + amount / 60.0)
	hud.flash_hurt()
	spawn_fx("number", player.global_position + Vector2(0, -24), Color(1.0, 0.35, 0.3), 20.0, "-%d" % int(amount))


## 주먹밥을 먹으면 xp_orb.gd가 호출합니다.
func heal_player(amount: float) -> void:
	player.hp = minf(player.max_hp, player.hp + amount)
	sfx.play("heal")
	spawn_fx("number", player.global_position + Vector2(0, -24), Color(0.5, 1.0, 0.5), 20.0, "+%d" % int(amount))
	spawn_fx("ring", player.global_position, Color(0.5, 1.0, 0.5), 60.0)


## 효과를 하나 만듭니다. important가 true면 효과가 많아도 무조건 만듭니다.
func spawn_fx(kind: String, pos: Vector2, color: Color, size: float, text := "", important := false) -> void:
	if not important and fx_layer.get_child_count() >= MAX_FX:
		return
	var fx = FxScript.new()
	fx.setup(kind, color, size, text)
	fx.position = pos
	fx_layer.add_child(fx)


## 화면을 흔듭니다. amount: 0.1(살짝) ~ 1.0(크게)
func add_shake(amount: float) -> void:
	shake = minf(1.0, shake + amount * SCREEN_SHAKE)


func _update_shake(delta: float) -> void:
	if shake <= 0.0:
		return
	shake = maxf(0.0, shake - delta * 2.0)
	var strength := shake * shake * 14.0
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength


# ===== 경험치와 레벨업 =====

## 다음 레벨까지 필요한 경험치. 초반엔 빨리 오르고, 레벨이 높을수록 점점 더 많이 필요합니다.
## (예: 1→2 = 5, 10→11 = 36, 20→21 = 83)
func xp_to_next() -> int:
	var n := level - 1
	return 5 + n * 3 + int(n * n * 0.06)


func add_xp(amount: int) -> void:
	# 연속으로 주우면 소리가 조금씩 높아짐
	var now := Time.get_ticks_msec() / 1000.0
	pickup_combo = pickup_combo + 1 if now - last_pickup_time < 0.4 else 0
	last_pickup_time = now
	sfx.play("pickup", 1.0 + minf(pickup_combo, 15) * 0.05)

	# 난이도 경험치 배율 (예: 1.2배면 1짜리 구슬이 다섯 번에 한 번꼴로 2)
	var gained: float = amount * Settings.value("xp")
	xp += int(gained) + (1 if randf() < gained - int(gained) else 0)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending_level_ups += 1
	if pending_level_ups > 0 and not get_tree().paused:
		sfx.play("levelup")
		spawn_fx("ring", player.global_position, Color(1.0, 0.85, 0.3), 120.0, "", true)
		_open_level_up()


func _open_level_up() -> void:
	get_tree().paused = true
	if player.job == "" and level >= JobData.JOB_LEVEL:
		hud.show_job_select()   # 5레벨: 강화 대신 전직 선택
	else:
		hud.show_level_up(UpgradeData.pick_options(player.upgrade_levels, 3, player.job, player.weapons.size(), Settings.value("evolve")))


## 레벨업 창에서 강화를 고르면 hud.gd가 호출합니다.
func choose_upgrade(id: String) -> void:
	player.apply_upgrade(id)
	var info: Dictionary = UpgradeData.get_info(id)
	if info.has("evolve"):   # 무기 진화 연출
		sfx.play("gong", 1.2)
		add_shake(0.5)
		spawn_fx("ring", player.global_position, Color(1.0, 0.85, 0.3), 220.0, "", true)
		spawn_fx("ring", player.global_position, Color.WHITE, 130.0, "", true)
		hud.show_banner("무기 진화! %s" % info["evolve"]["banner"], 4.0)
	_finish_choice()


## 전직 창에서 직업을 고르면 hud.gd가 호출합니다.
func choose_job(job_id: String) -> void:
	player.change_job(job_id)
	sfx.play("gong", 1.5)
	# 전직 연출: 직업 색 고리 두 겹 + 알림
	var color: Color = JobData.JOBS[job_id]["color"].lightened(0.3)
	spawn_fx("ring", player.global_position, color, 160.0, "", true)
	spawn_fx("ring", player.global_position, Color.WHITE, 90.0, "", true)
	var looks := {"civil": "푸른 도포를 입은 문관", "military": "갑옷을 두른 장군"}
	hud.show_banner("전직! 이제 %s입니다" % looks[job_id], 3.0)
	_finish_choice()


func _finish_choice() -> void:
	pending_level_ups -= 1
	hud.hide_choice()
	if pending_level_ups > 0:
		_open_level_up()   # 한 번에 여러 레벨이 올랐으면 연달아 선택
	else:
		get_tree().paused = false


# ===== 게임 오버와 재시작 =====

func _on_player_died() -> void:
	_end_game("defeat")


## 한 판을 끝냅니다. result: "victory"(보스 처치) / "defeat"(사망) / "timeout"(10분 경과)
func _end_game(result: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	get_tree().paused = true
	coins_earned = calc_coins(result == "victory")
	Meta.add_coins(coins_earned)
	sfx.play("victory" if result == "victory" else "defeat")
	hud.show_game_over(result)


## 이번 판의 엽전: 처치 15마리당 1, 생존 1분당 5, 두목 1명당 10, 승리 보너스 100
## 여기에 난이도 배율(이지 0.6 / 노말 1 / 하드 1.6)을 곱합니다.
func calc_coins(victory: bool) -> int:
	var total := kills / 15 + int(elapsed / 60.0) * 5 + chiefs_killed * 10
	if victory:
		total += 100
	return int(round(total * Settings.value("coins")))


## 바로 다시 하기 (타이틀 화면 건너뜀)
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## 타이틀(상점) 화면으로
func restart_to_title() -> void:
	skip_title = false
	restart()
