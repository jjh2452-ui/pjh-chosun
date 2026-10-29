extends CharacterBody2D
## 적 하나. 종류(type)에 따라 능력치와 행동이 달라집니다. (능력치는 enemy_data.gd)
##   산적·힘센 산적·좀비 : 플레이어를 쫓아가 몸으로 부딪힘
##   호랑이              : 멈춰서 노란 선으로 돌진 방향을 예고한 뒤 빠르게 돌진
##   산적 두목           : 멈춰서 붉은 원으로 범위를 예고한 뒤 내려찍기
##   도깨비 대왕(보스)   : 내려찍기 → 돌진 → 좀비 소환을 번갈아 사용
## 위험한 공격은 항상 예고(WINDUP) 뒤에 실행되므로, 예고를 보고 피할 수 있습니다.
## CharacterBody2D라서 적끼리는 서로 밀어내며 겹치지 않습니다.

const EnemyData = preload("res://scripts/enemy_data.gd")

enum State { CHASE, WINDUP, ACTION, RECOVER }

# ===== 공격 패턴 숫자 (예고 시간을 늘리면 피하기 쉬워집니다) =====
const TIGER_TRIGGER := 280.0       # 이 거리 안에 들어오면 돌진 준비
const TIGER_WINDUP := 0.75         # 돌진 예고 시간(초)
const TIGER_DASH_SPEED := 560.0
const TIGER_DASH_TIME := 0.45
const TIGER_COOLDOWN := 3.0

const CHIEF_TRIGGER := 140.0
const CHIEF_WINDUP := 1.0          # 내려찍기 예고 시간(초)
const CHIEF_SLAM_RADIUS := 110.0
const CHIEF_COOLDOWN := 4.0

const BOSS_TRIGGER := 520.0
const BOSS_SLAM_WINDUP := 1.2
const BOSS_SLAM_RADIUS := 160.0
const BOSS_DASH_WINDUP := 0.9
const BOSS_DASH_SPEED := 600.0
const BOSS_DASH_TIME := 0.7
const BOSS_SUMMON_WINDUP := 0.6
const BOSS_SUMMON_COUNT := 8
const BOSS_COOLDOWN := 2.5

const RECOVER_TIME := 0.6          # 공격 후 잠깐 느려지는 시간
const SLAM_EFFECT_TIME := 0.25

var main
var target                  # 쫓아갈 대상(플레이어)
var type := "bandit"
var display_name := ""
var max_hp := 10.0
var hp := 10.0
var move_speed := 80.0
var contact_damage := 6.0
var slam_damage := 0.0
var dash_damage := 0.0
var radius := 14.0
var xp_value := 1
var body_color := Color.WHITE
var knockback_resist := 0.0
var is_dead := false
var flash_timer := 0.0

var state := State.CHASE
var state_time := 0.0
var attack_cooldown := 1.5
var attack_kind := ""          # "dash" / "slam" / "summon"
var locked_dir := Vector2.RIGHT
var slam_radius := 0.0
var slam_effect := 0.0
var boss_pattern := 0

# ===== 그림·움직임 =====
# 옆에서 비스듬히 본 민화풍 모습. 오른쪽을 보는 기준으로 그리고, 왼쪽으로 갈 때는 좌우를 뒤집습니다.
const OUTLINE := Color(0.16, 0.11, 0.08)
const DRAW_SCALE := {"bandit": 1.0, "brute": 1.45, "zombie": 0.95, "tiger": 1.15, "ghost": 1.0, "chief": 1.7, "boss": 2.6}
const STEP_RATE := {"bandit": 6.0, "brute": 4.0, "zombie": 3.0, "tiger": 7.0, "ghost": 3.0, "chief": 4.5, "boss": 3.5}   # 초당 걸음 수

# ===== 귀신 =====
const GHOST_ALPHA := 0.82        # 살짝 비쳐 보이는 정도 (1 = 불투명)
const GHOST_WAVE := 0.55         # 좌우로 일렁이며 다가오는 정도 (0 = 곧장)
const GHOST_HOVER := 5.0         # 땅에서 떠 있는 높이(픽셀, 몸 크기 기준)

# ===== 스프라이트 시트 (sprite-gen으로 만든 적 아틀라스) =====
# assets/imgs/enemies/<적 종류>-sheet-alpha.png 가 있으면 그 시트로 idle·walk 애니메이션을 씁니다.
# 시트 구성은 플레이어와 같습니다: 가로 4칸 × 세로 2줄(첫 줄 idle, 둘째 줄 walk), 한 칸 256×256.
# 시트가 없는 적은 지금처럼 직접 그린(구운) 모습을 씁니다.
const SHEET_DIR := "res://assets/imgs/enemies/"
const SHEET_COLUMNS := 4
const SHEET_ROWS := {"idle": 0, "walk": 1}
const SHEET_FPS := {"idle": 4.0, "walk": 8.0}
const SHEET_SCALE := 0.19        # 256칸 그림(키 약 207px) → 몸 크기 1배 기준 약 39px. 적마다 DRAW_SCALE 이 또 곱해짐
const SHEET_FEET_Y := 231.0      # 칸 안에서 발끝 높이 (256칸 기준)
const SHEET_TYPE_SCALE := {"tiger": 1.6, "chief": 1.25}   # 호랑이는 옆으로 길게 그려져, 두목은 날씬하게 그려져 작아 보이므로 더 키움
const BODY_FEET_Y := 14.0        # 몸 그림 좌표에서 발끝 높이 (그림자와 맞춤)
static var sheet_cache := {}     # 적 종류 → SpriteFrames (시트가 없으면 null) — 한 번만 읽어서 모든 적이 함께 씀
var anim_sprite: AnimatedSprite2D   # 시트 애니메이션 (시트가 없으면 null)

var body: Node2D          # 몸 그림을 그리는 자식 노드
var k := 1.0              # 그림 크기 배율
var facing := 1.0         # 1 = 오른쪽, -1 = 왼쪽
var anim_time := 0.0
var leg_frame := 0        # 0 / 1: 다리를 번갈아 내딛는 두 장면

