shader_type spatial;
render_mode world_vertex_coords;


// help from https://catlikecoding.com/unity/tutorials/flow/waves/
// https://www.youtube.com/watch?v=Jq3he9Lbj7M

// vertex props
uniform float amplitude = 1.0;
uniform float modulator_wavelength;
uniform vec4 wave_one = vec4(1.0, 1.0, 0.2, 60.0);
uniform vec4 wave_two = vec4(0.7, -0.5, 0.1, 31.0);
uniform vec4 wave_three = vec4(0.3, 0.6, 0.4, 18.0);

// frag props
uniform float metallic : hint_range(0.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0);

uniform sampler2D texture_map;
uniform vec2 texture_scale = vec2(8.0, 8.0);

uniform sampler2D uv_offset_texture;
uniform vec2 uv_offset_scale = vec2(0.2, 0.2);
uniform float uv_offset_speed = 0.05;
uniform float uv_offset_amplitude = 0.2;

uniform sampler2D normal_map : hint_normal;
uniform float refraction = 0.05;

uniform sampler2D noise_tex;
uniform float beer_factor = 1;
uniform float noise_cutoff = 0.8;
uniform float shore_noise_cutoff = 0.4;
uniform float foam_level = 0.2;
uniform float shore_foam_distance = 20.0;
uniform sampler2D shore_foam_tex;

float get_k(float wavelength) {
    return 2.0 * PI / wavelength;
}
float get_c(float k) {
    return sqrt(9.8 / k);
}
float get_f(float k, vec2 d, vec3 vert, float time) {
    return k * (dot(d, vert.xz) - time * get_c(k));
}
float get_a(float steepness, float k) {
    return steepness / k * amplitude;
}

vec3 gerstner_wave(float time, vec4 wave, vec3 vert, bool use_mod, inout vec3 tangent, inout vec3 binormal) {
    float steepness = wave.z;
    float wavelength = wave.w;
    vec2 d = normalize(wave.xy);
    float k = get_k(wavelength);
    float f = get_f(k, d, vert, time);
    float a = get_a(steepness, k);
    vert.x += d.x * (a * cos(f));
    vert.y += a * sin(f);
//  vert.y += amplitude * sin(k * (vert.x - time)); // amp mod
    vert.z += d.y * (a * cos(f));

    // freq/amp mod
    if (use_mod) {
        float k_mod = get_k(modulator_wavelength);
        float f_mod = get_f(k_mod, d, vert, time);
        float a_mod = get_a(steepness, k_mod);
        vert.y += a_mod * sin(f_mod);
    }

    tangent += vec3(
        1.0 - d.x * d.x * (steepness * sin(f)),
        d.x * (steepness * cos(f)),
        -d.x * d.y * (steepness * sin(f))
    );
    binormal += vec3(
        -d.x * d.y * (steepness * sin(f)),
        d.y * (steepness * cos(f)),
        1.0 - d.y * d.y * (steepness * sin(f))
    );
    return vert;
}

void vertex() {
    VERTEX = gerstner_wave(TIME, wave_one, VERTEX, true, TANGENT, BINORMAL);
    VERTEX = gerstner_wave(TIME, wave_two, VERTEX, false, TANGENT, BINORMAL);
    VERTEX = gerstner_wave(TIME, wave_three, VERTEX, false, TANGENT, BINORMAL);
    NORMAL = normalize(cross(BINORMAL, TANGENT));
}

void fragment() {
    vec2 base_uv_offset = UV * uv_offset_scale;
    base_uv_offset += TIME * uv_offset_speed;

    vec2 texture_based_offset = texture(uv_offset_texture, base_uv_offset).rg;
    texture_based_offset = texture_based_offset * 2.0 - 1.0;

    vec2 texture_uv = UV * texture_scale;
    texture_uv += uv_offset_amplitude * texture_based_offset;

    ALBEDO = texture(texture_map, texture_uv).rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = 1.0;
//  NORMALMAP = texture(normal_map, base_uv_offset * 2.0).rgb;



    float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    depth = depth * 2.0 - 1.0;
    depth = PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);


    // refraction
    vec3 ref_normal = normalize(mix(NORMAL, TANGENT * NORMAL_MAP.x + BINORMAL * NORMAL_MAP.y + NORMAL * NORMAL_MAP.z, NORMAL_MAP_DEPTH));
    vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction;

    // beers law
    float beer_depth = depth + VERTEX.z;
    beer_depth *= 0.1;
    beer_depth = exp(-beer_depth * beer_factor);
    ALPHA = clamp(1.0 - beer_depth, 0.0, 1.0);

    EMISSION = textureLod(SCREEN_TEXTURE, ref_ofs, ROUGHNESS).rgb * (1.0 - ALPHA);
    ALBEDO *= ALPHA;
    ALPHA = 1.0;


    // bits
    // help from https://roystan.net/articles/toon-water.html
    float noise_full = texture(noise_tex, texture_uv).r;
    float noise = noise_full > noise_cutoff ? 1.0 : 0.0;
    ALBEDO += vec3(noise, noise, noise);

    // shore foam
    float shore_amount = max(min(1.0, (shore_foam_distance - depth - VERTEX.z) / shore_foam_distance), 0.0);
    ALBEDO += texture(shore_foam_tex, texture_uv).rgb * shore_amount;

    // foam
    // help from https://github.com/gstark31897/GodotTerrain
    float shore_noise = noise_full > shore_noise_cutoff ? 1.0 : 0.0;
    float foam_amount = max(min(1.0, (foam_level - depth - VERTEX.z) / foam_level), 0.0);
    ALBEDO += vec3(shore_noise, shore_noise, shore_noise) * foam_amount * 10.0;
}