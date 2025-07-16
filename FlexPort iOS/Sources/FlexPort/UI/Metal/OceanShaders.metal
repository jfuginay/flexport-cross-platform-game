#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// MARK: - Structures

struct OceanVertex {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct OceanUniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
    float time;
    float waveAmplitude;
    float waveFrequency;
    float waveSpeed;
    float2 windDirection;
    float windSpeed;
    float weatherIntensity;
    int weatherType;
    float3 stormCenter;
    float3 cameraPosition;
    float3 lightDirection;
    float3 lightColor;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoord;
    float2 waveTexCoord;
    float3 viewDirection;
    float distance;
    float foam;
    float depth;
};

struct Particle {
    float3 position;
    float3 velocity;
    float life;
    float size;
    float4 color;
    int type;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
    float life;
};

// MARK: - Utility Functions

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

float3 calculateWaveNormal(float2 position, float time, float amplitude, float frequency, float speed, float2 windDir) {
    float eps = 0.1;
    
    float2 p1 = position + float2(eps, 0.0);
    float2 p2 = position + float2(0.0, eps);
    
    float h0 = calculateWaveHeight(position, time, amplitude, frequency, speed, windDir);
    float h1 = calculateWaveHeight(p1, time, amplitude, frequency, speed, windDir);
    float h2 = calculateWaveHeight(p2, time, amplitude, frequency, speed, windDir);
    
    float3 tangent1 = normalize(float3(eps, h1 - h0, 0.0));
    float3 tangent2 = normalize(float3(0.0, h2 - h0, eps));
    
    return normalize(cross(tangent1, tangent2));
}

float calculateWaveHeight(float2 position, float time, float amplitude, float frequency, float speed, float2 windDir) {
    float2 adjustedPos = position * frequency;
    
    // Multiple wave layers for realistic ocean
    float wave1 = sin(dot(adjustedPos, windDir) + time * speed) * amplitude;
    float wave2 = sin(dot(adjustedPos * 1.5, windDir * 0.8) + time * speed * 1.2) * amplitude * 0.6;
    float wave3 = sin(dot(adjustedPos * 0.3, windDir * 1.2) + time * speed * 0.8) * amplitude * 1.4;
    
    // Add high-frequency detail waves
    float detail = fbm(adjustedPos * 4.0 + time * speed * 0.5, 3) * amplitude * 0.1;
    
    return wave1 + wave2 + wave3 + detail;
}

float3 calculateFoam(float2 position, float time, float waveHeight, float amplitude) {
    // Generate foam based on wave height and steepness
    float foamThreshold = amplitude * 0.7;
    float foam = smoothstep(foamThreshold, amplitude, abs(waveHeight));
    
    // Add animated foam texture
    float foamNoise = fbm(position * 8.0 + time * 2.0, 4);
    foam *= foamNoise;
    
    return float3(foam, foam, foam);
}