# ===== 그림 굽기(베이킹) =====
# 적 수백 마리가 매번 선·원 수십 개를 그리면 느려집니다.
# 그래서 게임 시작 때(타이틀 화면) 자세별 그림을 한 번씩 이미지로 구워 두고(main.gd의 _bake_enemy_art),
# 실제 적은 그 이미지를 붙인 Sprite2D 하나만 보여줍니다. 구운 그림이 없으면 직접 그립니다.
const BAKE_ANCHOR := Vector2(160, 220)   # 구운 이미지 안에서 몸 가운데(0, 0)의 위치
const BAKE_RES := 2.0                    # 2배 크기로 구워서 선명하게
static var baked := {}                   # "bandit_1_" 같은 이름 → 이미지
var sprite: Sprite2D                     # 구운 그림을 보여주는 노드 (없으면 null)
var baking := false                      # true면 굽기용 견본 (움직이지 않음)
var bake_swing := 0.0
var bake_raised := false


## 종류와 경과 시간(분)으로 능력치를 정합니다. 시간이 지날수록 튼튼해집니다.
func setup(enemy_type: String, minutes: float) -> void:
	type = enemy_type
	var d: Dictionary = EnemyData.ENEMIES[type]
	display_name = d["name"]
	max_hp = d["hp"] * (1.0 + d["hp_growth"] * minutes)
	hp = max_hp
	move_speed = (d["speed"] * EnemyData.SPEED_MULT + EnemyData.SPEED_OFFSET) * randf_range(0.9, 1.1)
	var dmg_mult := EnemyData.DAMAGE_MULT * (1.0 + EnemyData.DAMAGE_GROWTH * minutes)   # 늦게 나온 적일수록 아픔
	if type != "tiger":
		dmg_mult *= EnemyData.NON_TIGER_DAMAGE_MULT
	contact_damage = d["damage"] * dmg_mult
	slam_damage = d.get("slam_damage", 0.0) * dmg_mult
	dash_damage = d.get("dash_damage", 0.0) * dmg_mult
	radius = d["radius"]
	xp_value = d["xp"]
	body_color = d["color"]
	knockback_resist = d["knockback_resist"]


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2   # 적끼리만 부딪힘
	collision_mask = _normal_mask()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	# 몸 그림은 자식 노드(body)에 따로 그립니다.
	# → 걷기·좌우 반전·흔들림은 body를 움직이기만 하면 돼서, 매 프레임 다시 그리지 않아도 됩니다.
	k = DRAW_SCALE[type]
	body = Node2D.new()
	body.scale = Vector2(k, k)
	add_child(body)
	body.draw.connect(_draw_body)
	anim_time = randf() * 2.0   # 모두 똑같이 걷지 않도록 시작 박자를 다르게
	if baking:
		body.scale = Vector2(k, k) * BAKE_RES
		set_physics_process(false)
		return
	var frames := sheet_frames_for(type)
	if frames != null:
		# 스프라이트 시트가 있으면: 시트 애니메이션 (구운 그림·직접 그리기 대신)
		anim_sprite = AnimatedSprite2D.new()
		anim_sprite.sprite_frames = frames
		var ss: float = SHEET_SCALE * SHEET_TYPE_SCALE.get(type, 1.0)
		anim_sprite.scale = Vector2(ss, ss)
		# 칸 가운데가 기준점이므로, 칸 안의 발끝이 몸 그림의 발 높이에 오도록 위로 올림
		var cell_h: float = frames.get_frame_texture("idle", 0).get_height()
		anim_sprite.position = Vector2(0, BODY_FEET_Y - (SHEET_FEET_Y * cell_h / 256.0 - cell_h / 2.0) * ss)
		body.add_child(anim_sprite)
		anim_sprite.play("walk")
		anim_sprite.frame = randi() % SHEET_COLUMNS   # 모두 똑같은 박자로 걷지 않게
	elif baked.has(_bake_key(0.0, false)):
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.offset = -BAKE_ANCHOR
		sprite.scale = Vector2.ONE / (k * BAKE_RES)
		body.add_child(sprite)
		_refresh_body()


## 적 종류별 시트를 한 번만 읽어 칸 단위로 자른 SpriteFrames 를 돌려줍니다. 시트가 없으면 null.
static func sheet_frames_for(enemy_type: String) -> SpriteFrames:
	if sheet_cache.has(enemy_type):
		return sheet_cache[enemy_type]
	var frames: SpriteFrames = null
	var path := SHEET_DIR + enemy_type + "-sheet-alpha.png"
	if ResourceLoader.exists(path):
		var sheet: Texture2D = load(path)
		var cell_w := sheet.get_width() / SHEET_COLUMNS
		var cell_h := sheet.get_height() / SHEET_ROWS.size()
		frames = SpriteFrames.new()
		frames.remove_animation("default")
		for anim in SHEET_ROWS:
			frames.add_animation(anim)
			frames.set_animation_loop(anim, true)
			frames.set_animation_speed(anim, SHEET_FPS[anim])
			for col in SHEET_COLUMNS:
				var cell := AtlasTexture.new()
				cell.atlas = sheet
				cell.region = Rect2(col * cell_w, SHEET_ROWS[anim] * cell_h, cell_w, cell_h)
				frames.add_frame(anim, cell)
	sheet_cache[enemy_type] = frames
	return frames


## 평소 충돌 설정: 적끼리 밀어냄. 귀신은 다른 적을 뚫고 지나감
func _normal_mask() -> int:
	return 0 if type == "ghost" else 2


static func bake_key_of(enemy_type: String, swing: float, raised: bool) -> String:
	return "%s_%d_%s" % [enemy_type, int(swing), "up" if raised else ""]


func _bake_key(swing: float, raised: bool) -> String:
	return bake_key_of(type, swing, raised)


