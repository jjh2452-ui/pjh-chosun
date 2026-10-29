extends Node2D
## 주인공 선비. 키보드로 이동하고, 가진 무기들이 자동으로 공격합니다.
## 5레벨에 문관/무관으로 전직하면 기본 무기(먹물 탄환)가 직업 무기로 바뀝니다.

signal died

const JobData = preload("res://scripts/job_data.gd")
const UpgradeData = preload("res://scripts/upgrade_data.gd")
const Meta = preload("res://scripts/meta.gd")
const Settings = preload("res://scripts/settings.gd")

# 무기 id → 무기 스크립트. 새 무기를 만들면 여기에 한 줄 추가합니다.
const WEAPON_SCRIPTS := {
	"ink_brush": preload("res://scripts/weapons/ink_brush.gd"),
	"hwacha": preload("res://scripts/weapons/hwacha.gd"),
	"crossbow": preload("res://scripts/weapons/crossbow.gd"),
	"bomb": preload("res://scripts/weapons/bomb.gd"),
	"kite": preload("res://scripts/weapons/kite.gd"),
	"sword": preload("res://scripts/weapons/sword.gd"),
	"bow": preload("res://scripts/weapons/bow.gd"),
	"spin": preload("res://scripts/weapons/spin.gd"),
	"rapid": preload("res://scripts/weapons/rapid.gd"),
	# 하드 모드 진화 무기
	"musket": preload("res://scripts/weapons/musket.gd"),
	"singijeon": preload("res://scripts/weapons/singijeon.gd"),
	"thunder": preload("res://scripts/weapons/thunder.gd"),
}

# ===== 기본 능력치 (숫자를 바꾸면 바로 반영됩니다) =====
# 기본 체력·방어력·이동력은 직업마다 다릅니다 → job_data.gd
#   선비 45/2/2, 문관 60/4/4, 무관 75/6/3 (체력/방어력/이동력). 엽전 상점 강화로 올라감
const BASE_PICKUP_RANGE := 85.0      # 경험치 구슬을 끌어당기는 거리
const INVINCIBLE_TIME := 0.8         # 맞은 뒤 무적 시간(초). 길수록 연속으로 덜 맞음
# 무기별 피해량과 공격 간격은 scripts/weapons/ 폴더의 각 무기 파일에 있습니다.

# ===== 스프라이트 시트 (sprite-gen으로 만든 아틀라스) =====
# 1024×512 = 가로 4칸 × 세로 2줄, 한 칸 256×256. 첫 줄 idle, 둘째 줄 walk.
# 칸 크기는 이미지 크기 ÷ 칸 수로 계산합니다 (sprite-gen <run>/manifest.json 과 같은 값).
# 직업별 시트: 파일이 있으면 전직할 때 그 시트로 바뀌고, 없으면 직접 그린 모습을 씁니다.
#   문관 = sprite-gen mungwan 런, 장군(무관) = sprite-gen mugwan 런의 sprite-sheet-alpha.png
const JOB_SHEETS := {
	"": "res://assets/imgs/sprite-sheet-alpha.png",          # 선비 (hero)
	"civil": "res://assets/imgs/mungwan-sheet-alpha.png",    # 문관
	"military": "res://assets/imgs/mugwan-sheet-alpha.png",  # 장군
}
const HERO_SHEET_COLUMNS := 4
const HERO_SHEET_ROWS := {"idle": 0, "walk": 1}   # 애니메이션 이름 → 줄 번호
const HERO_FPS := {"idle": 4.0, "walk": 8.0}      # 숨쉬기는 천천히, 걸음은 발 디딤이 보이게
const HERO_SCALE := 0.27            # 256칸 그림(캐릭터 키 약 207px)을 게임 크기(약 56px)로 줄임
const HERO_FEET_Y := 231.0          # 칸 안에서 발끝 높이 (모든 프레임 공통)
const FEET_Y := 16.0                # 플레이어 원점 기준 발이 닿는 높이 (그림자 위치와 맞춤)

