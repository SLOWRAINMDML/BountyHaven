// BountyHaven ink & watercolor character shading (Godot 4.x).
// Soft-edged watercolor washes: warm cream light, slate-blue shadow wash,
// pigment pooling at silhouettes, paper grain from the texture the GLB carries.
// Outlines come from the inverted-hull "M_outline" surfaces in the GLB (brown ink).
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D paper_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float paper_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 light_tint : source_color = vec3(1.04, 1.0, 0.93);
uniform vec3 shadow_tint : source_color = vec3(0.56, 0.64, 0.82);
uniform float wash_soft : hint_range(0.01, 0.5) = 0.12;
uniform float mid_value : hint_range(0.0, 1.0) = 0.55;
uniform float edge_pool : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec3 paper = texture(paper_tex, UV).rgb;
	ALBEDO = albedo.rgb * mix(vec3(1.0), paper, paper_strength);
	ROUGHNESS = 1.0;
	// pigment pools where the surface turns away from the viewer
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO *= mix(1.0 - edge_pool, 1.0, smoothstep(0.0, 0.6, facing));
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = ndl * ATTENUATION;
	// two soft steps: shadow wash -> mid wash -> light
	float a = smoothstep(0.22 - wash_soft, 0.22 + wash_soft, lit);
	float b = smoothstep(0.55 - wash_soft, 0.55 + wash_soft, lit);
	vec3 wash = mix(shadow_tint, mix(shadow_tint, light_tint, mid_value), a);
	wash = mix(wash, light_tint, b);
	DIFFUSE_LIGHT += wash * LIGHT_COLOR / PI;
}
