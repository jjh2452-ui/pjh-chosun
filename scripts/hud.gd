extends CanvasLayer
## 화면 UI: 체력·경험치·레벨·직업·생존 시간 표시, 레벨업·일시정지·게임 오버 창.
## 게임이 일시정지돼도 이 UI는 계속 동작합니다(PROCESS_MODE_ALWAYS).

const UpgradeData = preload("res://scripts/upgrade_data.gd")
const JobData = preload("res://scripts/job_data.gd")

const SfxScript = preload("res://scripts/sfx.gd")
const SkillTreeScript = preload("res://scripts/skill_tree.gd")
const Meta = preload("res://scripts/meta.gd")
const Settings = preload("res://scripts/settings.gd")

enum State { TITLE, PLAY, PAUSE, LEVEL_UP, JOB_SELECT, GAME_OVER }

var main
var state := State.PLAY

var hp_bar: ProgressBar
var hp_label: Label
var xp_bar: ProgressBar
var level_label: Label
var time_label: Label
var kill_label: Label
var weapon_label: Label

var level_up_overlay: Control
var job_overlay: Control
var job_ids: Array = []
var level_up_buttons: Array = []
var level_up_options: Array = []
var pause_overlay: Control
var pause_info_label: Label
var game_over_overlay: Control
var game_over_label: Label
var game_over_title: Label

var banner_label: Label
var banner_time := 0.0
var hurt_overlay: TextureRect
var title_overlay: Control
var tree_overlay: Control
var skill_tree
var boss_box: Control
var boss_bar: ProgressBar

var mapae_label: Label         # 마패를 가지고 있을 때 화면 왼쪽 위 안내
var amhaeng_label: Label       # "암행어사 출두야!" 큰 글씨
var amhaeng_time := 0.0
var white_flash: ColorRect     # 출두 순간 화면이 하얗게 번쩍임
var coin_label: Label          # 타이틀 상점의 보유 엽전
var shop_buttons := {}         # 영구 강화 id → 구매 버튼
var shop_ids: Array = []
var difficulty_buttons := {}   # 난이도 id → 버튼
var difficulty_desc: Label
var fullscreen_button: Button

# ===== 조선풍 화면 꾸밈 =====
# 창은 한지 바탕에 먹 글씨, 제목은 붉은 붓글씨체.
# 제목 글꼴은 궁서 → 바탕 순서로 찾고(이 PC에는 바탕만 있음), 둘 다 없으면 기본 글꼴로 대체됩니다.
const PAPER := Color(0.95, 0.9, 0.78, 0.97)     # 한지
const PAPER_DARK := Color(0.88, 0.81, 0.66)
const INK := Color(0.15, 0.1, 0.07)             # 먹
const SEAL_RED := Color(0.62, 0.12, 0.08)       # 낙관(도장) 빨강
var brush_font: Font       # 제목용 붓글씨 (궁서, 없으면 바탕)
var paper_font: Font       # 창 안 본문용 (바탕)
var paper_theme: Theme     # 한지 창의 버튼 모양


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_style()
	_build_vignette()
	_build_status()
	_build_level_up()
	_build_job_select()
	_build_pause()
	_build_game_over()
	_build_skill_tree()
	_build_title()
	for overlay in [level_up_overlay, job_overlay, pause_overlay, game_over_overlay, title_overlay]:
		_paperize(overlay)