var main                 # main.gd (게임 관리자)
var job := ""            # "" = 선비, "civil" = 문관, "military" = 무관
var job_name := "선비"
var radius := 14.0        # 충돌 크기 (그림 크기와는 따로)
var upgrade_levels := {}  # 예: {"damage": 2}
var weapons := {}         # 가진 무기들. 예: {"sword": 검술 노드}

var base_hp := JobData.SEONBI_MAX_HP     # 직업 기본 체력 (전직하면 바뀜)
var base_defense: float = JobData.SEONBI_DEFENSE   # 직업 기본 방어력 (전직하면 바뀜)
var defense := 0.0                       # 실제 방어력 = 기본 × 난이도 배율. 맞을 때 피해에서 이만큼 뺌
var max_hp := base_hp
var hp := base_hp
var move_stat := JobData.SEONBI_MOVE     # 이동력 (전직하면 바뀜)
var speed := 200.0                       # 실제 이동 속도(초당 픽셀). _recalc_speed()가 계산
var pickup_range := BASE_PICKUP_RANGE
var damage_mult := 1.0    # 모든 무기의 피해 배율 (공격력 강화)
var cooldown_mult := 1.0  # 모든 무기의 공격 간격 배율 (공격 속도 강화)
var has_mapae := false    # 암행어사 마패를 가지고 있는지 (SPACE로 한 번 사용)

# 상점에서 산 영구 강화 (회차를 넘어 유지, meta.gd)
var meta_hp := 0.0
var meta_speed := 1.0
var meta_damage := 1.0

var invincible_timer := 0.0

# 그림 움직임
var facing := 1.0         # 1 = 오른쪽을 봄, -1 = 왼쪽을 봄 (그림을 좌우로 뒤집음)
var moving := false
var walk_time := 0.0      # 걷는 동안만 흐르는 시간 (다리·팔 흔들기)
var idle_time := 0.0      # 항상 흐르는 시간 (숨쉬기)
var sprite: AnimatedSprite2D   # 선비 스프라이트 애니메이션 (시트가 없으면 null → 직접 그림)


func _ready() -> void:
	apply_meta()
	_setup_sprite()      # 무기보다 먼저 붙여서 칼 휘두르기 효과가 캐릭터 위에 그려지게
	add_weapon("ink_brush")


## 선비 스프라이트를 준비합니다. 시트가 없으면 sprite 는 null 로 두고 직접 그립니다.
func _setup_sprite() -> void:
	var frames := _load_sheet_frames(JOB_SHEETS[""])
	if frames == null:
		push_warning("스프라이트 시트가 없어 선비를 직접 그립니다: " + JOB_SHEETS[""])
		return
	sprite = AnimatedSprite2D.new()
	sprite.scale = Vector2(HERO_SCALE, HERO_SCALE)
	add_child(sprite)
	_use_frames(frames)


## 시트 한 장을 칸 단위로 잘라 idle·walk 애니메이션(SpriteFrames)을 만듭니다. 파일이 없으면 null.
func _load_sheet_frames(path: String) -> SpriteFrames:
	if not ResourceLoader.exists(path):
		return null
	var sheet: Texture2D = load(path)
	if sheet == null:
		return null
	var cell_w := sheet.get_width() / HERO_SHEET_COLUMNS     # 1024 / 4 = 256
	var cell_h := sheet.get_height() / HERO_SHEET_ROWS.size() # 512 / 2 = 256
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in HERO_SHEET_ROWS:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, HERO_FPS[anim])
		for col in HERO_SHEET_COLUMNS:
			var cell := AtlasTexture.new()
			cell.atlas = sheet
			cell.region = Rect2(col * cell_w, HERO_SHEET_ROWS[anim] * cell_h, cell_w, cell_h)
			frames.add_frame(anim, cell)
	return frames


