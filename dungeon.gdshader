shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform float u_time = 0.0;
uniform float u_fadeout_time = 0.0;
uniform float u_torch_level = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
	float factor = u_torch_level * 2.5 * (0.175 + 0.025 * cos(0.2 * 2.0 * PI * u_time));
	float fadeout_factor = 1.0 - 0.9 * sin(PI / 2.0 * u_fadeout_time);
    COLOR = tex * vec4(vec3(0.9, 0.7, 0.8) * factor * fadeout_factor, tex.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
