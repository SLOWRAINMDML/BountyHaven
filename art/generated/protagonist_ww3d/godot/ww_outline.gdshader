// Inverted-hull outline pass (next_pass of the toon material).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec3 outline_color : source_color = vec3(0.12, 0.08, 0.06);
uniform float thickness = 0.0028;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color;
}
