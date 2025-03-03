shader_type spatial;

uniform sampler2D dirnoise;
uniform sampler2D colornoise;
uniform sampler2D gradient;
uniform sampler2D normal_texture;

uniform float initspeed;
uniform float amplitude;
uniform float freq;
uniform int wavecount;

uniform float maxpeak;
uniform float drag;

varying float h;
varying vec3 world_position;

struct Wave {
	vec2 direction;
	vec2 origin;
	float frequency;
	float amplitude;
	float phase;
};

float GetWaveCoord(vec3 v, vec2 d, Wave w) {
	return v.x * d.x + v.z * d.y;
}

float GetTime(Wave w) {
	return TIME * w.phase;
}

float Sine(vec3 v, Wave w) {
	vec2 d = w.direction;
	float xz = GetWaveCoord(v, d, w);
	float t = GetTime(w);
	return w.amplitude * sin(xz * w.frequency + t);
}

vec3 SineNormal(vec3 v, Wave w) {
	vec2 d = w.direction;
	float xz = GetWaveCoord(v, d, w);
	float t = GetTime(w);

	// Compute partial derivatives
	float dh_dx = -w.frequency * w.amplitude * d.x * cos(xz * w.frequency + t);
	float dh_dz = -w.frequency * w.amplitude * d.y * cos(xz * w.frequency + t);

	// Construct the normal using the gradient
	vec3 normal =  normalize(vec3(dh_dx, 1.0, dh_dz));
	return normal;
}

vec3 offset(vec3 v, Wave w)
{
	return vec3(0., Sine(v, w), 0.f);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.001;
    h = 0.0;
    vec3 n = vec3(0.0);
    float total_weight = 0.0;

    // Use different directions for each wave
    for (int wi = 0; wi < wavecount; wi++) {
        Wave wave;

        // Create varied wave directions by offsetting the noise sampling
        float angle_offset = float(wi) * 0.618033988749895 * 6.28318; // Golden ratio * 2π
        vec2 noise_offset = vec2(cos(angle_offset), sin(angle_offset)) * 0.1;
        float dir_noise = texture(dirnoise, world_position.xz + noise_offset).x;

        // Create varied direction
        wave.direction = normalize(vec2(cos(dir_noise * 6.28318 + angle_offset),
                                        sin(dir_noise * 6.28318 + angle_offset)));

        // Vary frequency slightly for each wave
        float freq_variation = 0.8 + 0.4 * float(wi)* 10.0 / float(wavecount);
        wave.frequency = freq * freq_variation;

        // Vary speed for each wave
        float speed_variation = 0.7 + 0.6 * float(wi) / float(wavecount);
        float x = dot(wave.direction, world_position.xz) * wave.frequency + TIME * initspeed * speed_variation;

        // Amplitude varies by position and time
        wave.amplitude = amplitude * (0.5 + 0.5 * texture(colornoise, world_position.xz * 0.05 + vec2(TIME * 0.02 * float(wi) / float(wavecount))).x);

        wave.origin = world_position.xz;
        wave.phase = initspeed * speed_variation;

        float weight = wave.amplitude;
        float wave_height = Sine(world_position, wave);
        vec3 wave_normal = SineNormal(world_position, wave);

        // Pure addition of wave heights allows for interference
        h += wave_height;
        n += wave_normal * weight;
        total_weight += weight;
    }

    if (total_weight > 0.0) {
        n = normalize(n / total_weight);
    } else {
        n = vec3(0.0, 1.0, 0.0);
    }

    // Apply wave height directly without normalization to preserve interference
    VERTEX.y = h;
    NORMAL = n;
}

void fragment() {
    float normalized_height = clamp((h + amplitude) / (2.0 * amplitude), 0.0, 1.0);

    vec3 water_color = texture(gradient, vec2(normalized_height, 0.0)).rgb;

    float shore_proximity = 1.0 - clamp(abs(h) / (amplitude * 0.3), 0.0, 1.0);
    float foam_intensity = pow(shore_proximity, 3.0);

    vec2 foam_uv = world_position.xz * 100.0;
    vec2 foam_movement = TIME * vec2(0.01, 0.02);
    float foam_noise = texture(colornoise, foam_uv + foam_movement).r;

    foam_intensity *= step(0.7, foam_noise) * shore_proximity;

    vec2 ripple_uv = world_position.xz * 50.0 + TIME * vec2(0.05, 0.03);
	vec3 normal_map = normalize(texture(normal_texture, ripple_uv).rgb * 2.0 - 1.0);
	NORMAL = normalize(mix(NORMAL, normal_map, 0.2));

    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - VERTEX);
    vec3 light_dir = normalize(vec3(0.5, 0.8, 0.2));

    vec3 half_vec = normalize(view_dir + light_dir);
    float spec_intensity = pow(max(dot(NORMAL, half_vec), 0.0), 32.0);

    float fresnel = pow(1.0 - max(dot(NORMAL, view_dir), 0.0), 5.0);

    vec3 final_color = water_color;
    final_color += vec3(1.0) * foam_intensity * 0.8;
    final_color += vec3(1.0, 0.98, 0.9) * spec_intensity * 0.5;
    final_color = mix(final_color, vec3(0.1, 0.2, 0.3), fresnel * 0.6);

    ALBEDO = final_color;

	vec2 caustic_uv = world_position.xz * 10.0 + TIME * vec2(0.03, 0.02);
	float caustic = texture(normal_texture, caustic_uv).r;
	ALBEDO += caustic * 0.2 * max(dot(NORMAL, vec3(0.0, 1.0, 0.0)), 0.0);
    METALLIC = 0.1;
    ROUGHNESS = 0.1 + shore_proximity * 0.3;
    SPECULAR = 0.5 + fresnel * 0.3;
}

void light() {
    float attenuation = ATTENUATION;
    float diffuse_amount = max(dot(NORMAL, LIGHT), 0.0);
    vec3 half = normalize(VIEW + LIGHT);
    float spec_amount = pow(max(dot(NORMAL, half), 0.0), 32.0);
    vec3 specular_color = LIGHT_COLOR * spec_amount * 0.5;

	float sss_amount = pow(max(dot(-LIGHT, VIEW), 0.0), 8.0) * 0.5;
	DIFFUSE_LIGHT += LIGHT_COLOR * sss_amount * vec3(0.0, 0.2, 0.3); // Bluish subsurface
    SPECULAR_LIGHT += specular_color * attenuation;
}