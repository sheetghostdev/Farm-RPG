extends Node
## Shared materials, shaders and a cache of procedurally built meshes.

var _mats := {}
var _meshes := {}

const CUTAWAY := """
global uniform vec3 player_pos;
global uniform float cutaway_enabled;
uniform float cut_radius = 2.6;
void cutaway(vec3 wp, vec3 cam, vec2 frag) {
	if (cutaway_enabled < 0.5) { return; }
	vec3 pp = player_pos + vec3(0.0, 1.1, 0.0);
	vec3 seg = pp - cam;
	float t = clamp(dot(wp - cam, seg) / max(dot(seg, seg), 0.001), 0.0, 1.0);
	float d = length(wp - (cam + seg * t));
	if (t < 0.93 && wp.y > player_pos.y + 0.35) {
		float f = 1.0 - smoothstep(cut_radius * 0.55, cut_radius, d);
		float b = mod(floor(frag.x) + floor(frag.y) * 2.0, 4.0) / 4.0 + 0.125;
		if (f > b) { discard; }
	}
}
"""

const NOISE := """
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
"""

const SH_WINDOW := """
shader_type spatial;
render_mode diffuse_burley;
global uniform float night_amount;
void fragment() {
	vec3 glass = vec3(0.22, 0.28, 0.34);
	ALBEDO = mix(glass, COLOR.rgb * 0.6, 0.25 + 0.5 * night_amount);
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
	EMISSION = COLOR.rgb * vec3(1.0, 0.8, 0.55) * (0.1 + 0.95 * night_amount);
}
"""

const SH_VC := """
shader_type spatial;
render_mode diffuse_burley;
global uniform float snow_amount;
global uniform float wetness;
uniform float roughness_v = 0.88;
uniform float snow_ok = 1.0;
uniform float cut_ok = 0.0;
uniform float emission_v = 0.0;
uniform float hide = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
%s
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	if (hide > 0.5 && wpos.y > player_pos.y + 1.5) { discard; }
	if (cut_ok > 0.5) { cutaway(wpos, CAMERA_POSITION_WORLD, FRAGCOORD.xy); }
	vec3 col = COLOR.rgb;
	float n = vnoise(wpos.xz * 3.1 + wpos.y * 1.7);
	col *= 0.94 + 0.12 * n;
	float s = smoothstep(0.55, 0.85, wnorm.y) * snow_amount * snow_ok;
	col = mix(col, vec3(0.93, 0.95, 1.0), s * 0.9);
	col *= 1.0 - 0.18 * wetness * snow_ok;
	ALBEDO = col;
	ROUGHNESS = mix(roughness_v, 0.35, wetness * snow_ok * 0.7);
	EMISSION = COLOR.rgb * emission_v;
}
"""

const SH_GLOW := """
shader_type spatial;
render_mode diffuse_burley;
uniform float strength = 2.2;
uniform float pulse = 0.25;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float p = 1.0 - pulse + pulse * sin(TIME * 1.7 + wpos.x * 0.7 + wpos.z * 0.5);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.3;
	EMISSION = COLOR.rgb * strength * p;
}
"""

