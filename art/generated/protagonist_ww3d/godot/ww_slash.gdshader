// Crescent slash trail: UV.x runs along the arc, UV.y across it. A bright head sweeps along with TIME.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.85, 0.5);
uniform vec3 edge : source_color = vec3(0.4, 0.85, 1.0);
uniform float intensity = 3.0;
uniform float period = 1.6;
uniform float phase = 0.0;

void fragment() {
	float head = fract(TIME / period + phase) * 1.4;
	float along = UV.x;
	float trail = smoothstep(head - 0.7, head, along) * (1.0 - smoothstep(head, head + 0.02, along));
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	vec3 col = mix(edge, core, smoothstep(0.2, 0.9, across));
	ALBEDO = col * trail * pow(across, 0.6) * intensity;
}
