shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Paredões de arenito. As paredes usam a estampa de rocha feita no Blender
// (camadas, fendas, blocos), projetada de lado com as camadas sempre na
// horizontal; o topo usa a estampa do chão, puxada para o verde. As cores de
// vértice (faixas creme e vermelhas, pé mais escuro) continuam por cima.

uniform vec3 color_a : source_color = vec3(0.50, 0.31, 0.21);
uniform vec3 color_b : source_color = vec3(0.70, 0.51, 0.37);
// Cor do topo (o platô com mato).
uniform vec3 accent_color : source_color = vec3(0.46, 0.52, 0.26);
uniform float noise_scale = 0.35;
uniform float detail_scale = 2.6;
// Quanto as manchas grandes de duas cores aparecem (a estampa já traz o detalhe).
uniform float tint_variation : hint_range(0.0, 1.0) = 0.4;
uniform float streak_amount : hint_range(0.0, 1.0) = 0.15;
uniform float streak_scale = 3.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.93;
uniform float specular_value : hint_range(0.0, 1.0) = 0.2;
uniform float vertex_color_mix : hint_range(0.0, 1.0) = 1.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.05;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform sampler2D rocha_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D topo_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D topo_relevo : hint_normal, filter_linear_mipmap, repeat_enable;
// Cor média de cada estampa (o detalhe é a estampa dividida por ela).
uniform vec3 rocha_media : source_color = vec3(0.796, 0.610, 0.468);
uniform vec3 topo_media : source_color = vec3(0.382, 0.316, 0.183);
// Tamanho de uma estampa no mundo, em metros.
uniform float tile_size = 4.0;
uniform float top_tile_size = 2.0;
// As camadas sobem e descem devagar ao longo do paredão (metros), para a
// estampa não se repetir sempre na mesma altura.
uniform float strata_warp = 1.2;
uniform float detail_amount : hint_range(0.0, 1.5) = 1.0;
uniform float relief_strength : hint_range(0.0, 3.0) = 1.0;
// Distância (m) em que o relevo some, para não piscar de longe.
uniform vec2 relief_fade = vec2(50.0, 120.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Tom geral, como antes (manchas grandes de duas cores).
	float n1 = tri_noise(wpos, nw, noise_scale * 0.1);
	float n2 = tri_noise(wpos + 13.7, nw, detail_scale * 0.1);
	vec3 tint = mix(color_a, color_b, 0.5 + (smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4) - 0.5) * tint_variation);

	// Pesos das três direções; o topo (virado para cima) usa a estampa do chão.
	vec3 w = pow(abs(nw), vec3(6.0));
	w /= (w.x + w.y + w.z);
	bool up = nw.y > 0.0;

	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(relief_fade.x, relief_fade.y, dist);
	bool near = fade > 0.0;

	float warp = (texture(noise_tex, wpos.xz * 0.004).r - 0.5) * strata_warp;
	float vy = -(wpos.y + warp) / tile_size;
	float sx = nw.x >= 0.0 ? 1.0 : -1.0;
	float sz = nw.z >= 0.0 ? -1.0 : 1.0;
	vec2 uvx = vec2(wpos.z * sx / tile_size, vy);
	vec2 uvz = vec2(wpos.x * sz / tile_size + 0.43, vy);
	vec2 uvy = up ? wpos.xz / top_tile_size : wpos.xz / tile_size;
	vec4 gx = vec4(dFdx(uvx), dFdy(uvx));
	vec4 gz = vec4(dFdx(uvz), dFdy(uvz));
	vec4 gy = vec4(dFdx(uvy), dFdy(uvy));

	vec4 cx = vec4(rocha_media, 0.5), cz = cx, cy = cx;
	if (w.x > 0.01) cx = textureGrad(rocha_cor, uvx, gx.xy, gx.zw);
	if (w.z > 0.01) cz = textureGrad(rocha_cor, uvz, gz.xy, gz.zw);
	if (w.y > 0.01) {
		cy = up ? textureGrad(topo_cor, uvy, gy.xy, gy.zw) : textureGrad(rocha_cor, uvy, gy.xy, gy.zw);
	}
	// Mistura pela altura: onde as direções se encontram, fica por cima o que é
	// mais alto (sem imagem fantasma de duas fendas).
	vec3 wh = w * (vec3(cx.a, cy.a, cz.a) + 0.15);
	wh = pow(wh, vec3(3.0));
	wh /= (wh.x + wh.y + wh.z + 1e-6);

	vec3 rock_x = cx.rgb / rocha_media;
	vec3 rock_z = cz.rgb / rocha_media;
	vec3 det_y = cy.rgb / (up ? topo_media : rocha_media);
	vec3 wall = tint * mix(vec3(1.0), rock_x * wh.x + rock_z * wh.z, detail_amount);
	vec3 top = (up ? accent_color : tint) * mix(vec3(1.0), det_y, detail_amount);
	vec3 col = wall + top * wh.y;

	if (streak_amount > 0.0) {
		float s = texture(noise_tex, vec2((wpos.x + wpos.z) * streak_scale * 0.05, wpos.y * 0.04)).r;
		col *= 1.0 - streak_amount * smoothstep(0.55, 0.75, s) * (1.0 - wh.y);
	}
	col = mix(col, col * COLOR.rgb, vertex_color_mix);
	ALBEDO = col;

	if (near) {
		vec3 pert = vec3(0.0);
		if (wh.x > 0.01) {
			vec2 t = textureGrad(rocha_relevo, uvx, gx.xy, gx.zw).rg * 2.0 - 1.0;
			pert += wh.x * vec3(0.0, t.y, t.x * sx);
		}
		if (wh.z > 0.01) {
			vec2 t = textureGrad(rocha_relevo, uvz, gz.xy, gz.zw).rg * 2.0 - 1.0;
			pert += wh.z * vec3(t.x * sz, t.y, 0.0);
		}
		if (wh.y > 0.01) {
			vec2 t = (up ? textureGrad(topo_relevo, uvy, gy.xy, gy.zw).rg : textureGrad(rocha_relevo, uvy, gy.xy, gy.zw).rg) * 2.0 - 1.0;
			pert += wh.y * vec3(t.x, 0.0, -t.y);
		}
		vec3 n2w = normalize(nw + pert * relief_strength * fade);
		NORMAL = normalize((VIEW_MATRIX * vec4(n2w, 0.0)).xyz);
	}
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
