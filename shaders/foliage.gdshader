shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Copas fofas (estilo animação): núcleo opaco + cartões de folhas com recorte.
// COLOR.r = sombreamento interno (0 dentro .. 1 borda), COLOR.a = peso do balanço.

global uniform vec2 wind_dir;
global uniform float wind_strength;

uniform vec3 color_dark : source_color = vec3(0.16, 0.30, 0.12);
uniform vec3 color_light : source_color = vec3(0.47, 0.62, 0.22);
uniform vec3 color_tip : source_color = vec3(0.86, 0.78, 0.36);
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float use_texture : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.45;
uniform float sway = 0.05;
uniform float backlight_amount = 0.65;
// Cartões com a estampa de folhas: tom de cada folha (canal G) e folhas
// secas (canal B). Zero nos ipês (a estampa das flores não tem esses canais).
uniform float tone_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dry_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dry_color : source_color = vec3(0.55, 0.38, 0.18);

varying vec3 wpos;
varying float vshade;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.5 + wpos.x * 0.37 + wpos.y * 0.61 + wpos.z * 0.29)
		+ 0.5 * sin(TIME * 3.1 + wpos.x * 1.3 + wpos.z * 1.1);
	VERTEX += vec3(wind_dir.x, 0.15, wind_dir.y) * s * sway * wind_strength * COLOR.a;
	vshade = COLOR.r;
}

void fragment() {
	vec4 leaf = texture(leaf_tex, UV);
	if (use_texture > 0.5) {
		// Com mipmaps (versões menores da textura para longe) o recorte das folhas
		// afinaria com a distância: compensa a transparência pelo nível usado.
		vec2 tp = UV * vec2(textureSize(leaf_tex, 0));
		float mip = max(0.0, 0.5 * log2(max(dot(dFdx(tp), dFdx(tp)), dot(dFdy(tp), dFdy(tp)))));
		ALPHA = leaf.a * (1.0 + mip * 0.25);
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
	float n = texture(noise_tex, wpos.xz * 0.31 + vec2(wpos.y * 0.13, -wpos.y * 0.11)).r;
	vec3 col = mix(color_dark, color_light, smoothstep(0.15, 0.9, vshade * 0.75 + n * 0.45));
	col = mix(col, color_tip, smoothstep(0.78, 1.05, vshade + (n - 0.5) * 0.5) * 0.55);
	col *= mix(0.78, 0.72 + leaf.r * 0.42, use_texture);
	// Cada folha puxa um pouco para o amarelado ou para o azulado.
	float tg = (pow(leaf.g, 0.4545) - 0.5) * 2.0 * tone_amount * use_texture;
	col *= vec3(1.0 + tg * 0.12, 1.0 + tg * 0.04, 1.0 - tg * 0.22);
	// Folhas secas (e os raminhos), marrons.
	col = mix(col, dry_color * (0.55 + leaf.r * 0.6), leaf.b * dry_amount * use_texture);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
	BACKLIGHT = col * backlight_amount;
	AO = mix(0.45, 1.0, vshade);
	AO_LIGHT_AFFECT = 0.45;
}