func _process(delta: float) -> void:
	if hurt_overlay.modulate.a > 0.0:
		hurt_overlay.modulate.a = maxf(0.0, hurt_overlay.modulate.a - delta * 2.5)
	if main == null or main.player == null:
		return
	var p = main.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	hp_label.text = "%d / %d" % [int(ceil(p.hp)), int(p.max_hp)]
	xp_bar.max_value = main.xp_to_next()
	xp_bar.value = main.xp
	level_label.text = "Lv.%d  %s   방어 %s · 이동 %d" % [main.level, p.job_name, str(snappedf(p.defense, 0.1)), int(p.move_stat)]
	time_label.text = "%s  %s / 10:00" % [Settings.DIFFICULTIES[Settings.difficulty]["name"], _format_time(main.elapsed)]
	kill_label.text = "처치 %d" % main.kills
	var names := PackedStringArray()
	for weapon in p.weapons.values():
		names.append("%s Lv.%d" % [weapon.display_name, weapon.level])
	weapon_label.text = "공격 스킬 %d/%d: %s" % [p.weapons.size(), UpgradeData.MAX_WEAPONS, ", ".join(names)]
	mapae_label.visible = p.has_mapae

	# 암행어사 출두 연출: 큰 글씨와 흰 번쩍임이 서서히 사라짐
	if amhaeng_time > 0.0:
		amhaeng_time -= delta
		amhaeng_label.modulate.a = clampf(amhaeng_time / 0.8, 0.0, 1.0)
		amhaeng_label.scale = Vector2.ONE * (1.0 + 0.15 * clampf(amhaeng_time - 1.6, 0.0, 1.0))
		amhaeng_label.visible = amhaeng_time > 0.0
	if white_flash.color.a > 0.0:
		white_flash.color.a = maxf(0.0, white_flash.color.a - delta * 1.5)

	# 보스 체력바
	var boss = main.boss
	boss_box.visible = boss != null and is_instance_valid(boss) and not boss.is_dead
	if boss_box.visible:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp

	# 알림 문구: 잠깐 보였다가 서서히 사라짐
	if banner_time > 0.0 and not get_tree().paused:
		banner_time -= delta
		banner_label.modulate.a = clampf(banner_time, 0.0, 1.0)
		banner_label.visible = banner_time > 0.0


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	# 전체화면 ↔ 창 모드: F11 또는 Alt+Enter (언제든지)
	if key == KEY_F11 or ((key == KEY_ENTER or key == KEY_KP_ENTER) and key_event.alt_pressed):
		_toggle_fullscreen()
		return
	# 타이틀 화면: 1·2·3 = 상점 구매, ← → = 난이도, ENTER·SPACE = 시작 (마우스로 버튼을 눌러도 됨)
	if state == State.TITLE:
		if key >= KEY_1 and key < KEY_1 + shop_ids.size():
			_buy(shop_ids[key - KEY_1])
		elif key == KEY_LEFT or key == KEY_RIGHT or key == KEY_A or key == KEY_D:
			var i: int = Settings.ORDER.find(Settings.difficulty)
			i = clampi(i + (1 if key == KEY_RIGHT or key == KEY_D else -1), 0, Settings.ORDER.size() - 1)
			_choose_difficulty(Settings.ORDER[i])
		elif key == KEY_ENTER or key == KEY_SPACE or key == KEY_KP_ENTER:
			_start_from_title()
		return
	if key == KEY_M:   # 소리 켜기/끄기 (언제든지)
		var muted := SfxScript.toggle_mute()
		show_banner("소리 끔 (M)" if muted else "소리 켬 (M)", 1.5)
		return
	# 스킬 트리: 일시정지·레벨업·전직 화면에서 T로 열고, T나 ESC로 닫음
	if tree_overlay.visible:
		if key == KEY_T or key == KEY_ESCAPE:
			tree_overlay.visible = false
		return
	if key == KEY_T and state in [State.PAUSE, State.LEVEL_UP, State.JOB_SELECT]:
		skill_tree.refresh()
		tree_overlay.visible = true
		return
	match state:
		State.PLAY:
			if key == KEY_ESCAPE or key == KEY_P:
				_set_paused(true)
			elif key == KEY_SPACE and main.player.has_mapae:
				main.use_amhaeng()
		State.PAUSE:
			if key == KEY_ESCAPE or key == KEY_P:
				_set_paused(false)
			elif key == KEY_R:
				main.restart()
		State.LEVEL_UP:
			if key >= KEY_1 and key <= KEY_3:
				_on_level_up_chosen(key - KEY_1)
		State.JOB_SELECT:
			if key >= KEY_1 and key <= KEY_2:
				_on_job_chosen(key - KEY_1)
		State.GAME_OVER:
			if key == KEY_R or key == KEY_ENTER:
				main.restart()
			elif key == KEY_T:
				main.restart_to_title()


