// BountyHaven protagonist: MToon 1.0 style toon (VRMC_materials_mtoon shading term) with a fixed key light.
//   shading = linearstep(-1 + toony, 1 - toony, dot(N, L) + shift);  color = mix(shade, base, shading)
//   rim     = rim_color * pow(saturate(1 - dot(N, V) + rim_lift), rim_fresnel_power)
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 lit_color : source_color = vec3(1.0);
uniform vec3 shade_color : source_color = vec3(0.6);
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_mix = 0.0;
uniform vec3 key_dir = vec3(-0.45, 0.75, 0.5);      // world space, towards the light
uniform float shading_shift = -0.495;
uniform float shading_toony = 0.947;
uniform vec3 rim_color : source_color = vec3(0.0);
uniform float rim_fresnel_power = 3.0;
uniform float rim_lift = 0.0;
uniform vec3 emit_color : source_color = vec3(0.0);
uniform float emit_strength = 0.0;
uniform float double_sided = 0.0;

float linearstep(float a, float b, float x) { return clamp((x - a) / max(b - a, 1e-4), 0.0, 1.0); }

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (!FRONT_FACING && double_sided > 0.5) { n = -n; }
	float shading = dot(n, normalize(key_dir)) + shading_shift;
	shading = linearstep(-1.0 + shading_toony, 1.0 - shading_toony, shading);
	vec4 tx = texture(detail_tex, UV);
	vec3 tex = mix(vec3(1.0), tx.rgb, tex_mix);
	vec3 col = mix(shade_color, lit_color, shading) * tex;
	float rim = pow(clamp(1.0 - dot(NORMAL, VIEW) + rim_lift, 0.0, 1.0), rim_fresnel_power);
	col += rim_color * rim * (0.4 + 0.6 * shading);
	col += emit_color * emit_strength;
	ALBEDO = col;
	//ALPHA_CUT
}