## 자세가 바뀌었을 때: 구운 그림이 있으면 그림만 바꿔 끼우고, 없으면 다시 그림
func _refresh_body() -> void:
	if anim_sprite != null:
		return   # 시트 애니메이션은 _animate 에서 idle·walk 만 바꿈
	if sprite == null:
		body.queue_redraw()
		return
	var swing := 0.0
	if velocity.length() > 3.0:
		swing = 1.0 if leg_frame == 0 else -1.0
	var raised := state == State.WINDUP and (type == "chief" or type == "boss")
	sprite.texture = baked.get(_bake_key(swing, raised))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var to_player: Vector2 = target.global_position - global_position
	var dist := to_player.length()
	state_time += delta
	attack_cooldown -= delta

	match state:
		State.CHASE:
			var chase := to_player / maxf(dist, 0.001)
			if type == "ghost":   # 좌우로 일렁이며 다가옴
				chase = (chase + chase.orthogonal() * sin(anim_time * 2.2) * GHOST_WAVE).normalized()
			velocity = chase * move_speed
			_try_start_attack(dist, to_player)
		State.WINDUP:
			velocity = Vector2.ZERO
			if state_time >= _windup_time():
				_do_action()
		State.ACTION:   # 돌진 중
			velocity = locked_dir * _dash_speed()
			if state_time >= _dash_time():
				_enter(State.RECOVER)
		State.RECOVER:
			velocity = to_player / maxf(dist, 0.001) * move_speed * 0.3
			if state_time >= RECOVER_TIME:
				_enter(State.CHASE)
	move_and_slide()

	# 몸으로 부딪히면 피해 (돌진 중이면 돌진 피해). 플레이어 무적 시간 덕에 연속으로는 안 들어감
	if dist < radius + target.radius:
		var is_dashing := state == State.ACTION
		target.take_damage(dash_damage if is_dashing else contact_damage)

	if flash_timer > 0.0:
		flash_timer -= delta
	_animate(delta)
	# 바닥 표시(예고·효과)는 필요할 때만 다시 그림 (적이 수백 마리라 매 프레임 그리면 느려짐)
	if slam_effect > 0.0:
		slam_effect -= delta
		queue_redraw()
	if state != State.CHASE:
		queue_redraw()


# ===== 공격 패턴 =====

func _try_start_attack(dist: float, to_player: Vector2) -> void:
	if attack_cooldown > 0.0:
		return
	match type:
		"tiger":
			if dist < TIGER_TRIGGER:
				_start_windup("dash", to_player)
		"chief":
			if dist < CHIEF_TRIGGER:
				_start_windup("slam", to_player)
		"boss":
			if dist < BOSS_TRIGGER:
				var kinds := ["slam", "dash", "summon"]
				var kind: String = kinds[boss_pattern % kinds.size()]
				# 멀리 있을 때 내려찍기는 의미가 없으니 돌진으로 바꿈
				if kind == "slam" and dist > BOSS_SLAM_RADIUS + 80.0:
					kind = "dash"
				boss_pattern += 1
				_start_windup(kind, to_player)


func _start_windup(kind: String, to_player: Vector2) -> void:
	attack_kind = kind
	locked_dir = to_player.normalized()   # 예고하는 순간 방향을 고정 → 옆으로 피하면 빗나감
	if absf(locked_dir.x) > 0.05:
		facing = signf(locked_dir.x)      # 공격할 쪽을 바라봄
	slam_radius = BOSS_SLAM_RADIUS if type == "boss" else CHIEF_SLAM_RADIUS
	_enter(State.WINDUP)
	main.sfx.play("warn", 0.7 if type == "boss" else 1.0)


func _do_action() -> void:
	match attack_kind:
		"dash":
			collision_mask = 0   # 돌진 중에는 다른 적을 뚫고 지나감
			_enter(State.ACTION)
			main.sfx.play("slash", 0.5)
		"slam":
			if global_position.distance_to(target.global_position) < slam_radius + target.radius:
				target.take_damage(slam_damage)
			slam_effect = SLAM_EFFECT_TIME
			main.sfx.play("boom", 0.7)
			main.add_shake(0.5 if type == "boss" else 0.3)
			_enter(State.RECOVER)
		"summon":
			for i in BOSS_SUMMON_COUNT:
				var offset := Vector2.RIGHT.rotated(TAU * i / BOSS_SUMMON_COUNT) * (radius + 40.0)
				main.spawn_enemy_at("zombie", global_position + offset)
			_enter(State.RECOVER)
	match type:
		"tiger":
			attack_cooldown = TIGER_COOLDOWN
		"chief":
			attack_cooldown = CHIEF_COOLDOWN
		"boss":
			attack_cooldown = BOSS_COOLDOWN


func _enter(new_state: State) -> void:
	state = new_state
	state_time = 0.0
	# 예고·공격 중에는 다른 적보다 위에 그려서 잘 보이게
	z_index = 1 if (new_state == State.WINDUP or new_state == State.ACTION) else 0
	if new_state == State.CHASE or new_state == State.RECOVER:
		collision_mask = _normal_mask()
	_refresh_body()   # 자세가 바뀜 (예: 두목·보스가 무기를 치켜듦)


func _windup_time() -> float:
	match attack_kind:
		"dash":
			return BOSS_DASH_WINDUP if type == "boss" else TIGER_WINDUP
		"slam":
			return BOSS_SLAM_WINDUP if type == "boss" else CHIEF_WINDUP
	return BOSS_SUMMON_WINDUP


func _dash_speed() -> float:
	return BOSS_DASH_SPEED if type == "boss" else TIGER_DASH_SPEED


func _dash_time() -> float:
	return BOSS_DASH_TIME if type == "boss" else TIGER_DASH_TIME


# ===== 피해 =====

func take_damage(amount: float, knockback_dir := Vector2.ZERO) -> void:
	if is_dead:
		return
	hp -= amount
	if state != State.ACTION:
		global_position += knockback_dir * 6.0 * (1.0 - knockback_resist)
	flash_timer = 0.08
	if type == "chief":
		queue_redraw()   # 머리 위 체력바
	main.on_enemy_hit(self, amount)
	if hp <= 0.0:
		is_dead = true
		main.on_enemy_killed(self)
		queue_free()


