extends Node
class_name UTownLeisureAudio
## Fully generated original PCM tones. Small, no imported copyrighted sounds.
## All sound files are built once in memory at 22050 Hz (Godot 4.4).

const SAMPLE_RATE: int = 22050
var players: Dictionary = {}
var enabled: bool = true

func _ready() -> void:
    var presets: Array[Dictionary] = [
        {"id": "move", "frequency": 510.0, "duration": 0.075, "harmonic": 0.15, "volume": -21.0},
        {"id": "card", "frequency": 335.0, "duration": 0.11, "harmonic": 0.18, "volume": -20.0},
        {"id": "win", "frequency": 660.0, "duration": 0.43, "harmonic": 0.35, "volume": -16.0},
        {"id": "lose", "frequency": 205.0, "duration": 0.19, "harmonic": 0.25, "volume": -22.0},
        {"id": "social", "frequency": 445.0, "duration": 0.24, "harmonic": 0.29, "volume": -20.0},
        {"id": "ending", "frequency": 850.0, "duration": 0.68, "harmonic": 0.40, "volume": -18.0}
    ]
    for preset in presets:
        var player := AudioStreamPlayer.new()
        player.name = "LeisureCue_" + str(preset["id"])
        player.stream = _make_tone(float(preset["frequency"]), float(preset["duration"]), float(preset["harmonic"]))
        player.volume_db = float(preset["volume"])
        add_child(player)
        players[str(preset["id"])] = player
    var cheer := AudioStreamPlayer.new()
    cheer.name = "LeisureCue_OriginalClaps"
    cheer.stream = _make_celebration_cheer()
    cheer.volume_db = -23.0
    add_child(cheer)
    players["cheer"] = cheer

func _make_celebration_cheer() -> AudioStreamWAV:
    # Original synthetic clap/noise and vowel-like pitch sweep; no borrowed
    # crowd sample or recordings. Rendered once, never processed per frame.
    var wave := AudioStreamWAV.new()
    wave.format = AudioStreamWAV.FORMAT_16_BITS
    wave.mix_rate = SAMPLE_RATE
    wave.stereo = false
    var count: int = SAMPLE_RATE
    var buffer := PackedByteArray()
    buffer.resize(count * 2)
    var seed: int = 13023
    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        seed = (seed * 1103515245 + 12345) & 2147483647
        var noise: float = float(seed % 65536) / 32768.0 - 1.0
        var pulse: float = pow(maxf(0.0, sin(TAU * 5.0 * t)), 15.0)
        var fade: float = minf(1.0, t * 17.0) * pow(1.0 - t, 1.2)
        var whoop: float = sin(TAU * (350.0 + 135.0 * t + 18.0 * sin(TAU * 3.0 * t)) * t)
        var sample_value: int = clampi(int(round((noise * (0.22 + 0.75 * pulse) + whoop * 0.11) *
            fade * 10500.0)), -32768, 32767)
        buffer[i * 2] = sample_value & 255
        buffer[i * 2 + 1] = (sample_value >> 8) & 255
    wave.data = buffer
    return wave

func _make_tone(frequency: float, duration_s: float, harmonic: float) -> AudioStreamWAV:
    var wave := AudioStreamWAV.new()
    wave.format = AudioStreamWAV.FORMAT_16_BITS
    wave.mix_rate = SAMPLE_RATE
    wave.stereo = false
    var sample_count: int = maxi(1, int(float(SAMPLE_RATE) * duration_s))
    var bytes := PackedByteArray()
    bytes.resize(sample_count * 2)
    for n in range(sample_count):
        var phase: float = float(n) / float(SAMPLE_RATE)
        var normalized: float = float(n) / float(sample_count)
        var envelope: float = minf(1.0, normalized * 90.0) * pow(1.0 - normalized, 2.4)
        var bend: float = 1.0 + 0.08 * (1.0 - normalized) if duration_s > 0.3 else 1.0
        var signal_value: float = sin(TAU * frequency * bend * phase)
        signal_value += harmonic * sin(TAU * frequency * 2.0 * phase)
        # Keep peak well below 0 dBFS; apply gentle attack and decay.
        var sample_value: int = clampi(int(round(signal_value * envelope * 8400.0)), -32768, 32767)
        bytes[n * 2] = sample_value & 255
        bytes[n * 2 + 1] = (sample_value >> 8) & 255
    wave.data = bytes
    return wave

func play_cue(which: String) -> void:
    if not enabled or not players.has(which):
        return
    var player: AudioStreamPlayer = players[which]
    if player.playing:
        player.stop()
    player.play()

func set_enabled(value: bool) -> void:
    enabled = value
    if not enabled:
        for item in players.values():
            var player: AudioStreamPlayer = item
            player.stop()
