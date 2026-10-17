shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Native existing atlas pixels on every real face; no mesh UVs required.
uniform sampler2D painted_surface : source_color, filter_nearest, repeat_disable;
uniform vec4 trim_region = vec4(0.0, 512.0, 512.0, 512.0);
uniform vec4 face_region = vec4(1024.0, 512.0, 512.0, 512.0);
uniform vec4 floor_region = vec4(512.0, 0.0, 512.0, 512.0);
uniform float pixels_per_metre = 64.0;
// 0 metal equipment; 1 platform; 2 control; 3 integral exit frame.
uniform int surface_mode = 0;
uniform vec3 local_half_size = vec3(0.75, 0.9, 0.25);
uniform bool engaged = false;
varying vec3 world_point;
varying vec3 world_normal;
varying vec3 local_point;
varying vec3 local_normal;
void vertex() {
 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
 local_point = VERTEX;
 local_normal = NORMAL;
}
void fragment() {
 vec3 n = abs(normalize(world_normal));
 vec2 plane = world_point.xy;
 if (n.y >= n.x && n.y >= n.z) { plane = world_point.xz; }
 else if (n.x > n.z) { plane = world_point.zy; }
 vec4 region = trim_region;
 bool front = local_normal.z > 0.6;
 if (surface_mode == 1 && local_normal.y > 0.6) { region = floor_region; }
 if (surface_mode == 2 && front) { region = face_region; }
 vec2 face = local_point.xy / max(local_half_size.xy, vec2(0.001));
 if (surface_mode == 3 && front) {
  // Door pixels in the recess; trim on the integral frame and threshold.
  if (abs(face.x) < 0.77 && face.y < 0.78 && face.y > -0.70) { region = face_region; }
 }
 vec2 pixel = floor(fract(plane * pixels_per_metre / region.zw) * region.zw);
 vec2 uv = (region.xy + pixel + vec2(0.5)) / vec2(textureSize(painted_surface, 0));
 ALBEDO = texture(painted_surface, uv).rgb;
 METALLIC = 0.72;
 ROUGHNESS = 0.82;
 SPECULAR = 0.22;
 if (surface_mode == 3 && front) {
  // Narrow physical status strip in the existing top frame, not a new portal.
  if (abs(face.x) < (engaged ? 0.60 : 0.28) && face.y > 0.83 && face.y < 0.89) {
   vec3 light = engaged ? vec3(0.48, 0.67, 0.33) : vec3(0.58, 0.18, 0.08);
   ALBEDO = light; EMISSION = light * 0.35;
  }
 }
}