## 스프라이트에 새 애니메이션 묶음을 붙이고, 발이 그림자 위에 오도록 위치를 맞춥니다.
func _use_frames(frames: SpriteFrames) -> void:
	sprite.sprite_frames = frames
	var cell_h: float = frames.get_frame_texture("idle", 0).get_height()
	# 칸 가운데가 기준점이므로, 칸 안의 발끝(256칸 기준 231)이 플레이어 발 높이(FEET_Y)에 오도록 위로 올림
	var feet_in_cell := HERO_FEET_Y * cell_h / 256.0
	sprite.position = Vector2(0, FEET_Y - (feet_in_cell - cell_h / 2.0) * HERO_SCALE)
	sprite.visible = true
	sprite.play("walk" if moving else "idle")


## 멈춰 있으면 idle, 움직이면 walk. 왼쪽으로 가면 좌우 반전 (원본 그림은 오른쪽을 봄)
func _update_sprite() -> void:
	if sprite == null or not sprite.visible:
		return
	var anim := "walk" if moving else "idle"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = facing < 0.0


## 상점에서 산 영구 강화와 난이도를 적용합니다. (타이틀에서 고르고 시작할 때 main.gd가 다시 호출)
func apply_meta() -> void:
	meta_hp = Meta.hp_bonus()
	meta_speed = Meta.speed_mult()
	meta_damage = Meta.damage_mult()
	_recalc_max_hp()
	hp = max_hp
	_recalc_speed()
	_recalc_defense()
	_recalc_damage()


## 이동 속도 = 이동력으로 정한 기본 속도 × 짚신 강화(레벨당 +10%) × 상점 날랜 걸음 × 난이도
func _recalc_speed() -> void:
	var base := JobData.MOVE_BASE + move_stat * JobData.MOVE_PER_POINT
	speed = base * (1.0 + 0.1 * upgrade_levels.get("move_speed", 0)) * meta_speed * Settings.value("player_move")


## 방어력 = 직업 기본 방어력 × 난이도 (노말·하드는 0.6배)
func _recalc_defense() -> void:
	defense = base_defense * Settings.value("player_defense")


## 공격력 배율 = 기본(0.85) × 진한 먹(레벨당 +20%) × 상점 정진 × 난이도
func _recalc_damage() -> void:
	damage_mult = JobData.BASE_DAMAGE_MULT * (1.0 + 0.2 * upgrade_levels.get("damage", 0)) * meta_damage * Settings.value("player_damage")


## 최대 체력 = 직업 기본 체력 + 인삼 보약(레벨당 20) + 상점 기력 단련
func _recalc_max_hp() -> void:
	max_hp = base_hp + 20.0 * upgrade_levels.get("max_hp", 0) + meta_hp


func _process(delta: float) -> void:
	# 이동 (WASD 또는 방향키)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * speed * delta

	# 걷기 동작: 마지막으로 움직인 좌우 방향을 바라봄
	moving = dir != Vector2.ZERO
	if dir.x > 0.1:
		facing = 1.0
	elif dir.x < -0.1:
		facing = -1.0
	if moving:
		walk_time += delta
	idle_time += delta
	_update_sprite()
	queue_redraw()

	# 무적 시간 동안 깜빡임
	if invincible_timer > 0.0:
		invincible_timer -= delta
		modulate.a = 0.4 if int(invincible_timer * 20) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0


# ===== 무기 =====

func add_weapon(id: String) -> void:
	var weapon = WEAPON_SCRIPTS[id].new()
	weapon.player = self
	weapon.main = main
	weapons[weapon.weapon_id] = weapon
	add_child(weapon)


func remove_weapon(id: String) -> void:
	if weapons.has(id):
		weapons[id].queue_free()
		weapons.erase(id)


