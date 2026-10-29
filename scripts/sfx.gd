extends Node
## 효과음. 소리 파일 없이 코드로 파형을 직접 만들어 재생합니다.
## 다른 스크립트에서는 main.sfx.play("hit") 처럼 부릅니다.
## M 키로 소리를 끄고 켤 수 있습니다(hud.gd).

const RATE := 22050           # 1초당 샘플 수 (낮을수록 가볍고 거친 소리)
const PLAYER_COUNT := 16      # 동시에 낼 수 있는 소리 수

# 같은 소리가 너무 자주 겹치지 않도록 최소 간격(초)
const MIN_GAP := {
	"hit": 0.05, "shoot": 0.05, "pop": 0.04, "pickup": 0.03,
	"slash": 0.08, "boom": 0.08, "warn": 0.25, "hurt": 0.15,
}
# 소리별 기본 음량(dB). 0이 원래 크기, -6은 절반쯤
const VOLUME := {
	"hit": -10.0, "shoot": -14.0, "pop": -9.0, "pickup": -12.0, "slash": -8.0,
	"boom": -4.0, "hurt": -3.0, "warn": -8.0, "levelup": -6.0, "heal": -6.0,
	"gong": -2.0, "victory": -4.0, "defeat": -4.0,
}

static var _cache := {}       # 만든 소리는 재시작해도 다시 만들지 않음

# ===== 배경음악 =====
# 파일을 바꾸려면 assets/audio/ 에 넣고 경로만 고치면 됩니다. (M 키로 효과음과 함께 꺼짐)
const BGM_PATH := "res://assets/audio/bgm.mp3"
const BGM_VOLUME := -12.0     # 효과음이 묻히지 않게 조금 작게 (dB)
static var bgm_player: AudioStreamPlayer   # 게임을 다시 시작해도 음악이 끊기지 않도록 한 번만 만듦

var players: Array[AudioStreamPlayer] = []
var next_player := 0
var last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 레벨업 창(일시정지) 중에도 소리가 나도록
	for i in PLAYER_COUNT:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	if _cache.is_empty():
		_build_all()
	_start_bgm()


## 배경음악을 무한 반복 재생. 장면(scene) 밖 root에 붙여서 재시작·타이틀 이동에도 이어서 흐름
func _start_bgm() -> void:
	if bgm_player != null and is_instance_valid(bgm_player):
		return
	if not ResourceLoader.exists(BGM_PATH):
		return
	var stream: AudioStreamMP3 = load(BGM_PATH)
	stream.loop = true
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = stream
	bgm_player.volume_db = BGM_VOLUME
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지·레벨업 창에서도 계속
	bgm_player.autoplay = true
	get_tree().root.add_child.call_deferred(bgm_player)


func play(sound: String, pitch := 1.0) -> void:
	if not _cache.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_played.get(sound, -10.0) < MIN_GAP.get(sound, 0.0):
		return
	last_played[sound] = now
	var p := players[next_player]
	next_player = (next_player + 1) % PLAYER_COUNT
	p.stream = _cache[sound]
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.volume_db = VOLUME.get(sound, 0.0)
	p.play()


static func toggle_mute() -> bool:
	var muted := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
	return muted


# ===== 소리 만들기 =====
# 각 소리는 -1 ~ 1 사이 숫자(샘플)의 배열입니다.

func _build_all() -> void:
	_cache["shoot"] = _wav(_sweep(0.07, 700.0, 300.0, 0.0, 0.6))
	_cache["hit"] = _wav(_noise_hit(0.05, 0.5))
	_cache["pop"] = _wav(_sweep(0.14, 320.0, 90.0, 0.35, 0.8))
	_cache["pickup"] = _wav(_sweep(0.06, 1300.0, 1800.0, 0.0, 0.5))
	_cache["slash"] = _wav(_whoosh(0.16))
	_cache["boom"] = _wav(_boom(0.55))
	_cache["hurt"] = _wav(_square_sweep(0.2, 160.0, 80.0))
	_cache["warn"] = _wav(_bell([880.0, 1320.0], 0.3, 0.5))
	_cache["gong"] = _wav(_bell([98.0, 162.0, 231.0, 297.0], 2.2, 0.9))     # 징
	# 국악 느낌의 5음 음계(궁·상·각·치·우)로 만든 짧은 가락
	_cache["levelup"] = _wav(_melody([523.0, 587.0, 698.0, 784.0, 880.0], 0.07))
	_cache["heal"] = _wav(_melody([587.0, 880.0], 0.09))
	_cache["victory"] = _wav(_melody([392.0, 440.0, 523.0, 587.0, 698.0, 784.0, 880.0, 1046.0], 0.12))
	_cache["defeat"] = _wav(_melody([440.0, 392.0, 349.0, 293.0, 262.0], 0.22))


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## 높이가 미끄러지듯 바뀌는 소리 (발사, 처치, 줍기). noise_mix = 잡음 섞는 비율
func _sweep(dur: float, f0: float, f1: float, noise_mix: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var s := sin(phase * TAU) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		out[i] = s * vol * pow(1.0 - t, 2.0)
	return out


## 짧고 딱딱한 타격음
func _noise_hit(dur: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * 0.5
		out[i] = lp * vol * pow(1.0 - t, 3.0)
	return out


## 칼 휘두르는 바람 소리: 잡음이 점점 날카로워졌다 사라짐
func _whoosh(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * lerpf(0.05, 0.6, t)
		out[i] = lp * 0.9 * sin(t * PI)
	return out


## 폭발: 낮은 울림 + 거친 잡음
func _boom(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * 0.08
		phase += lerpf(90.0, 40.0, t) / RATE
		out[i] = (lp * 2.5 + sin(phase * TAU) * 0.6) * pow(1.0 - t, 2.5) * 0.8
	return out


## 맞았을 때: 거친 네모파가 낮아짐
func _square_sweep(dur: float, f0: float, f1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		out[i] = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * 0.35 * (1.0 - t)
	return out


## 종·징처럼 여러 높이가 겹쳐 길게 울리는 소리
func _bell(freqs: Array, dur: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(dur * RATE)
	out.resize(n)
	for i in n:
		var time := float(i) / RATE
		var t := float(i) / n
		var s := 0.0
		for k in freqs.size():
			var f: float = freqs[k] * (1.0 + 0.004 * sin(time * 5.0))   # 살짝 떨리는 울림
			s += sin(time * f * TAU) / (k + 1)
		var attack := minf(1.0, time * 200.0)
		out[i] = s * vol * 0.5 * attack * pow(1.0 - t, 2.0)
	return out


## 음 여러 개를 차례로 (레벨업, 승리, 패배)
func _melody(freqs: Array, note_len: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var note_n := int(note_len * RATE)
	var tail := int(0.25 * RATE)
	out.resize(note_n * freqs.size() + tail)
	for k in freqs.size():
		var f: float = freqs[k]
		var len_n := note_n + tail
		for i in len_n:
			var idx := k * note_n + i
			if idx >= out.size():
				break
			var time := float(i) / RATE
			var env := minf(1.0, time * 150.0) * exp(-time * 6.0)
			out[idx] += (sin(time * f * TAU) + 0.3 * sin(time * f * 2.0 * TAU)) * 0.3 * env
	return out