# ===== 창 열고 닫기 (main.gd가 호출) =====

func show_level_up(options: Array) -> void:
	level_up_options = options
	for i in level_up_buttons.size():
		var btn: Button = level_up_buttons[i]
		if i >= options.size():
			btn.visible = false
			continue
		var id: String = options[i]
		var info: Dictionary = UpgradeData.get_info(id)
		var tag: String = UpgradeData.CATEGORY_NAMES[info["category"]]
		var title: String = "[%d] <%s> %s" % [i + 1, tag, info["name"]]
		var desc: String = info["desc"]
		if id != "heal":
			var cur: int = main.player.upgrade_levels.get(id, 0)
			if info.has("evolve"):
				title += "   ★★ 무기 진화!"
			elif info.get("new_weapon", false) and cur == 0:
				title += "   ★ 새 스킬"
			else:
				# 기본 무기 강화는 무기 레벨(1부터 시작)로 보여줌
				var shown: int = cur + 1 if info.has("weapon") and not info.get("new_weapon", false) else cur
				title += "   Lv.%d → %d" % [shown, shown + 1]
				desc = info.get("desc_up", desc)
		btn.text = title + "\n" + desc
		btn.visible = true
	level_up_overlay.visible = true
	state = State.LEVEL_UP


func show_title() -> void:
	title_overlay.visible = true
	state = State.TITLE
	_refresh_shop()


func _start_from_title() -> void:
	title_overlay.visible = false
	state = State.PLAY
	main.start_game()


func _choose_difficulty(id: String) -> void:
	if id != Settings.difficulty:
		main.sfx.play("pickup", 1.3)
	Settings.set_difficulty(id)
	_refresh_difficulty()


