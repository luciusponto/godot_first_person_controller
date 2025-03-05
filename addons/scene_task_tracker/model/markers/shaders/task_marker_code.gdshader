shader_type spatial;

render_mode unshaded; //blend_mix;

// Dithering effect from https://godotshaders.com/shader/transparency-dither/
//const vec3 magic = vec3(0.06711056f, 0.00583715f, 52.9829189f);
uniform float alpha = 0.75;

void fragment() {
	
	const float sRGB_to_linear = 1.0 / 2.2;
	ALBEDO = pow(COLOR.xyz, vec3(sRGB_to_linear));
	
	//if (alpha < 0.001 || alpha < fract(magic.z * fract(dot(FRAGCOORD.xy, magic.xy)))) {
		//discard;
	//}
}
