shader_type spatial;
render_mode world_vertex_coords, cull_back, diffuse_burley, specular_schlick_ggx;
// Língua comprida e grudenta do tamanduá: um tubo que segue uma curva de Bézier
// (p0 boca -> p3 ponta). A malha é um cilindro unitário: VERTEX.xy = anel, VERTEX.z = t.

uniform vec3 p0 = vec3(0.0);
uniform vec3 p1 = vec3(0.0, 0.0, -0.3);
uniform vec3 p2 = vec3(0.0, 0.0, -0.6);
uniform vec3 p3 = vec3(0.0, 0.0, -1.0);
uniform float r0 = 0.004;
uniform float r1 = 0.011;
uniform float wobble = 0.0;
uniform vec3 tongue_color : source_color = vec3(0.92, 0.42, 0.50);
uniform vec3 tip_color : source_color = vec3(0.98, 0.58, 0.62);

varying float vt;

vec3 bez(float t) {
	float u = 1.0 - t;
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3;
}

vec3 bez_d(float t) {
	float u = 1.0 - t;
	return 3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2);
}

void vertex() {
	float t = VERTEX.z;
	vec2 ring = VERTEX.xy;
	vec3 c = bez(t);
	vec3 tg = normalize(bez_d(t) + vec3(1e-5, 0.0, 0.0));
	vec3 ref = abs(tg.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 side = normalize(cross(tg, ref));
	vec3 up = cross(tg, side);
	float r = mix(r0, r1, sqrt(t));
	r *= 1.0 + 0.18 * sin(t * 40.0 - TIME * 25.0) * wobble;
	r *= 1.0 + smoothstep(0.92, 1.0, t) * 0.35;
	vec3 n = side * ring.x + up * ring.y;
	VERTEX = c + n * r;
	NORMAL = n;
	vt = t;
}

void fragment() {
	vec3 col = mix(tongue_color, tip_color, smoothstep(0.6, 1.0, vt));
	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.7;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.08;
	RIM = 0.35;
	RIM_TINT = 0.5;
	BACKLIGHT = col * 0.4;
}
