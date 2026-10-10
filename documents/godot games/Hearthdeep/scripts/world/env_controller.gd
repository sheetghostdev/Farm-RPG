class_name EnvController
extends Node
## Lighting, sky, fog, weather particles, seasonal tints and ambience for
## whatever zone the local player is standing in.

var env: Environment
var we: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var rain: CPUParticles3D
var snow: CPUParticles3D
var motes: CPUParticles3D
var _flash := 0.0
var _thunder_t := 8.0
var _profile := "surface"
var _cave_tint := Color(0.5, 0.45, 0.4)
var _cave_fog := Color(0.05, 0.04, 0.04)
var _cave_amb := 0.35
var _music_t := 0.0

func _ready() -> void:
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.25
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 1.5
	sun.light_cull_mask = 1
	add_child(sun)
	rain = _precip(false)
	snow = _precip(true)
	motes = _motes()

func _precip(is_snow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	if is_snow:
		p.mesh = Meshes.particle_mesh(0.09)
		p.amount = 900
		p.lifetime = 5.0
		p.gravity = Vector3(0.4, -1.4, 0.2)
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.5
		p.color = Color(1, 1, 1, 0.9)
	else:
		var q := QuadMesh.new()
		q.size = Vector2(0.025, 0.55)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.75, 0.82, 0.95, 0.45)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		q.material = m
		p.mesh = q
		p.amount = 1600
		p.lifetime = 0.9
		p.gravity = Vector3(0.6, -28.0, 0.0)
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 6.0
		p.direction = Vector3.DOWN
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 0.5, 22)
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	add_child(p)
	return p

func _motes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = Meshes.particle_mesh(0.07, true)
	p.amount = 70
	p.lifetime = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 4, 14)
	p.gravity = Vector3(0, 0.08, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.spread = 180.0
	p.local_coords = false
	p.emitting = false
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.7))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = g
	add_child(p)
	return p

## Called when the local player changes zone.
func set_zone(z: Zone) -> void:
	_profile = z.env_profile()
	if z.has_method("cave_palette"):
		var pal: Dictionary = z.cave_palette()
		_cave_tint = pal.get("ambient", _cave_tint)
		_cave_fog = pal.get("fog", _cave_fog)
		_cave_amb = pal.get("amb", 0.35)
		motes.color = pal.get("motes", Color(1, 0.9, 0.7))
	_update_audio(true)

func _process(delta: float) -> void:
	if not Game.running:
		return
	var lp = Game.local_player
	var focus: Vector3 = lp.global_position if lp else Vector3.ZERO
	match _profile:
		"surface":
			_surface(delta, focus)
		"home":
			_home()
		_:
			_cave(focus)
	_seasonal_globals(delta)
	var night := 1.0 - Game.daylight() if _profile == "surface" else (0.6 if _profile == "home" else 1.0)
	RenderingServer.global_shader_parameter_set("night_amount", night)
	if lp:
		RenderingServer.global_shader_parameter_set("player_pos", lp.global_position)
	_music_t += delta
	if _music_t > 3.0:
		_music_t = 0.0
		_update_audio(false)

func _surface(delta: float, focus: Vector3) -> void:
	var w := Game.weather()
	var dl := Game.daylight()
	var m := float(Game.clock_minutes())
	# sun travels east -> west; moon takes over at night
	var day_frac := clamp((m - 330.0) / (1230.0 - 330.0), 0.0, 1.0)
	var elev := sin(day_frac * PI)
	var sun_pitch = -lerp(8.0, 62.0, elev)
	var sun_yaw = lerp(-110.0, 110.0, day_frac) + 30.0
	if dl <= 0.02:
		sun_pitch = -50.0
		sun_yaw = 160.0
	sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0)
	var dusk = clamp(1.0 - abs(elev) * 2.2, 0.0, 1.0) * float(dl > 0.02)
	var sun_col := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.38), dusk)
	var moon_col := Color(0.55, 0.65, 0.95)
	var overcast := 0.0
	match w:
		"cloudy":
			overcast = 0.45
		"rain", "snow":
			overcast = 0.65
		"storm":
			overcast = 0.85
		"fog":
			overcast = 0.5
	sun.light_color = sun_col.lerp(moon_col, 1.0 - dl)
	sun.light_energy = lerp(0.32, 1.45 - overcast * 0.75, dl)
	sun.shadow_enabled = true
	sun.visible = true
	# sky
	var top_day := Color(0.33, 0.56, 0.86).lerp(Color(0.5, 0.55, 0.6), overcast)
	var hor_day := Color(0.72, 0.82, 0.9).lerp(Color(0.68, 0.7, 0.72), overcast)
	var top_night := Color(0.05, 0.07, 0.16)
	var hor_night := Color(0.16, 0.19, 0.3)
	var dusk_col := Color(0.95, 0.55, 0.35)
	sky_mat.sky_top_color = top_night.lerp(top_day, dl)
	sky_mat.sky_horizon_color = hor_night.lerp(hor_day, dl).lerp(dusk_col, dusk * 0.7 * (1.0 - overcast))
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	sky_mat.ground_bottom_color = Color(0.15, 0.17, 0.12).lerp(Color(0.02, 0.02, 0.04), 1.0 - dl)
	sky_mat.sky_energy_multiplier = lerp(0.35, 1.0, dl)
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = lerp(0.55, 0.55 + overcast * 0.2, dl)
	env.fog_enabled = true
	var fog_col := sky_mat.sky_horizon_color
	var dens := 0.0012 + overcast * 0.003
	if w == "fog":
		dens = 0.022
		fog_col = Color(0.75, 0.78, 0.8).lerp(Color(0.12, 0.13, 0.18), 1.0 - dl)
	elif w == "snow":
		dens = 0.012
		fog_col = Color(0.85, 0.88, 0.92).lerp(Color(0.15, 0.16, 0.22), 1.0 - dl)
	env.fog_light_color = fog_col
	env.fog_density = lerp(env.fog_density, dens, 0.05)
	env.fog_sky_affect = 0.2 if w != "fog" else 0.8
	env.glow_hdr_threshold = 1.1 if dl > 0.5 else 0.8
	env.adjustment_saturation = lerp(0.85, 1.14 - overcast * 0.18, dl)
	# weather particles
	rain.emitting = w == "rain" or w == "storm"
	rain.amount = 2400 if w == "storm" else 1500
	snow.emitting = w == "snow"
	rain.global_position = focus + Vector3(0, 14, 0)
	snow.global_position = focus + Vector3(0, 12, 0)
	# fireflies on summer nights, pollen/dust on bright days
	var s := Game.season()
	motes.emitting = (dl < 0.4 and s == 1 and w == "clear") or (dl > 0.7 and s in [0, 1] and w == "clear")
	motes.global_position = focus + Vector3(0, 1.5, 0)
	if dl < 0.4:
		motes.color = Color(0.85, 1.0, 0.4)
		motes.mesh = Meshes.particle_mesh(0.1, true)
	else:
		motes.color = Color(1, 1, 0.9, 0.6)
		motes.mesh = Meshes.particle_mesh(0.05, false)
	# lightning
	if w == "storm":
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(7.0, 18.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 1.6)).timeout.connect(func(): Sfx.play("thunder", -4.0))
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 3.0)
		sun.light_energy += _flash * 2.5
		env.ambient_light_energy += _flash
	# town & lamp lights at night
	var lamps_on := dl < 0.45 or w in ["storm", "fog"]
	for l in Zones.night_lights:
		if is_instance_valid(l):
			l.visible = lamps_on

