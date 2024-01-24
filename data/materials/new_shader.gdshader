shader_type canvas_item;

uniform int pixelSize = 4;

void fragment() {
    ivec2 size = textureSize(TEXTURE, 0);

    int xRes = size.x;
    int yRes = size.y;

    // Calculate aspect ratio
    float aspectRatio = float(xRes) / float(yRes);

    // Adjust the UV coordinates based on the aspect ratio
    float xFactor = float(xRes) / float(pixelSize);
    float yFactor = float(yRes) / float(pixelSize);

    // Apply aspect ratio correction to both x and y coordinates
    float grid_uv_x = round((UV.x * aspectRatio) * xFactor) / xFactor;
    grid_uv_x /= aspectRatio;
    float grid_uv_y = round(UV.y * yFactor) / yFactor;

    vec4 text = texture(TEXTURE, vec2(grid_uv_x, grid_uv_y));

    COLOR = text;
}