float calculateFresnel(float3 viewDir, float3 normal, float F0) {
    float cosTheta = max(dot(viewDir, normal), 0.0);
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float3 calculateReflection(float3 viewDir, float3 normal) {
    return reflect(-viewDir, normal);
}

float3 calculateRefraction(float3 viewDir, float3 normal, float eta) {
    return refract(-viewDir, normal, eta);
}

// MARK: - Ocean Vertex Shader

vertex VertexOut oceanVertexShader(
    OceanVertex in [[stage_in]],
    constant OceanUniforms& uniforms [[buffer(1)]],
    constant float4* waveData [[buffer(2)]],
    uint vid [[vertex_id]]
) {
    VertexOut out;
    
    float3 worldPosition = in.position;
    
    // Calculate wave displacement
    float waveHeight = calculateWaveHeight(
        worldPosition.xz,
        uniforms.time,
        uniforms.waveAmplitude,
        uniforms.waveFrequency,
        uniforms.waveSpeed,
        uniforms.windDirection
    );
    
    // Apply weather intensity to wave height
    waveHeight *= (1.0 + uniforms.weatherIntensity * 0.5);
    
    worldPosition.y += waveHeight;
    
    // Calculate normal
    float3 normal = calculateWaveNormal(
        worldPosition.xz,
        uniforms.time,
        uniforms.waveAmplitude,
        uniforms.waveFrequency,
        uniforms.waveSpeed,
        uniforms.windDirection
    );
    
    // Transform to clip space
    float4x4 mvpMatrix = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvpMatrix * float4(worldPosition, 1.0);
    
    out.worldPosition = worldPosition;
    out.normal = normal;
    out.texCoord = in.texCoord;
    out.waveTexCoord = in.texCoord + uniforms.time * 0.02 * uniforms.windDirection;
    
    // Calculate view direction
    out.viewDirection = normalize(uniforms.cameraPosition - worldPosition);
    out.distance = length(uniforms.cameraPosition - worldPosition);
    
    // Calculate foam factor
    out.foam = length(normal.xz) * uniforms.waveAmplitude;
    
    // Approximate depth (for shallow water effects)
    out.depth = max(0.0, worldPosition.y + 10.0) / 20.0;
    
    return out;
}

// MARK: - Ocean Fragment Shader

fragment float4 oceanFragmentShader(
    VertexOut in [[stage_in]],
    constant OceanUniforms& uniforms [[buffer(0)]],
    texture2d<float> heightmapTexture [[texture(0)]],
    texture2d<float> normalTexture [[texture(1)]],
    texture2d<float> foamTexture [[texture(2)]],
    texture2d<float> causticTexture [[texture(3)]],
    texturecube<float> skyboxTexture [[texture(4)]]
) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::repeat);
    
    constexpr sampler skyboxSampler(mag_filter::linear,
                                  min_filter::linear,
                                  address::clamp_to_edge);
    
    // Base ocean color based on depth and weather
    float3 deepWaterColor = float3(0.02, 0.1, 0.2);
    float3 shallowWaterColor = float3(0.1, 0.4, 0.6);
    float3 stormColor = float3(0.05, 0.05, 0.1);
    
    // Mix colors based on weather
    float3 baseColor = mix(
        mix(deepWaterColor, shallowWaterColor, in.depth),
        stormColor,
        uniforms.weatherIntensity
    );
    
    // Sample normal map for additional detail
    float3 detailNormal = normalTexture.sample(textureSampler, in.waveTexCoord * 4.0).xyz * 2.0 - 1.0;
    float3 normal = normalize(in.normal + detailNormal * 0.3);
    
    // Lighting calculation
    float3 lightDir = normalize(-uniforms.lightDirection);
    float diffuse = max(dot(normal, lightDir), 0.0);
    
    // Specular reflection
    float3 halfVector = normalize(lightDir + in.viewDirection);
    float specular = pow(max(dot(normal, halfVector), 0.0), 64.0);
    
    // Fresnel effect
    float fresnel = calculateFresnel(in.viewDirection, normal, 0.02);
    
    // Reflection
    float3 reflectionDir = calculateReflection(in.viewDirection, normal);
    float3 skyColor = skyboxTexture.sample(skyboxSampler, reflectionDir).rgb;
    
    // Caustics effect
    float2 causticCoord = in.worldPosition.xz * 0.1 + uniforms.time * 0.1;
    float caustic = causticTexture.sample(textureSampler, causticCoord).r;
    caustic *= smoothstep(0.5, 1.0, diffuse); // Only show caustics in lit areas
    
    // Foam calculation
    float foamMask = foamTexture.sample(textureSampler, in.texCoord * 2.0 + uniforms.time * 0.5).r;
    float foam = in.foam * foamMask;
    foam = smoothstep(0.3, 0.8, foam);
    
    // Storm effects
    float stormEffect = 0.0;
    if (uniforms.weatherType == 2 || uniforms.weatherType == 3) { // storm or hurricane
        float distanceToStorm = length(in.worldPosition - uniforms.stormCenter);
        float stormRadius = 200.0;
        stormEffect = 1.0 - smoothstep(0.0, stormRadius, distanceToStorm);
        stormEffect *= uniforms.weatherIntensity;
        
        // Add turbulence to the surface
        float turbulence = fbm(in.worldPosition.xz * 0.02 + uniforms.time * 2.0, 4);
        foam += stormEffect * turbulence * 0.5;
    }
    
    // Final color composition
    float3 finalColor = baseColor;
    
    // Apply lighting
    finalColor *= (0.3 + 0.7 * diffuse); // Ambient + diffuse
    finalColor += uniforms.lightColor * specular * 0.5; // Specular
    finalColor += caustic * float3(0.8, 1.0, 0.9) * 0.3; // Caustics
    
    // Mix with reflection
    finalColor = mix(finalColor, skyColor, fresnel * 0.6);
    
    // Add foam
    finalColor = mix(finalColor, float3(1.0, 1.0, 1.0), foam);
    
    // Distance fog
    float fogFactor = 1.0 - exp(-in.distance * 0.001);
    float3 fogColor = mix(float3(0.7, 0.8, 0.9), float3(0.3, 0.3, 0.4), uniforms.weatherIntensity);
    finalColor = mix(finalColor, fogColor, fogFactor);
    
    // Weather effects
    if (uniforms.weatherType == 4) { // fog
        float fogIntensity = uniforms.weatherIntensity;
        finalColor = mix(finalColor, float3(0.8, 0.8, 0.8), fogIntensity * 0.7);
    }
    
    return float4(finalColor, 1.0);
}

// MARK: - Wave Compute Shader

