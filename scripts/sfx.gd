extends Node
## 程序化音效合成器（autoload）：运行时生成 PCM 波形，零外部音频资源。
## Sfx.play(name) 音效钩子接口（实现 R8；DC1 零外部资源）

var _streams := {}

const _RATE: int = 22050

func _ready() -> void:
	_streams["coin"] = _make_tone(880.0, 0.12, 0.35)
	_streams["jump"] = _make_tone(520.0, 0.18, 0.5)
	_streams["crash"] = _make_noise(0.4, 0.6)

func play(sound_name: String) -> void:
	if not _streams.has(sound_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sound_name]
	player.bus = "Master"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _make_tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var count := int(dur * _RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / _RATE
		var env := 1.0 - float(i) / count
		var sample := sin(TAU * freq * t) * env * vol
		var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _make_noise(dur: float, vol: float) -> AudioStreamWAV:
	var count := int(dur * _RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var env := 1.0 - float(i) / count
		var sample := (randf() * 2.0 - 1.0) * env * vol
		var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = _RATE
	wav.stereo = false
	wav.data = bytes
	return wav