## 고른 난이도 버튼은 그 색으로 칠하고, 설명을 보여줌
func _refresh_difficulty() -> void:
	Settings.load_data()
	for id in difficulty_buttons:
		var btn: Button = difficulty_buttons[id]
		var color: Color = Settings.DIFFICULTIES[id]["color"]
		if id == Settings.difficulty:
			for st in ["normal", "hover", "pressed"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = color if st != "hover" else color.lightened(0.1)
				sb.border_color = INK
				sb.set_border_width_all(3)
				sb.set_corner_radius_all(4)
				sb.set_content_margin_all(8)
				btn.add_theme_stylebox_override(st, sb)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.text = "● " + Settings.DIFFICULTIES[id]["name"]
		else:
			for st in ["normal", "hover", "pressed"]:
				btn.remove_theme_stylebox_override(st)
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")
			btn.text = Settings.DIFFICULTIES[id]["name"]
	difficulty_desc.text = Settings.DIFFICULTIES[Settings.difficulty]["desc"]
	fullscreen_button.text = "창 모드로 (F11)" if Settings.fullscreen else "전체화면 (F11)"
	if Settings.is_embedded():
		fullscreen_button.text = "전체화면 불가\n(에디터 Embed 켜짐)"
		fullscreen_button.add_theme_font_size_override("font_size", 14)


func _toggle_fullscreen() -> void:
	if Settings.is_embedded():
		show_banner("에디터 Game 탭 안에서는 전체화면이 안 됩니다 — Game 탭 ⋮ 메뉴에서 Embed 끄기", 5.0)
		return
	Settings.toggle_fullscreen()
	if fullscreen_button != null:
		fullscreen_button.text = "창 모드로 (F11)" if Settings.fullscreen else "전체화면 (F11)"


## 상점에서 영구 강화 구매
func _buy(id: String) -> void:
	if Meta.buy(id):
		main.sfx.play("levelup")
	else:
		main.sfx.play("hurt", 1.5)   # 엽전 부족 또는 최대 레벨
	_refresh_shop()


func _refresh_shop() -> void:
	Meta.load_data()
	coin_label.text = "보유 엽전 : %d 냥" % Meta.coins
	for i in shop_ids.size():
		var id: String = shop_ids[i]
		var info: Dictionary = Meta.UPGRADES[id]
		var lv: int = Meta.levels[id]
		var btn: Button = shop_buttons[id]
		var price := "최대" if Meta.is_max(id) else "%d냥" % Meta.cost(id)
		btn.text = "[%d] %s  Lv.%d/%d   %s   —   %s" % [i + 1, info["name"], lv, info["max"], info["desc"], price]
		btn.disabled = Meta.is_max(id) or Meta.coins < Meta.cost(id)


## 암행어사 출두 연출 (main.use_amhaeng가 호출)
func show_amhaeng() -> void:
	amhaeng_time = 2.4
	amhaeng_label.visible = true
	amhaeng_label.modulate.a = 1.0
	white_flash.color.a = 0.85


## 맞았을 때 화면 가장자리가 붉게 번쩍임
func flash_hurt() -> void:
	hurt_overlay.modulate.a = 0.8


## 화면 위쪽에 알림 문구를 잠깐 띄웁니다.
func show_banner(text: String, seconds := 4.0) -> void:
	banner_label.text = text
	banner_label.visible = true
	banner_label.modulate.a = 1.0
	banner_time = seconds


func show_job_select() -> void:
	job_overlay.visible = true
	state = State.JOB_SELECT


## 레벨업 창과 전직 창을 닫습니다.
func hide_choice() -> void:
	level_up_overlay.visible = false
	job_overlay.visible = false
	tree_overlay.visible = false
	state = State.PLAY


## 결과 화면. result: "victory"(보스 처치) / "defeat"(사망) / "timeout"(10분 경과)
func show_game_over(result: String) -> void:
	match result:
		"victory":
			game_over_title.text = "승리!"
			game_over_title.add_theme_color_override("font_color", Color(0.7, 0.45, 0.05))   # 짙은 금빛
			game_over_label.text = "도깨비 대왕을 물리쳤습니다!\n\n"
		"timeout":
			game_over_title.text = "시간 종료"
			game_over_title.add_theme_color_override("font_color", Color(0.15, 0.3, 0.6))    # 쪽빛
			game_over_label.text = "10분을 버텼지만 도깨비 대왕은 달아났습니다.\n\n"
		_:
			game_over_title.text = "게임 오버"
			game_over_title.add_theme_color_override("font_color", SEAL_RED)
			game_over_label.text = ""
	game_over_label.text += "난이도  %s\n직업  %s\n생존 시간  %s\n도달 레벨  %d\n처치한 적  %d" % [
		Settings.DIFFICULTIES[Settings.difficulty]["name"], main.player.job_name, _format_time(main.elapsed), main.level, main.kills]
	game_over_label.text += "\n\n획득 엽전  +%d냥   (보유 %d냥)" % [main.coins_earned, Meta.coins]
	amhaeng_time = 0.0
	amhaeng_label.visible = false
	banner_label.visible = false
	pause_overlay.visible = false
	level_up_overlay.visible = false
	job_overlay.visible = false
	game_over_overlay.visible = true
	state = State.GAME_OVER


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_overlay.visible = paused
	tree_overlay.visible = false
	if paused:
		pause_info_label.text = _skill_summary()
	state = State.PAUSE if paused else State.PLAY


func _on_level_up_chosen(index: int) -> void:
	if state != State.LEVEL_UP or index >= level_up_options.size():
		return
	main.choose_upgrade(level_up_options[index])


func _on_job_chosen(index: int) -> void:
	if state != State.JOB_SELECT or index >= job_ids.size():
		return
	main.choose_job(job_ids[index])


## 일시정지 화면에 보여줄 보유 스킬·강화 목록
func _skill_summary() -> String:
	var p = main.player
	var lines := PackedStringArray()
	lines.append("[%s]  체력 %d · 방어력 %s · 이동력 %d   공격 스킬 %d/%d" % [p.job_name, int(p.max_hp), str(snappedf(p.defense, 0.1)), int(p.move_stat), p.weapons.size(), UpgradeData.MAX_WEAPONS])
	for weapon in p.weapons.values():
		lines.append("   %s  Lv.%d" % [weapon.display_name, weapon.level])
	lines.append("")
	lines.append("공통 강화")
	var any := false
	for id in p.upgrade_levels:
		var info: Dictionary = UpgradeData.UPGRADES[id]
		if info["category"] == "common":
			lines.append("   %s  Lv.%d/%d" % [info["name"], p.upgrade_levels[id], info["max_level"]])
			any = true
	if not any:
		lines.append("   (없음)")
	return "\n".join(lines)


func _format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


# ===== 화면 구성 =====

## 글꼴과 한지 버튼 모양 준비
func _build_style() -> void:
	var brush := SystemFont.new()
	brush.font_names = PackedStringArray(["Gungsuh", "궁서", "GungSeo", "Batang", "바탕"])
	brush_font = brush
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Batang", "바탕", "HANBatang", "Noto Serif CJK KR"])
	paper_font = serif

	paper_theme = Theme.new()
	var states := {
		"normal": Color(0.9, 0.83, 0.68),
		"hover": Color(0.98, 0.92, 0.76),
		"pressed": Color(0.8, 0.7, 0.52),
		"disabled": Color(0.85, 0.82, 0.76, 0.6),
	}
	for st in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[st]
		sb.border_color = Color(INK, 0.35 if st == "disabled" else 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(8)
		paper_theme.set_stylebox(st, "Button", sb)
	paper_theme.set_color("font_color", "Button", INK)
	paper_theme.set_color("font_hover_color", "Button", SEAL_RED)
	paper_theme.set_color("font_pressed_color", "Button", INK)
	paper_theme.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	paper_theme.set_font("font", "Button", serif)


## 한지 창 안의 글씨를 먹색으로 바꿈. 제목(meta "title")은 붉은 궁서체, meta "keep_color"는 색 유지
func _paperize(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			var label: Label = child
			label.add_theme_constant_override("outline_size", 0)
			if label.has_meta("title"):
				label.add_theme_font_override("font", brush_font)
				if not label.has_meta("keep_color"):
					label.add_theme_color_override("font_color", SEAL_RED)
			else:
				label.add_theme_font_override("font", paper_font)
				if not label.has_meta("keep_color"):
					label.add_theme_color_override("font_color", INK)
		_paperize(child)


## 게임 화면 위 정보 밑에 까는 반투명 받침
func _plate(alpha := 0.42) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, alpha)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	return sb

## 화면 가장자리를 은은하게 어둡게(비네트) + 맞았을 때 붉게 번쩍이는 테두리
func _build_vignette() -> void:
	add_child(_make_edge_glow(Color(0, 0, 0, 0.55)))
	hurt_overlay = _make_edge_glow(Color(0.9, 0.05, 0.05, 0.7))
	hurt_overlay.modulate.a = 0.0
	add_child(hurt_overlay)


func _make_edge_glow(edge_color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(edge_color, 0.0))
	gradient.set_color(1, edge_color)
	gradient.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.15, 1.15)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _build_skill_tree() -> void:
	tree_overlay = _make_overlay(0.6)
	skill_tree = SkillTreeScript.new()
	skill_tree.main = main
	skill_tree.title_font = brush_font
	tree_overlay.get_child(1).add_child(skill_tree)   # CenterContainer 안에 넣기


func _build_title() -> void:
	title_overlay = _make_overlay(0.55)
	var panel := _make_panel(title_overlay)
	var title := _make_label("조선 괴이록", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_meta("title", true)
	panel.add_child(title)
	var sub := _make_label("산적과 괴이가 들끓는 고갯길, 평범한 선비가 길을 나선다", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)
	var guide := _make_label(
		"이동 : WASD / 방향키      공격 : 자동      마패 : SPACE\n" +
		"5레벨에 문관 · 무관 전직      8분에 도깨비 대왕 등장\n" +
		"10:00 전에 도깨비 대왕을 물리치면 승리!      ESC 일시정지   M 소리   F11 전체화면", 16)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(guide)

	# 상점: 엽전으로 영구 강화 (회차를 넘어 유지)
	var shop_title := _make_label("— 엽전 상점 (영구 강화, 다음 판부터 계속 적용) —", 18)
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.set_meta("keep_color", true)
	shop_title.add_theme_color_override("font_color", SEAL_RED)
	panel.add_child(shop_title)
	coin_label = _make_label("", 20)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(coin_label)
	shop_ids = Meta.UPGRADES.keys()
	for i in shop_ids.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(620, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(_buy.bind(shop_ids[i]))
		panel.add_child(btn)
		shop_buttons[shop_ids[i]] = btn

	# 난이도: 버튼을 누르거나 ← → 로 고름 (다음에 켜도 기억)
	var diff_title := _make_label("— 난이도 (← → 로 선택) —", 18)
	diff_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_title.set_meta("keep_color", true)
	diff_title.add_theme_color_override("font_color", SEAL_RED)
	panel.add_child(diff_title)
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 14)
	panel.add_child(diff_row)
	for id in Settings.ORDER:
		var btn := Button.new()
		btn.text = Settings.DIFFICULTIES[id]["name"]
		btn.custom_minimum_size = Vector2(140, 42)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_choose_difficulty.bind(id))
		diff_row.add_child(btn)
		difficulty_buttons[id] = btn
	difficulty_desc = _make_label("", 16)
	difficulty_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(difficulty_desc)

	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 12)
	panel.add_child(start_row)
	var start := Button.new()
	start.text = "길을 나선다  (ENTER / SPACE)"
	start.custom_minimum_size = Vector2(0, 52)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_start_from_title)
	start_row.add_child(start)
	fullscreen_button = Button.new()
	fullscreen_button.custom_minimum_size = Vector2(190, 52)
	fullscreen_button.focus_mode = Control.FOCUS_NONE
	fullscreen_button.add_theme_font_size_override("font_size", 17)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	start_row.add_child(fullscreen_button)
	_refresh_difficulty()

