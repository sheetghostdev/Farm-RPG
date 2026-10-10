extends Node
## Sfx - Hearthdeep's procedural audio singleton (autoload "Sfx").
##
## The project ships no audio files: every effect, ambience loop and music instrument
## is synthesized here (inner class Synth) into 16-bit mono AudioStreamWAV buffers.
##  * At startup a WorkerThreadPool task pre-builds everything off the main thread.
##    Anything requested before it is ready is built on demand (also the only path
##    on headless servers and web). Unknown names are silently ignored.
##  * Ambience beds are seamless loops; spot sounds (bird chirps, cave drips, fire
##    crackles) are separate one-shots fired by a random timer.
##  * Music is generative: four instrument samples are synthesized once and
##    pitch-shifted per note, scheduled from _process on an eighth-note clock.

const SR := 22050
const PEAK := 0.6
const AMB_FADE := 1.5
const MUSIC_FADE := 3.0

## Every public effect name, in background build order (frequent sounds first).
const SOUNDS := [
	"step", "step_stone", "swing", "whoosh", "hit", "hurt", "chop", "mine", "clank", "rustle",
	"roll", "dig", "water", "splash", "plant", "place", "pluck", "pickup", "tick", "click",
	"error", "eat", "drink", "magic", "bow", "arrow_hit", "levelup", "downed", "revive", "coin",
	"ui_open", "ui_close", "chat", "bite", "reel", "catch", "fish_escape", "door", "stairs",
	"chest_open", "bubble", "craft", "sell", "buy", "gift", "discovery", "quest", "sleep",
	"bat", "growl", "slime", "spit", "slam", "charge", "burrow", "enemy_die", "telegraph", "thunder",
]
## Internal one-shots fired by ambience timers.
const SPOT_SOUNDS := ["chirp", "drip", "crackle", "rumble"]
const AMBIENCES := ["birds", "night", "rain", "storm", "cave", "cave_deep", "wind", "indoor"]
const VARIANTS := {"step": 3, "step_stone": 3, "hit": 2, "chop": 2, "mine": 2, "dig": 2,
	"chirp": 6, "drip": 3, "crackle": 4}
## Normalized peak per effect (default 0.5): quiet UI ticks up to heavy impacts.
const FX_PEAK := {"hit": 0.6, "slam": 0.6, "thunder": 0.6, "chop": 0.55, "hurt": 0.55,
	"splash": 0.55, "growl": 0.55, "arrow_hit": 0.55, "step": 0.45, "step_stone": 0.45,
	"water": 0.45, "plant": 0.45, "error": 0.45, "eat": 0.45, "drink": 0.45, "magic": 0.45,
	"downed": 0.45, "revive": 0.45, "fish_escape": 0.45, "stairs": 0.45, "bubble": 0.45,
	"sell": 0.45, "buy": 0.45, "discovery": 0.45, "chirp": 0.45, "drip": 0.45, "roll": 0.4,
	"rustle": 0.4, "coin": 0.4, "pickup": 0.4, "gift": 0.4, "sleep": 0.4, "telegraph": 0.4,
	"crackle": 0.4, "click": 0.35, "ui_open": 0.35, "ui_close": 0.35, "reel": 0.35,
	"bat": 0.35, "tick": 0.3, "chat": 0.3}
## Low, dark effects rendered at 11025 Hz (half the synthesis cost).
const LOW_RATE := {"thunder": true, "rumble": true, "burrow": true, "slam": true, "growl": true, "charge": true}
## Sounds that get +-6 % random pitch so repeats never sound mechanical.
const VARIED := {"step": true, "step_stone": true, "swing": true, "whoosh": true, "chop": true,
	"mine": true, "clank": true, "rustle": true, "hit": true, "hurt": true, "roll": true,
	"dig": true, "water": true, "splash": true, "plant": true, "place": true, "eat": true,
	"drink": true, "pluck": true, "bow": true, "arrow_hit": true, "reel": true, "bubble": true,
	"craft": true, "bat": true, "growl": true, "slime": true, "spit": true, "slam": true,
	"burrow": true, "enemy_die": true, "charge": true}
## Bus trim (dB) added to the user's linear volume, so 1.0 sits at a comfortable level.
const BUS_TRIM := {"Master": 0.0, "Music": -10.0, "SFX": 0.0, "Ambience": -3.0}
const AMB_DB := {"birds": -9.0, "night": -8.0, "rain": -7.0, "storm": -3.0, "cave": -5.0,
	"cave_deep": -4.0, "wind": -6.0, "indoor": -18.0}
## Spot sounds per ambience: [names, min gap s, max gap s, dB].
const AMB_SPOTS := {
	"birds": [["chirp"], 2.0, 8.0, -12.0],
	"cave": [["drip"], 2.0, 7.0, -12.0],
	"cave_deep": [["drip", "rumble"], 4.0, 11.0, -12.0],
	"indoor": [["crackle"], 0.3, 2.2, -17.0],
	"storm": [["thunder"], 15.0, 35.0, -15.0],
}

# --- Music tables ----------------------------------------------------------------
const INST_DB := {"pluck": -5.0, "bell": -6.0, "pad": -11.0, "bass": -6.0}
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const DORIAN := [0, 2, 3, 5, 7, 9, 10]
const PHRYGIAN := [0, 1, 3, 5, 7, 8, 10]
const PENTA_MAJ := [0, 2, 4, 7, 9]
const PENTA_MIN := [0, 3, 5, 7, 10]
const PENTA_DARK := [0, 1, 5, 7, 8]
## Arpeggio patterns over 8 eighth-notes: chord-tone index (3-5 = octave up), -1 = rest.
const ARPS := [
	[0, 2, 3, 2, 4, 2, 3, 2],
	[0, -1, 2, -1, 3, -1, 2, -1],
	[0, 1, 2, 4, 3, 2, 1, -1],
	[0, 2, 4, 5, 4, 2, -1, -1],
	[0, -1, -1, 2, -1, -1, 3, -1],
	[0, -1, -1, -1, 2, -1, -1, -1],
	[3, 2, 1, 2, 0, -1, 2, -1],
]
const MEL_STEPS := [-2, -1, -1, 1, 1, 2]
const MEL_RHYTHM := [1, 2, 2, 2, 3, 4]
## Title theme (C major over C-Am-F-G): [eighth-note step in phrase, midi note].
const THEME_A := [[0, 76], [2, 79], [4, 84], [8, 81], [11, 79], [12, 76], [16, 72], [18, 74],
	[20, 76], [22, 81], [24, 79], [28, 74]]
const THEME_B := [[0, 76], [2, 79], [4, 84], [6, 86], [8, 88], [11, 84], [12, 81], [16, 81],
	[18, 79], [20, 77], [22, 76], [24, 74], [28, 72]]
