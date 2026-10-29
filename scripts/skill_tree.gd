extends Control
## 스킬 트리 화면. upgrade_data.gd의 데이터(선행 조건 requires)를 읽어 자동으로 그립니다.
## 새 스킬을 데이터에 추가하면 이 화면에도 저절로 나타납니다.
##
## 칸 색깔: 금색 = 최대 레벨 / 초록 = 보유 중 / 흰 테두리 = 다음 레벨업에 나올 수 있음 / 회색 = 아직 잠김
## 마우스를 칸 위에 올리면 아래쪽에 설명이 나옵니다.

const UpgradeData = preload("res://scripts/upgrade_data.gd")
const JobData = preload("res://scripts/job_data.gd")
const Settings = preload("res://scripts/settings.gd")

const SIZE := Vector2(1160, 640)

const COL_MAX := Color(0.95, 0.78, 0.3)
const COL_OWNED := Color(0.45, 0.85, 0.45)
const COL_OPEN := Color(0.92, 0.92, 0.88)
const COL_LOCKED := Color(0.45, 0.45, 0.45)
const PAPER := Color(0.95, 0.9, 0.78)      # 한지
const INK := Color(0.15, 0.1, 0.07)        # 먹
const SEAL_RED := Color(0.62, 0.12, 0.08)  # 낙관 빨강

var main
var title_font: Font       # 제목 붓글씨 (hud.gd가 넣어 줌)
var boxes: Array = []      # 화면에 그린 칸들: {rect, id, title, desc}
var hover := -1            # 마우스가 올라간 칸 번호


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh() -> void:
	hover = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var found := -1
		for i in boxes.size():
			if boxes[i]["rect"].has_point(motion.position):
				found = i
		if found != hover:
			hover = found
			queue_redraw()


# ===== 칸의 상태 =====

## 강화 하나의 상태: "max" / "owned" / "open" / "locked" / "full" / "prejob"
## 두 번째 값은 칸에 적을 짧은 설명
func _state(id: String) -> Array:
	var p = main.player
	var data: Dictionary = UpgradeData.UPGRADES[id]
	var cur: int = p.upgrade_levels.get(id, 0)
	if cur >= data["max_level"]:
		return ["max", "최대 레벨"]
	if cur > 0:
		return ["owned", "보유 중"]
	if data.has("evolve") and not Settings.value("evolve"):
		return ["locked", "하드 모드 전용"]
	var requires: Dictionary = data.get("requires", {})
	for req_id in requires:
		if p.upgrade_levels.get(req_id, 0) < requires[req_id]:
			return ["locked", "필요: %s Lv.%d" % [_short_name(req_id), requires[req_id]]]
	if data["category"] != "common" and p.job == "":
		return ["prejob", "전직 후 열림"]
	if data.get("new_weapon", false) and p.weapons.size() >= UpgradeData.MAX_WEAPONS:
		return ["full", "공격 스킬 4개 가득"]
	return ["open", "선택 가능"]


func _short_name(id: String) -> String:
	var full: String = UpgradeData.UPGRADES[id]["name"]
	var cut := full.find(" (")
	return full.substr(0, cut) if cut >= 0 else full


func _state_color(state: String) -> Color:
	match state:
		"max":
			return COL_MAX
		"owned":
			return COL_OWNED
		"open":
			return COL_OPEN
	return COL_LOCKED


# ===== 트리 모양 계산 =====

## 직업 하나의 트리: 기본 무기(뿌리)에서 시작해, 선행 조건을 따라 가지를 뻗습니다.
## 결과: [{id, parent, depth, row, req_level}]  (id가 "root"면 기본 무기)
func _job_layout(job_id: String) -> Array:
	var children := {"root": []}
	var req_level := {}
	for id in UpgradeData.UPGRADES:
		var data: Dictionary = UpgradeData.UPGRADES[id]
		if data["category"] != job_id or data.has("evolve"):
			continue   # 진화는 트리 아래 따로 한 줄로 그림
		var requires: Dictionary = data.get("requires", {})
		var parent := "root"
		req_level[id] = 0
		for r in requires:
			parent = r
			req_level[id] = requires[r]
		if not children.has(parent):
			children[parent] = []
		children[parent].append(id)
	var result: Array = []
	var next_row := [0]   # 배열에 담아야 아래 함수 안에서 바꿀 수 있음
	_place("root", "", 0, children, req_level, result, next_row)
	return result


func _place(id: String, parent: String, depth: int, children: Dictionary, req_level: Dictionary, result: Array, next_row: Array) -> int:
	var kids: Array = children.get(id, [])
	var row: int
	if kids.is_empty():
		row = next_row[0]
		next_row[0] += 1
	else:
		var rows: Array = []
		for k in kids:
			rows.append(_place(k, id, depth + 1, children, req_level, result, next_row))
		row = rows[0]
	result.append({"id": id, "parent": parent, "depth": depth, "row": row, "req": req_level.get(id, 0)})
	return row


# ===== 그리기 =====