func _build_status() -> void:
	# 맨 위 경험치 바
	xp_bar = _make_bar(Color(0.3, 0.75, 0.9), Vector2(0, 12))
	add_child(xp_bar)
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_bottom = 12

	# 왼쪽 위: 레벨·직업, 체력 (반투명 받침 위)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _plate())
	plate.position = Vector2(10, 18)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var box := VBoxContainer.new()
	plate.add_child(box)
	level_label = _make_label("", 22)
	box.add_child(level_label)
	var hp_row := HBoxContainer.new()
	box.add_child(hp_row)
	hp_bar = _make_bar(Color(0.8, 0.2, 0.2), Vector2(220, 18))
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(hp_bar)
	hp_label = _make_label("", 16)
	hp_row.add_child(hp_label)
	weapon_label = _make_label("", 16)
	box.add_child(weapon_label)
	mapae_label = _make_label("◆ 마패 보유 — SPACE : 암행어사 출두!", 18)
	mapae_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	mapae_label.visible = false
	box.add_child(mapae_label)

	# 가운데 위: 생존 시간 (반투명 받침 위)
	time_label = _make_label("", 28)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_stylebox_override("normal", _plate())
	add_child(time_label)
	time_label.anchor_left = 0.5
	time_label.anchor_right = 0.5
	time_label.offset_left = -150
	time_label.offset_right = 150
	time_label.offset_top = 16

	# 오른쪽 위: 처치 수
	kill_label = _make_label("", 20)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.add_theme_stylebox_override("normal", _plate())
	add_child(kill_label)
	kill_label.anchor_left = 1.0
	kill_label.anchor_right = 1.0
	kill_label.offset_left = -170
	kill_label.offset_right = -10
	kill_label.offset_top = 18

	# 가운데 아래: 보스 이름과 체력바 (보스가 있을 때만)
	var bbox := VBoxContainer.new()
	add_child(bbox)
	bbox.anchor_left = 0.5
	bbox.anchor_right = 0.5
	bbox.anchor_top = 1.0
	bbox.anchor_bottom = 1.0
	bbox.offset_left = -260
	bbox.offset_right = 260
	bbox.offset_top = -70
	bbox.offset_bottom = -20
	var boss_name := _make_label("도깨비 대왕", 24)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	boss_name.add_theme_font_override("font", brush_font)
	bbox.add_child(boss_name)
	boss_bar = _make_bar(Color(0.55, 0.25, 0.85), Vector2(520, 16))
	bbox.add_child(boss_bar)
	bbox.visible = false
	boss_box = bbox

	# 화면 위쪽 알림 문구: 한지 띠 위에 먹 글씨 (방 붙인 느낌)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_override("font", brush_font)
	banner_label.add_theme_font_size_override("font_size", 28)
	banner_label.add_theme_color_override("font_color", INK)
	var strip := StyleBoxFlat.new()
	strip.bg_color = PAPER
	strip.border_color = SEAL_RED
	strip.border_width_top = 3
	strip.border_width_bottom = 3
	strip.set_content_margin_all(10)
	strip.content_margin_left = 28
	strip.content_margin_right = 28
	strip.shadow_color = Color(0, 0, 0, 0.35)
	strip.shadow_size = 6
	banner_label.add_theme_stylebox_override("normal", strip)
	add_child(banner_label)
	banner_label.anchor_left = 0.5
	banner_label.anchor_right = 0.5
	banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.offset_top = 110
	banner_label.visible = false

	# 암행어사 출두: 흰 번쩍임 + 화면 가운데 큰 글씨
	white_flash = ColorRect.new()
	white_flash.color = Color(1, 1, 1, 0)
	white_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white_flash)
	white_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amhaeng_label = _make_label("암행어사 출두야!", 84)
	amhaeng_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amhaeng_label.add_theme_font_override("font", brush_font)
	amhaeng_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	amhaeng_label.add_theme_color_override("font_outline_color", Color(0.35, 0.05, 0.02))
	amhaeng_label.add_theme_constant_override("outline_size", 8)   # 너무 두꺼우면 붓 획 모양이 묻힘
	add_child(amhaeng_label)
	amhaeng_label.anchor_left = 0.5
	amhaeng_label.anchor_right = 0.5
	amhaeng_label.anchor_top = 0.5
	amhaeng_label.anchor_bottom = 0.5
	amhaeng_label.offset_left = -500
	amhaeng_label.offset_right = 500
	amhaeng_label.offset_top = -160
	amhaeng_label.offset_bottom = -60
	amhaeng_label.pivot_offset = Vector2(500, 50)
	amhaeng_label.visible = false