func _home() -> void:
	sun.visible = false
	rain.emitting = false
	snow.emitting = false
	motes.emitting = false
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.7, 0.55)
	env.ambient_light_energy = 0.45 + 0.35 * Game.daylight()
	env.fog_enabled = false
	env.adjustment_saturation = 1.05
	env.glow_hdr_threshold = 0.9

func _cave(focus: Vector3) -> void:
	sun.visible = false
	rain.emitting = false
	snow.emitting = false
	env.background_mode = Environment.BG_COLOR
	env.background_color = _cave_fog
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _cave_tint
	env.ambient_light_energy = _cave_amb * 2.4
	env.fog_enabled = true
	env.fog_light_color = _cave_fog
	env.fog_density = 0.014
	env.fog_sky_affect = 1.0
	env.adjustment_saturation = 1.1
	env.glow_hdr_threshold = 0.75
	motes.emitting = true
	motes.global_position = focus + Vector3(0, 1.5, 0)

func _seasonal_globals(delta: float) -> void:
	var s := Game.season()
	var dos = float(Game.day_of_season() - 1) / max(1, Game.season_len() - 1)
	var w := Game.weather()
	var tint := Color(1, 1, 1, 0)
	var leaves := 1.0
	var snow_v := 0.0
	match s:
		0:
			tint = Color(0.75, 1.0, 0.55, 0.18 * (1.0 - dos))
			leaves = 0.75 + 0.25 * dos
		1:
			tint = Color(0.85, 0.95, 0.4, 0.12 * dos)
		2:
			tint = Color(1.0, 0.5, 0.18, 0.35 + 0.5 * dos)
			leaves = 1.0 - 0.55 * max(0.0, dos - 0.3)
		3:
			tint = Color(0.8, 0.72, 0.6, 0.55)
			leaves = 0.0
			snow_v = clamp(0.55 + dos, 0.0, 1.0) if w != "clear" or dos > 0.2 else 0.4
	if w == "snow":
		snow_v = 1.0
	var wet := 1.0 if w in ["rain", "storm"] else 0.0
	var wind := 1.0
	match w:
		"storm":
			wind = 3.0
		"rain":
			wind = 1.6
		"cloudy":
			wind = 1.3
		"fog":
			wind = 0.4
	if _profile != "surface":
		wet = 0.0
		snow_v = 0.0
		wind = 0.3
	RenderingServer.global_shader_parameter_set("season_tint", tint)
	RenderingServer.global_shader_parameter_set("leaf_density", leaves)
	RenderingServer.global_shader_parameter_set("snow_amount", snow_v)
	RenderingServer.global_shader_parameter_set("wetness", wet)
	RenderingServer.global_shader_parameter_set("wind_strength", wind)

func _update_audio(force: bool) -> void:
	var lp = Game.local_player
	if lp == null:
		return
	var z = lp.zone()
	if z == null:
		return
	var w := Game.weather()
	var music := "day"
	var amb := "birds"
	match _profile:
		"home":
			music = "home"
			amb = "indoor"
		"surface":
			if Game.is_night():
				music = "night"
				amb = "night"
			if w in ["rain", "storm"]:
				music = "rain"
				amb = "rain" if w == "rain" else "storm"
			elif w == "snow" or w == "fog":
				amb = "wind"
			if z is Overworld and (z as Overworld).gen.town_rect.grow(10).has_point(Vector2(lp.global_position.x, lp.global_position.z)) and not Game.is_night():
				music = "town"
		_:
			var f := Zones.floor_of(z.zone_id)
			music = "cave" if f <= 12 else "cave_deep"
			amb = "cave" if f <= 12 else "cave_deep"
	Sfx.set_music(music)
	Sfx.set_ambience(amb)