## 전직: 먹물 탄환을 버리고 직업 기본 무기를 받습니다. 공통 강화는 그대로 유지됩니다.
## 기본 체력·방어력도 직업 값으로 바뀌고, 늘어난 체력만큼 현재 체력도 채워집니다.
func change_job(job_id: String) -> void:
	job = job_id
	var data: Dictionary = JobData.JOBS[job_id]
	job_name = data["name"]
	var old_max := max_hp
	base_hp = data["max_hp"]
	base_defense = data["defense"]
	move_stat = data["move"]
	_recalc_max_hp()
	_recalc_speed()
	_recalc_defense()
	hp = minf(max_hp, hp + (max_hp - old_max))
	remove_weapon("ink_brush")
	add_weapon(data["start_weapon_id"])
	# 직업 시트가 있으면 그 애니메이션으로 바꾸고, 없으면 문관·장군 모습을 직접 그림
	var job_frames := _load_sheet_frames(JOB_SHEETS.get(job_id, ""))
	if job_frames != null:
		if sprite == null:
			sprite = AnimatedSprite2D.new()
			sprite.scale = Vector2(HERO_SCALE, HERO_SCALE)
			add_child(sprite)
			move_child(sprite, 0)   # 무기 효과보다 아래에 그려지게
		_use_frames(job_frames)
	elif sprite != null:
		sprite.visible = false
	queue_redraw()


## max_range 안에서 가장 가까운 적을 찾습니다. 없으면 null.
func find_nearest_enemy(max_range: float):
	var nearest = null
	var best := max_range * max_range
	for enemy in main.enemy_layer.get_children():
		if enemy.is_dead:
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest


func take_damage(amount: float) -> void:
	if invincible_timer > 0.0 or hp <= 0.0:
		return
	amount = maxf(JobData.MIN_DAMAGE, amount - defense)   # 방어력만큼 덜 아픔
	hp -= amount
	invincible_timer = INVINCIBLE_TIME
	main.on_player_hurt(amount)
	if hp <= 0.0:
		hp = 0.0
		died.emit()


## 레벨업에서 고른 강화를 적용합니다. (설명 문구는 upgrade_data.gd에 있습니다)
func apply_upgrade(id: String) -> void:
	if id == "heal":
		hp = min(max_hp, hp + 30.0)
		return
	upgrade_levels[id] = upgrade_levels.get(id, 0) + 1
	var lv: int = upgrade_levels[id]

	# 직업 스킬: 새 무기를 얻거나, 가진 무기의 레벨을 올립니다.
	var data: Dictionary = UpgradeData.UPGRADES[id]
	# 무기 진화 (하드 모드): 원래 무기를 버리고 진화한 무기를 같은 자리에 받습니다
	if data.has("evolve"):
		remove_weapon(data["evolve"]["from"])
		add_weapon(data["evolve"]["to"])
		return
	if data.has("weapon"):
		var weapon_id: String = data["weapon"]
		if data.get("new_weapon", false):
			if lv == 1:
				add_weapon(weapon_id)
			else:
				weapons[weapon_id].set_level(lv)
		else:
			weapons[weapon_id].set_level(lv + 1)   # 기본 무기는 1레벨에서 시작하므로 +1
		return

	# 공통 강화
	match id:
		"damage":
			_recalc_damage()
		"attack_speed":
			cooldown_mult = pow(0.9, lv)
		"move_speed":
			_recalc_speed()
		"max_hp":
			_recalc_max_hp()
			hp = min(max_hp, hp + 20.0)
		"pickup":
			pickup_range = BASE_PICKUP_RANGE * (1.0 + 0.3 * lv)
		"amhaeng":
			has_mapae = true
	queue_redraw()


# ===== 그리기 =====
# 옆에서 비스듬히 본 2~3등신 민화풍 모습입니다.
# 오른쪽을 보는 기준으로 그리고, 왼쪽을 볼 때는 그림 전체를 좌우로 뒤집습니다.
# 좌표: (0, 0) = 몸 가운데, 아래로 갈수록 y가 커짐. 발끝 y ≈ 14, 머리 가운데 y = -16
#   선비(처음) : 흰 도포 + 갓 + 붓
#   문관       : 푸른 비단 도포 + 뒷자락 + 붉은 세조대 + 갓끈 구슬 + 부채
#   무관(장군) : 붉은 두정갑 + 상모 달린 투구 + 망토 + 환도 (궁술을 얻으면 등에 활)