func _build_level_up() -> void:
	level_up_overlay = _make_overlay(0.45)
	var panel := _make_panel(level_up_overlay)
	panel.add_child(_make_title("레벨 업!"))
	panel.add_child(_make_label("강화를 하나 고르세요 (마우스 클릭 또는 1·2·3 키)   T : 스킬 트리 보기", 16))
	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(480, 72)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_level_up_chosen.bind(i))
		panel.add_child(btn)
		level_up_buttons.append(btn)


func _build_job_select() -> void:
	job_overlay = _make_overlay(0.6)
	var panel := _make_panel(job_overlay)
	panel.add_child(_make_title("전직의 갈림길"))
	var guide := _make_label(("%d레벨 달성! 걸어갈 길을 고르세요. 한 번 고르면 이번 판 동안 유지됩니다.\n" +
		"선비(체력 %d · 방어력 %d · 이동력 %d)에서 직업 능력치로 바뀌고, 얻은 공통 강화는 그대로 남습니다.   T : 스킬 트리 비교") % [
		JobData.JOB_LEVEL, int(JobData.SEONBI_MAX_HP), int(JobData.SEONBI_DEFENSE), int(JobData.SEONBI_MOVE)], 16)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(guide)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	job_ids = JobData.JOBS.keys()
	for i in job_ids.size():
		row.add_child(_make_job_card(job_ids[i], i))


