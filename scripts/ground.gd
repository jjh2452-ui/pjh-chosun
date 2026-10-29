extends Node2D
## 바닥: 조선의 들판.
## 풀밭 위에 흙길, 풀포기, 들꽃, 억새, 돌, 소나무, 돌탑, 장승을 흩뿌립니다.
## 장식은 '월드 좌표'로 정해지므로 같은 자리에 가면 항상 같은 모양이 보입니다.
##
## 장식이 수천 개라 매 프레임 그리면 느려지므로, 그림 굽기를 씁니다:
##   플레이어가 CHUNK만큼 움직일 때만 '그리는 노드(painter)'가 SubViewport 안에 바닥을 한 번 그리고,
##   평소에는 그 결과 이미지 한 장(sprite)만 보여줍니다.
##   이 스크립트는 두 역할을 합니다: 보여주는 쪽(painting = false)과 그리는 쪽(painting = true).

const CHUNK := 256.0      # 이만큼 움직일 때마다 바닥을 다시 그림
const CELL := 64.0        # 작은 장식을 놓는 칸 크기
const BLOCK := 256.0      # 큰 장식(소나무 등)을 놓는 칸 크기
const HALF := 1152.0      # 플레이어 주변으로 그리는 범위

const GRASS := Color(0.40, 0.50, 0.29)
const GRASS_DARK := Color(0.30, 0.40, 0.22)
const GRASS_LIGHT := Color(0.50, 0.59, 0.33)
const DIRT := Color(0.66, 0.55, 0.38)
const DIRT_EDGE := Color(0.55, 0.45, 0.30)
const INK := Color(0.16, 0.12, 0.08)       # 민화풍 외곽선

# 장식이 얼마나 자주 나오는지 (0~1, 클수록 많음)
const PINE_CHANCE := 0.12
const CAIRN_CHANCE := 0.03
const JANGSEUNG_CHANCE := 0.012

var target
var snap := Vector2(INF, INF)
var painting := false     # true면 SubViewport 안에서 실제로 그리는 쪽

var vp: SubViewport
var painter               # 그리는 쪽 노드 (같은 스크립트)
var sprite: Sprite2D      # 구운 바닥 이미지


func _ready() -> void:
	if painting:
		set_process(false)
		return
	vp = SubViewport.new()
	vp.size = Vector2i(int(HALF * 2), int(HALF * 2))
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	painter = get_script().new()
	painter.painting = true
	painter.position = Vector2(HALF, HALF)   # 이미지 가운데가 (0, 0)
	vp.add_child(painter)
	sprite = Sprite2D.new()
	sprite.texture = vp.get_texture()
	add_child(sprite)


func _process(_delta: float) -> void:
	if target == null:
		return
	var s: Vector2 = (target.global_position / CHUNK).floor() * CHUNK
	if s != snap:
		snap = s
		sprite.global_position = snap
		painter.snap = snap
		painter.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE   # 이번 프레임에 한 번만 다시 굽기


## 좌표 (x, y)마다 항상 같은 0~1 사이 값을 돌려줌 (무작위처럼 보이지만 고정)
func _hash(x: float, y: float, seed_value: float) -> float:
	var h := sin(x * 12.9898 + y * 78.233 + seed_value * 37.719) * 43758.5453
	return h - floor(h)


func _draw() -> void:
	if not painting:
		return
	draw_rect(Rect2(-HALF, -HALF, HALF * 2, HALF * 2), GRASS)
	_draw_patches()
	_draw_paths()
	_draw_small()
	_draw_big()