const MOODS := {
	"day": {"bpm": 84.0, "root": 60, "mode": MAJOR, "penta": PENTA_MAJ,
		"progs": [[0, 5, 3, 4], [0, 3, 5, 4], [0, 4, 5, 3], [0, 5, 1, 4], [3, 4, 0, 0]],
		"arp": "pluck", "arp_p": 0.85, "arps": [0, 1, 2, 4], "mel": 0.35, "pad": 0.55,
		"bass": 0.35, "rest": 0.2, "echo": 0.0, "db": 0.0},
	"night": {"bpm": 60.0, "root": 57, "mode": MAJOR, "penta": PENTA_MAJ, "sus": true,
		"progs": [[0, 3, 0, 4], [0, 5, 3, 0], [3, 0, 4, 0]], "arp_oct": 12,
		"arp": "bell", "arp_p": 0.45, "arps": [1, 4, 5], "mel": 0.3, "pad": 0.85,
		"bass": 0.0, "rest": 0.35, "echo": 0.3, "db": -3.0},
	"town": {"bpm": 96.0, "root": 62, "mode": MAJOR, "penta": PENTA_MAJ, "walk": true,
		"progs": [[0, 3, 4, 0], [0, 5, 3, 4], [0, 3, 0, 4], [5, 3, 4, 0]],
		"arp": "pluck", "arp_p": 0.9, "arps": [0, 2, 3, 6], "mel": 0.45, "pad": 0.3,
		"bass": 0.9, "rest": 0.12, "echo": 0.0, "db": -1.0},
	"rain": {"bpm": 66.0, "root": 62, "mode": DORIAN, "penta": PENTA_MIN,
		"progs": [[0, 3, 0, 6], [0, 0, 3, 3], [0, 6, 3, 0]],
		"arp": "pluck", "arp_p": 0.4, "arps": [1, 4, 5], "mel": 0.15, "pad": 0.85,
		"bass": 0.15, "rest": 0.3, "echo": 0.25, "db": -2.0},
	"home": {"bpm": 70.0, "root": 65, "mode": MAJOR, "penta": PENTA_MAJ,
		"progs": [[0, 3, 0, 4], [0, 5, 3, 4], [0, 3, 4, 0]],
		"arp": "bell", "arp_p": 0.7, "arps": [1, 4, 6], "mel": 0.4, "pad": 0.5,
		"bass": 0.25, "rest": 0.15, "echo": 0.0, "db": -2.0},
	"cave": {"bpm": 62.0, "root": 57, "mode": DORIAN, "penta": PENTA_MIN, "pad_oct": -12,
		"progs": [[0, 0, 3, 0], [0, 6, 0, 3], [0, 0, 6, 6]],
		"arp": "pluck", "arp_p": 0.18, "arps": [4, 5], "mel": 0.18, "pad": 0.9,
		"bass": 0.0, "rest": 0.4, "echo": 0.35, "db": -2.0},
	"cave_deep": {"bpm": 54.0, "root": 52, "mode": PHRYGIAN, "penta": PENTA_DARK, "pad_oct": -12,
		"progs": [[0, 1, 0, 0], [0, 5, 1, 0], [0, 0, 6, 1]],
		"arp": "pluck", "arp_p": 0.1, "arps": [5], "mel": 0.1, "pad": 0.95,
		"bass": 0.0, "rest": 0.5, "echo": 0.3, "db": -2.0},
	"title": {"bpm": 76.0, "root": 60, "mode": MAJOR, "penta": PENTA_MAJ, "theme": true,
		"progs": [[0, 5, 3, 4]], "arp": "pluck", "arp_p": 0.9, "arps": [0, 1], "mel": 0.0,
		"pad": 0.7, "bass": 0.45, "rest": 0.0, "echo": 0.0, "db": 0.0},
}

var _syn := Synth.new()                   # main-thread synthesizer (on-demand builds)
var _rng := RandomNumberGenerator.new()   # playback variation + composition
var _cache: Dictionary = {}               # effect name -> Array[AudioStreamWAV] ([] = unknown)
var _last_ms: Dictionary = {}
var _last_us := 0

# Background synthesis (WorkerThreadPool). Guarded by _mutex: _jobs, _done, _busy, _stop.
var _mutex := Mutex.new()
var _jobs: Array = []                     # keys: effect name, "amb:<name>" or "inst"
var _done: Array = []                     # [key, result]
var _busy := ""
var _stop := false
var _task := -1

var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _pool3d_i := 0

var _amb_cache: Dictionary = {}
var _amb: Array[AudioStreamPlayer] = []
var _amb_gain := PackedFloat32Array([0.0, 0.0])
var _amb_target := PackedFloat32Array([0.0, 0.0])
var _amb_db := PackedFloat32Array([0.0, 0.0])
var _amb_name := ""
var _amb_pending := ""
var _amb_t := 0.0
var _spots: Array[AudioStreamPlayer] = []
var _spot_i := 0

var _inst: Dictionary = {}                # instrument -> [AudioStreamWAV, base Hz]
var _mus: Array[AudioStreamPlayer] = []
var _mus_db := PackedFloat32Array()
var _mus_fade := PackedFloat32Array()
var _mus_rate := PackedFloat32Array()
var _mus_gen := PackedInt32Array()
var _mus_i := 0
var _mood := ""
var _cfg: Dictionary = {}
var _gen := 0
var _level := 1.0
var _wait := 0.0
var _clock := 0.0
var _step_len := 0.35
var _step := 0
var _events: Array = []                   # [step, instrument, midi, dB]
var _bar_i := 0
var _phrase_n := 0
var _rest_left := 0
var _prog: Array = []
var _arp := 0
var _last_deg := -1
var _mel_idx := 2
var _mel_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	for i in 12:
		_pool.append(_player("SFX"))
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 6.0
		p.max_distance = 45.0
		add_child(p)
		_pool3d.append(p)
	for i in 2:
		_amb.append(_player("Ambience"))
	for i in 4:
		_spots.append(_player("Ambience"))
	for i in 20:
		_mus.append(_player("Music"))
	_mus_db.resize(20)
	_mus_fade.resize(20)
	_mus_rate.resize(20)
	_mus_gen.resize(20)
	_mus_fade.fill(0.0)
	_mus_rate.fill(0.0)
	_mus_gen.fill(-1)
	_last_us = Time.get_ticks_usec()
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		_start_worker()


func _exit_tree() -> void:
	if _task >= 0:
		_mutex.lock()
		_stop = true
		_mutex.unlock()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = StringName(bus)
	add_child(p)
	return p


func _ensure_buses() -> void:
	for bus: String in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.set_bus_volume_db(idx, float(BUS_TRIM[bus]))
		if bus == "SFX":
			var lim := AudioEffectHardLimiter.new()
			lim.ceiling_db = -1.0
			AudioServer.add_bus_effect(idx, lim)
		else:
			var rev := AudioEffectReverb.new()
			rev.room_size = 0.7 if bus == "Music" else 0.6
			rev.damping = 0.6
			rev.wet = 0.18 if bus == "Music" else 0.12
			rev.predelay_msec = 40.0
			rev.hipass = 0.1
			AudioServer.add_bus_effect(idx, rev)


# --- Public API --------------------------------------------------------------------

## Non-positional (UI / global) sound.
func play(sound: String, vol_db: float = 0.0) -> void:
	if _pool.is_empty() or _throttled(sound):
		return
	var st := _pick(sound)
	if st == null:
		return
	var i := _free_slot(_pool, _pool_i)
	_pool_i = (i + 1) % _pool.size()
	var p := _pool[i]
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = _pitch(sound)
	p.play()


## 3D positional sound.
func play_at(sound: String, pos: Vector3, vol_db: float = 0.0) -> void:
	if _pool3d.is_empty() or _throttled(sound):
		return
	var st := _pick(sound)
	if st == null:
		return
	var i := _free_slot(_pool3d, _pool3d_i)
	_pool3d_i = (i + 1) % _pool3d.size()
	var p := _pool3d[i]
	p.stream = st
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = _pitch(sound)
	p.play()


## Crossfade (~3 s) to a generative music mood; "" or "none" = silence.
func set_music(mood: String) -> void:
	if mood == "none":
		mood = ""
	if mood == _mood:
		return
	_mood = mood
	var was_playing := false
	for i in _mus.size():
		if not _mus[i].playing:
			continue
		was_playing = true
		if _mus_rate[i] == 0.0:
			_mus_fade[i] *= _level if _mus_gen[i] == _gen else 1.0
			_mus_rate[i] = -1.0 / MUSIC_FADE
	_events.clear()
	_gen += 1
	_level = 0.0
	if not MOODS.has(mood):
		_cfg = {}
		return
	_collect()
	if _inst.is_empty() and not _await("inst"):
		_inst = _syn.instruments()
	_cfg = MOODS[mood]
	_step_len = 30.0 / float(_cfg["bpm"])
	_clock = 0.0
	_step = 0
	_bar_i = 0
	_phrase_n = 0
	_rest_left = 0
	_last_deg = -1
	_mel_until = 0
	_mel_idx = 2
	_wait = 1.0 if was_playing else 0.2


## Crossfade (~1.5 s) to a looping ambience bed; "" or "none" = silence.
func set_ambience(amb: String) -> void:
	if amb == "none":
		amb = ""
	if amb == _amb_name:
		return
	_amb_name = amb
	_amb_pending = ""
	_amb_t = _rng.randf_range(1.0, 3.0)
	_amb_target[0] = 0.0
	_amb_target[1] = 0.0
	if not AMBIENCES.has(amb):
		return
	_collect()
	if not _amb_cache.has(amb):
		if _await("amb:" + amb):
			_amb_pending = amb   # the worker is building it; starts in _collect()
			return
		_amb_cache[amb] = _syn.ambience(amb)
	_start_ambience(amb)


