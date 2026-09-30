// Ground sigil: rotating, pulsing additive decal driven by the Codex sigil texture.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sigil : source_color, filter_linear_mipmap;
uniform vec3 color_a : source_color = vec3(1.0, 0.75, 0.35);
uniform vec3 color_b : source_color = vec3(0.4, 0.85, 1.0);
uniform float speed = 0.25;
uniform float intensity = 2.5;

void fragment() {
	vec2 c = UV - 0.5;
	float a = TIME * speed;
	vec2 r = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * c + 0.5;
	float m = texture(sigil, r).r;
	float d = length(c) * 2.0;
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0 - d * 8.0);
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.95, d));
	ALBEDO = col * m * pulse * intensity * (1.0 - smoothstep(0.92, 1.0, d));
}