const SH_FOLIAGE := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
global uniform float wind_strength;
global uniform float leaf_density;
global uniform vec4 season_tint;
global uniform float snow_amount;
uniform float deciduous = 1.0;
uniform float sway = 1.0;
uniform float cut_ok = 1.0;
varying vec3 wpos;
varying vec3 wnorm;
varying float vhash;
%s
%s
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * 1.6 + w.x * 0.35 + w.z * 0.27) * 0.045 * wind_strength * sway * h;
	VERTEX.x += s;
	VERTEX.z += s * 0.6;
	wpos = w;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vhash = hash12(floor(origin.xz * 1.37) + vec2(3.1, 7.7));
}
void fragment() {
	if (cut_ok > 0.5) { cutaway(wpos, CAMERA_POSITION_WORLD, FRAGCOORD.xy); }
	if (deciduous > 0.5) {
		float h = hash12(floor(wpos.xz * 3.0 + wpos.y * 5.0));
		if (h > leaf_density) { discard; }
	}
	vec3 col = COLOR.rgb;
	float amt = season_tint.a * (deciduous > 0.5 ? 1.0 : 0.25);
	vec3 target = season_tint.rgb * vec3(0.85 + 0.3 * vhash, 0.55 + 0.6 * fract(vhash * 7.3), 0.7 + 0.4 * fract(vhash * 3.1));
	col = mix(col, target * (0.75 + 0.5 * COLOR.g), amt);
	float s = smoothstep(0.3, 0.8, wnorm.y) * snow_amount * (deciduous > 0.5 ? 0.0 : 1.0);
	col = mix(col, vec3(0.92, 0.95, 1.0), s * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.8;
	BACKLIGHT = vec3(0.25, 0.3, 0.15);
}
"""

const SH_GRASS := """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
global uniform float wind_strength;
global uniform vec4 season_tint;
global uniform float snow_amount;
varying vec3 wpos;
%s
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float s = (sin(TIME * 2.1 + w.x * 0.5 + w.z * 0.4) + 0.5 * sin(TIME * 3.3 + w.x * 1.3)) * 0.12 * wind_strength * h;
	VERTEX.x += s;
	VERTEX.z += s * 0.5;
	wpos = w;
}
void fragment() {
	vec3 col = COLOR.rgb;
	col = mix(col, season_tint.rgb * (0.7 + 0.5 * COLOR.g), season_tint.a * 0.55);
	col = mix(col, vec3(0.9, 0.93, 1.0), snow_amount * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.2, 0.25, 0.1);
}
"""

const SH_TERRAIN := """
shader_type spatial;
render_mode diffuse_burley;
global uniform float snow_amount;
global uniform float wetness;
global uniform vec4 season_tint;
varying vec3 wpos;
varying vec3 wnorm;
%s
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 col = COLOR.rgb;
	float grassy = COLOR.a;
	float n1 = vnoise(wpos.xz * 0.35);
	float n2 = vnoise(wpos.xz * 2.7);
	col *= 0.9 + 0.12 * n1 + 0.08 * n2;
	vec3 seasonal = season_tint.rgb * (0.65 + 0.4 * n1);
	col = mix(col, seasonal * col.g * 1.6, season_tint.a * 0.45 * grassy);
	float s = smoothstep(0.5, 0.8, wnorm.y) * snow_amount;
	s *= smoothstep(0.25, 0.6, n2 * 0.4 + 0.6);
	col = mix(col, vec3(0.92, 0.94, 0.99), s);
	col *= 1.0 - 0.22 * wetness;
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.4, wetness * 0.8);
}
"""

const SH_WATER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.25, 0.62, 0.72, 1.0);
uniform vec4 deep : source_color = vec4(0.08, 0.28, 0.42, 1.0);
uniform float glow = 0.0;
uniform float alpha_v = 0.82;
uniform float speed = 1.0;
global uniform float wetness;
varying vec3 wpos;
%s
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(w.x * 0.7 + TIME * 1.3 * speed) + sin(w.z * 0.9 - TIME * 1.1 * speed)) * 0.03;
	wpos = w;
}
void fragment() {
	float t = TIME * speed;
	float n = vnoise(wpos.xz * 0.8 + vec2(t * 0.25, t * 0.18));
	float n2 = vnoise(wpos.xz * 2.3 - vec2(t * 0.4, -t * 0.3));
	float rain = wetness * step(0.93, hash12(floor(wpos.xz * 6.0) + floor(vec2(t * 7.0))));
	vec2 slope = vec2(n - 0.5, n2 - 0.5) * 0.9 + vec2(rain * 0.5);
	NORMAL_MAP = normalize(vec3(0.5 + slope.x * 0.5, 0.5 + slope.y * 0.5, 1.0));
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep.rgb, shallow.rgb, 0.35 + 0.4 * n);
	float sparkle = step(0.86, n2) * (0.5 + 0.5 * sin(t * 4.0 + wpos.x * 3.0));
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
	ALPHA = clamp(alpha_v + fres * 0.25, 0.0, 1.0);
	EMISSION = col * glow * (0.35 + 0.5 * n) + vec3(sparkle) * glow * 0.35;
}
"""

