shader_type spatial;

uniform sampler2D noise;

uniform sampler2D ground_tex;
uniform sampler2D ground_normal_map;
uniform sampler2D ground_roughness_map;
uniform sampler2D ground_ao_map;
uniform sampler2D ground_displacement;

uniform sampler2D mountain_tex;
uniform sampler2D mountain_normal_map;
uniform sampler2D mountain_roughness_map;
uniform sampler2D mountain_ao_map;
uniform sampler2D mountain_displacement;

uniform sampler2D rock_tex;
uniform sampler2D rock_normal_map;
uniform sampler2D rock_roughness_map;
uniform sampler2D rock_ao_map;
uniform sampler2D rock_displacement;

uniform sampler2D sand_tex;
uniform sampler2D sand_normal_map;
uniform sampler2D sand_roughness_map;
uniform sampler2D sand_ao_map;
uniform sampler2D sand_displacement;

uniform float displacement_scale = 0.04;
uniform float ao_strength = 3.5;
uniform float height_scale = 7.5;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 world_tangent;
varying vec3 world_bitangent;

varying vec4 blend;

const vec3 DOWN = vec3(0.0, -1.0, 0.0);
// ( MOUNTAIN, SAND, ROCK, GROUND)

vec3 albedo_blend(vec2 uv, vec4 factor) {
	vec3 mountain = texture(mountain_tex, uv).rgb;
	vec3 sand = texture(sand_tex, uv).rgb;
	vec3 rock = texture(rock_tex, uv).rgb;
	vec3 ground = texture(ground_tex, uv).rgb;
	return mountain * factor.x + sand * factor.y +
		   rock * factor.z + ground * factor.w;
}
vec3 normal_blend(vec2 uv, vec4 factor) {
	vec3 mountain = texture(mountain_normal_map, uv).rgb;
	vec3 sand = texture(sand_normal_map, uv).rgb;
	vec3 rock = texture(rock_normal_map, uv).rgb;
	vec3 ground = texture(ground_normal_map, uv).rgb;
	return mountain * factor.x + sand * factor.y +
		   rock * factor.z + ground * factor.w;
}
float roughness_blend(vec2 uv, vec4 factor) {
	float mountain = texture(mountain_roughness_map, uv).r;
	float sand = texture(sand_roughness_map, uv).r;
	float rock = texture(rock_roughness_map, uv).r;
	float ground = texture(ground_roughness_map, uv).r;
	return mountain * factor.x + sand * factor.y +
		   rock * factor.z + ground * factor.w;
}
float displacement_blend(vec2 uv, vec4 factor) {
	float mountain = texture(mountain_displacement, uv).r;
	float sand = texture(sand_displacement, uv).r;
	float rock = texture(rock_displacement, uv).r;
	float ground = texture(ground_displacement, uv).r;
	return mountain * factor.x + sand * factor.y +
		   rock * factor.z + ground * factor.w;
}

float ao_blend(vec2 uv, vec4 factor) {
	float mountain = texture(mountain_ao_map, uv).r;
	float sand = texture(sand_ao_map, uv).r;
	float rock = texture(rock_ao_map, uv).r;
	float ground = texture(ground_ao_map, uv).r;
	return mountain * factor.x + sand * factor.y +
		   rock * factor.z + ground * factor.w;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.001;

    float h = texture(noise, world_position.xz).r;
	float magic = 1.2 * h * 1.1 * h * 1.6 * h * height_scale * h * height_scale;
	magic = magic - (1.0 / magic);
	h = h * magic;
	// cursed height algo
    VERTEX.y = h;
	VERTEX.y -= 2.5;

    // finite difference method :>>>
    float height_right = texture(noise, world_position.xz + vec2(-0.01, 0.0)).r * magic;
    float height_up = texture(noise, world_position.xz + vec2(0.0, -0.01)).r * magic;

    vec3 local_tangent = normalize(vec3(-0.01, (height_right - VERTEX.y), 0.0));
    vec3 local_bitangent = normalize(vec3(0.0, (height_up - VERTEX.y), -0.01));

    world_tangent = normalize(local_tangent);
    world_bitangent = normalize(local_bitangent);
    world_normal = normalize(cross(world_tangent, world_bitangent));

	float randiff =  0.0;//texture(noise, world_position.xz * vec2(500.0, 500.0)).r;
	if (abs(dot(world_normal, DOWN)) < 0.00125) {
	    blend = vec4(0.0, 0.0, 1.0, 0.0); // Rock cliff
	} else if (VERTEX.y * randiff > 5.0) {
	    blend = vec4(1.0, 0.0, 0.0, 0.0); // Mountain
	} else if (VERTEX.y * randiff < 0.0) {
	    blend = vec4(0.0, 1.0, 0.0, 0.0); // Sand
	} else {
	    blend = vec4(0.0, 0.0, 0.0, 1.0); // Ground
	}
}

