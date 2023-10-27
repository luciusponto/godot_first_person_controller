shader_type spatial;

render_mode unshaded, blend_mix;

uniform float alpha = 0.75;

void fragment() {
	
	const float sRGB_to_linear = 1.0 / 2.2;
	ALBEDO = pow(COLOR.xyz, vec3(sRGB_to_linear));
	ALPHA = alpha;
}
