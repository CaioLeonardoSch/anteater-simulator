shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Marco distante (o cupinzeiro gigante). A névoa do cenário o apagaria a 200 m,
// então ele calcula a própria névoa: a mesma conta da névoa do cenário (a cor do
// céu logo atrás dele, mais o brilho do sol), só que menos densa. Assim ele fica
// na mesma luz do resto, sem virar um recorte escuro contra o céu.

uniform vec3 color_a : source_color = vec3(0.5, 0.24, 0.13);
uniform vec3 color_b : source_color = vec3(0.78, 0.45, 0.26);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Quanto de névoa no topo e no pé (o pé, mais perto do chão, fica mais apagado).
uniform float haze_top = 0.22;
uniform float haze_base = 0.42;
// Névoa a mais quando a neblina volumétrica está ligada (ela clareia todo o resto).
uniform float extra_haze = 0.0;
// Brilho na borda virada para o sol (contraluz), como nas árvores.
uniform float rim_strength = 0.35;
// Escala do modelo no mundo (o desenho da terra e a névoa seguem o tamanho dele).
uniform float world_scale = 1.0;

// Copiados do céu, da névoa e do sol do cenário (world.gd).
uniform vec3 fog_color : source_color = vec3(0.92, 0.74, 0.6);
uniform float aerial = 0.6;
uniform float sun_scatter = 0.45;
uniform vec3 sun_dir = vec3(-0.84, 0.29, -0.45);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.56);
uniform float sun_energy = 1.85;
uniform vec3 zenith_color : source_color = vec3(0.26, 0.36, 0.62);
uniform vec3 mid_color : source_color = vec3(0.66, 0.62, 0.74);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.70, 0.45);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.6, 0.3);
uniform float sun_glow_power = 6.0;
uniform float sun_glow_strength = 0.9;
uniform float horizon_sharpness = 3.0;

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// A mesma conta do céu (sky_dusk.gdshader), sem as nuvens e sem o disco do sol.
vec3 sky_color(vec3 dir, vec3 sdir) {
	float h = dir.y;
	float t_up = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.25, pow(t_up, 0.8)));
	col = mix(col, zenith_color, smoothstep(0.2, 0.85, t_up));
	float sun_side = dot(normalize(dir.xz + 1e-4), normalize(sdir.xz + 1e-4)) * 0.5 + 0.5;
	float horizon_band = exp(-max(h, 0.0) * horizon_sharpness);
	col = mix(col, sun_glow_color, horizon_band * pow(sun_side, 3.0) * 0.55);
	float sd = max(dot(dir, sdir), 0.0);
	col += sun_glow_color * pow(sd, sun_glow_power) * sun_glow_strength;
	return col;
}

void fragment() {
	vec3 lp = wpos / world_scale;
	// Posição em volta do eixo do cupinzeiro (para os sulcos que descem).
	vec3 rel = (wpos - MODEL_MATRIX[3].xyz) / world_scale;
	float ang = atan(rel.z, rel.x);
	float n = texture(noise_tex, lp.xz * 0.012 + vec2(0.0, lp.y * 0.01)).r;
	float streak = texture(noise_tex, vec2((lp.x + lp.z) * 0.03, lp.y * 0.004)).r;
	float wob = texture(noise_tex, vec2(ang * 0.4, rel.y * 0.006)).r;
	// Sulcos verticais da chuva escorrendo (ondulados, mais fundos no meio da torre).
	float rib_ph = ang * 34.0 + wob * 9.0 + rel.y * 0.02;
	float rib = sin(rib_ph);
	float gully = smoothstep(0.35, 0.95, -rib);
	// Camadas de barro, uma por cima da outra.
	float layer = smoothstep(0.55, 0.95, sin(rel.y * 0.55 + n * 5.0));
	vec3 base = mix(color_a, color_b, smoothstep(0.3, 0.7, n)) * COLOR.rgb;
	base *= mix(0.8, 1.08, smoothstep(0.35, 0.65, streak));
	base *= 1.0 - gully * 0.32;
	base *= 1.0 - layer * 0.12;
	// Pé úmido e escuro, topo seco e mais claro.
	float hgt = smoothstep(4.0, 70.0, rel.y);
	base *= mix(0.72, 1.12, hgt);
	ALBEDO = base;
	ROUGHNESS = 1.0;

	// Os sulcos entortam a luz: um lado da costela pega sol, o outro fica na sombra.
	vec3 tang = normalize(vec3(-sin(ang), 0.0, cos(ang)));
	vec3 nrm = normalize(normalize(wnormal) + tang * cos(rib_ph) * 0.55 * (1.0 - smoothstep(0.7, 0.95, abs(normalize(wnormal).y))));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);

	vec3 sdir = normalize(sun_dir);
	vec3 view = normalize(wpos - CAMERA_POSITION_WORLD);
	// Contraluz: olhando para o lado do sol, a borda virada para ele acende.
	float rim = pow(1.0 - clamp(dot(nrm, -view), 0.0, 1.0), 3.0);
	float toward_sun = smoothstep(0.2, 1.0, dot(view, sdir));
	float sun_side = clamp(dot(nrm, sdir) + 0.35, 0.0, 1.0);
	EMISSION = sun_color * sun_energy * rim * toward_sun * sun_side * rim_strength;

	// Névoa: cor do céu atrás dele + brilho do sol, como a névoa do cenário.
	vec3 fog_col = mix(fog_color, sky_color(view, sdir), aerial);
	fog_col += sun_color * sun_energy * sun_scatter * pow(max(dot(view, sdir), 0.0), 8.0);
	float amount = mix(haze_base, haze_top, smoothstep(0.0, 55.0, lp.y));
	amount = 1.0 - (1.0 - amount) * (1.0 - extra_haze);
	FOG = vec4(fog_col, amount);
}
