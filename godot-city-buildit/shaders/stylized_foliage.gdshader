shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A single locally generated foliage atlas keeps the game fully offline.
// Alpha is soft in the texture; the shader uses scissor rather than blending.
uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 seasonal_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float leaf_density : hint_range(0.0, 1.0) = 1.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.10;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.85;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.25);
uniform vec3 sun_direction = vec3(-0.45, -0.82, -0.30);
uniform float fake_sss_strength : hint_range(0.0, 1.0) = 0.28;

varying vec3 bent_world_normal;
varying float wind_weight;
varying vec4 instance_data;
varying vec4 canopy_vertex_color;
varying float volumetric_canopy;

void vertex() {
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wind_weight = UV2.x;
    instance_data = INSTANCE_CUSTOM;
    canopy_vertex_color = COLOR;
    volumetric_canopy = UV2.y;

    // Each tree receives a stable phase from MultiMesh INSTANCE_CUSTOM.b.
    float phase = world_position.x * 0.115
        + world_position.z * 0.091
        + TIME * wind_speed
        + instance_data.b * 6.2831853;
    float wave = sin(phase) * 0.68
        + sin(phase * 0.53 + TIME * 0.31) * 0.32;

    vec3 wind = normalize(wind_direction);
    VERTEX += wind * wave * wind_strength * wind_weight;

    // The source mesh stores normals bent toward the centre of each canopy
    // cluster. They remain stable under MultiMesh transforms.
    bent_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec4 leaf = texture(leaf_atlas, UV);
    bool is_solid_crown = volumetric_canopy > 0.5;

    float instance_variation = mix(0.88, 1.12, instance_data.r);
    float instance_density = mix(0.84, 1.0, instance_data.g);
    float instance_brightness = mix(0.92, 1.08, instance_data.a);

    vec3 foliage = (is_solid_crown ? canopy_vertex_color.rgb : leaf.rgb) * seasonal_tint.rgb;
    foliage *= instance_variation * instance_brightness;

    // Snow is biased toward upward-facing bent normals.
    float upward = smoothstep(0.38, 0.90, bent_world_normal.y);
    foliage = mix(foliage, vec3(0.82, 0.88, 0.91), snow_amount * upward * 0.78);

    ALBEDO = foliage;
    ALPHA = is_solid_crown ? 1.0 : leaf.a * leaf_density * instance_density;
    ALPHA_SCISSOR_THRESHOLD = 0.32;

    ROUGHNESS = 0.94;
    METALLIC = 0.0;
    SPECULAR = 0.08;
    AO = 0.82;
    AO_LIGHT_AFFECT = 0.62;

    // Low-cost foliage translucency approximation, driven by the sun direction.
    float back_light = max(
        dot(normalize(bent_world_normal), -normalize(sun_direction)),
        0.0
    );
    float edge_light = pow(
        1.0 - max(dot(normalize(bent_world_normal), normalize(VIEW)), 0.0),
        2.4
    );
    ALBEDO += seasonal_tint.rgb * back_light * fake_sss_strength * 0.12;
    ALBEDO += vec3(0.055, 0.075, 0.028) * edge_light * 0.10;
}