# ===== 그리기 =====

## 매 프레임: 몸 노드를 움직여 걷기·방향·자세를 표현 (다시 그리지 않으므로 가벼움)
func _animate(delta: float) -> void:
	if state != State.WINDUP and absf(velocity.x) > 3.0:
		facing = signf(velocity.x)
	var walking := velocity.length() > 3.0
	anim_time += delta
	var rate: float = STEP_RATE[type]
	var bob := absf(sin(anim_time * rate * PI)) * 2.0 * k if walking else 0.0
	var lean := 0.06 if walking else 0.0
	var sx := 1.0
	var sy := 1.0
	match type:
		"zombie":   # 앞으로 고꾸라질 듯 휘청휘청
			lean = 0.16 + sin(anim_time * 2.5) * 0.08
		"tiger":
			if state == State.WINDUP:     # 돌진 전 웅크림
				sx = 1.1
				sy = 0.82
				bob = 0.0
			elif state == State.ACTION:   # 길게 뻗으며 돌진
				sx = 1.3
				sy = 0.85
				lean = 0.0
	if anim_sprite != null:
		# 시트 그림은 걸음 동작이 그림 안에 있으므로 통통 튀기·기울이기는 빼고, 멈추면 idle / 움직이면 walk
		bob = 0.0
		lean = 0.0
		var want := "walk" if walking else "idle"
		if anim_sprite.animation != want:
			anim_sprite.play(want)
	if type == "ghost":   # 땅에서 떠서 천천히 오르내림, 앞으로 살짝 기울어 미끄러짐
		bob = GHOST_HOVER * k + sin(anim_time * 2.5) * 2.0 * k
		lean = 0.08 if walking else 0.0
	# 내려찍기 예고 중에는 힘을 모으며 부르르 떨림
	body.position.x = sin(anim_time * 60.0) * 1.2 if (state == State.WINDUP and attack_kind != "dash") else 0.0
	body.position.y = -bob
	body.rotation = lean * facing
	body.scale = Vector2(facing * k * sx, k * sy)
	# 다리는 두 장면을 번갈아: 장면이 바뀔 때만 다시 그림
	var f := int(anim_time * rate) % 2 if walking else 0
	if f != leg_frame:
		leg_frame = f
		_refresh_body()
	# 맞으면 밝게 번쩍임 (다시 그리지 않고 색만 바꿈). 큰 적은 덜 밝게
	var alpha := GHOST_ALPHA if type == "ghost" else 1.0   # 귀신은 살짝 비쳐 보임
	if flash_timer > 0.0:
		var glow := 1.6 if radius >= 26.0 else 2.4
		body.modulate = Color(glow, glow, glow, alpha)
	else:
		body.modulate = Color(1, 1, 1, alpha)


## 바닥에 그리는 것: 그림자, 공격 예고, 내려찍기 효과
func _draw() -> void:
	if baking:
		return
	var shadow_w := radius * (1.5 if type == "tiger" else (0.7 if type == "ghost" else 1.0))
	var shadow_a := 0.14 if type == "ghost" else 0.28   # 떠 있는 귀신은 그림자가 작고 옅음
	_ellipse_on(self, Vector2(0, 14.0 * k), shadow_w, shadow_w * 0.3, Color(0, 0, 0, shadow_a))
	if type == "chief":   # 머리 위 체력바 (시트 그림은 키가 커서 더 위에)
		var lift: float = SHEET_TYPE_SCALE.get(type, 1.0) + 0.1 if anim_sprite != null else 1.0
		var bar_y := -30.0 * k * lift
		draw_rect(Rect2(-26, bar_y, 52, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-26, bar_y, 52 * hp / max_hp, 5), Color(0.9, 0.2, 0.15))
	if state == State.WINDUP:
		var p := clampf(state_time / _windup_time(), 0.0, 1.0)
		match attack_kind:
			"dash":  # 돌진 경로: 노란 띠가 점점 진해짐
				var end := locked_dir * _dash_speed() * _dash_time()
				draw_line(Vector2.ZERO, end, Color(1, 0.85, 0.2, 0.15 + 0.35 * p), radius * 2.0)
				draw_line(Vector2.ZERO, end, Color(1, 0.9, 0.3, 0.9), 2.0)
			"slam":  # 내려찍기 범위: 붉은 원이 안쪽부터 차오름
				draw_circle(Vector2.ZERO, slam_radius, Color(1, 0.15, 0.1, 0.12))
				draw_circle(Vector2.ZERO, slam_radius * p, Color(1, 0.15, 0.1, 0.3))
				draw_arc(Vector2.ZERO, slam_radius, 0, TAU, 48, Color(1, 0.2, 0.1, 0.9), 3.0)
			"summon":  # 소환: 보랏빛 고리
				draw_arc(Vector2.ZERO, radius + 20.0 + 20.0 * p, 0, TAU, 40, Color(0.7, 0.3, 1.0, 0.8), 4.0)
	if slam_effect > 0.0:
		var e := slam_effect / SLAM_EFFECT_TIME
		draw_circle(Vector2.ZERO, slam_radius, Color(1, 0.6, 0.3, 0.45 * e))
		draw_arc(Vector2.ZERO, slam_radius * (1.1 - 0.1 * e), 0, TAU, 48, Color(1, 0.9, 0.6, e), 4.0)


## 몸 그림 (body 노드에 그림). 좌표: 오른쪽을 봄, 발끝 y ≈ 14, 사람 머리 가운데 y ≈ -15
func _draw_body() -> void:
	if sprite != null or anim_sprite != null:
		return   # 구운 그림이나 시트 애니메이션을 쓰는 중
	var swing := 1.0 if leg_frame == 0 else -1.0
	if velocity.length() <= 3.0:
		swing = 0.0
	if baking:
		swing = bake_swing
	match type:
		"brute":
			_draw_brute(swing)
		"zombie":
			_draw_zombie(swing)
		"tiger":
			_draw_tiger(swing)
		"ghost":
			_draw_ghost(swing)
		"chief":
			_draw_chief(swing)
		"boss":
			_draw_boss(swing)
		_:
			_draw_bandit(swing)


