extends Node
## Original procedural audio; no third-party sound assets or runtime downloads.
var enabled: bool = true
var bank: Dictionary = {}
var voices: Array = []
var voice: int = 0

func _ready() -> void:
	for item in [["click",540.0,680.0,0.045],["laser",760.0,190.0,0.095],["hit",110.0,48.0,0.12],["scan",440.0,980.0,0.18],["skill",180.0,540.0,0.23],["win",520.0,1040.0,0.5]]:
		bank[item[0]] = tone(float(item[1]),float(item[2]),float(item[3]))
	for i in range(6):
		var player = AudioStreamPlayer.new()
		player.volume_db = -21
		add_child(player)
		voices.append(player)

func tone(start: float, end: float, duration: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(rate*duration)
	var data = PackedByteArray()
	data.resize(count*2)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i)/count
		phase += TAU*lerpf(start,end,t)/rate
		var envelope: float = minf(1.0,t*25.0)*pow(1.0-t,1.7)
		var sample: float = (sin(phase)+sin(phase*2.0)*0.15)*envelope*0.6
		data.encode_s16(i*2,int(sample*32760))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func play(id: String) -> void:
	if not enabled or not bank.has(id) or voices.is_empty():
		return
	voice = (voice+1)%voices.size()
	voices[voice].stream = bank[id]
	voices[voice].play()
