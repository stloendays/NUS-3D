extends Node
class_name NUS3DUISound
## Original, compact UI sounds generated in memory; no external sound assets.

const SAMPLE_RATE: int = 22050
const SAVE_PATH: String = "user://nus3d-ui-sound.cfg"

var enabled: bool = true
var _clips: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last_tap_ms: int = -1000

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var settings: ConfigFile = ConfigFile.new()
    if settings.load(SAVE_PATH) == OK:
        enabled = bool(settings.get_value("audio", "ui_sfx", true))
    _clips = {
        "press": _synthesize(0.052, 440.0, 0.28),
        "release": _synthesize(0.036, 620.0, 0.16),
        "open": _synthesize(0.092, 540.0, 0.31),
        "confirm": _synthesize(0.14, 740.0, 0.32),
        "reward": _synthesize(0.21, 890.0, 0.39),
        "error": _synthesize(0.13, 215.0, 0.29)
    }
    for i in range(3):
        var voice: AudioStreamPlayer = AudioStreamPlayer.new()
        voice.name = "UIVoice%d" % i
        voice.volume_db = -13.0
        add_child(voice)
        _voices.append(voice)

func _synthesize(length: float, pitch: float, gain: float) -> AudioStreamWAV:
    var count: int = maxi(1, int(ceil(length * float(SAMPLE_RATE))))
    var bytes: PackedByteArray = PackedByteArray()
    bytes.resize(count * 2)
    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var phase: float = t / length
        var envelope: float = pow(maxf(0.0, 1.0 - phase), 3.2)
        var body: float = sin(TAU * pitch * t * (1.08 - 0.08 * phase))
        var attack: float = sin(TAU * 2450.0 * t) * pow(maxf(0.0, 1.0 - phase), 23.0)
        var fade: float = minf(1.0, t * 2500.0)
        var sample: float = clampf((body * 0.77 + attack * 0.23) * envelope * fade * gain, -1.0, 1.0)
        bytes.encode_s16(i * 2, int(sample * 32767.0))
    var stream: AudioStreamWAV = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = bytes
    return stream

func play_ui(effect: String = "press") -> void:
    if not enabled or _voices.is_empty() or not _clips.has(effect):
        return
    # Headless smoke tests have no speakers; validate synthesis but skip playback.
    if DisplayServer.get_name() == "headless":
        return
    if effect == "press":
        var now_ms: int = Time.get_ticks_msec()
        if now_ms - _last_tap_ms < 65:
            return
        _last_tap_ms = now_ms
    var voice: AudioStreamPlayer = _voices[_cursor]
    _cursor = (_cursor + 1) % _voices.size()
    voice.stream = _clips[effect]
    voice.pitch_scale = 1.0
    voice.play()

func toggle_enabled() -> bool:
    enabled = not enabled
    var settings: ConfigFile = ConfigFile.new()
    settings.set_value("audio", "ui_sfx", enabled)
    if settings.save(SAVE_PATH) != OK:
        push_warning("Could not save UI sound preference")
    if enabled:
        play_ui("open")
    return enabled