## 산적: 갈색 저고리, 붉은 머리띠, 상투, 손에 낫
func _draw_bandit(swing: float) -> void:
	var skin := Color(0.88, 0.7, 0.52)
	var jacket := body_color
	var hair := Color(0.1, 0.08, 0.06)
	_legs(swing, Color(0.5, 0.47, 0.42), Color(0.6, 0.45, 0.25), 2.0)
	_limb(Vector2(-2, -5), Vector2(-3 - swing * 3.0, 4), jacket, 4.0)          # 뒤쪽 팔
	var coat := [Vector2(-6.5, -9), Vector2(7, -9), Vector2(8, 4), Vector2(-7.5, 4)]
	_poly(coat, jacket)                                                                  # 짧은 저고리
	_shade(coat)
	body.draw_line(Vector2(1, -9), Vector2(3, 4), jacket.darkened(0.3), 1.2)            # 여밈
	_circ(Vector2(-4, -1), 1.0, Color(0.35, 0.25, 0.15), false)                         # 기운 자국
	_circ(Vector2(-2, 2), 1.0, Color(0.35, 0.25, 0.15), false)
	body.draw_line(Vector2(-7.5, 1), Vector2(8, 1), Color(0.3, 0.2, 0.1), 2.0)          # 새끼줄 허리띠
	var c := Vector2(1, -15)
	_circ(c, 6.5, skin)
	body.draw_arc(c, 6.0, PI * 1.05, PI * 1.95, 10, hair, 3.0)                       # 머리카락
	_circ(c + Vector2(-2, -7), 2.4, hair)                                              # 상투
	var red := Color(0.85, 0.15, 0.1)
	body.draw_line(c + Vector2(-6.5, -2.5), c + Vector2(6.5, -2.5), red, 2.5)          # 머리띠
	body.draw_line(c + Vector2(-6, -2.5), c + Vector2(-10, 0.5), red, 1.8)
	body.draw_line(c + Vector2(-6, -2.5), c + Vector2(-10.5, -4), red, 1.8)
	body.draw_line(c + Vector2(2, -1.2), c + Vector2(5, -0.2), OUTLINE, 1.2)           # 사나운 눈썹
	body.draw_circle(c + Vector2(3.6, 0.6), 1.0, OUTLINE)
	body.draw_arc(c, 5.2, 0.4, 1.5, 6, Color(0.3, 0.25, 0.2, 0.6), 2.0)                # 수염 자국
	var hand := Vector2(3 + swing * 2.0, 3)
	_limb(Vector2(2, -5), hand, jacket, 4.0)
	body.draw_line(hand + Vector2(0, 2), hand + Vector2(2, -9), Color(0.5, 0.35, 0.2), 2.0)   # 낫 자루
	body.draw_arc(hand + Vector2(5, -9), 4.5, PI, PI * 1.9, 8, Color(0.82, 0.82, 0.88), 2.0)  # 낫 날
	body.draw_circle(hand, 2.0, skin)


## 힘센 산적: 드럼통 몸, 열린 조끼, 대머리 상투, 어깨에 멘 몽둥이
func _draw_brute(swing: float) -> void:
	var skin := Color(0.85, 0.66, 0.5)
	var vest := body_color
	var wood := Color(0.48, 0.32, 0.16)
	_legs(swing, Color(0.4, 0.35, 0.3), Color(0.35, 0.28, 0.2), 3.0)
	# 어깨에 멘 몽둥이 (몸 뒤로 넘어감)
	body.draw_line(Vector2(5, -4), Vector2(-9, -22), OUTLINE, 7.0)
	body.draw_line(Vector2(5, -4), Vector2(-9, -22), wood, 5.0)
	for t in [0.55, 0.75, 0.92]:
		_circ(Vector2(5, -4).lerp(Vector2(-9, -22), t), 1.6, Color(0.35, 0.22, 0.1))   # 옹이
	_limb(Vector2(-4, -5), Vector2(-5 - swing * 2.0, 4), skin, 5.0)                 # 뒤쪽 맨팔
	_ellipse_on(body, Vector2(0, -2), 9.5, 10.0, vest, true)                         # 드럼통 몸
	_shade(_ellipse_pts(Vector2(0, -2), 9.5, 10.0))
	_ellipse_on(body, Vector2(3, 0), 5.0, 6.5, skin)                                 # 열린 조끼 사이 배
	body.draw_line(Vector2(-9, 5), Vector2(9, 5), Color(0.3, 0.2, 0.1), 2.5)
	var c := Vector2(2, -15)
	_circ(c, 6.0, skin)
	_circ(c + Vector2(-1, -6.5), 2.2, Color(0.1, 0.08, 0.06))                        # 대머리에 상투
	_poly([c + Vector2(-1, 2.5), c + Vector2(6, 1.5), c + Vector2(4, 8), c + Vector2(0, 7)], Color(0.12, 0.08, 0.06), false)   # 수염
	body.draw_line(c + Vector2(1.5, -2.5), c + Vector2(5.5, -1), OUTLINE, 1.6)       # 성난 눈썹
	body.draw_circle(c + Vector2(3.8, 0), 1.0, OUTLINE)
	_limb(Vector2(3, -6), Vector2(5, -4), skin, 5.5)                                  # 몽둥이 쥔 앞팔
	_circ(Vector2(5, -4), 2.6, skin)