void fragment() {
	// cursed cursed cursed cursed cursed
    vec3 view_normal = normalize(VIEW_MATRIX * vec4(world_normal, 0.0)).xyz;
    vec3 view_tangent = normalize(VIEW_MATRIX * vec4(world_tangent, 0.0)).xyz;
    vec3 view_bitangent = normalize(VIEW_MATRIX * vec4(world_bitangent, 0.0)).xyz;

    view_tangent = normalize(view_tangent - dot(view_tangent, view_normal) * view_normal);
    view_bitangent = normalize(cross(view_normal, view_tangent));
    mat3 TBN = mat3(view_tangent, view_bitangent, view_normal);

    vec2 uv = world_position.xz * 20.0;

	// PARALLAX stillingar
	vec3 view_dir_tangent = normalize(TBN * (normalize(CAMERA_POSITION_WORLD - world_position)));
	float num_layers = mix(32.0, 8.0, abs(view_dir_tangent.z));
	float layer_depth = 1.0 / num_layers;
	float current_layer_depth = 0.0;

	// stilla þetta til að fá minna nasty warping glitch
	float min_view_angle = 0.6;
	vec2 delta_uv = (view_dir_tangent.xy / max(abs(view_dir_tangent.z), min_view_angle)) * (displacement_scale / num_layers) ;

	vec2 current_uv = uv;
	float current_depth = displacement_blend(current_uv, blend) + texture(noise, current_uv).r;
	float previous_depth = 0.0;

	// oof
	for (float i = 0.0; i < num_layers; i++) {
	    previous_depth = current_depth;
	    current_layer_depth += layer_depth;
	    current_uv -= delta_uv * 0.99;
	    current_depth = displacement_blend(current_uv, blend) * texture(noise, current_uv).r;

	    if (current_layer_depth >= current_depth) break;
	}
	vec2 prev_uv = current_uv + delta_uv ;
	float prev_depth = displacement_blend(prev_uv, blend) + texture(noise, current_uv).r;
	float refined_uv_offset = 0.2;

	// binary search >:000
	for (int j = 0; j < 5; j++) {
	    vec2 mid_uv = mix(prev_uv, current_uv, refined_uv_offset);
	    float mid_depth = displacement_blend(mid_uv, blend) + texture(noise, current_uv).r;

	    if (current_layer_depth < mid_depth) {
	        current_uv = mid_uv;
	    } else {
	        prev_uv = mid_uv;
	    }

	    refined_uv_offset *= 0.5;
	}
	vec2 final_uv = current_uv;

    // evil uv
    float ao = ao_blend(final_uv, blend);
    ao = mix(1.0, ao, ao_strength);

	// GL normal
    vec3 normal_tex = normal_blend(final_uv, blend).xyz * 2.0 - 1.0;
    vec3 normal_view = TBN * normal_tex;

    NORMAL = normalize(normal_view);
    ALBEDO = albedo_blend(final_uv, blend) * ao;
	//vec3(final_uv, 0.0);
    ROUGHNESS =roughness_blend(final_uv, blend);
}