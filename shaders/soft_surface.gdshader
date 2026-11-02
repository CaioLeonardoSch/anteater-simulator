shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Superfície estilizada genérica (casca de árvore, barro de cupinzeiro, pedras,
// terra de formigueiro). Ruído triplanar em coordenadas de mundo, sem UVs.

global uniform vec2 wind_dir;
global uniform float wind_strength;

uniform vec3 color_a : source_color = vec3(0.45, 0.35, 0.28);
uniform vec3 color_b : source_color = vec3(0.62, 0.50, 0.40);
uniform vec3 accent_color : source_color = vec3(0.70, 0.66, 0.30);
uniform float noise_scale = 0.8;
uniform float detail_scale = 4.0;
uniform float accent_amount : hint_range(0.0, 1.0) = 0.0;
uniform float accent_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float accent_up_bias : hint_range(-1.0, 1.0) = 0.0;
uniform float streak_amount : hint_range(0.0, 1.0) = 0.0;
uniform float streak_scale = 6.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float specular_value : hint_range(0.0, 1.0) = 0.3;
uniform float vertex_color_mix : hint_range(0.0, 1.0) = 1.0;
uniform float sway = 0.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (sway > 0.0) {
		float h = max(VERTEX.y, 0.0);
		float s = sin(TIME * 1.3 + wpos.x * 0.21 + wpos.z * 0.17) * sway * h * h * wind_strength;
		VERTEX.xz += wind_dir * s;
	}
}

float tri_noise(vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float x = texture(noise_tex, p.zy * scale).r;
	float y = texture(noise_tex, p.xz * scale).r;
	float z = texture(noise_tex, p.xy * scale).r;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	float n1 = tri_noise(wpos, wnorm, noise_scale * 0.1);
	float n2 = tri_noise(wpos + 13.7, wnorm, detail_scale * 0.1);
	vec3 col = mix(color_a, color_b, smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4));
	if (streak_amount > 0.0) {
		float s = texture(noise_tex, vec2((wpos.x + wpos.z) * streak_scale * 0.05, wpos.y * 0.04)).r;
		col *= 1.0 - streak_amount * smoothstep(0.55, 0.75, s);
	}
	if (accent_amount > 0.0) {
		float a = smoothstep(accent_threshold, accent_threshold + 0.08, n2 + wnorm.y * accent_up_bias);
		col = mix(col, accent_color, a * accent_amount);
	}
	col = mix(col, col * COLOR.rgb, vertex_color_mix);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