# ----- 풀빛 얼룩: 밝은 풀, 짙은 풀, 마른 풀이 넓게 섞임 -----
func _draw_patches() -> void:
	var n := int(HALF / BLOCK) + 1
	var base := snap / BLOCK
	for ix in range(-n, n + 1):
		for iy in range(-n, n + 1):
			var wx := base.x + ix
			var wy := base.y + iy
			var pos := Vector2(ix + _hash(wx, wy, 2.0), iy + _hash(wx, wy, 3.0)) * BLOCK
			var h := _hash(wx, wy, 1.0)
			var r := 110.0 + 90.0 * _hash(wx, wy, 4.0)
			var col := GRASS_LIGHT if h < 0.4 else (GRASS_DARK if h < 0.75 else Color(0.55, 0.55, 0.32))
			# 옅은 원을 여러 겹 겹쳐서 가장자리가 부드럽게 번지도록
			for k in 4:
				var rr := r * (1.0 - k * 0.22)
				draw_circle(pos + Vector2(r * 0.1 * k, -r * 0.05 * k), rr, Color(col, 0.11))


# ----- 흙길: 세로·가로로 굽이굽이 이어지는 길 -----
func _path_x(col: int, wy: float) -> float:
	return col * 1900.0 + 280.0 * sin(wy / 430.0 + col * 1.7) + 90.0 * sin(wy / 160.0 + col)


func _path_y(row: int, wx: float) -> float:
	return row * 2300.0 + 260.0 * sin(wx / 470.0 + row * 2.3) + 80.0 * sin(wx / 150.0 + row)


func _draw_paths() -> void:
	var top := snap.y - HALF
	var left := snap.x - HALF
	# 세로 길
	for col in range(int(floor(left / 1900.0)) - 1, int(ceil((left + HALF * 2) / 1900.0)) + 1):
		var y := top
		while y <= top + HALF * 2:
			var p := Vector2(_path_x(col, y), y) - snap
			if absf(p.x) < HALF + 60:
				draw_circle(p, 40.0, DIRT_EDGE)
			y += 22.0
		y = top
		while y <= top + HALF * 2:
			var p := Vector2(_path_x(col, y), y) - snap
			if absf(p.x) < HALF + 60:
				draw_circle(p, 34.0, DIRT)
				if _hash(col, y, 9.0) < 0.3:   # 길 위 작은 자갈
					draw_circle(p + Vector2(_hash(col, y, 10.0) * 40 - 20, 6), 2.5, DIRT_EDGE)
			y += 22.0
	# 가로 길
	for row in range(int(floor(top / 2300.0)) - 1, int(ceil((top + HALF * 2) / 2300.0)) + 1):
		var x := left
		while x <= left + HALF * 2:
			var p := Vector2(x, _path_y(row, x)) - snap
			if absf(p.y) < HALF + 60:
				draw_circle(p, 36.0, DIRT_EDGE)
			x += 22.0
		x = left
		while x <= left + HALF * 2:
			var p := Vector2(x, _path_y(row, x)) - snap
			if absf(p.y) < HALF + 60:
				draw_circle(p, 30.0, DIRT)
			x += 22.0


# ----- 작은 장식: 풀포기, 들꽃, 돌, 억새 -----
func _draw_small() -> void:
	var base := snap / CELL
	var n := int(HALF / CELL)
	for ix in range(-n, n):
		for iy in range(-n, n):
			var wx := base.x + ix
			var wy := base.y + iy
			var h := _hash(wx, wy, 5.0)
			if h > 0.34:
				continue
			var pos := Vector2(ix + _hash(wx, wy, 6.0), iy + _hash(wx, wy, 7.0)) * CELL
			var v := _hash(wx, wy, 8.0)
			if h < 0.17:
				_tuft(pos, v)
			elif h < 0.23:
				_flowers(pos, v)
			elif h < 0.26:
				_stone(pos, 4.0 + 6.0 * v)
			elif h < 0.30:
				_eulalia(pos, v)


func _tuft(p: Vector2, v: float) -> void:
	var dark := Color(0.24, 0.35, 0.17)
	var light := Color(0.42, 0.55, 0.26)
	var blades := 3 + int(v * 3)
	for i in blades:
		var dx: float = (i - (blades - 1) / 2.0) * 3.0
		var tip := p + Vector2(dx * 1.6 + (v - 0.5) * 4.0, -8.0 - 4.0 * _hash(p.x, i, 1.0))
		draw_polyline(PackedVector2Array([p + Vector2(dx, 0), p + Vector2(dx * 1.2, -4), tip]), dark if i % 2 == 0 else light, 1.6)