const SH_LAVA := """
shader_type spatial;
render_mode unshaded;
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vnoise(wpos.xz * 0.6 + vec2(TIME * 0.12, TIME * 0.05));
	float n2 = vnoise(wpos.xz * 1.7 - vec2(TIME * 0.2, 0.0));
	float h = n * 0.65 + n2 * 0.35;
	vec3 col = mix(vec3(0.45, 0.04, 0.02), vec3(1.0, 0.55, 0.08), smoothstep(0.35, 0.8, h));
	col = mix(col, vec3(1.0, 0.92, 0.5), smoothstep(0.78, 0.95, h));
	ALBEDO = col * 1.6;
}
"""

const SH_CAVE_WALL := """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strata = 1.0;
varying vec3 wpos;
%s
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	cutaway(wpos, CAMERA_POSITION_WORLD, FRAGCOORD.xy);
	vec3 col = COLOR.rgb * tint.rgb;
	float band = sin(wpos.y * 4.0 + vnoise(wpos.xz * 0.5) * 6.0) * 0.5 + 0.5;
	col *= 0.85 + 0.15 * band * strata + 0.1 * vnoise(wpos.xz * 2.0 + wpos.y);
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
"""

func _ready() -> void:
	pass

func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s

func mat(nm: String) -> Material:
	if _mats.has(nm):
		return _mats[nm]
	var m: Material
	match nm:
		"vc":
			m = _sm(SH_VC % [NOISE, CUTAWAY], {})
		"vc_nosnow":
			m = _sm(SH_VC % [NOISE, CUTAWAY], {"snow_ok": 0.0})
		"vc_cut":
			m = _sm(SH_VC % [NOISE, CUTAWAY], {"cut_ok": 1.0})
		"vc_hidden":
			m = _sm(SH_VC % [NOISE, CUTAWAY], {"hide": 1.0})
		"vc_shiny":
			m = _sm(SH_VC % [NOISE, CUTAWAY], {"roughness_v": 0.3, "snow_ok": 0.0})
		"vc_soft_glow":
			m = _sm(SH_VC % [NOISE, CUTAWAY], {"emission_v": 0.6, "snow_ok": 0.0})
		"glow":
			m = _sm(SH_GLOW, {})
		"glow_steady":
			m = _sm(SH_GLOW, {"pulse": 0.0, "strength": 1.6})
		"window":
			m = _sm(SH_WINDOW, {})
		"foliage":
			m = _sm(SH_FOLIAGE % [NOISE, CUTAWAY], {})
		"foliage_ever":
			m = _sm(SH_FOLIAGE % [NOISE, CUTAWAY], {"deciduous": 0.0})
		"foliage_still":
			m = _sm(SH_FOLIAGE % [NOISE, CUTAWAY], {"deciduous": 0.0, "sway": 0.25, "cut_ok": 0.0})
		"plant":
			m = _sm(SH_FOLIAGE % [NOISE, CUTAWAY], {"deciduous": 0.0, "sway": 1.5, "cut_ok": 0.0})
		"grass":
			m = _sm(SH_GRASS % [NOISE], {})
		"terrain":
			m = _sm(SH_TERRAIN % [NOISE], {})
		"water":
			m = _sm(SH_WATER % [NOISE], {})
		"water_cave":
			m = _sm(SH_WATER % [NOISE], {"shallow": Color(0.18, 0.55, 0.62), "deep": Color(0.02, 0.1, 0.16), "glow": 0.55, "alpha_v": 0.9})
		"water_hot":
			m = _sm(SH_WATER % [NOISE], {"shallow": Color(0.45, 0.75, 0.7), "deep": Color(0.2, 0.45, 0.5), "glow": 0.1, "alpha_v": 0.85})
		"lava":
			m = _sm(SH_LAVA % [NOISE], {})
		"cave_wall":
			m = _sm(SH_CAVE_WALL % [NOISE, CUTAWAY], {})
		"cave_cap":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.roughness = 1.0
			m = sm
		"flash":
			var f := StandardMaterial3D.new()
			f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			f.albedo_color = Color(1, 1, 1, 0.0)
			f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			f.render_priority = 1
			m = f
		"ghost_ok", "ghost_bad":
			var g := StandardMaterial3D.new()
			g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			g.albedo_color = Color(0.4, 1.0, 0.5, 0.45) if nm == "ghost_ok" else Color(1.0, 0.35, 0.3, 0.45)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.no_depth_test = false
			m = g
		"unshaded":
			var u := StandardMaterial3D.new()
			u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			u.vertex_color_use_as_albedo = true
			u.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			u.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = u
		"telegraph":
			var tg := StandardMaterial3D.new()
			tg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tg.albedo_color = Color(1.0, 0.25, 0.15, 0.35)
			tg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tg.cull_mode = BaseMaterial3D.CULL_DISABLED
			tg.no_depth_test = true
			tg.render_priority = 2
			m = tg
		"select":
			var sel := StandardMaterial3D.new()
			sel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sel.albedo_color = Color(1.0, 0.95, 0.6, 0.55)
			sel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sel.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = sel
		"particle":
			var p := StandardMaterial3D.new()
			p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			p.vertex_color_use_as_albedo = true
			p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m = p
		"particle_lit":
			var pl := StandardMaterial3D.new()
			pl.vertex_color_use_as_albedo = true
			pl.roughness = 0.9
			m = pl
		"particle_glow":
			var pg := StandardMaterial3D.new()
			pg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pg.vertex_color_use_as_albedo = true
			pg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pg.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pg.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m = pg
		_:
			m = _sm(SH_VC % [NOISE, CUTAWAY], {})
	_mats[nm] = m
	return m

