shader_type canvas_item;
render_mode unshaded;

// Quantize the already-composited world and weapon in one shared visible grid.
// This changes spatial sampling only: no palette, contrast or texture grading.
uniform vec2 virtual_resolution = vec2(320.0, 180.0);
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec2 virtual_pixel = floor(UV * virtual_resolution);
    // At 2:1 reduction the virtual midpoint lies on a native texel boundary.
    // Choose its containing texel explicitly, then sample the native center so
    // GPU nearest ties cannot shift a sample when the window changes size.
    vec2 source_pixel = floor((virtual_pixel + vec2(0.5))
        * (vec2(textureSize(TEXTURE, 0)) / virtual_resolution));
    vec2 sample_uv = (source_pixel + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
    COLOR = texture(TEXTURE, sample_uv) * vertex_tint;
}
