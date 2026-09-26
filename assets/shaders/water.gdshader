shader_type canvas_item;
uniform vec4 water_color : source_color = vec4(0.57, 0.70, 0.68, 0.62);
void fragment() {
    float wave = sin(UV.y * 165.0 + TIME * 0.48 + sin(UV.x * 12.0 + TIME * 0.18) * 2.0);
    float fleck = smoothstep(0.92, 1.0, wave) * (0.3 + 0.3 * sin(UV.x * 65.0));
    COLOR = vec4(water_color.rgb + vec3(fleck * 0.25), water_color.a);
}
