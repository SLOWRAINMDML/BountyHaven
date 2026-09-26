shader_type canvas_item;
// Illustration sprites only. UI/text bypass this shader entirely.
// COLOR already contains texture sampling in canvas_item: never multiply it twice.
uniform float grain_strength : hint_range(0.0, 0.2) = 0.022;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    float grain = hash21(floor(UV * vec2(1600.0, 900.0)));
    float fiber = sin(UV.y * 2410.0) * sin(UV.x * 1710.0);
    COLOR.rgb *= 1.0 - grain_strength * (grain + fiber * 0.2);
}
