extends Node2D
## 잠깐 나타났다 사라지는 시각 효과 하나. main.spawn_fx()로 만듭니다.
##   "number" : 떠오르는 피해 숫자
##   "spark"  : 맞은 자리에 튀는 불꽃
##   "burst"  : 적이 쓰러질 때 번지는 먹물
##   "ring"   : 퍼져 나가는 고리 (레벨업, 폭발 등)

var kind := "number"
var life := 0.5
var max_life := 0.5
var text := ""
var color := Color.WHITE
var size := 16.0
var velocity := Vector2.ZERO
var dirs: Array = []          # 불꽃·먹물 조각이 튀는 방향


func setup(fx_kind: String, fx_color: Color, fx_size: float, fx_text := "") -> void:
	kind = fx_kind
	color = fx_color
	size = fx_size
	text = fx_text
	match kind:
		"number":
			max_life = 0.6
			velocity = Vector2(randf_range(-20, 20), -70)
		"spark":
			max_life = 0.16
			for i in 4:
				dirs.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.6, 1.0))
		"burst":
			max_life = 0.35
			for i in 6:
				dirs.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.5, 1.0))
		"ring":
			max_life = 0.4
	life = max_life


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += velocity * delta
	velocity *= 0.92
	queue_redraw()


func _draw() -> void:
	var p := 1.0 - life / max_life      # 0 → 1로 진행
	var a := 1.0 - p                     # 점점 투명하게
	match kind:
		"number":
			var font := ThemeDB.fallback_font
			var fs := int(size * (1.0 + 0.3 * maxf(0.0, 0.2 - p) / 0.2))   # 처음에 살짝 크게 튀어나옴
			draw_string_outline(font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 4, Color(0, 0, 0, a))
			draw_string(font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(color, a))
		"spark":
			# 맞은 순간 번쩍이는 네 갈래 별 + 바깥으로 튀는 불티
			var star := size * 0.45 * a
			draw_line(Vector2(-star, 0), Vector2(star, 0), Color(1, 1, 1, a), 2.5)
			draw_line(Vector2(0, -star), Vector2(0, star), Color(1, 1, 1, a), 2.5)
			draw_circle(Vector2.ZERO, star * 0.35, Color(color, a))
			for d in dirs:
				draw_line(d * size * p, d * size * (0.35 + p), Color(color, a), 1.8)
		"burst":
			# 먹물이 튀어 번지는 처치 자국: 큰 먹 얼룩 + 튄 방울 + 흘러내리는 줄기
			draw_circle(Vector2.ZERO, size * (0.55 + 0.5 * p), Color(color, 0.45 * a))
			draw_circle(Vector2(size * 0.2, -size * 0.1), size * (0.35 + 0.3 * p), Color(color, 0.35 * a))
			for d in dirs:
				var drop: Vector2 = d * size * (0.5 + 1.2 * p)
				draw_line(drop * 0.6, drop, Color(color, 0.5 * a), size * 0.12 * a + 0.5)
				draw_circle(drop, size * 0.22 * a, Color(color, 0.8 * a))
				draw_line(drop, drop + Vector2(0, size * 0.6 * p), Color(color, 0.4 * a), 1.2)   # 흘러내림
		"ring":
			# 붓으로 그은 듯한 두 겹 고리
			var r := size * (0.3 + 0.7 * p)
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, a), 4.0 * a + 1.0)
			draw_arc(Vector2.ZERO, r * 0.85, 0.4, TAU - 0.4, 40, Color(color, 0.5 * a), 2.0 * a + 0.5)