## 직업 하나를 소개하는 카드: 이름, 플레이 방식, 대표 무기, 시작 무기, 선택 버튼
func _make_job_card(job_id: String, index: int) -> Control:
	var data: Dictionary = JobData.JOBS[job_id]
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_DARK
	style.border_color = data["color"]
	style.set_border_width_all(4)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var name_label := _make_label(data["name"], 36)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_meta("title", true)
	box.add_child(name_label)
	name_label.set_meta("keep_color", true)   # 직업 색 유지
	name_label.add_theme_color_override("font_color", data["color"].darkened(0.15))
	var stats := _make_label("체력 %d  ·  방어력 %d  ·  이동력 %d" % [int(data["max_hp"]), int(data["defense"]), int(data["move"])], 18)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.set_meta("keep_color", true)
	stats.add_theme_color_override("font_color", SEAL_RED)
	box.add_child(stats)
	box.add_child(_make_wrapped("[플레이 방식]\n" + data["style"]))
	box.add_child(_make_wrapped("[대표 무기]\n" + data["weapons"]))
	box.add_child(_make_wrapped("[전직 즉시 지급]\n" + data["start_weapon"]))

	var btn := Button.new()
	btn.text = "[%d] %s의 길을 걷는다" % [index + 1, data["name"]]
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_job_chosen.bind(index))
	box.add_child(btn)
	return card