## 좀비: 해진 흰 소복, 창백한 피부, 얼굴을 덮은 긴 머리, 앞으로 뻗은 팔
func _draw_zombie(swing: float) -> void:
	var skin := body_color
	var robe := Color(0.9, 0.9, 0.85)
	var hair := Color(0.06, 0.06, 0.08)
	_legs(swing * 0.6, skin, skin.darkened(0.2), 1.5)
	_limb(Vector2(-1, -6), Vector2(10, -4), robe.darkened(0.12), 3.5)                # 뒤쪽 팔 (앞으로 뻗음)
	_circ(Vector2(10, -4), 1.8, skin, false)
	# 해진 소복: 아랫단이 들쭉날쭉
	var sobok := [Vector2(-6, -9), Vector2(6.5, -9), Vector2(8, 9), Vector2(5, 11), Vector2(3, 8), Vector2(0, 11),
		Vector2(-3, 8), Vector2(-6, 11), Vector2(-8, 9)]
	_poly(sobok, robe)
	_shade(sobok, -1.0, 0.2)
	body.draw_line(Vector2(-3, -2), Vector2(-4, 5), Color(0.6, 0.62, 0.55, 0.6), 1.0)   # 얼룩·주름
	body.draw_line(Vector2(3, 0), Vector2(4, 7), Color(0.6, 0.62, 0.55, 0.6), 1.0)
	var c := Vector2(2, -15)
	_poly([c + Vector2(-7, -2), c + Vector2(-3, -7.5), c + Vector2(3, -7.5), c + Vector2(6.5, -3),
		c + Vector2(-8, 12)], hair, false)                                                # 등 뒤로 늘어진 머리
	_circ(c, 6.3, skin)
	_poly([c + Vector2(-6.5, -2), c + Vector2(-2, -7.5), c + Vector2(4, -7), c + Vector2(7, -1),
		c + Vector2(5.5, 6), c + Vector2(3.5, 1), c + Vector2(1.5, 7), c + Vector2(-1, 2)], hair, false)   # 얼굴을 덮은 머리
	body.draw_circle(c + Vector2(4.5, 2.5), 1.1, Color(0.85, 0.15, 0.15))            # 머리카락 사이로 보이는 눈
	_limb(Vector2(1, -6), Vector2(12, -6), robe, 3.5)                                 # 앞팔
	_circ(Vector2(12, -6), 1.9, skin, false)


## 호랑이: 민화 까치호랑이처럼 큰 동그란 눈과 익살스러운 얼굴, 줄무늬, 말린 꼬리
func _draw_tiger(swing: float) -> void:
	var fur := body_color
	var stripe := Color(0.12, 0.06, 0.03)
	var white := Color(0.98, 0.95, 0.88)
	# 뒷다리·앞다리 (안쪽 다리는 어둡게)
	for leg in [[-9.0, -1.0, true], [6.0, 1.0, true], [-6.0, 1.0, false], [9.0, -1.0, false]]:
		var x: float = leg[0]
		var foot := Vector2(x + swing * leg[1] * 2.5, 13)
		var col: Color = fur.darkened(0.25) if leg[2] else fur
		_limb(Vector2(x, 4), foot, col, 3.5)
		body.draw_line(Vector2(x, 4).lerp(foot, 0.45) + Vector2(-1.5, 0), Vector2(x, 4).lerp(foot, 0.45) + Vector2(1.5, 0), stripe, 1.3)   # 다리 줄무늬
		_circ(foot + Vector2(1, 0.5), 1.8, white)
	# 말린 꼬리 (줄무늬)
	var tail := PackedVector2Array([Vector2(-12, 0), Vector2(-16, -3), Vector2(-17, -9), Vector2(-14, -13)])
	body.draw_polyline(tail, OUTLINE, 5.0)
	body.draw_polyline(tail, fur, 3.0)
	body.draw_circle(Vector2(-16.3, -4), 1.2, stripe)
	body.draw_circle(Vector2(-16.8, -8.5), 1.2, stripe)
	body.draw_circle(Vector2(-14, -13), 1.8, stripe)
	# 몸통 + 흰 배 + 줄무늬
	_ellipse_on(body, Vector2(-1, 1), 13.0, 6.5, fur, true)
	_ellipse_on(body, Vector2(-1, -1.5), 10.0, 2.5, fur.lightened(0.2))              # 등의 빛
	_ellipse_on(body, Vector2(-1, 5), 9.0, 2.5, white)
	for x in [-9.0, -5.0, -1.0, 3.0]:
		body.draw_line(Vector2(x, -4.5), Vector2(x + 1.5, 0.5), stripe, 2.0)
	# 큰 머리
	var c := Vector2(11, -5)
	_circ(c + Vector2(-4, -6), 2.4, fur)                                              # 귀
	_circ(c + Vector2(2, -7), 2.4, fur)
	_circ(c, 7.5, fur)
	_poly([c + Vector2(-5, 0), c + Vector2(-9, 2.5), c + Vector2(-6, 3.5), c + Vector2(-8.5, 6),
		c + Vector2(-3, 5)], white, false)                                                # 흰 뺨털
	_ellipse_on(body, c + Vector2(3, 3), 4.2, 3.0, white)                            # 주둥이
	for x in [-3.0, 0.0, 3.0]:
		body.draw_line(c + Vector2(x - 1, -7), c + Vector2(x - 0.5, -4.5), stripe, 1.5)   # 이마 무늬
	for e in [Vector2(0.5, -1.5), Vector2(5, -1)]:                                    # 왕방울 눈
		_circ(c + e, 2.6, Color(1, 0.95, 0.5))
		body.draw_circle(c + e + Vector2(0.6, 0.2), 1.3, Color.BLACK)
	body.draw_circle(c + Vector2(6.5, 2), 1.2, Color(0.3, 0.1, 0.1))                 # 코
	body.draw_arc(c + Vector2(4, 3.5), 2.5, 0.2, PI - 0.2, 8, OUTLINE, 1.2)          # 씩 웃는 입
	body.draw_line(c + Vector2(6, 3), c + Vector2(10, 2), Color(0.2, 0.15, 0.1), 0.8)   # 수염
	body.draw_line(c + Vector2(6, 4), c + Vector2(10, 5), Color(0.2, 0.15, 0.1), 0.8)