func _sm(code: String, params: Dictionary) -> ShaderMaterial:
	var key := code.md5_text()
	var sh: Shader
	if _mats.has("__sh_" + key):
		sh = _mats["__sh_" + key]
	else:
		sh = _shader(code)
		_mats["__sh_" + key] = sh
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

## Cached mesh by key; builder is a Callable returning a Mesh.
func cached(key: String, builder: Callable) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh = builder.call()
	_meshes[key] = m
	return m

func has_mesh(key: String) -> bool:
	return _meshes.has(key)

## Small helper: a MeshInstance3D for a mesh at a transform.
func inst(mesh: Mesh, parent: Node, pos: Vector3 = Vector3.ZERO, rot_y: float = 0.0, scl: float = 1.0, vis_range: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot_y
	if scl != 1.0:
		mi.scale = Vector3.ONE * scl
	if vis_range > 0.0:
		mi.visibility_range_end = vis_range
		mi.visibility_range_end_margin = 4.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(mi)
	return mi

func quad_mesh(size: Vector2, mat_name: String) -> Mesh:
	return cached("quad_%s_%s" % [str(size), mat_name], func():
		var q := QuadMesh.new()
		q.size = size
		q.material = mat(mat_name)
		return q)

func particle_mesh(sz: float, glow: bool = false) -> Mesh:
	var key := "pmesh_%.2f_%s" % [sz, str(glow)]
	return cached(key, func():
		var q := QuadMesh.new()
		q.size = Vector2(sz, sz)
		q.material = mat("particle_glow" if glow else "particle")
		return q)

func cube_particle_mesh(sz: float) -> Mesh:
	return cached("pcube_%.2f" % sz, func():
		var b := BoxMesh.new()
		b.size = Vector3.ONE * sz
		b.material = mat("particle_lit")
		return b)