func _draw() -> void:
	boxes.clear()
	var font := ThemeDB.fallback_font
	var p = main.player

	# 배경과 제목
	# 한지 바탕에 먹빛 테두리 (칸들은 먹으로 찍은 듯 어둡게)
	draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.32, 0.22, 0.13), false, 4.0)
	draw_rect(Rect2(Vector2(8, 8), SIZE - Vector2(16, 16)), Color(SEAL_RED, 0.5), false, 1.5)
	draw_string(title_font if title_font else font, Vector2(0, 50), "스킬 트리", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 38, SEAL_RED)
	draw_string(font, Vector2(0, 74), "[%s]  공격 스킬 %d/%d" % [p.job_name, p.weapons.size(), UpgradeData.MAX_WEAPONS],
		HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 18, INK)

	# 공통 강화: 한 줄로
	draw_string(font, Vector2(40, 112), "공통 강화", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, SEAL_RED)
	var common: Array = []
	for id in UpgradeData.UPGRADES:
		if UpgradeData.UPGRADES[id]["category"] == "common":
			common.append(id)
	var gap := 12.0   # 칸 수에 맞춰 너비를 나눔
	var cw := minf(204.0, (SIZE.x - 80.0 - gap * (common.size() - 1)) / common.size())
	if common.size() > 1:
		gap = (SIZE.x - 80.0 - cw * common.size()) / (common.size() - 1)
	for i in common.size():
		_draw_upgrade_box(Rect2(40 + i * (cw + gap), 124, cw, 78), common[i], font)

	# 직업 트리: 전직 전이면 두 직업을 나란히, 전직 후면 내 직업만 크게
	var jobs: Array = [p.job] if p.job != "" else JobData.JOBS.keys()
	var area_w := (SIZE.x - 80.0) / jobs.size()
	for j in jobs.size():
		var left := 40.0 + j * area_w
		var job_id: String = jobs[j]
		var data: Dictionary = JobData.JOBS[job_id]
		var heading: String = data["name"] + " 스킬" + ("" if p.job != "" else "  (5레벨 전직 후)")
		draw_string(font, Vector2(left, 250), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, data["color"].darkened(0.15))
		_draw_job_tree(job_id, left, area_w, font)

	# 아래쪽: 마우스를 올린 칸의 설명, 또는 사용법
	draw_line(Vector2(40, SIZE.y - 70), Vector2(SIZE.x - 40, SIZE.y - 70), Color(0.8, 0.65, 0.3, 0.4), 1.0)
	if hover >= 0:
		var b: Dictionary = boxes[hover]
		draw_string(font, Vector2(40, SIZE.y - 42), b["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SEAL_RED)
		draw_string(font, Vector2(40, SIZE.y - 16), b["desc"], HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - 80, 15, INK)
	else:
		draw_string(font, Vector2(40, SIZE.y - 42), "칸 위에 마우스를 올리면 설명이 보입니다.      T / ESC : 닫기",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
		var x := 40.0
		for item in [[COL_MAX, "최대 레벨"], [COL_OWNED, "보유 중"], [COL_OPEN, "다음 레벨업에 나올 수 있음"], [COL_LOCKED, "아직 잠김"]]:
			draw_rect(Rect2(x, SIZE.y - 30, 14, 14), item[0])
			draw_string(font, Vector2(x + 20, SIZE.y - 18), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
			x += 60.0 + item[1].length() * 14.0


func _draw_job_tree(job_id: String, left: float, area_w: float, font: Font) -> void:
	var layout := _job_layout(job_id)
	var single := area_w > 700.0
	var bw := 230.0 if single else 150.0          # 칸 너비
	var col_gap := 90.0 if single else 26.0       # 칸 사이 가로 간격
	var row_h := 120.0 if single else 110.0
	var top := 275.0
	var total_w := bw * 3 + col_gap * 2
	var x0 := left + (area_w - total_w) / 2.0
	var rects := {}
	for n in layout:
		rects[n["id"]] = Rect2(x0 + n["depth"] * (bw + col_gap), top + n["row"] * row_h, bw, 84)

	# 연결선 (선행 조건 레벨이 2 이상이면 선 위에 표시)
	for n in layout:
		if n["parent"] == "":
			continue
		var a: Rect2 = rects[n["parent"]]
		var b: Rect2 = rects[n["id"]]
		var from := Vector2(a.end.x, a.get_center().y)
		var to := Vector2(b.position.x, b.get_center().y)
		var mid_x := (from.x + to.x) / 2.0
		var line_col := Color(INK, 0.75)
		draw_polyline(PackedVector2Array([from, Vector2(mid_x, from.y), Vector2(mid_x, to.y), to]), line_col, 2.0)
		draw_colored_polygon(PackedVector2Array([to, to + Vector2(-8, -5), to + Vector2(-8, 5)]), line_col)
		if n["req"] >= 2:
			draw_string(font, Vector2(mid_x - 20, to.y - 6), "Lv.%d" % n["req"], HORIZONTAL_ALIGNMENT_CENTER, 40, 13, SEAL_RED)

	for n in layout:
		if n["id"] == "root":
			_draw_root_box(rects["root"], job_id, font)
		else:
			_draw_upgrade_box(rects[n["id"]], n["id"], font)

	# 무기 진화 (하드 모드): 트리 아래 한 줄. 필요한 두 스킬은 칸 설명에 적힘
	var evos: Array = []
	for id in UpgradeData.UPGRADES:
		if UpgradeData.UPGRADES[id]["category"] == job_id and UpgradeData.UPGRADES[id].has("evolve"):
			evos.append(id)
	if evos.is_empty():
		return
	var evo_top := 490.0
	draw_string(font, Vector2(left, evo_top - 6), "무기 진화 (하드 모드)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SEAL_RED)
	var ew := bw
	var egap := 20.0
	var ex := left + (area_w - (ew * evos.size() + egap * (evos.size() - 1))) / 2.0
	for i in evos.size():
		_draw_upgrade_box(Rect2(ex + i * (ew + egap), evo_top, ew, 78), evos[i], font)


## 직업 기본 무기 칸 (전직하면 바로 얻는 무기)
func _draw_root_box(r: Rect2, job_id: String, font: Font) -> void:
	var p = main.player
	var data: Dictionary = JobData.JOBS[job_id]
	var owned: bool = p.job == job_id
	var col := COL_OWNED if owned else COL_LOCKED
	draw_rect(r, Color(0.16, 0.2, 0.15) if owned else Color(0.12, 0.12, 0.12))
	draw_rect(r, data["color"].lightened(0.2), false, 3.0)
	var weapon_name: String = data["start_weapon_name"]
	draw_string(font, r.position + Vector2(0, 28), weapon_name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color.WHITE if owned else COL_LOCKED)
	var sub := "전직 시 지급"
	if owned:
		sub = "기본 무기 Lv.%d" % p.weapons[data["start_weapon_id"]].level
	draw_string(font, r.position + Vector2(0, 56), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, col)
	boxes.append({"rect": r, "id": "root", "title": weapon_name + " (" + data["name"] + " 기본 무기)", "desc": data["start_weapon"]})


## 강화 하나의 칸: 이름, 레벨 칸(■□□), 상태
func _draw_upgrade_box(r: Rect2, id: String, font: Font) -> void:
	var p = main.player
	var data: Dictionary = UpgradeData.UPGRADES[id]
	var st := _state(id)
	var state: String = st[0]
	var col := _state_color(state)
	var cur: int = p.upgrade_levels.get(id, 0)
	var maxl: int = data["max_level"]
	var is_hover := boxes.size() == hover

	var fill := Color(0.14, 0.13, 0.11)
	if state == "max":
		fill = Color(0.32, 0.25, 0.08)
	elif state == "owned":
		fill = Color(0.15, 0.24, 0.14)
	elif state in ["locked", "full", "prejob"]:
		fill = Color(0.1, 0.1, 0.1)
	if is_hover:
		fill = fill.lightened(0.15)
	draw_rect(r, fill)
	draw_rect(r, col, false, 3.0 if state != "locked" else 1.5)

	var title := _short_name(id)
	if data.has("evolve"):
		title = "★★ " + title  # 무기 진화
	elif data.get("new_weapon", false):
		title = "★ " + title   # 새 공격 스킬
	var text_col := Color.WHITE if state in ["max", "owned", "open"] else COL_LOCKED
	draw_string(font, r.position + Vector2(0, 26), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, text_col)

	# 레벨 칸: 얻은 만큼 채움
	var pip := 12.0
	var pip_gap := 5.0
	var px := r.position.x + (r.size.x - (pip * maxl + pip_gap * (maxl - 1))) / 2.0
	for i in maxl:
		var pr := Rect2(px + i * (pip + pip_gap), r.position.y + 38, pip, pip)
		if i < cur:
			draw_rect(pr, col)
		else:
			draw_rect(pr, Color(col, 0.6), false, 1.5)

	# 상태 글자: 좁은 칸(전직 전 두 직업 비교)에서는 짧게. 자세한 내용은 마우스를 올리면 보임
	var status: String = "Lv.%d/%d · %s" % [cur, maxl, st[1]]
	if state == "locked":
		status = st[1] if r.size.x >= 200.0 else "선행 스킬 필요"
	elif r.size.x < 200.0:
		status = st[1]
	draw_string(font, r.position + Vector2(0, 74), status, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, col)

	var desc: String = data["desc"]
	if data.has("evolve"):
		var need := PackedStringArray()
		for req_id in data["requires"]:
			need.append("%s Lv.%d" % [_short_name(req_id), data["requires"][req_id]])
		desc += "   (조건: " + " + ".join(need) + ")"
	if data.has("desc_up"):
		desc += "   /   강화: " + data["desc_up"]
	boxes.append({"rect": r, "id": id, "title": data["name"] + "  —  " + st[1], "desc": desc})