const OUTLINE := Color(0.18, 0.13, 0.1)   # 민화풍 외곽선
const SKIN := Color(0.97, 0.84, 0.7)
const DRAW_SCALE := 1.2                   # 그림 크기 (장군은 조금 더 크게)
const GENERAL_SCALE := 1.32


func _draw() -> void:
	draw_arc(Vector2.ZERO, pickup_range, 0, TAU, 48, Color(1, 1, 1, 0.1), 1.5)   # 경험치 획득 범위
	_ellipse(Vector2(0, 17), 14.0, 4.5, Color(0, 0, 0, 0.3))                     # 발밑 그림자
	if sprite != null and sprite.visible:
		return   # 선비는 스프라이트 시트 애니메이션이 몸을 그림

	var swing := sin(walk_time * 10.0) if moving else 0.0       # 팔다리 흔들림 (-1 ~ 1)
	var bob := absf(sin(walk_time * 10.0)) * 2.5 if moving else sin(idle_time * 3.0) * 0.6
	var lean := 0.07 if moving else 0.0                           # 걸을 때 앞으로 살짝 기울임
	var s := GENERAL_SCALE if job == "military" else DRAW_SCALE
	draw_set_transform(Vector2(0, -bob), lean * facing, Vector2(facing * s, s))
	match job:
		"civil":
			_draw_civil(swing)
		"military":
			_draw_general(swing)
		_:
			_draw_seonbi(swing)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_seonbi(swing: float) -> void:
	var robe := Color(0.95, 0.93, 0.86)
	_legs(swing, Color(0.9, 0.88, 0.82), Color(0.6, 0.45, 0.25))    # 흰 바지 + 짚신
	var cuff := Color(0.99, 0.99, 0.97)
	_arm(Vector2(-2, -6), -swing, robe.darkened(0.15), false, cuff)  # 뒤쪽 팔
	_robe(robe, 7.5, 10.5, 8.0, true)
	draw_line(Vector2(-7, 0), Vector2(7.5, 0), Color(0.4, 0.5, 0.7), 1.5)   # 소박한 허리끈
	_head(false)
	_gat(false)
	_arm(Vector2(2, -6), swing, robe, false, cuff)                   # 앞쪽 팔
	# 손에 든 붓 (먹물 공격)
	var hand := _hand_pos(Vector2(2, -6), swing)
	draw_line(hand + Vector2(-1, 3), hand + Vector2(4, -7), Color(0.55, 0.35, 0.2), 2.0)
	draw_circle(hand + Vector2(4.5, -8), 1.6, Color(0.05, 0.05, 0.05))


func _draw_civil(swing: float) -> void:
	var robe := Color(0.22, 0.38, 0.64)
	var lining := Color(0.75, 0.85, 0.95)
	var red := Color(0.82, 0.15, 0.15)
	# 도포 뒷자락: 걸으면 뒤로 펄럭임
	var back := PackedVector2Array([Vector2(-6, -4), Vector2(-14 - swing, 11), Vector2(-4, 10)])
	draw_colored_polygon(back, robe.darkened(0.2))
	draw_polyline(_closed(back), OUTLINE, 1.5)
	_legs(swing, Color(0.92, 0.92, 0.9), Color(0.15, 0.15, 0.18))   # 흰 버선 + 검은 신
	_arm(Vector2(-2, -6), -swing, robe.darkened(0.15), true, Color.WHITE)
	_robe(robe, 8.0, 11.5, 10.0, true)
	# 비단 무늬: 옷자락에 옅은 구름무늬 점
	for m in [Vector2(-5, 3), Vector2(1, 6), Vector2(6, 2), Vector2(-2, -3)]:
		draw_arc(m, 1.6, PI, TAU * 0.9, 6, Color(0.6, 0.75, 0.95, 0.5), 1.0)
	draw_line(Vector2(3, -8), Vector2(5.5, 10), lining, 1.5)          # 안감이 비치는 여밈선
	# 붉은 세조대와 늘어진 술
	draw_line(Vector2(-7.5, 0), Vector2(8, 0), red, 2.0)
	draw_line(Vector2(3, 0), Vector2(4 + swing, 9), red, 1.5)
	draw_circle(Vector2(4 + swing, 9), 1.6, red)
	_head(true)
	_gat(true)
	_arm(Vector2(2, -6), swing, robe, true, Color.WHITE)
	# 손에 든 부채
	var hand := _hand_pos(Vector2(2, -6), swing)
	var fan := PackedVector2Array([hand])
	for i in 7:
		fan.append(hand + Vector2.RIGHT.rotated(lerpf(-2.0, -0.5, i / 6.0)) * 9.0)
	draw_colored_polygon(fan, Color(0.98, 0.95, 0.85))
	draw_polyline(fan.slice(1), red, 1.5)