func _make_wrapped(text: String) -> Label:
	var label := _make_label(text, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(320, 0)
	return label


func _build_pause() -> void:
	pause_overlay = _make_overlay(0.5)
	var panel := _make_panel(pause_overlay)
	panel.add_child(_make_title("일시정지"))
	pause_info_label = _make_label("", 17)
	panel.add_child(pause_info_label)
	panel.add_child(_make_label("ESC : 계속하기      T : 스킬 트리      R : 처음부터 다시      M : 소리", 18))


func _build_game_over() -> void:
	game_over_overlay = _make_overlay(0.6)
	var panel := _make_panel(game_over_overlay)
	game_over_title = _make_title("게임 오버")
	panel.add_child(game_over_title)
	game_over_label = _make_label("", 20)
	panel.add_child(game_over_label)
	var btn := Button.new()
	btn.text = "다시 하기 (R)"
	btn.custom_minimum_size = Vector2(240, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): main.restart())
	var to_title := Button.new()
	to_title.text = "엽전 상점·타이틀로 (T)"
	to_title.custom_minimum_size = Vector2(240, 44)
	to_title.focus_mode = Control.FOCUS_NONE
	to_title.add_theme_font_size_override("font_size", 18)
	to_title.pressed.connect(func(): main.restart_to_title())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(btn)
	row.add_child(to_title)
	panel.add_child(row)


# ===== UI 부품 만드는 도우미 함수 =====

func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_title(text: String) -> Label:
	var label := _make_label(text, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_meta("title", true)   # 한지 창에서 붉은 궁서체로 (_paperize)
	return label


func _make_bar(fill: Color, min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = min_size
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.07, 0.05, 0.75)
	bg.border_color = Color(0.85, 0.75, 0.5, 0.8)   # 옅은 금빛 테두리
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	fg.border_color = fill.lightened(0.35)          # 윗면 빛
	fg.border_width_top = 2
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


## 화면 전체를 어둡게 덮는 창(처음에는 숨김)
func _make_overlay(dim: float) -> Control:
	var root := Control.new()
	root.theme = paper_theme   # 한지 버튼
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	return root


## 창 가운데의 한지 상자. 먹빛 테두리와 그림자. 안에 위→아래로 내용을 쌓습니다.
func _make_panel(overlay: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(0.32, 0.22, 0.13)
	style.set_border_width_all(4)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(4, 6)
	panel.add_theme_stylebox_override("panel", style)
	overlay.get_child(1).add_child(panel)   # CenterContainer 안에 넣기
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	return vbox
