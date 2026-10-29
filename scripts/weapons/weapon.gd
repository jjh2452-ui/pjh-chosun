extends Node2D
## 모든 무기의 공통 부분. 플레이어의 자식으로 붙어서, 쿨타임이 끝날 때마다 attack()을 호출합니다.
## 새 무기를 만들 때는 이 파일을 extends 하고 attack()만 다시 정의하면 됩니다.

const Projectile = preload("res://scripts/bullet.gd")

var player
var main
var weapon_id := ""
var display_name := ""
var level := 1
var base_cooldown := 1.0   # 공격 간격(초). 공격 속도 강화가 여기에 곱해집니다.
var fire_pitch := 1.0      # 발사음 높이 (화살은 낮게, 화차는 높게)
var timer := 0.0


func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0 and attack():
		timer = base_cooldown * player.cooldown_mult


## 공격했으면 true, 공격할 대상이 없으면 false를 돌려줍니다. (각 무기 파일에서 다시 정의)
func attack() -> bool:
	return false


## 무기 레벨을 바꾸고 레벨에 맞게 능력치를 다시 계산합니다. (각 무기 파일에서 다시 정의)
func set_level(lv: int) -> void:
	level = lv


## 플레이어 위치에서 투사체를 하나 발사합니다.
func fire(dir: Vector2, speed: float, damage: float, style: String, pierce := 0) -> void:
	var p = Projectile.new()
	p.main = main
	p.velocity = dir * speed
	p.damage = damage
	p.style = style
	p.pierce = pierce
	p.position = player.global_position
	main.bullet_layer.add_child(p)
	main.sfx.play("shoot", fire_pitch)