func _draw_general(swing: float) -> void:
	var armor := Color(0.75, 0.16, 0.13)
	var trim := Color(0.15, 0.2, 0.42)
	var gold := Color(0.98, 0.8, 0.3)
	# 망토: 걸으면 뒤로 펄럭임
	var cape := PackedVector2Array([Vector2(-3, -9), Vector2(-15 - swing * 1.5, 12), Vector2(-3, 11)])
	draw_colored_polygon(cape, trim)
	draw_polyline(_closed(cape), OUTLINE, 1.5)
	# 궁술을 얻으면 등에 활
	if weapons.has("bow") or weapons.has("rapid"):
		var bc := Vector2(-5, -2)
		draw_arc(bc, 11.0, PI * 0.6, PI * 1.4, 12, Color(0.5, 0.32, 0.15), 2.5)
		draw_line(bc + Vector2.RIGHT.rotated(PI * 0.6) * 11.0, bc + Vector2.RIGHT.rotated(PI * 1.4) * 11.0, Color(0.9, 0.9, 0.85), 1.0)
	_legs(swing, Color(0.2, 0.2, 0.25), Color(0.08, 0.08, 0.1))     # 검은 목화(장화)
	# 허리에 찬 환도: 몸 뒤쪽으로 비스듬히 (몸통보다 먼저 그려서 칼집 끝만 보이게)
	draw_line(Vector2(-2, 2), Vector2(-16, 7), Color(0.12, 0.1, 0.1), 3.0)
	draw_circle(Vector2(-16, 7), 1.3, gold)
	_arm(Vector2(-2, -6), -swing, armor.darkened(0.2), false)
	# 두정갑: 붉은 갑옷에 금빛 징
	_robe(armor, 9.0, 11.5, 8.5, false)
	draw_line(Vector2(-11.3, 8.5), Vector2(11.3, 8.5), trim, 3.0)     # 아랫단
	draw_line(Vector2(2, -8), Vector2(3, 8.5), trim, 2.0)             # 여밈
	for row in 3:
		for col in 4:
			draw_circle(Vector2(-6 + col * 4 + row * 0.5, -4.5 + row * 4.5), 0.9, gold)
	draw_line(Vector2(-9, 0.5), Vector2(9.5, 0.5), Color(0.1, 0.1, 0.1), 2.5)   # 허리띠
	draw_circle(Vector2(5, 0.5), 1.6, gold)                                      # 띠 장식
	# 어깨 갑옷
	draw_circle(Vector2(1, -7), 4.0, Color(0.3, 0.3, 0.34))
	draw_arc(Vector2(1, -7), 4.0, 0, TAU, 16, OUTLINE, 1.2)
	# 투구 뒤 목가리개 → 얼굴 → 투구
	var c := Vector2(1, -16)
	draw_rect(Rect2(c + Vector2(-8, -2), Vector2(6, 10)), trim)
	_head(false)
	# 팔자 콧수염 + 짧은 턱수염
	draw_line(c + Vector2(2.5, 2.5), c + Vector2(6.5, 3.5), Color(0.1, 0.08, 0.08), 1.6)
	var beard := PackedVector2Array([c + Vector2(1, 4.5), c + Vector2(5, 4.5), c + Vector2(3.5, 8.5)])
	draw_colored_polygon(beard, Color(0.1, 0.08, 0.08))
	draw_line(c + Vector2(1.5, -3.5), c + Vector2(5, -2.2), OUTLINE, 1.6)   # 굵은 눈썹
	_helmet(swing)
	_arm(Vector2(2, -6), swing, armor, false)
	draw_circle(_hand_pos(Vector2(2, -6), swing), 2.4, Color(0.3, 0.3, 0.34))   # 쇠 장갑


