// BountyHaven WW-style toon: lit/shade switched by a soft ramp on a fixed key light, cool rim, optional detail texture.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.6);
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_mix = 0.0;
uniform vec3 key_dir = vec3(-0.45, 0.75, 0.5);      // world space, towards the light
uniform vec2 ramp = vec2(0.42, 0.52);
uniform float rim = 0.15;
uniform vec3 rim_color : source_color = vec3(0.75, 0.85, 1.0);
uniform vec3 emit_color : source_color = vec3(0.0);
uniform float emit_strength = 0.0;
uniform float double_sided = 0.0;

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (!FRONT_FACING && double_sided > 0.5) { n = -n; }
	float ndl = max(dot(n, normalize(key_dir)), 0.0) * 0.95;      // matches Blender Diffuse -> Shader to RGB
	float t = smoothstep(ramp.x, ramp.y, ndl);
	vec3 tex = mix(vec3(1.0), texture(detail_tex, UV).rgb, tex_mix);
	vec3 col = mix(shade_color, lit_color, t) * tex;
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col += rim_color * smoothstep(0.55, 0.8, facing) * rim * (0.4 + 0.6 * t);
	col += emit_color * emit_strength;
	ALBEDO = col;
}