func _flowers(p: Vector2, v: float) -> void:
	# 진달래(분홍) · 민들레(노랑) · 구절초(흰색)
	var colors := [Color(0.95, 0.55, 0.7), Color(1.0, 0.85, 0.3), Color(0.97, 0.95, 0.9)]
	var col: Color = colors[int(v * 3.0) % 3]
	for i in 3:
		var fp := p + Vector2(i * 6.0 - 6.0, (i % 2) * 4.0 - 2.0)
		draw_line(fp, fp + Vector2(0, 6), Color(0.3, 0.45, 0.2), 1.2)
		for k in 5:
			draw_circle(fp + Vector2.RIGHT.rotated(TAU * k / 5.0) * 2.2, 1.6, col)
		draw_circle(fp, 1.2, Color(0.95, 0.65, 0.2))


func _stone(p: Vector2, r: float) -> void:
	draw_circle(p + Vector2(1.5, 2.5), r, Color(0, 0, 0, 0.18))
	draw_circle(p, r, Color(0.56, 0.56, 0.52))
	draw_circle(p + Vector2(r * 0.25, r * 0.25), r * 0.75, Color(0.48, 0.48, 0.45))   # 아래쪽 그늘
	draw_circle(p - Vector2(r * 0.3, r * 0.35), r * 0.35, Color(0.72, 0.72, 0.68))   # 반짝임


## 억새: 가늘고 긴 줄기 끝에 하얀 이삭
func _eulalia(p: Vector2, v: float) -> void:
	for i in 4:
		var bend: float = (i - 1.5) * 4.0 + (v - 0.5) * 6.0
		var tip := p + Vector2(bend, -22.0 - i % 2 * 5.0)
		draw_polyline(PackedVector2Array([p + Vector2(i - 1.5, 0), p + Vector2(bend * 0.4, -12), tip]), Color(0.62, 0.6, 0.4), 1.4)
		draw_line(tip, tip + Vector2(bend * 0.3 + 2.0, -6), Color(0.93, 0.9, 0.8), 3.0)


# ----- 큰 장식: 소나무, 돌탑, 장승 (아래쪽에 있는 것이 위에 겹치도록 y 순서로) -----
func _draw_big() -> void:
	var base := snap / BLOCK
	var n := int(HALF / BLOCK)
	var items: Array = []
	for ix in range(-n, n):
		for iy in range(-n, n):
			var wx := base.x + ix
			var wy := base.y + iy
			var h := _hash(wx, wy, 11.0)
			var pos := Vector2(ix + 0.15 + 0.7 * _hash(wx, wy, 12.0), iy + 0.15 + 0.7 * _hash(wx, wy, 13.0)) * BLOCK
			var v := _hash(wx, wy, 14.0)
			if h < PINE_CHANCE:
				items.append([pos, "pine", v])
				if v < 0.4:   # 가끔 두 그루가 함께
					items.append([pos + Vector2(46, 14), "pine", v + 0.5])
			elif h < PINE_CHANCE + CAIRN_CHANCE:
				items.append([pos, "cairn", v])
			elif h < PINE_CHANCE + CAIRN_CHANCE + JANGSEUNG_CHANCE:
				items.append([pos, "jangseung", v])
	items.sort_custom(func(a, b): return a[0].y < b[0].y)
	for it in items:
		match it[1]:
			"pine":
				_pine(it[0], 0.85 + 0.45 * fmod(it[2], 1.0))
			"cairn":
				_cairn(it[0])
			"jangseung":
				_jangseung(it[0])


