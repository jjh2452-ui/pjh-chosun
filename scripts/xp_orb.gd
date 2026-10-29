extends Node2D
## 떨어진 물건. 플레이어의 획득 범위에 들어오면 끌려가서 흡수됩니다.
##   kind "xp"   : 경험치 옥구슬 (value = 경험치. 많을수록 크고 노랗게)
##   kind "food" : 주먹밥 (체력 회복)

var main
var kind := "xp"
var value := 1
var magnet := false
var fly_speed := 0.0


func _process(delta: float) -> void:
	var player = main.player
	var dist: float = global_position.distance_to(player.global_position)
	if not magnet and dist < player.pickup_range:
		magnet = true
	if magnet:
		fly_speed += 1200.0 * delta
		global_position = global_position.move_toward(player.global_position, fly_speed * delta)
		if dist < player.radius + 4.0:
			if kind == "food":
				main.heal_player(main.FOOD_HEAL)
			else:
				main.add_xp(value)
			queue_free()


func _draw() -> void:
	if kind == "food":
		# 주먹밥: 흰 삼각형 + 김
		draw_circle(Vector2(0, 5), 9.0, Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(10, 7), Vector2(-10, 7)]), Color(0.98, 0.97, 0.92))
		draw_rect(Rect2(-5, 1, 10, 7), Color(0.1, 0.15, 0.1))
		return
	# 옥구슬: 경험치가 많을수록 크고 노랗게 (두목은 큰 금빛 구슬)
	var s := 1.0 + minf(value, 25) / 12.0
	var color := Color(0.35, 0.85, 0.7) if value < 10 else Color(1.0, 0.85, 0.3)
	draw_circle(Vector2.ZERO, 9.0 * s, Color(color, 0.18))   # 은은한 빛
	var pts := PackedVector2Array([Vector2(0, -7) * s, Vector2(5, 0) * s, Vector2(0, 7) * s, Vector2(-5, 0) * s])
	draw_colored_polygon(pts, color)
	draw_circle(Vector2(-1, -2) * s, 1.5 * s, Color(1, 1, 1, 0.8))
