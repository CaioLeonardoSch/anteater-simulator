shader_type sky;
// Céu de fim de tarde estilizado: degradê, sol com halo e nuvens pintadas.

uniform vec3 zenith_color : source_color = vec3(0.23, 0.30, 0.55);
uniform vec3 mid_color : source_color = vec3(0.62, 0.55, 0.70);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.66, 0.40);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.55, 0.25);
uniform vec3 ground_color : source_color = vec3(0.30, 0.22, 0.16);
uniform vec3 cloud_lit_color : source_color = vec3(1.0, 0.78, 0.60);
uniform vec3 cloud_shadow_color : source_color = vec3(0.55, 0.42, 0.55);
uniform float sun_disk_size = 0.035;
uniform float sun_glow_power = 11.0;
uniform float sun_glow_strength = 0.65;
uniform float horizon_sharpness = 3.0;
uniform float brightness = 1.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.16;
uniform vec2 cloud_offset = vec2(0.0);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(-0.6, 0.15, -0.8));

	// Degradê vertical em três faixas.
	float t_up = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.25, pow(t_up, 0.8)));
	col = mix(col, zenith_color, smoothstep(0.2, 0.85, t_up));

	// Lado do sol mais quente.
	float sun_side = dot(normalize(vec2(dir.x, dir.z) + 1e-4), normalize(vec2(sun_dir.x, sun_dir.z) + 1e-4)) * 0.5 + 0.5;
	float horizon_band = exp(-max(h, 0.0) * horizon_sharpness);
	col = mix(col, sun_glow_color, horizon_band * pow(sun_side, 3.0) * 0.55);

	// Halo e disco do sol.
	float sd = max(dot(dir, sun_dir), 0.0);
	col += sun_glow_color * pow(sd, sun_glow_power) * sun_glow_strength;
	col += vec3(1.0, 0.85, 0.6) * pow(sd, 120.0) * 1.2;
	float disk = smoothstep(1.0 - sun_disk_size * 0.012, 1.0 - sun_disk_size * 0.009, sd);
	col = mix(col, vec3(1.0, 0.93, 0.78) * 6.0, disk);

	// Nuvens pintadas (projeção num plano alto).
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * 0.22 + cloud_offset;
		float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.3 + 0.37).r * 0.35;
		float cover = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
		cover *= smoothstep(0.02, 0.18, h) * (1.0 - smoothstep(0.55, 0.95, h));
		float lit = clamp(pow(sd, 2.0) * 0.8 + sun_side * 0.4 + (n - 0.5), 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow_color, cloud_lit_color, lit);
		ccol += sun_glow_color * pow(sd, 8.0) * 0.8;
		col = mix(col, ccol, cover * 0.92);
	}

	// Abaixo do horizonte.
	float below = smoothstep(0.0, -0.08, h);
	col = mix(col, mix(horizon_color * 0.6, ground_color, smoothstep(0.0, -0.4, h)), below);

	COLOR = col * brightness;
}
