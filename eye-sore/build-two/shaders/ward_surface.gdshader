shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Exact, untouched approved board pixels. Wrap within the chosen swatch only:
// nearest filtering never selects atlas mipmaps or blends neighboring artwork.
uniform sampler2D painted_surface : source_color, filter_nearest, repeat_disable;
uniform vec4 source_region_pixels = vec4(1216.0, 625.0, 111.0, 102.0);
uniform float world_scale = 0.3;
uniform vec4 tint : source_color = vec4(1.0);
uniform float metal = 0.0;
uniform float base_roughness = 0.7;
uniform float relief = 1.0;
varying vec3 world_point;
varying vec3 world_normal;

vec3 region_paint(vec2 local_uv) {
	vec2 region_size = source_region_pixels.zw;
	vec2 half_pixel = vec2(0.5) / region_size;
	vec2 wrapped = clamp(fract(local_uv), half_pixel, vec2(1.0) - half_pixel);
	vec2 board_size = vec2(textureSize(painted_surface, 0));
	vec2 atlas_uv = (source_region_pixels.xy + wrapped * region_size) / board_size;
	return texture(painted_surface, atlas_uv).rgb;
}

vec3 painted(vec3 point, vec3 weights) {
	return region_paint(point.zy * world_scale) * weights.x
		+ region_paint(point.xz * world_scale) * weights.y
		+ region_paint(point.xy * world_scale) * weights.z;
}

float height_at(vec3 point, vec3 weights) {
	return dot(painted(point, weights), vec3(0.299, 0.587, 0.114));
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 paint = painted(world_point, weights);
	// Relief offsets use the same local wrap and inner-region clamp as albedo.
	// A source-pixel step avoids inventing subpixel texture detail.
	float step_size = 1.0 / (min(source_region_pixels.z, source_region_pixels.w) * world_scale);
	vec3 gradient = vec3(
		height_at(world_point + vec3(step_size,0.0,0.0), weights) - height_at(world_point - vec3(step_size,0.0,0.0), weights),
		height_at(world_point + vec3(0.0,step_size,0.0), weights) - height_at(world_point - vec3(0.0,step_size,0.0), weights),
		height_at(world_point + vec3(0.0,0.0,step_size), weights) - height_at(world_point - vec3(0.0,0.0,step_size), weights));
	vec3 bumped = normalize(n - (gradient - n * dot(gradient,n)) * relief);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped,0.0)).xyz);
	ALBEDO = paint * tint.rgb;
	METALLIC = metal;
	ROUGHNESS = clamp(base_roughness + (0.18 - dot(paint,vec3(0.333))) * 0.65, 0.24, 0.94);
	SPECULAR = 0.55;
}