# ----- 몸의 부분들 -----

func _legs(swing: float, pants: Color, shoe: Color) -> void:
	var back_x := -2.5 - swing * 3.5
	var front_x := 2.5 + swing * 3.5
	draw_line(Vector2(-1.5, 4), Vector2(back_x, 14), OUTLINE, 5.0)
	draw_line(Vector2(-1.5, 4), Vector2(back_x, 14), pants.darkened(0.2), 3.5)
	_ellipse(Vector2(back_x + 1.5, 15), 3.2, 1.7, shoe.darkened(0.2))
	draw_line(Vector2(1.5, 4), Vector2(front_x, 14), OUTLINE, 5.0)
	draw_line(Vector2(1.5, 4), Vector2(front_x, 14), pants, 3.5)
	_ellipse(Vector2(front_x + 1.5, 15), 3.2, 1.7, shoe)


func _hand_pos(shoulder: Vector2, swing: float) -> Vector2:
	return shoulder + Vector2(swing * 4.0, 11.0)


## 팔: 소매 + 손. wide면 도포처럼 넓은 소매
## cuff: 소맷부리 색 (도포의 흰 거들지). 투명이면 그리지 않음
func _arm(shoulder: Vector2, swing: float, color: Color, wide: bool, cuff := Color(0, 0, 0, 0)) -> void:
	var hand := _hand_pos(shoulder, swing)
	var w := 6.0 if wide else 4.0
	draw_line(shoulder, hand, OUTLINE, w + 2.0)
	draw_line(shoulder, hand, color, w)
	draw_line(shoulder, shoulder.lerp(hand, 0.5), color.darkened(0.12), w * 0.45)   # 소매 주름 그늘
	if cuff.a > 0.0:
		var dir := (hand - shoulder).normalized()
		draw_line(hand - dir * 3.2, hand - dir * 1.0, cuff, w)
	draw_circle(hand, 2.2, SKIN)


## 몸통(도포·갑옷): 어깨에서 아래로 넓어지는 사다리꼴. collar면 흰 동정(깃)
func _robe(color: Color, top_w: float, bottom_w: float, hem_y: float, collar: bool) -> void:
	var pts := PackedVector2Array([Vector2(-top_w + 1, -9), Vector2(top_w, -9), Vector2(bottom_w, hem_y), Vector2(-bottom_w, hem_y)])
	draw_colored_polygon(pts, color)
	_shade(pts, -2.0, 0.09)                                                       # 등 쪽 그늘 (옅게)
	draw_line(Vector2(top_w - 2.0, -7), Vector2(bottom_w - 2.5, hem_y - 2), Color(1, 1, 1, 0.18), 1.5)   # 앞쪽 빛
	draw_polyline(_closed(pts), OUTLINE, 1.5)
	if collar:
		draw_polyline(PackedVector2Array([Vector2(-1, -9), Vector2(3, -4), Vector2(6, -9)]), Color(0.98, 0.98, 0.95), 1.8)