## Set a bus volume from a linear 0..1 slider value (0 mutes). Buses: Master, Music, SFX, Ambience.
func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + float(BUS_TRIM.get(bus, 0.0)))


# --- Background synthesis ---------------------------------------------------------

func _start_worker() -> void:
	var first: Array = SOUNDS.slice(0, 20)
	_jobs = ["inst"] + first + ["amb:birds", "amb:indoor"] + SPOT_SOUNDS + SOUNDS.slice(20)
	for a: String in AMBIENCES:
		if not _jobs.has("amb:" + a):
			_jobs.append("amb:" + a)
	_task = WorkerThreadPool.add_task(_worker, false, "Sfx synthesis")


func _worker() -> void:
	var syn := Synth.new()
	while true:
		_mutex.lock()
		if _stop or _jobs.is_empty():
			_mutex.unlock()
			return
		var key: String = _jobs.pop_front()
		_busy = key
		_mutex.unlock()
		var res: Variant
		if key == "inst":
			res = syn.instruments()
		elif key.begins_with("amb:"):
			res = syn.ambience(key.substr(4))
		else:
			res = syn.build(key)
		_mutex.lock()
		_done.append([key, res])
		_busy = ""
		_mutex.unlock()


## Moves finished background results into the caches (main thread).
func _collect() -> void:
	if _task < 0:
		return
	_mutex.lock()
	var done := _done
	_done = []
	var finished := _jobs.is_empty() and _busy == ""
	_mutex.unlock()
	for d: Array in done:
		var key: String = d[0]
		if key == "inst":
			if _inst.is_empty():
				_inst = d[1]
		elif key.begins_with("amb:"):
			var nm := key.substr(4)
			if not _amb_cache.has(nm):
				_amb_cache[nm] = d[1]
			if nm == _amb_pending:
				_amb_pending = ""
				_start_ambience(nm)
		elif not _cache.has(key):
			_cache[key] = d[1]
	if finished:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## True if the worker is (or will shortly be) building `key`; bumps it to the queue front.
func _await(key: String) -> bool:
	if _task < 0:
		return false
	_mutex.lock()
	var found := _busy == key
	var i := _jobs.find(key)
	if i >= 0:
		_jobs.remove_at(i)
		_jobs.push_front(key)
		found = true
	_mutex.unlock()
	return found


# --- Playback helpers ---------------------------------------------------------------