kernel void waveComputeShader(
    device float4* waveData [[buffer(0)]],
    constant OceanUniforms& uniforms [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= 256 || gid.y >= 256) return;
    
    uint index = gid.y * 256 + gid.x;
    
    float2 position = float2(gid) / 256.0 - 0.5;
    position *= 2000.0; // Ocean size
    
    // Calculate wave height and gradient
    float waveHeight = calculateWaveHeight(
        position,
        uniforms.time,
        uniforms.waveAmplitude,
        uniforms.waveFrequency,
        uniforms.waveSpeed,
        uniforms.windDirection
    );
    
    float3 normal = calculateWaveNormal(
        position,
        uniforms.time,
        uniforms.waveAmplitude,
        uniforms.waveFrequency,
        uniforms.waveSpeed,
        uniforms.windDirection
    );
    
    waveData[index] = float4(waveHeight, normal.x, normal.y, normal.z);
}

// MARK: - Particle Vertex Shader

vertex ParticleVertexOut particleVertexShader(
    device Particle* particles [[buffer(0)]],
    constant OceanUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    ParticleVertexOut out;
    
    Particle particle = particles[vid];
    
    float4x4 mvpMatrix = uniforms.projectionMatrix * uniforms.viewMatrix;
    out.position = mvpMatrix * float4(particle.position, 1.0);
    out.color = particle.color;
    out.size = particle.size * 10.0; // Scale for visibility
    out.life = particle.life;
    
    return out;
}

// MARK: - Particle Fragment Shader

fragment float4 particleFragmentShader(
    ParticleVertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Create circular particle shape
    float distance = length(pointCoord - 0.5);
    float alpha = 1.0 - smoothstep(0.4, 0.5, distance);
    
    // Fade based on particle life
    alpha *= smoothstep(0.0, 1.0, in.life / 5.0);
    
    float4 color = in.color;
    color.a *= alpha;
    
    return color;
}

// MARK: - Disaster Effect Vertex Shader

struct DisasterEffect {
    float3 position;
    float radius;
    float intensity;
    float remainingTime;
    float4 color;
    int type;
};

vertex VertexOut disasterVertexShader(
    device DisasterEffect* disasters [[buffer(0)]],
    constant OceanUniforms& uniforms [[buffer(1)]],
    uint vid [[vertex_id]]
) {
    VertexOut out;
    
    // Generate quad vertices for each disaster
    uint disasterIndex = vid / 4;
    uint vertexIndex = vid % 4;
    
    DisasterEffect disaster = disasters[disasterIndex];
    
    // Quad positions (in local space)
    float2 quadPositions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    
    float2 localPos = quadPositions[vertexIndex] * disaster.radius;
    float3 worldPos = disaster.position + float3(localPos.x, 0.0, localPos.y);
    
    float4x4 mvpMatrix = uniforms.projectionMatrix * uniforms.viewMatrix;
    out.position = mvpMatrix * float4(worldPos, 1.0);
    
    out.worldPosition = worldPos;
    out.texCoord = (quadPositions[vertexIndex] + 1.0) * 0.5;
    out.distance = length(uniforms.cameraPosition - worldPos);
    
    return out;
}

// MARK: - Disaster Effect Fragment Shader

fragment float4 disasterFragmentShader(
    VertexOut in [[stage_in]],
    constant OceanUniforms& uniforms [[buffer(0)]]
) {
    float2 center = float2(0.5, 0.5);
    float distance = length(in.texCoord - center);
    
    // Create circular effect
    float mask = 1.0 - smoothstep(0.3, 0.5, distance);
    
    // Animated effect based on time
    float animation = sin(uniforms.time * 3.0 + distance * 10.0) * 0.5 + 0.5;
    mask *= animation;
    
    // Base color (this would be passed from the disaster data)
    float4 effectColor = float4(1.0, 0.3, 0.0, 0.6); // Default to orange (fire/explosion)
    
    effectColor.a *= mask;
    
    return effectColor;
}

// MARK: - Skybox Vertex Shader

struct SkyboxVertex {
    float3 position [[attribute(0)]];
};

struct SkyboxVertexOut {
    float4 position [[position]];
    float3 texCoord;
};

vertex SkyboxVertexOut skyboxVertexShader(
    SkyboxVertex in [[stage_in]],
    constant OceanUniforms& uniforms [[buffer(1)]]
) {
    SkyboxVertexOut out;
    
    float4x4 viewMatrix = uniforms.viewMatrix;
    viewMatrix[3][0] = 0.0; // Remove translation
    viewMatrix[3][1] = 0.0;
    viewMatrix[3][2] = 0.0;
    
    float4x4 mvpMatrix = uniforms.projectionMatrix * viewMatrix;
    out.position = mvpMatrix * float4(in.position, 1.0);
    
    // Ensure skybox is always at max depth
    out.position.z = out.position.w;
    
    out.texCoord = in.position;
    
    return out;
}

// MARK: - Skybox Fragment Shader

fragment float4 skyboxFragmentShader(
    SkyboxVertexOut in [[stage_in]],
    texturecube<float> skyboxTexture [[texture(0)]]
) {
    constexpr sampler skyboxSampler(mag_filter::linear,
                                  min_filter::linear,
                                  address::clamp_to_edge);
    
    return skyboxTexture.sample(skyboxSampler, in.texCoord);
}