## 민화풍 소나무: 굽은 줄기 + 납작한 솔잎 덩어리를 층층이
func _pine(p: Vector2, s: float) -> void:
	_ellipse(p + Vector2(4, 2) * s, 30.0 * s, 9.0 * s, Color(0, 0, 0, 0.2))
	var trunk := PackedVector2Array([p, p + Vector2(-4, -20) * s, p + Vector2(5, -42) * s, p + Vector2(0, -62) * s])
	draw_polyline(trunk, INK, 9.0 * s)
	draw_polyline(trunk, Color(0.5, 0.33, 0.2), 6.5 * s)
	draw_line(p + Vector2(-2, -30) * s, p + Vector2(-18, -40) * s, INK, 3.5 * s)   # 곁가지
	draw_line(p + Vector2(3, -46) * s, p + Vector2(18, -56) * s, INK, 3.0 * s)
	var leaf := Color(0.17, 0.32, 0.2)
	var leaf_hi := Color(0.29, 0.46, 0.27)
	for f in [[Vector2(-18, -42), 20.0, 8.0], [Vector2(18, -57), 21.0, 8.5], [Vector2(-2, -70), 18.0, 7.5], [Vector2(6, -84), 12.0, 5.5]]:
		var c: Vector2 = p + f[0] * s
		_ellipse(c, f[1] * s + 1.5, f[2] * s + 1.5, INK)
		_ellipse(c, f[1] * s, f[2] * s, leaf)
		_ellipse(c + Vector2(-2, -2.5) * s, f[1] * s * 0.7, f[2] * s * 0.45, leaf_hi)


## 돌탑: 소원을 빌며 쌓은 돌무더기
func _cairn(p: Vector2) -> void:
	_ellipse(p + Vector2(3, 2), 22.0, 6.0, Color(0, 0, 0, 0.2))
	var y := 0.0
	var w := 18.0
	for i in 5:
		_ellipse(p + Vector2(sin(i * 1.7) * 2.0, y - 4.0), w + 1.5, 5.5, INK)
		_ellipse(p + Vector2(sin(i * 1.7) * 2.0, y - 4.0), w, 4.5, Color(0.6, 0.6, 0.56).darkened(0.05 * i))
		y -= 8.0
		w *= 0.75


## 장승: 천하대장군·지하여장군 한 쌍
func _jangseung(p: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var b := p + Vector2(side * 14.0, 0)
		_ellipse(b + Vector2(3, 2), 10.0, 3.5, Color(0, 0, 0, 0.2))
		draw_rect(Rect2(b + Vector2(-6, -46), Vector2(12, 46)), Color(0.55, 0.38, 0.22))
		draw_rect(Rect2(b + Vector2(-6, -46), Vector2(12, 46)), INK, false, 1.5)
		var face := b + Vector2(0, -38)
		draw_circle(face + Vector2(-2.5, 0), 2.2, Color.WHITE)       # 왕방울 눈
		draw_circle(face + Vector2(2.5, 0), 2.2, Color.WHITE)
		draw_circle(face + Vector2(-2.5, 0.3), 1.1, INK)
		draw_circle(face + Vector2(2.5, 0.3), 1.1, INK)
		draw_line(face + Vector2(-5, -3), face + Vector2(-1, -2), INK, 1.5)   # 부릅뜬 눈썹
		draw_line(face + Vector2(5, -3), face + Vector2(1, -2), INK, 1.5)
		draw_line(face + Vector2(-3, 6), face + Vector2(3, 6), INK, 1.5)      # 입
		var hat := Color(0.12, 0.1, 0.1) if side < 0 else Color(0.75, 0.2, 0.15)
		draw_rect(Rect2(b + Vector2(-7, -54), Vector2(14, 8)), hat)           # 관모
		draw_line(b + Vector2(0, -28), b + Vector2(0, -6), Color(0.15, 0.1, 0.08), 1.0)   # 새긴 글씨 자리


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(c + Vector2(cos(TAU * i / 16.0) * rx, sin(TAU * i / 16.0) * ry))
	draw_colored_polygon(pts, color)
