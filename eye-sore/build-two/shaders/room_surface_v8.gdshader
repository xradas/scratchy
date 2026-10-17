shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The full original PNG is bound here. AtlasTexture.region is also registered
// in the scene for inspection, but shader samplers need explicit atlas bounds.
uniform sampler2D painted_surface : source_color, filter_nearest, repeat_disable;
uniform vec4 source_region_pixels = vec4(0.0, 0.0, 512.0, 512.0);
uniform float pixels_per_metre = 64.0;
uniform float metal = 0.0;
uniform float base_roughness = 0.88;
varying vec3 surface_world_point;
varying vec3 surface_world_normal;

void vertex() {
	surface_world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// BoxMesh packs its six UV faces into a 3x2 grid. World projection bypasses
	// that unwrap completely: every face, floor and prism has square native
	// texels at the same density, independent of mesh size or node scale.
	vec3 n = abs(normalize(surface_world_normal));
	vec2 plane = surface_world_point.xy;
	if (n.y >= n.x && n.y >= n.z) {
		plane = surface_world_point.xz;
	} else if (n.x > n.z) {
		plane = surface_world_point.zy;
	}
	// Wrap locally before entering the source region. Integer pixel centres
	// cannot read another cell, even with negative coordinates or at seams.
	vec2 local_pixel = floor(fract(plane * pixels_per_metre / source_region_pixels.zw) * source_region_pixels.zw);
	vec2 atlas_uv = (source_region_pixels.xy + local_pixel + vec2(0.5)) / vec2(textureSize(painted_surface, 0));
	ALBEDO = texture(painted_surface, atlas_uv).rgb;
	METALLIC = metal;
	ROUGHNESS = base_roughness;
	SPECULAR = 0.22;
}