## 귀신: 흰 소복, 뒤로 흩날리는 긴 검은 머리, 붉은 눈, 앞으로 뻗은 손. 다리 없이 아래가 물결치며 흐려짐
func _draw_ghost(swing: float) -> void:
	var robe := body_color
	var skin := Color(0.92, 0.92, 0.95)
	var hair := Color(0.05, 0.05, 0.07)
	var ripple := swing * 1.5
	# 뒤로 흩날리는 긴 머리 (몸보다 먼저 그려 등 뒤에 보이게)
	_poly([Vector2(-1, -21), Vector2(-9, -18), Vector2(-17 - ripple, -10), Vector2(-14, -6), Vector2(-21 + ripple, 0),
		Vector2(-12, -2), Vector2(-4, -8)], hair, false)
	# 다리 없는 소복: 아래로 갈수록 넓어지고 끝이 물결치며 뒤로 끌림
	var gown := [Vector2(-5, -11), Vector2(5, -11), Vector2(8, 0), Vector2(6, 8), Vector2(2, 6 + ripple),
		Vector2(-2, 10), Vector2(-6, 7 - ripple), Vector2(-11, 12), Vector2(-10, 3)]
	_poly(gown, robe)
	_shade(gown, -1.0, 0.12)
	body.draw_line(Vector2(0, -11), Vector2(1, 4), Color(0.75, 0.76, 0.82), 1.0)   # 옷섶
	# 앞으로 뻗은 팔과 창백한 손
	_limb(Vector2(2, -8), Vector2(12, -6), robe.darkened(0.06), 3.5)
	_circ(Vector2(13, -6), 1.8, skin, false)
	# 얼굴과 앞머리 (얼굴 반쯤을 덮음)
	var c := Vector2(1, -16)
	_circ(c, 5.5, skin)
	_poly([c + Vector2(-6, -1), c + Vector2(-3, -6.5), c + Vector2(3, -6), c + Vector2(6, -2), c + Vector2(2, -2.5),
		c + Vector2(0, 3), c + Vector2(-3, 1)], hair, false)
	body.draw_circle(c + Vector2(3.2, 0.3), 1.0, Color(0.9, 0.1, 0.1))            # 붉은 눈
	body.draw_line(c + Vector2(2.5, 3), c + Vector2(4, 3), Color(0.55, 0.2, 0.25), 0.8)   # 입


## 산적 두목: 검붉은 장포, 털 조끼, 안대, 덥수룩한 수염, 언월도. 내려찍기 예고 때 칼을 치켜듦
func _draw_chief(swing: float) -> void:
	var skin := Color(0.85, 0.66, 0.5)
	var coat := body_color.lightened(0.15)
	var fur := Color(0.55, 0.52, 0.48)
	var steel := Color(0.85, 0.85, 0.9)
	var raised := bake_raised if baking else state == State.WINDUP
	_legs(swing, Color(0.2, 0.18, 0.18), Color(0.1, 0.1, 0.1), 2.5)
	# 언월도: 치켜든 자세 / 앞으로 겨눈 자세
	var hand := Vector2(-5, -23) if raised else Vector2(6, 0)
	var tip := Vector2(-16, -33) if raised else Vector2(18, -14)
	body.draw_line(hand.lerp(tip, -0.3), tip, Color(0.4, 0.25, 0.12), 2.5)            # 긴 자루
	var dir := (tip - hand).normalized()
	var side := dir.orthogonal()
	_poly([tip, tip + dir * 9.0 + side * 2.0, tip + dir * 6.0 - side * 3.5], steel)   # 휜 칼날
	_limb(Vector2(-2, -6), Vector2(-3 - swing * 2.0, 3), coat, 4.5)
	var robe_pts := [Vector2(-7, -9), Vector2(7.5, -9), Vector2(9.5, 9), Vector2(-9.5, 9)]
	_poly(robe_pts, coat)                                                              # 장포
	_shade(robe_pts)
	body.draw_line(Vector2(-9.3, 8), Vector2(9.3, 8), Color(0.95, 0.75, 0.2, 0.8), 1.5)   # 금빛 단
	_poly([Vector2(-7.5, -10), Vector2(8, -10), Vector2(7, -3), Vector2(-7, -3)], fur)    # 털 조끼
	body.draw_line(Vector2(-8.5, 1), Vector2(9, 1), Color(0.95, 0.75, 0.2), 2.0)     # 금빛 띠
	if raised:   # 치켜든 팔은 머리 뒤로 (얼굴을 가리지 않게)
		_limb(Vector2(-1, -7), hand, coat, 4.5)
		_circ(hand, 2.3, skin)
	var c := Vector2(1, -16)
	_circ(c, 6.5, skin)
	body.draw_arc(c, 6.2, PI, TAU, 12, Color(0.08, 0.06, 0.05), 4.0)                 # 검은 두건
	_poly([c + Vector2(-2, 2), c + Vector2(6.5, 1.5), c + Vector2(5, 10), c + Vector2(0, 9)], Color(0.1, 0.07, 0.05), false)   # 수염
	body.draw_line(c + Vector2(-5, -4), c + Vector2(6, 1), Color.BLACK, 1.0)          # 안대 끈
	body.draw_circle(c + Vector2(3.5, -0.5), 1.8, Color.BLACK)                        # 안대
	if not raised:
		_limb(Vector2(2, -6), hand, coat, 4.5)
		_circ(hand, 2.3, skin)