func _pick(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_collect()
		if not _cache.has(sound):
			_cache[sound] = _syn.build(sound)
	var arr: Array = _cache[sound]
	if arr.is_empty():
		return null
	return arr[_rng.randi() % arr.size()]


func _throttled(sound: String) -> bool:
	var now := Time.get_ticks_msec()
	var last: int = _last_ms.get(sound, -1000)
	if now - last < 30:
		return true
	_last_ms[sound] = now
	return false


func _pitch(sound: String) -> float:
	return _rng.randf_range(0.94, 1.06) if VARIED.has(sound) else 1.0


func _free_slot(players: Array, start: int) -> int:
	var n := players.size()
	for k in n:
		var i := (start + k) % n
		if not players[i].playing:
			return i
	return start % n


func _start_ambience(amb: String) -> void:
	var st: AudioStreamWAV = _amb_cache.get(amb)
	if st == null:
		return
	var i := -1
	for k in 2:
		if _amb[k].stream == st and _amb[k].playing:
			i = k
	if i < 0:
		i = 0 if _amb_gain[0] <= _amb_gain[1] else 1
		_amb[i].stream = st
		_amb[i].volume_db = -80.0
		_amb_gain[i] = 0.0
		_amb[i].play(_rng.randf() * st.get_length() * 0.9)
	_amb_db[i] = float(AMB_DB.get(amb, -8.0))
	_amb_target[i] = 1.0
	_amb_target[1 - i] = 0.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_collect()
	_tick(clampf(float(now - _last_us) / 1000000.0, 0.0, 0.25))
	_last_us = now


## Advances fades, ambience spot timers and the music clock by dt seconds (real time).
func _tick(dt: float) -> void:
	for i in 2:
		var g := _amb_gain[i]
		if g == _amb_target[i]:
			continue
		g = move_toward(g, _amb_target[i], dt / AMB_FADE)
		_amb_gain[i] = g
		if g <= 0.0:
			_amb[i].stop()
		else:
			_amb[i].volume_db = _amb_db[i] + linear_to_db(sin(g * PI * 0.5))
	if AMB_SPOTS.has(_amb_name):
		_amb_t -= dt
		if _amb_t <= 0.0:
			var spec: Array = AMB_SPOTS[_amb_name]
			var names: Array = spec[0]
			_spot(names[_rng.randi() % names.size()], float(spec[3]))
			_amb_t = _rng.randf_range(0.3, 0.9) if _rng.randf() < 0.2 else _rng.randf_range(spec[1], spec[2])
	var ramping := _level < 1.0
	if ramping:
		_level = minf(1.0, _level + dt / MUSIC_FADE)
	for i in _mus.size():
		var p := _mus[i]
		if not p.playing:
			continue
		var g := _mus_fade[i]
		if _mus_rate[i] != 0.0:
			g = maxf(0.0, g + _mus_rate[i] * dt)
			_mus_fade[i] = g
			if g <= 0.0:
				p.stop()
				continue
		elif not (ramping and _mus_gen[i] == _gen):
			continue
		if _mus_gen[i] == _gen:
			g *= _level
		p.volume_db = _mus_db[i] + linear_to_db(maxf(g, 0.0001))
	if _cfg.is_empty() or _inst.is_empty():
		return
	if _wait > 0.0:
		_wait -= dt
		return
	_clock += dt
	if _clock > _step_len * 3.0:
		_clock = _step_len
	while _clock >= _step_len:
		_clock -= _step_len
		_music_tick()


func _spot(sound: String, db: float) -> void:
	var st := _pick(sound)
	if st == null:
		return
	var p := _spots[_spot_i]
	_spot_i = (_spot_i + 1) % _spots.size()
	p.stream = st
	p.pitch_scale = _rng.randf_range(0.9, 1.12)
	p.volume_db = db + _rng.randf_range(-5.0, 0.0) + linear_to_db(maxf(maxf(_amb_gain[0], _amb_gain[1]), 0.01))
	p.play()


# --- Generative music -----------------------------------------------------------------

func _music_tick() -> void:
	if _step % 8 == 0:
		_compose_bar()
	for i in range(_events.size() - 1, -1, -1):
		var e: Array = _events[i]
		if int(e[0]) <= _step:
			_note(e[1], e[2], e[3])
			_events.remove_at(i)
	_step += 1


func _queue(step: int, inst: String, midi: int, db: float) -> void:
	_events.append([step, inst, midi, db])


func _note(inst: String, midi: int, db: float) -> void:
	var data: Array = _inst.get(inst, [])
	if data.is_empty():
		return
	var i := _free_slot(_mus, _mus_i)
	_mus_i = (i + 1) % _mus.size()
	var p := _mus[i]
	p.stream = data[0]
	p.pitch_scale = 440.0 * pow(2.0, (midi - 69) / 12.0) / float(data[1])
	_mus_db[i] = float(INST_DB[inst]) + float(_cfg.get("db", 0.0)) + db + _rng.randf_range(-1.5, 1.0)
	_mus_fade[i] = 1.0
	_mus_rate[i] = 0.0
	_mus_gen[i] = _gen
	p.volume_db = _mus_db[i] + linear_to_db(maxf(_level, 0.0001))
	p.play()


## Writes one bar (8 eighth-notes) of pad, bass, arpeggio and melody events.
func _compose_bar() -> void:
	var s0 := _step
	if _rest_left > 0:
		_rest_left -= 1
		if _rng.randf() < float(_cfg["echo"]):
			_queue(s0 + _rng.randi_range(0, 5), "bell", _mel_note(_rng.randi_range(3, 7)), -5.0)
		return
	if _bar_i == 0:
		var progs: Array = _cfg["progs"]
		_prog = (progs[_rng.randi() % progs.size()] as Array).duplicate()
		if not _cfg.has("theme") and _rng.randf() < 0.3:
			var k := _rng.randi_range(1, 3)
			_prog[k] = (int(_prog[k]) + 5) % 7   # relative-minor/major substitution
		var arps: Array = _cfg["arps"]
		_arp = arps[_rng.randi() % arps.size()]
	var deg: int = _prog[_bar_i]
	var ct := _chord(deg)
	var same := deg == _last_deg
	_last_deg = deg
	var pad_oct: int = _cfg.get("pad_oct", 0)
	if _rng.randf() < float(_cfg["pad"]) and not (same and _rng.randf() < 0.6):
		_queue(s0, "pad", ct[0] - 12 + pad_oct, 0.0)
		_queue(s0, "pad", ct[1] + pad_oct, -2.0)
		_queue(s0, "pad", ct[2] + pad_oct, -3.0)
	if _rng.randf() < float(_cfg["bass"]):
		var bn := _bass_note(ct[0])
		_queue(s0, "bass", bn, 0.0)
		if _cfg.has("walk"):
			_queue(s0 + 4, "bass", _bass_note(ct[2]), -2.0)
			if _rng.randf() < 0.35:
				_queue(s0 + 6, "bass", bn + 12, -5.0)
	var pat: Array = ARPS[_arp]
	var arp_p: float = _cfg["arp_p"]
	var arp_inst: String = _cfg["arp"]
	var arp_oct: int = _cfg.get("arp_oct", 0)
	for s in 8:
		var idx: int = pat[s]
		if idx < 0 or _rng.randf() > arp_p:
			continue
		var m := ct[idx % 3] + (12 if idx >= 3 else 0) + arp_oct
		_queue(s0 + s, arp_inst, m, 0.0 if s == 0 else -2.5)
	if _cfg.has("theme"):
		if _bar_i == 0 and _phrase_n % 3 != 2:
			var mel: Array = THEME_A if _phrase_n % 3 == 0 else THEME_B
			for k in mel.size():
				if k > 0 and _rng.randf() < 0.07:
					continue
				_queue(s0 + int(mel[k][0]), "bell", int(mel[k][1]), -1.0)
	elif _step >= _mel_until and _rng.randf() < float(_cfg["mel"]):
		var st := s0 + 2 * _rng.randi_range(0, 2)
		var count := _rng.randi_range(3, 6)
		for k in count:
			_mel_idx = clampi(_mel_idx + int(MEL_STEPS[_rng.randi() % MEL_STEPS.size()]), 0, 7)
			_queue(st, "bell", _mel_note(_mel_idx), -0.4 * k)
			st += int(MEL_RHYTHM[_rng.randi() % MEL_RHYTHM.size()])
		_mel_until = st + 4
	_bar_i += 1
	if _bar_i >= 4:
		_bar_i = 0
		_phrase_n += 1
		if _rng.randf() < float(_cfg["rest"]):
			_rest_left = _rng.randi_range(1, 2)


func _chord(deg: int) -> PackedInt32Array:
	var mode: Array = _cfg["mode"]
	var root: int = _cfg["root"]
	var out := PackedInt32Array()
	for s: int in ([0, 1, 4] if _cfg.has("sus") else [0, 2, 4]):
		var d := deg + s
		out.append(root + int(mode[d % 7]) + 12 * floori(d / 7.0))
	return out


func _mel_note(idx: int) -> int:
	var penta: Array = _cfg["penta"]
	return int(_cfg["root"]) + 12 + 12 * floori(idx / 5.0) + int(penta[idx % 5])


func _bass_note(m: int) -> int:
	var b := m - 24
	while b > 50:
		b -= 12
	while b < 33:
		b += 12
	return b


# --- Synthesis ---------------------------------------------------------------------

## Self-contained synthesizer (own RNG and buffers, no shared state), so one instance
## can run on a worker thread while another serves on-demand requests.
class Synth extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var sr := float(SR)
	var fx := PackedFloat32Array()   # scratch buffer effect recipes write into
	var hi := 0                      # highest sample index written so far

	func _init() -> void:
		rng.seed = 0x4EA27D
		fx.resize(3 * SR)

	## All variants of an effect ([] for unknown names).
	func build(name: String) -> Array:
		sr = 11025.0 if LOW_RATE.has(name) else float(SR)
		var out: Array = []
		for v in int(VARIANTS.get(name, 1)):
			fx.fill(0.0)
			hi = 0
			if not recipe(name, v):
				break
			out.append(make(fx, float(FX_PEAK.get(name, 0.5)), 0, hi))
		sr = float(SR)
		return out

	## Music instruments: name -> [AudioStreamWAV, base frequency Hz].
	func instruments() -> Dictionary:
		var b := buf(1.8)    # soft plucked string (Karplus-Strong), ~C4
		ks(b, 0.0, 1.8, 84, 1.0, 0.994, 0.5)
		var out := {"pluck": [make(b), sr / 84.5]}
		var f := 523.25      # music box / bell, C5
		b = buf(2.3)
		tone(b, 0.0, 2.3, f, f, 0.62, 2.1, 0.002)
		tone(b, 0.0, 1.4, f * 2.0, f * 2.0, 0.2, 3.6, 0.002)
		tone(b, 0.0, 0.7, f * 3.0, f * 3.0, 0.07, 7.0, 0.002)
		tone(b, 0.0, 0.12, f * 5.43, f * 5.43, 0.05, 40.0, 0.0005)
		out["bell"] = [make(b), f]
		b = buf(3.6)         # warm pad, C4: detuned sines with a slow swell
		pad(b, 261.63)
		out["pad"] = [make(b), 261.63]
		b = buf(2.0)         # round bass pluck, C2
		tone(b, 0.0, 2.0, 65.41, 65.41, 0.8, 2.4, 0.008, 0.4, 0.12)
		out["bass"] = [make(b), 65.41]
		return out

	## Seamless 4 s ambience loop (low-content beds rendered at 11 kHz).
	func ambience(name: String) -> AudioStreamWAV:
		sr = float(SR) if name in ["night", "rain", "storm"] else 11025.0
		var secs := 4.0
		var n := int(secs * sr)
		var bl := secs + 0.5
		var bed := buf(bl)          # tail is crossfaded into the head
		var ev := buf(secs + 0.6)   # spot layer; overhang folds onto the head
		match name:
			"birds":
				noise(bed, 0.0, bl, 1.0, 700.0, 700.0, 80.0, 0.0, 0.0)
				lfo(bed, n, 0.6, 0.4, 1.3)
			"night":
				noise(bed, 0.0, bl, 0.5, 450.0, 450.0, 60.0, 0.0, 0.0)
				lfo(bed, n, 0.6, 0.4, 0.4)
				for vc: Array in [[4300.0, 0.5, 1.0], [3850.0, 0.8, 0.7], [4900.0, 1.0, 0.35]]:
					var t := rng.randf() * float(vc[1])
					for c in roundi(secs / float(vc[1])):
						for p in 3 + rng.randi() % 2:
							tone(ev, t + p * 0.028, 0.018, vc[0], float(vc[0]) * 0.995,
								float(vc[2]) * rng.randf_range(0.75, 1.0), 40.0, 0.003)
						t += float(vc[1])
			"rain":
				noise(bed, 0.0, bl, 1.0, 3200.0, 3200.0, 300.0, 0.0, 0.0)
				drops(ev, secs, 130, 0.25)
			"storm":
				noise(bed, 0.0, bl, 1.0, 5500.0, 5500.0, 250.0, 0.0, 0.0)
				noise(bed, 0.0, bl, 1.4, 160.0, 160.0, 20.0, 0.0, 0.0)
				lfo(bed, n, 0.75, 0.25, 2.1)
				drops(ev, secs, 260, 0.35)
			"cave":
				noise(bed, 0.0, bl, 0.5, 260.0, 260.0, 30.0, 0.0, 0.0)
				drone(ev, n, 55.0, 0.5, 1, 0.0)
				drone(ev, n, 82.5, 0.3, 2, 1.7)
				drone(ev, n, 110.0, 0.12, 3, 0.6)
				drone(ev, n, 220.4, 0.04, 1, 2.4)
			"cave_deep":
				noise(bed, 0.0, bl, 1.0, 120.0, 120.0, 20.0, 0.0, 0.0)
				lfo(bed, n, 0.4, 0.6, 2.4)
				drone(ev, n, 41.2, 0.55, 1, 0.0)
				drone(ev, n, 61.7, 0.25, 2, 1.1)
				drone(ev, n, 43.6, 0.15, 1, 2.0)
			"wind":
				wind(bed, n, 520.0, 260.0, 5.0)
				noise(bed, 0.0, bl, 0.35, 900.0, 900.0, 100.0, 0.0, 0.0)
			"indoor":
				noise(bed, 0.0, bl, 1.0, 280.0, 280.0, 40.0, 0.0, 0.0)
		# Equal-power crossfade of the bed's overhang into its head; fold the event overhang.
		var x := bed.size() - n
		var out := bed.slice(0, n + 8)
		for i in x:
			var th := float(i) / x * PI * 0.5
			out[i] = bed[i] * sin(th) + bed[n + i] * cos(th)
		for i in n:
			out[i] += ev[i]
		for i in range(n, ev.size()):
			out[i - n] += ev[i]
		for i in 8:   # guard samples: resampling past loop_end reads the loop head
			out[n + i] = out[i]
		var w := make(out, PEAK, n)
		sr = float(SR)
		return w

	## Multiplies by a slow swell whose period is the loop length.
	func lfo(b: PackedFloat32Array, n: int, base: float, depth: float, ph: float) -> void:
		var g := 1.0
		for k in b.size():
			if (k & 63) == 0:
				var u := TAU * float(k % n) / n
				g = base + depth * (0.6 * sin(u + ph) + 0.4 * sin(2.0 * u + ph * 2.3))
			b[k] *= g

	## Sine drone snapped to whole cycles per loop (rotation recurrence) with slow tremolo.
	func drone(b: PackedFloat32Array, n: int, f: float, amp: float, cyc: int, ph: float) -> void:
		var w := TAU * roundf(f * n / sr) / n
		var c := cos(w)
		var s := sin(w)
		var x := cos(ph)
		var y := sin(ph)
		var am := 1.0
		for k in n:
			if (k & 63) == 0:
				am = amp * (0.7 + 0.3 * sin(TAU * cyc * k / n + ph))
			b[k] += y * am
			var nx := x * c - y * s
			y = x * s + y * c
			x = nx

	## Resonant band-passed noise with a wandering centre: soft howling wind.
	func wind(b: PackedFloat32Array, n: int, fc0: float, depth: float, q: float) -> void:
		var low := 0.0
		var band := 0.0
		var f := 0.1
		var g := 1.0
		for k in b.size():
			if (k & 63) == 0:
				var u := TAU * float(k % n) / n
				f = TAU * (fc0 + depth * (0.6 * sin(u) + 0.4 * sin(3.0 * u + 1.3))) / sr
				g = 0.45 + 0.55 * (0.5 + 0.5 * sin(2.0 * u + 0.7))
			band += f * (rng.randf_range(-1.0, 1.0) - low - band / q)
			low += f * band
			b[k] += band * g

	func drops(b: PackedFloat32Array, secs: float, count: int, amp: float) -> void:
		for i in count:
			var f := rng.randf_range(1800.0, 5200.0)
			tone(b, rng.randf() * secs, 0.02, f, f * 0.8, amp * rng.randf_range(0.2, 1.0), 260.0, 0.0005)

	# --- Primitives (inner loops kept minimal: GDScript cost is per operation) ---

	func buf(dur: float) -> PackedFloat32Array:
		var b := PackedFloat32Array()
		b.resize(int(dur * sr))
		b.fill(0.0)
		return b

	func lp_coef(fc: float) -> float:
		return 1.0 - exp(-TAU * minf(fc, sr * 0.45) / sr)

	## Adds a sine voice gliding f0 -> f1 Hz: linear attack, exponential decay (1/s),
	## short release. h2/h3 add 2nd/3rd harmonics; vib = vibrato depth at vrate Hz.
	func tone(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, amp: float,
			decay: float, atk: float = 0.003, h2: float = 0.0, h3: float = 0.0,
			vib: float = 0.0, vrate: float = 6.0) -> void:
		if h2 != 0.0:
			tone(b, t0, dur, f0 * 2.0, f1 * 2.0, amp * h2, decay * 1.4, atk, 0.0, 0.0, vib, vrate)
		if h3 != 0.0:
			tone(b, t0, dur, f0 * 3.0, f1 * 3.0, amp * h3, decay * 1.8, atk, 0.0, 0.0, vib, vrate)
		var i0 := int(t0 * sr)
		var n := mini(int(dur * sr), b.size() - i0)
		if decay > 0.0:
			n = mini(n, int((atk + 4.6 / decay) * sr))   # stop once ~40 dB down
		if n < 16 or i0 < 0:
			return
		hi = maxi(hi, i0 + n)
		var na := mini(maxi(1, int(atk * sr)), n >> 1)
		var nr := mini(110, (n - na) >> 1)
		var f := f0 * TAU / sr
		var fr := pow(f1 / f0, 1.0 / n)
		var dk := exp(-decay / sr)
		var ph := 0.0
		var env := amp
		for k in na:
			b[i0 + k] += sin(ph) * env * k / na
			ph += f
			f *= fr
		var j1 := i0 + n - nr
		if vib != 0.0:
			var vw := TAU * vrate / sr
			var vp := 0.0
			for j in range(i0 + na, j1):
				b[j] += sin(ph) * env
				ph += f * (1.0 + vib * sin(vp))
				vp += vw
				f *= fr
				env *= dk
		else:
			for j in range(i0 + na, j1):
				b[j] += sin(ph) * env
				ph += f
				f *= fr
				env *= dk
		for k in nr:
			b[j1 + k] += sin(ph) * env * (nr - k) / nr
			ph += f
			env *= dk

	## Adds noise through a 2-pole lowpass sweeping lp0 -> lp1 Hz and a 1-pole highpass
	## at hp Hz (0 = off), level-compensated so narrow bands are not much quieter.
	## Exponential attack (~atk s) and exponential decay (1/s, 0 = constant).
	func noise(b: PackedFloat32Array, t0: float, dur: float, amp: float, lp0: float, lp1: float,
			hp: float, decay: float, atk: float = 0.002) -> void:
		var i0 := int(t0 * sr)
		var n := mini(int(dur * sr), b.size() - i0)
		if decay > 0.0:
			n = mini(n, int((atk + 4.6 / decay) * sr))
		if n < 16 or i0 < 0:
			return
		hi = maxi(hi, i0 + n)
		var a := lp_coef(lp0)
		var ra := pow(lp_coef(lp1) / a, 1.0 / n)
		var ah := lp_coef(hp) if hp > 0.0 else 0.0
		var rc := 1.0 / sqrt(ra)
		var dk := exp(-decay / sr) * rc
		var ka := exp(-3.0 / maxf(atk * sr, 1.0)) * rc
		var env := amp / sqrt(a)
		var ea := env
		var y1 := 0.0
		var y2 := 0.0
		var yh := 0.0
		for j in range(i0, i0 + n):
			y1 += a * (rng.randf_range(-1.0, 1.0) - y1)
			y2 += a * (y1 - y2)
			yh += ah * (y2 - yh)
			b[j] += (y2 - yh) * (env - ea)
			env *= dk
			ea *= ka
			a *= ra

	## Music-box style chime: fundamental plus quickly fading upper partials.
	func bell(b: PackedFloat32Array, t: float, f: float, amp: float, decay: float) -> void:
		tone(b, t, 3.0, f, f, amp, decay, 0.002)
		tone(b, t, 3.0, f * 2.0, f * 2.0, amp * 0.28, decay * 1.7, 0.002)
		tone(b, t, 3.0, f * 3.0, f * 3.0, amp * 0.1, decay * 3.0, 0.002)
		tone(b, t, 0.06, f * 5.4, f * 5.4, amp * 0.06, 60.0, 0.0005)

	## Short noise grains scattered over [t0, t0+dur]: crunches, rustles, soil.
	func crunch(b: PackedFloat32Array, t0: float, dur: float, count: int, amp: float, lp: float, hp: float) -> void:
		for i in count:
			noise(b, t0 + rng.randf() * dur, 0.025, amp * rng.randf_range(0.4, 1.0), lp, lp * 0.7, hp, 120.0, 0.0005)

	## Random short pings: sparkles, droplets (glide > 1 = rising "plip").
	func sparkle(b: PackedFloat32Array, t0: float, dur: float, count: int, f_lo: float, f_hi: float,
			amp: float, decay: float, glide: float = 1.0) -> void:
		for i in count:
			var f := rng.randf_range(f_lo, f_hi)
			tone(b, t0 + rng.randf() * dur, 0.4, f, f * glide, amp * rng.randf_range(0.4, 1.0), decay, 0.001)

	## Train of resonant pulses (stick-slip): creaks at high fres, growls at low fres.
	func pulses(b: PackedFloat32Array, t0: float, dur: float, r0: float, r1: float, fres: float,
			amp: float, decay: float, jit: float) -> void:
		var t := 0.0
		while t < dur:
			var u := t / dur
			var f := fres * (1.0 + jit * rng.randf_range(-0.3, 0.3))
			tone(b, t0 + t, 0.15, f, f * 0.97, amp * sin(PI * u), decay, 0.0004, 0.3)
			t += (1.0 + jit * rng.randf_range(-1.0, 1.0)) / lerpf(r0, r1, u)

	## Karplus-Strong plucked string (delay line of `period` samples): 2 ms attack ramp,
	## faded out over its last quarter.
	func ks(b: PackedFloat32Array, t0: float, dur: float, period: int, amp: float, damp: float, bright: float) -> void:
		var dl := PackedFloat32Array()
		dl.resize(period)
		var y := 0.0
		var mean := 0.0
		for i in period:
			y += bright * (rng.randf_range(-1.0, 1.0) - y)
			dl[i] = y
			mean += y
		mean /= period
		for i in period:
			dl[i] -= mean
		var i0 := int(t0 * sr)
		var n := mini(int(dur * sr), b.size() - i0)
		hi = maxi(hi, i0 + n)
		var nf := n >> 2
		var idx := 0
		var last := 0.0
		var h := damp * 0.5
		for k in n:
			var v := dl[idx]
			dl[idx] = h * (v + last)
			last = v
			b[i0 + k] += v * (amp if k < n - nf else amp * (n - k) / nf) * minf(1.0, k / 44.0)
			idx += 1
			if idx == period:
				idx = 0

	func pad(b: PackedFloat32Array, f: float) -> void:
		var n := b.size()
		var na := int(1.1 * sr)
		var nr := int(1.7 * sr)
		var w := TAU * f / sr
		var p1 := 0.0
		var p2 := 1.3
		var p3 := 0.4
		var p4 := 2.1
		for k in n:
			var e := 1.0
			if k < na:
				e = sin(float(k) / na * PI * 0.5)
				e *= e
			elif k > nr:
				e = cos(float(k - nr) / (n - nr) * PI * 0.5)
				e *= e
			b[k] = e * (0.5 * sin(p1) + 0.5 * sin(p2) + 0.2 * sin(p3) + 0.06 * sin(p4))
			p1 += w * 0.9965
			p2 += w * 1.0035
			p3 += w * 2.002
			p4 += w * 2.997

	## Normalizes b[0, used) to `peak`, trims silent tails (one-shots) and packs 16-bit
	## PCM. loop_end > 0 makes a forward loop over [0, loop_end).
	func make(b: PackedFloat32Array, peak: float = PEAK, loop_end: int = 0, used: int = -1) -> AudioStreamWAV:
		var end := b.size() if used < 0 else mini(used, b.size())
		var m := 0.00001
		for k in end:
			m = maxf(m, absf(b[k]))
		if loop_end == 0:
			var thr := m * 0.002
			while end > 1 and absf(b[end - 1]) < thr:
				end -= 1
			end = mini(b.size(), end + 32)
		var g := peak / m * 32767.0
		var bytes := PackedByteArray()
		bytes.resize(end * 2)
		for k in end:
			bytes.encode_s16(k * 2, int(b[k] * g))
		if loop_end == 0:
			for k in mini(64, end):   # final fade so nothing ends on a click
				bytes.encode_s16((end - 1 - k) * 2, int(b[end - 1 - k] * g * k / 64.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = int(sr)
		w.stereo = false
		w.data = bytes
		if loop_end > 0:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = loop_end
		return w

	# --- Effect recipes (times s, frequencies Hz, decay 1/s; see tone()/noise()) ---

	func recipe(name: String, v: int) -> bool:
		var b := fx
		match name:
			"step":
				noise(b, 0.0, 0.12, 1.0, 1100.0, 350.0, 120.0, 38.0, 0.004)
				tone(b, 0.0, 0.08, 105.0 + v * 9.0, 60.0, 0.45, 45.0)
				crunch(b, 0.0, 0.05, 3, 0.25, 3000.0, 800.0)
			"step_stone":
				tone(b, 0.0, 0.07, 170.0 + v * 15.0, 120.0, 0.5, 60.0, 0.001)
				noise(b, 0.0, 0.06, 0.9, 4500.0, 1800.0, 500.0, 90.0, 0.001)
				tone(b, 0.0, 0.025, 2100.0 + v * 200.0, 2000.0 + v * 200.0, 0.12, 180.0, 0.0005)
			"swing":
				noise(b, 0.0, 0.29, 1.0, 500.0, 3000.0, 300.0, 18.0, 0.11)
			"whoosh", "roll":
				noise(b, 0.0, 0.4, 1.0, 400.0, 2200.0, 200.0, 12.0, 0.16)
				noise(b, 0.12, 0.28, 0.6, 1800.0, 600.0, 150.0, 14.0, 0.02)
				if name == "roll":
					crunch(b, 0.05, 0.3, 4, 0.2, 1500.0, 400.0)
			"chop":
				tone(b, 0.0, 0.28, 185.0 + v * 12.0, 160.0, 0.8, 22.0, 0.001, 0.25)
				tone(b, 0.0, 0.1, 410.0, 380.0, 0.25, 50.0, 0.001)
				noise(b, 0.0, 0.06, 0.7, 3500.0, 1200.0, 300.0, 70.0, 0.0005)
			"mine":
				for p: Array in [[1240.0, 0.5, 9.0], [1873.0, 0.35, 12.0], [2950.0, 0.25, 18.0]]:
					var f: float = p[0] * (1.0 + v * 0.045)
					tone(b, 0.0, 0.6, f, f * 0.997, p[1], p[2], 0.0005)
				noise(b, 0.0, 0.02, 0.6, 7000.0, 5000.0, 2000.0, 200.0, 0.0002)
				tone(b, 0.0, 0.06, 140.0, 100.0, 0.3, 60.0, 0.001)
			"clank":
				tone(b, 0.0, 0.28, 230.0, 220.0, 0.6, 26.0, 0.001, 0.3)
				tone(b, 0.0, 0.2, 347.0, 345.0, 0.4, 32.0, 0.001)
				tone(b, 0.0, 0.15, 532.0, 530.0, 0.25, 40.0, 0.001)
				noise(b, 0.0, 0.08, 0.5, 1500.0, 600.0, 150.0, 55.0, 0.0005)
			"rustle":
				for i in 7:
					noise(b, i * 0.04 + rng.randf() * 0.02, 0.09, rng.randf_range(0.5, 1.0), 6000.0, 3500.0, 1500.0, 40.0, 0.01)
				noise(b, 0.0, 0.36, 0.4, 4000.0, 2500.0, 900.0, 8.0, 0.05)
			"hit":
				tone(b, 0.0, 0.21, 140.0 + v * 10.0, 55.0, 0.9, 20.0, 0.001)
				noise(b, 0.0, 0.07, 0.7, 2500.0, 500.0, 80.0, 45.0, 0.0005)
			"hurt":
				tone(b, 0.0, 0.2, 110.0, 50.0, 0.8, 18.0, 0.001)
				tone(b, 0.02, 0.28, 540.0, 330.0, 0.35, 9.0, 0.01, 0.0, 0.15)
				noise(b, 0.0, 0.05, 0.4, 1500.0, 400.0, 80.0, 50.0, 0.0005)
			"dig":
				tone(b, 0.0, 0.12, 95.0 + v * 8.0, 55.0, 0.6, 30.0, 0.002)
				crunch(b, 0.0, 0.14, 9, 0.6, 3000.0, 250.0)
				noise(b, 0.0, 0.28, 0.5, 900.0, 300.0, 60.0, 14.0, 0.005)
			"water":
				noise(b, 0.0, 0.68, 0.5, 5000.0, 3500.0, 1200.0, 3.5, 0.08)
				sparkle(b, 0.0, 0.6, 22, 1400.0, 3800.0, 0.35, 90.0, 1.6)
			"splash":
				noise(b, 0.0, 0.72, 1.0, 4500.0, 900.0, 150.0, 5.5, 0.008)
				noise(b, 0.0, 0.1, 0.6, 1200.0, 300.0, 60.0, 30.0, 0.002)
				sparkle(b, 0.08, 0.42, 10, 1500.0, 3500.0, 0.25, 70.0, 1.5)
			"plant":
				noise(b, 0.0, 0.13, 0.8, 700.0, 250.0, 80.0, 35.0, 0.003)
				tone(b, 0.0, 0.1, 150.0, 95.0, 0.4, 35.0)
				crunch(b, 0.0, 0.04, 2, 0.15, 2500.0, 600.0)
			"place":
				tone(b, 0.0, 0.24, 230.0, 190.0, 0.7, 24.0, 0.001, 0.3)
				tone(b, 0.0, 0.12, 470.0, 450.0, 0.3, 45.0, 0.001)
				noise(b, 0.0, 0.03, 0.5, 4000.0, 1500.0, 300.0, 120.0, 0.0003)
			"error":
				tone(b, 0.0, 0.16, 196.0, 188.0, 0.6, 18.0, 0.004, 0.25, 0.1)
				tone(b, 0.15, 0.22, 165.0, 158.0, 0.6, 15.0, 0.004, 0.25, 0.1)
			"eat":
				for i in 3:
					var t := i * 0.14 + rng.randf() * 0.02
					crunch(b, t, 0.06, 7, 0.6, 3800.0, 700.0)
					noise(b, t, 0.08, 0.4, 1200.0, 500.0, 120.0, 40.0, 0.003)
					tone(b, t, 0.05, 120.0, 90.0, 0.2, 50.0)
			"drink":
				for t: float in [0.0, 0.22]:
					tone(b, t, 0.13, 240.0, 520.0, 0.6, 18.0, 0.01)
					noise(b, t, 0.1, 0.25, 800.0, 300.0, 100.0, 30.0, 0.01)
				sparkle(b, 0.05, 0.45, 6, 500.0, 1100.0, 0.2, 60.0, 1.5)
			"magic":
				var notes := [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3]
				for i in notes.size():
					tone(b, i * 0.055, 0.6, notes[i], notes[i], 0.35, 8.0, 0.003)
				sparkle(b, 0.1, 0.8, 12, 3000.0, 6000.0, 0.12, 25.0)
				noise(b, 0.0, 1.05, 0.12, 9000.0, 9000.0, 4000.0, 3.0, 0.25)
			"bow":
				ks(b, 0.0, 0.43, 110, 0.8, 0.985, 0.8)
				tone(b, 0.0, 0.3, 200.0, 196.0, 0.3, 10.0, 0.001, 0.0, 0.0, 0.01, 7.0)
				noise(b, 0.0, 0.03, 0.4, 3000.0, 1500.0, 400.0, 120.0, 0.0005)
			"pluck":
				tone(b, 0.0, 0.1, 320.0, 1100.0, 0.7, 30.0, 0.002)
				noise(b, 0.0, 0.04, 0.4, 2500.0, 800.0, 200.0, 80.0, 0.001)
				crunch(b, 0.0, 0.03, 2, 0.2, 3000.0, 800.0)
			"tick":
				tone(b, 0.0, 0.03, 3200.0, 3000.0, 0.6, 220.0, 0.0005)
			"click":
				tone(b, 0.0, 0.045, 1500.0, 1300.0, 0.6, 120.0, 0.0005)
				tone(b, 0.0, 0.035, 650.0, 600.0, 0.3, 120.0, 0.0005)
				noise(b, 0.0, 0.01, 0.3, 6000.0, 4000.0, 1000.0, 400.0, 0.0002)
			"levelup":
				for i in 4:
					bell(b, [0.0, 0.09, 0.18, 0.3][i], [523.25, 659.25, 783.99, 1046.5][i], 0.5, 4.5)
				sparkle(b, 0.3, 0.6, 8, 3000.0, 6000.0, 0.08, 20.0)
			"downed":
				for i in 3:
					var f: float = [440.0, 349.23, 293.66][i]
					tone(b, i * 0.3, 0.6 + i * 0.3, f, f * 0.985, 0.5, 4.0 - i, 0.02, 0.25)
			"revive":
				tone(b, 0.0, 0.7, 392.0, 392.0, 0.5, 4.0, 0.04, 0.3)
				tone(b, 0.18, 1.0, 523.25, 523.25, 0.5, 3.0, 0.04, 0.3)
				tone(b, 0.18, 1.0, 659.25, 659.25, 0.18, 3.5, 0.08)
			"coin", "buy":
				tone(b, 0.0, 0.09, 987.77, 987.77, 0.5, 25.0, 0.001, 0.2)
				tone(b, 0.07, 0.53, 1318.5, 1318.5, 0.5, 7.0, 0.001, 0.2)
				if name == "buy":   # ...and the coin bag
					noise(b, 0.18, 0.18, 1.0, 900.0, 350.0, 80.0, 25.0, 0.01)
					crunch(b, 0.18, 0.1, 4, 0.25, 2500.0, 600.0)
			"pickup":
				tone(b, 0.0, 0.14, 620.0, 1250.0, 0.6, 18.0, 0.004, 0.2)
			"ui_open", "ui_close":
				var op := name == "ui_open"
				noise(b, 0.0, 0.2, 0.6, 3000.0 if op else 5000.0, 5500.0 if op else 2500.0, 1200.0, 18.0, 0.05 if op else 0.02)
				tone(b, 0.03, 0.12, 330.0 if op else 400.0, 420.0 if op else 300.0, 0.35, 26.0, 0.003, 0.3)
			"chat":
				tone(b, 0.0, 0.045, 880.0, 980.0, 0.6, 40.0, 0.003, 0.2)
			"bite":
				tone(b, 0.0, 0.15, 1350.0, 1700.0, 0.5, 25.0, 0.001)
				noise(b, 0.03, 0.38, 0.5, 4000.0, 1200.0, 300.0, 9.0, 0.005)
				sparkle(b, 0.05, 0.2, 4, 1500.0, 3000.0, 0.2, 80.0, 1.5)
			"reel":
				for i in 5:
					tone(b, i * 0.026, 0.02, 2600.0, 2400.0, 0.5, 250.0, 0.0003)
					noise(b, i * 0.026, 0.01, 0.4, 5000.0, 4000.0, 1500.0, 400.0, 0.0002)
			"catch":
				var fs := [523.25, 659.25, 783.99, 1046.5]
				for i in 4:
					var last := i == 3
					tone(b, i * 0.11, 1.0 if last else 0.2, fs[i], fs[i], 0.45, 2.5 if last else 10.0,
						0.004, 0.25, 0.1, 0.006 if last else 0.0)
				sparkle(b, 0.33, 0.6, 8, 2500.0, 5500.0, 0.08, 20.0)
			"fish_escape":
				tone(b, 0.0, 0.68, 700.0, 240.0, 0.55, 3.5, 0.01, 0.2, 0.0, 0.06, 7.0)
				noise(b, 0.0, 0.2, 0.3, 3000.0, 800.0, 200.0, 15.0, 0.005)
			"door":
				pulses(b, 0.0, 0.42, 28.0, 55.0, 950.0, 0.35, 140.0, 0.15)
				tone(b, 0.45, 0.24, 160.0, 120.0, 0.8, 20.0, 0.001, 0.3)
				noise(b, 0.45, 0.05, 0.4, 2500.0, 800.0, 150.0, 70.0, 0.0005)
			"stairs":
				for i in 4:
					var a := pow(0.85, i)
					tone(b, i * 0.2, 0.09, 150.0 - i * 12.0, 80.0, 0.5 * a, 40.0)
					noise(b, i * 0.2, 0.08, 0.7 * a, 2600.0 - i * 300.0, 700.0, 200.0, 50.0, 0.002)
			"chest_open":
				pulses(b, 0.0, 0.35, 35.0, 60.0, 800.0, 0.3, 120.0, 0.2)
				tone(b, 0.0, 0.08, 180.0, 150.0, 0.3, 40.0, 0.001)
				for i in 4:
					bell(b, 0.35 + i * 0.06, [1318.5, 1568.0, 1975.5, 2637.0][i], 0.2, 5.0)
				sparkle(b, 0.4, 0.6, 10, 3000.0, 6500.0, 0.1, 30.0)
			"bubble":
				for i in 9:
					var f := rng.randf_range(260.0, 650.0)
					tone(b, rng.randf() * 0.8, 0.07, f, f * 2.2, rng.randf_range(0.3, 0.7), 35.0, 0.004)
				noise(b, 0.0, 0.88, 0.15, 500.0, 500.0, 100.0, 1.5, 0.2)
			"craft":
				for i in 3:
					var t := i * 0.16
					tone(b, t, 0.18, 1650.0 + i * 40.0, 1650.0 + i * 40.0, 0.35, 22.0, 0.0005)
					tone(b, t, 0.15, 2530.0, 2530.0, 0.2, 30.0, 0.0005)
					tone(b, t, 0.06, 160.0, 110.0, 0.5, 50.0, 0.001)
					noise(b, t, 0.015, 0.4, 6000.0, 4000.0, 1500.0, 300.0, 0.0002)
			"sell":
				for i in 6:
					var f := rng.randf_range(2000.0, 3200.0)
					var t := i * 0.075 + rng.randf() * 0.02
					tone(b, t, 0.35, f, f, 0.35, 12.0, 0.0005)
					tone(b, t, 0.15, f * 2.76, f * 2.76, 0.12, 30.0, 0.0005)
			"gift":
				for i in 3:
					bell(b, i * 0.08, [783.99, 987.77, 1318.5][i], 0.4, 3.5)
			"discovery":   # music-box motif D5 A5 G5 (+D6) over a soft D4
				tone(b, 0.0, 2.5, 293.66, 293.66, 0.25, 1.4, 0.3, 0.2)
				for i in 4:
					bell(b, [0.0, 0.28, 0.56, 0.95][i], [587.33, 880.0, 783.99, 1174.66][i], 0.45 if i < 3 else 0.2, 3.0)
			"quest":
				var qt := [0.0, 0.1, 0.2, 0.32, 0.42, 0.55]
				var qf := [523.25, 659.25, 783.99, 659.25, 783.99, 1046.5]
				for i in 6:
					var last := i == 5
					tone(b, qt[i], 1.0 if last else 0.18, qf[i], qf[i], 0.45, 2.4 if last else 6.0, 0.003, 0.3, 0.08)
				for f: float in [523.25, 659.25, 783.99]:
					tone(b, 0.55, 1.0, f, f, 0.12, 2.2, 0.05)
			"sleep":   # lullaby G5 E5 D5 C5 over C4/G3
				for i in 4:
					bell(b, i * 0.4, [783.99, 659.25, 587.33, 523.25][i], 0.4, 3.4)
				tone(b, 0.0, 2.5, 261.63, 261.63, 0.2, 1.2, 0.5, 0.2)
				tone(b, 0.8, 1.7, 196.0, 196.0, 0.15, 1.4, 0.5, 0.2)
			"thunder":
				noise(b, 0.0, 0.3, 0.8, 3500.0, 800.0, 100.0, 12.0, 0.003)
				noise(b, 0.0, 2.58, 0.9, 260.0, 50.0, 20.0, 1.3, 0.04)
				for i in 6:
					noise(b, rng.randf() * 1.5, 1.0, rng.randf_range(0.5, 1.0), 220.0, 70.0, 25.0, 2.5, 0.08)
			"bat":
				for t: float in [0.0, 0.09, 0.2]:
					tone(b, t, 0.04, 3600.0, 5200.0, 0.5, 30.0, 0.003)
			"growl":
				pulses(b, 0.0, 0.72, 55.0, 75.0, 260.0, 0.6, 45.0, 0.25)
				noise(b, 0.0, 0.72, 0.5, 400.0, 250.0, 50.0, 2.5, 0.1)
				tone(b, 0.0, 0.72, 70.0, 62.0, 0.4, 2.0, 0.12, 0.5, 0.3, 0.03, 9.0)
			"slime":
				tone(b, 0.0, 0.13, 140.0, 420.0, 0.6, 10.0, 0.01, 0.2)
				tone(b, 0.11, 0.22, 380.0, 130.0, 0.55, 12.0, 0.005, 0.2, 0.0, 0.08, 18.0)
				noise(b, 0.0, 0.32, 0.4, 900.0, 400.0, 80.0, 10.0, 0.01)
			"spit":
				tone(b, 0.0, 0.06, 450.0, 1300.0, 0.6, 30.0, 0.001)
				noise(b, 0.01, 0.17, 0.6, 3500.0, 1500.0, 600.0, 25.0, 0.002)
			"slam":
				tone(b, 0.0, 0.88, 75.0, 32.0, 1.0, 5.5, 0.001)
				noise(b, 0.0, 0.7, 0.9, 1800.0, 150.0, 30.0, 9.0, 0.001)
				noise(b, 0.0, 0.04, 0.5, 5000.0, 2000.0, 300.0, 90.0, 0.0003)
			"charge":
				noise(b, 0.0, 0.83, 0.8, 250.0, 2400.0, 80.0, 6.0, 0.55)
				pulses(b, 0.05, 0.75, 45.0, 95.0, 320.0, 0.4, 40.0, 0.2)
			"burrow":
				noise(b, 0.0, 0.78, 1.0, 500.0, 200.0, 40.0, 3.5, 0.1)
				crunch(b, 0.05, 0.6, 14, 0.4, 1800.0, 200.0)
				tone(b, 0.0, 0.7, 60.0, 45.0, 0.5, 4.0, 0.05)
			"enemy_die":
				tone(b, 0.0, 0.08, 380.0, 1500.0, 0.6, 25.0, 0.001)
				noise(b, 0.03, 0.45, 0.8, 2200.0, 400.0, 120.0, 8.0, 0.02)
				sparkle(b, 0.05, 0.3, 5, 2500.0, 5000.0, 0.1, 35.0)
			"telegraph":   # two detuned tones beating at 7 Hz
				tone(b, 0.0, 0.38, 330.0, 330.0, 0.4, 2.0, 0.06, 0.3, 0.15)
				tone(b, 0.0, 0.38, 337.0, 337.0, 0.4, 2.0, 0.06, 0.3)
			"arrow_hit":
				noise(b, 0.0, 0.05, 0.8, 3500.0, 1200.0, 250.0, 70.0, 0.0005)
				tone(b, 0.0, 0.12, 280.0, 170.0, 0.7, 30.0, 0.001)
				tone(b, 0.0, 0.28, 640.0, 620.0, 0.2, 18.0, 0.001, 0.0, 0.0, 0.03, 30.0)
			"chirp":   # ambience spot sounds from here on
				var t := 0.0
				var base := rng.randf_range(2300.0, 3900.0)
				for k in 2 + v % 4:
					var d := rng.randf_range(0.035, 0.08)
					var f0 := base * rng.randf_range(0.9, 1.15)
					var f1: float = f0 * float([1.35, 0.7, rng.randf_range(0.8, 1.25)][v % 3])
					tone(b, t, d, f0, f1, rng.randf_range(0.6, 1.0), 20.0, 0.006, 0.0, 0.0, 0.03 * (v % 2), 40.0)
					t += d + rng.randf_range(0.015, 0.07)
			"drip":
				var f := 1000.0 + v * 230.0
				for e in 3:
					tone(b, e * 0.13, 0.1, f, f * 1.9, [0.7, 0.22, 0.08][e], 40.0, 0.0008)
			"crackle":
				for i in 1 + v:
					var t := rng.randf() * 0.08
					noise(b, t, 0.012, rng.randf_range(0.5, 1.0), 7000.0, 3000.0, 1200.0, 350.0, 0.0002)
					if rng.randf() < 0.5:
						tone(b, t, 0.01, rng.randf_range(1200.0, 2000.0), 900.0, 0.2, 300.0, 0.0003)
			"rumble":
				noise(b, 0.0, 1.95, 1.0, 140.0, 60.0, 20.0, 1.2, 0.4)
				crunch(b, 0.4, 1.2, 8, 0.15, 2500.0, 400.0)
			_:
				return false
		return true