## 얼굴: 눈, 눈썹, 귀. beard면 단정한 염소수염
func _head(beard: bool) -> void:
	var c := Vector2(1, -16)
	draw_circle(c, 6.5, SKIN)
	draw_arc(c, 5.2, PI * 0.55, PI * 1.25, 10, Color(0.1, 0.08, 0.07), 2.6)   # 귀밑머리(뒤통수)
	draw_arc(c, 6.5, 0, TAU, 20, OUTLINE, 1.5)
	draw_circle(c + Vector2(-2.5, 0.5), 1.4, SKIN.darkened(0.15))    # 귀
	draw_circle(c + Vector2(3, -0.5), 1.0, OUTLINE)                  # 눈
	draw_circle(c + Vector2(3.3, -0.8), 0.35, Color.WHITE)           # 눈빛
	draw_line(c + Vector2(2, -2.5), c + Vector2(4.5, -2.8), OUTLINE, 1.0)
	draw_circle(c + Vector2(3.2, 2.3), 1.5, Color(1.0, 0.5, 0.5, 0.4))   # 볼터치
	draw_line(c + Vector2(4.6, 3.6), c + Vector2(5.8, 3.3), Color(0.55, 0.25, 0.2), 1.0)   # 입
	if beard:
		draw_colored_polygon(PackedVector2Array([c + Vector2(2, 4), c + Vector2(5, 4), c + Vector2(3.5, 9)]), Color(0.12, 0.1, 0.1))


## 갓: 비치는 말총 챙 + 검은 모자 + 갓끈. fancy면 갓끈에 호박 구슬
func _gat(fancy: bool) -> void:
	var c := Vector2(1, -21)
	# 갓끈: 챙 뒤쪽에서 귀 옆을 지나 턱 밑으로 (얼굴을 가로지르지 않게)
	draw_line(c + Vector2(-4.5, 0.5), c + Vector2(-1.5, 11.5), Color(0.1, 0.1, 0.1), 1.0)
	_ellipse(c, 14.0, 2.6, Color(0.05, 0.05, 0.08, 0.7))           # 넓고 얇은, 비치는 말총 챙
	# 모자 부분: 챙에 비해 작고 위가 둥근 원통
	var crown := PackedVector2Array([c + Vector2(-3, 0), c + Vector2(4, 0), c + Vector2(3.8, -6), c + Vector2(2.5, -7.5), c + Vector2(-1.5, -7.5), c + Vector2(-2.8, -6)])
	draw_colored_polygon(crown, Color(0.06, 0.06, 0.09))
	if fancy:   # 턱 밑으로 늘어진 호박 구슬 갓끈
		for i in 5:
			draw_circle(Vector2(1.5 + i * 0.4, -9 + i * 2.2), 1.1, Color(0.85, 0.55, 0.2))


## 장군 투구: 쇠 투구 + 금테 + 꼭대기의 붉은 상모(걸으면 흔들림)
func _helmet(swing: float) -> void:
	var c := Vector2(1, -18)
	var dome := PackedVector2Array()
	for i in 13:
		dome.append(c + Vector2.RIGHT.rotated(PI + PI * i / 12.0) * 8.0)
	draw_colored_polygon(dome, Color(0.28, 0.28, 0.32))
	draw_polyline(dome, OUTLINE, 1.5)
	draw_line(c + Vector2(-8.5, 0), c + Vector2(9, 0), Color(0.98, 0.8, 0.3), 2.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, -12), Color(0.98, 0.8, 0.3), 1.5)
	for i in 4:
		draw_line(c + Vector2(0, -12), c + Vector2(0, -12) + Vector2(-4.0 - i * 1.5 - swing, -3.0 + i * 1.6), Color(0.9, 0.12, 0.1), 1.5)


## 도형의 split_x보다 왼쪽(등 쪽)만 어둡게 덮어 입체감을 줌
func _shade(pts: PackedVector2Array, split_x: float, alpha: float) -> void:
	var back_half := PackedVector2Array([Vector2(-100, -100), Vector2(split_x, -100), Vector2(split_x, 100), Vector2(-100, 100)])
	for part in Geometry2D.intersect_polygons(pts, back_half):
		draw_colored_polygon(part, Color(0, 0, 0, alpha))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(center + Vector2(cos(TAU * i / 16.0) * rx, sin(TAU * i / 16.0) * ry))
	draw_colored_polygon(pts, color)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