## 도깨비 대왕: 푸른 피부, 불룩한 배, 호피 두르개, 두 뿔, 붉은 갈기, 가시 방망이
func _draw_boss(swing: float) -> void:
	var skin := body_color
	var belly := skin.lightened(0.25)
	var hide := Color(0.95, 0.6, 0.15)
	var mane := Color(0.85, 0.2, 0.1)
	var raised := bake_raised if baking else state == State.WINDUP
	_legs(swing, skin.darkened(0.1), skin.darkened(0.3), 3.0)
	# 방망이: 치켜든 자세(머리 뒤) / 들고 다니는 자세
	var hand := Vector2(-6, -25) if raised else Vector2(8, -1)
	var top := Vector2(-11, -35) if raised else Vector2(15, -18)
	var dir := (top - hand).normalized()
	var side := dir.orthogonal()
	_poly([hand + side * 1.8, hand - side * 1.8, top - side * 4.0, top + side * 4.0], Color(0.5, 0.3, 0.12))
	for t in [0.45, 0.7, 0.92]:
		var p := hand.lerp(top, t)
		_circ(p + side * 3.0 * t, 1.1, Color(0.9, 0.9, 0.85))     # 가시
		_circ(p - side * 3.0 * t, 1.1, Color(0.9, 0.9, 0.85))
	_limb(Vector2(-4, -7), Vector2(-6 - swing * 2.0, 3), skin, 5.0)                 # 뒤쪽 팔
	_ellipse_on(body, Vector2(0, -3), 10.0, 9.5, skin, true)                       # 몸
	_shade(_ellipse_pts(Vector2(0, -3), 10.0, 9.5), -2.0, 0.2)
	_ellipse_on(body, Vector2(2, -1), 6.5, 6.5, belly)                             # 불룩한 배
	body.draw_circle(Vector2(3, 0), 0.9, OUTLINE)                                   # 배꼽
	_poly([Vector2(-10, 3), Vector2(10, 3), Vector2(9, 9), Vector2(4, 7), Vector2(0, 10), Vector2(-5, 7), Vector2(-9, 9)], hide)   # 호피
	for x in [-6.0, -1.0, 4.0, 8.0]:
		body.draw_line(Vector2(x, 3.5), Vector2(x + 1, 6.5), Color(0.15, 0.08, 0.03), 1.5)
	if raised:   # 치켜든 팔은 머리 뒤로 (얼굴을 가리지 않게)
		_limb(Vector2(-2, -9), hand, skin, 5.0)
		_circ(hand, 2.6, skin)
	# 머리: 붉은 갈기 → 얼굴 → 뿔
	var c := Vector2(2, -17)
	var spikes := PackedVector2Array()
	for i in 9:
		var a := PI * 0.75 + PI * 1.1 * i / 8.0
		spikes.append(c + Vector2.RIGHT.rotated(a) * (11.0 if i % 2 == 0 else 7.5))
	spikes.append(c + Vector2(0, 4))
	_poly(spikes, mane)
	_circ(c, 8.0, skin)
	for hx in [-3.0, 3.5]:
		_poly([c + Vector2(hx - 1.8, -6.5), c + Vector2(hx + 1.8, -6.5), c + Vector2(hx + 0.5, -13)], Color(0.97, 0.93, 0.78))   # 뿔
	for e in [Vector2(1, -1.5), Vector2(5.5, -1.5)]:                                 # 부리부리한 눈
		_circ(c + e, 2.4, Color(1, 1, 0.9))
		body.draw_circle(c + e + Vector2(0.7, 0), 1.2, Color(0.8, 0.1, 0.05))
	body.draw_line(c + Vector2(-0.5, -4.5), c + Vector2(3, -3.5), OUTLINE, 2.0)       # 짙은 눈썹
	body.draw_line(c + Vector2(4.5, -3.5), c + Vector2(7.5, -4.5), OUTLINE, 2.0)
	body.draw_arc(c + Vector2(3.5, 3), 3.5, 0.15, PI - 0.15, 10, OUTLINE, 2.0)       # 큰 입
	_poly([c + Vector2(1.5, 4.5), c + Vector2(3, 4.5), c + Vector2(2.2, 7)], Color.WHITE, false)   # 송곳니
	_poly([c + Vector2(4.5, 4.5), c + Vector2(6, 4.5), c + Vector2(5.2, 7)], Color.WHITE, false)
	if not raised:
		_limb(Vector2(3, -8), hand, skin, 5.0)                                        # 방망이 쥔 앞팔
		_circ(hand, 2.6, skin)


# ----- 그리기 도우미 (body 노드에 그림) -----

## 사람 다리 두 개: 장면(swing)에 따라 앞뒤로 벌어짐. spread = 다리 벌림
func _legs(swing: float, pants: Color, shoe: Color, spread: float) -> void:
	var back_x := -spread - swing * 3.0
	var front_x := spread + swing * 3.0
	_limb(Vector2(-1.5, 4), Vector2(back_x, 13), pants.darkened(0.2), 3.5)
	_ellipse_on(body, Vector2(back_x + 1.5, 14), 3.2, 1.7, shoe.darkened(0.2))
	_limb(Vector2(1.5, 4), Vector2(front_x, 13), pants, 3.5)
	_ellipse_on(body, Vector2(front_x + 1.5, 14), 3.2, 1.7, shoe)


## 외곽선 있는 굵은 선 (팔다리)
func _limb(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	body.draw_line(a, b, OUTLINE, width + 2.0)
	body.draw_line(a, b, color, width)


func _poly(points, color: Color, outline := true) -> void:   # points: 점 배열 (Array 또는 PackedVector2Array)
	var pts := PackedVector2Array(points)
	body.draw_colored_polygon(pts, color)
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		body.draw_polyline(closed, OUTLINE, 1.5)


func _circ(c: Vector2, r: float, color: Color, outline := true) -> void:
	body.draw_circle(c, r, color)
	if outline:
		body.draw_arc(c, r, 0, TAU, 20, OUTLINE, 1.5)


## 도형의 split_x보다 왼쪽(등 쪽)만 어둡게 덮어 입체감을 줌
func _shade(points, split_x := -1.0, alpha := 0.16) -> void:
	var back_half := PackedVector2Array([Vector2(-100, -100), Vector2(split_x, -100), Vector2(split_x, 100), Vector2(-100, 100)])
	for part in Geometry2D.intersect_polygons(PackedVector2Array(points), back_half):
		body.draw_colored_polygon(part, Color(0, 0, 0, alpha))


func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 18:
		pts.append(c + Vector2(cos(TAU * i / 18.0) * rx, sin(TAU * i / 18.0) * ry))
	return pts


func _ellipse_on(canvas: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, outline := false) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		pts.append(c + Vector2(cos(TAU * i / 18.0) * rx, sin(TAU * i / 18.0) * ry))
	canvas.draw_colored_polygon(pts, color)
	if outline:
		pts.append(pts[0])
		canvas.draw_polyline(pts, OUTLINE, 1.5)
