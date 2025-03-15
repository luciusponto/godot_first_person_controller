shader_type spatial;

render_mode unshaded, skip_vertex_transform; //blend_mix;

// Dithering effect from https://godotshaders.com/shader/transparency-dither/
const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
uniform vec2 fade_start_end_dist = vec2(2., 5.);
uniform float alpha : hint_range(0.0, 1.0, 0.1) = 0.25;
varying float fade_alpha;
varying vec3 vert_col;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	const float sRGB_to_linear = 1.0 / 2.2;
	vert_col = pow(COLOR.xyz, vec3(sRGB_to_linear));
	float dist = -VERTEX.z;
	float fade_t = (dist - fade_start_end_dist.x) / (fade_start_end_dist.y - fade_start_end_dist.x);
	fade_alpha = mix(alpha, 1., 1. - clamp(fade_t, 0., 1.));
}

void fragment() {

	const float sRGB_to_linear = 1.0 / 2.2;
	ALBEDO = vert_col;

	//if (alpha < 0.001 || alpha < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
	if (fade_alpha < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
		discard;
	}
}
