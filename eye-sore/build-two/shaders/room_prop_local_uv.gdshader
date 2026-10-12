shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Godot's BoxMesh unwraps six faces into a 3x2 UV grid. Each face receives a
// complete authored atlas panel by normalizing its own cell; cylinders keep
// their ordinary 0..1 UVs. Neither path depends on world position.
uniform sampler2D painted_surface : source_color, filter_nearest, repeat_disable;
uniform vec4 source_region_pixels = vec4(4.0, 4.0, 306.0, 306.0);
uniform bool box_mesh_uv = true;

void fragment() {
	vec2 local_uv = box_mesh_uv ? fract(UV * vec2(3.0, 2.0)) : UV;
	vec2 half_texel = vec2(0.5) / source_region_pixels.zw;
	local_uv = clamp(local_uv, half_texel, vec2(1.0) - half_texel);
	vec2 atlas_size = vec2(textureSize(painted_surface, 0));
	vec2 atlas_uv = (source_region_pixels.xy + local_uv * source_region_pixels.zw) / atlas_size;
	ALBEDO = texture(painted_surface, atlas_uv).rgb;
	METALLIC = 0.18;
	ROUGHNESS = 0.82;
	SPECULAR = 0.24;
}
