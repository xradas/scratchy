shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

varying vec3 basin_world;

void vertex() {
	basin_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = basin_world.xz;
	float ripple = sin(p.x * 0.74 + TIME * 1.25) * sin(p.y * 0.55 - TIME * 0.92);
	float current = sin((p.x + p.y) * 0.21 + TIME * 0.47);
	float cross_wake = sin((p.x - p.y) * 1.05 - TIME * 1.42);
	float flow = ripple * 0.46 + current * 0.33 + cross_wake * 0.21;
	float scum = smoothstep(0.14, 0.42, flow);
	float foam = smoothstep(0.55, 0.68, flow);
	vec3 waste = mix(vec3(0.045, 0.12, 0.035), vec3(0.14, 0.29, 0.055), scum);
	waste = mix(waste, vec3(0.31, 0.42, 0.095), foam * 0.65);
	ALBEDO = waste;
	EMISSION = waste * 0.9;
	ROUGHNESS = 0.22 + (1.0 - scum) * 0.22;
}
