shader_type canvas_item;

void fragment() {
    vec2 uv = UV;

    uv.x += sin((uv.y * 30.0) + TIME * 2.5) * 0.015;
    uv.y += cos((uv.x * 25.0) + TIME * 2.0) * 0.008;

    COLOR = texture(TEXTURE, uv);
}