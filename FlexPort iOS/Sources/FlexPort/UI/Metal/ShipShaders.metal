#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// MARK: - Ship Shader Structures

struct ShipInstanceData {
    float4x4 modelMatrix;
    int textureIndex;
    float4 tintColor;
    float4 animationData; // x: bobAmount, y: bobPhase, z: wakeIntensity, w: damage
};

struct ShipUniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float time;
    float3 lightDirection;
    float3 lightColor;
    float3 ambientLight;
    float3 fogColor;
    float fogDensity;
};

struct ShipVertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float3 normal [[attribute(2)]];
};

struct ShipVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoord;
    float4 tintColor;
    float fogFactor;
    float damage;
    int textureIndex;
};

// MARK: - Ship Instance Vertex Shader

vertex ShipVertexOut shipInstanceVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant ShipInstanceData *instances [[buffer(0)]],
    constant ShipUniforms &uniforms [[buffer(1)]]
) {
    ShipVertexOut out;
    
    // Generate quad vertices
    float2 quadVertices[4] = {
        float2(-0.5, -0.5),
        float2( 0.5, -0.5),
        float2(-0.5,  0.5),
        float2( 0.5,  0.5)
    };
    
    float2 quadTexCoords[4] = {
        float2(0, 1),
        float2(1, 1),
        float2(0, 0),
        float2(1, 0)
    };
    
    ShipInstanceData instance = instances[instanceID];
    
    // Apply model transform
    float4 worldPosition = instance.modelMatrix * float4(quadVertices[vertexID].x * 30, 0, quadVertices[vertexID].y * 60, 1);
    
    // Apply wave animation
    float waveOffset = sin(uniforms.time + instance.animationData.y) * instance.animationData.x;
    worldPosition.y += waveOffset;
    
    // Apply view-projection transform
    float4x4 viewProjection = uniforms.projectionMatrix * uniforms.viewMatrix;
    out.position = viewProjection * worldPosition;
    
    out.worldPosition = worldPosition.xyz;
    out.worldNormal = normalize((instance.modelMatrix * float4(0, 1, 0, 0)).xyz);
    out.texCoord = quadTexCoords[vertexID];
    out.tintColor = instance.tintColor;
    out.damage = instance.animationData.w;
    out.textureIndex = instance.textureIndex;
    
    // Calculate fog
    float3 viewPos = (uniforms.viewMatrix * worldPosition).xyz;
    float distance = length(viewPos);
    out.fogFactor = 1.0 - exp(-distance * uniforms.fogDensity);
    
    return out;
}

// MARK: - Ship Instance Fragment Shader

fragment float4 shipInstanceFragmentShader(
    ShipVertexOut in [[stage_in]],
    constant ShipUniforms &uniforms [[buffer(0)]],
    texture2d_array<float> shipTextures [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   mip_filter::linear);
    
    // Sample ship texture
    float4 shipColor = shipTextures.sample(textureSampler, in.texCoord, in.textureIndex);
    
    // Apply tint color
    shipColor.rgb *= in.tintColor.rgb;
    
    // Basic lighting
    float3 normal = normalize(in.worldNormal);
    float diffuse = max(dot(normal, -uniforms.lightDirection), 0.0);
    float3 lighting = uniforms.ambientLight + uniforms.lightColor * diffuse;
    
    // Apply lighting
    shipColor.rgb *= lighting;
    
    // Damage effects
    if (in.damage > 0.0) {
        // Add damage tint and flashing
        float damageFlash = sin(uniforms.time * 10.0) * 0.5 + 0.5;
        shipColor.rgb = mix(shipColor.rgb, float3(1, 0.2, 0), in.damage * damageFlash * 0.5);
        
        // Add smoke/fire effect at damage locations
        float smokeNoise = fract(sin(dot(in.texCoord, float2(12.9898, 78.233))) * 43758.5453);
        if (smokeNoise < in.damage * 0.3) {
            shipColor.rgb = mix(shipColor.rgb, float3(0.2, 0.2, 0.2), 0.5);
        }
    }
    
    // Apply fog
    shipColor.rgb = mix(shipColor.rgb, uniforms.fogColor, in.fogFactor);
    
    return shipColor;
}

// MARK: - Wake Structures

struct WakeInstance {
    float3 position;
    float2 size;
    float opacity;
    float age;
};

struct WakeVertexOut {
    float4 position [[position]];
    float2 texCoord;
    float opacity;
    float distortion;
};

// MARK: - Wake Vertex Shader

vertex WakeVertexOut wakeVertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant WakeInstance *wakes [[buffer(0)]],
    constant ShipUniforms &uniforms [[buffer(1)]]
) {
    WakeVertexOut out;
    
    // Generate elongated quad for wake
    float2 quadVertices[4] = {
        float2(-0.5,  0.0),
        float2( 0.5,  0.0),
        float2(-0.5, -1.0),
        float2( 0.5, -1.0)
    };
    
    float2 quadTexCoords[4] = {
        float2(0, 0),
        float2(1, 0),
        float2(0, 1),
        float2(1, 1)
    };
    
    WakeInstance wake = wakes[instanceID];
    
    // Scale and position wake
    float3 vertexPos = float3(
        quadVertices[vertexID].x * wake.size.x,
        0.1, // Slightly above water
        quadVertices[vertexID].y * wake.size.y
    );
    
    float4 worldPosition = float4(wake.position + vertexPos, 1.0);
    
    // Apply view-projection
    float4x4 viewProjection = uniforms.projectionMatrix * uniforms.viewMatrix;
    out.position = viewProjection * worldPosition;
    
    out.texCoord = quadTexCoords[vertexID];
    out.opacity = wake.opacity * (1.0 - wake.age);
    
    // Add distortion based on age
    out.distortion = wake.age * 2.0;
    
    return out;
}

// MARK: - Wake Fragment Shader

fragment float4 wakeFragmentShader(
    WakeVertexOut in [[stage_in]],
    texture2d<float> wakeTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::clamp_to_edge);
    
    // Distort texture coordinates for movement effect
    float2 distortedCoord = in.texCoord;
    distortedCoord.y += sin(in.texCoord.x * 10.0 + in.distortion) * 0.05;
    
    // Sample wake texture
    float4 wakeColor = wakeTexture.sample(textureSampler, distortedCoord);
    
    // Fade out at edges
    float edgeFade = 1.0 - abs(in.texCoord.x * 2.0 - 1.0);
    edgeFade *= 1.0 - in.texCoord.y;
    
    wakeColor.a *= in.opacity * edgeFade;
    
    return wakeColor;
}

// MARK: - Particle Structures

struct Particle {
    float3 position;
    float3 velocity;
    float4 color;
    float size;
    float life;
    int type;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
    float2 texCoord;
    int type;
};

// MARK: - Particle Vertex Shader

vertex ParticleVertexOut particleVertexShader(
    uint vertexID [[vertex_id]],
    constant Particle *particles [[buffer(0)]],
    constant ShipUniforms &uniforms [[buffer(1)]]
) {
    ParticleVertexOut out;
    
    Particle particle = particles[vertexID];
    
    // Apply physics simulation
    float3 position = particle.position + particle.velocity * uniforms.time;
    
    // Apply gravity for certain particle types
    if (particle.type == 1) { // Water spray
        position.y -= 9.8 * uniforms.time * uniforms.time * 0.5;
    }
    
    // Transform to clip space
    float4x4 viewProjection = uniforms.projectionMatrix * uniforms.viewMatrix;
    out.position = viewProjection * float4(position, 1.0);
    
    // Fade based on life
    float lifeFactor = particle.life;
    out.color = particle.color;
    out.color.a *= lifeFactor;
    
    // Size based on type and distance
    float distance = length((uniforms.viewMatrix * float4(position, 1.0)).xyz);
    out.size = particle.size * (100.0 / distance) * lifeFactor;
    
    out.type = particle.type;
    
    return out;
}

// MARK: - Particle Fragment Shader

fragment float4 particleFragmentShader(
    ParticleVertexOut in [[stage_in]],
    texture2d<float> particleTexture [[texture(0)]],
    float2 pointCoord [[point_coord]]
) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear);
    
    // Sample particle texture
    float4 texColor = particleTexture.sample(textureSampler, pointCoord);
    
    // Apply particle color
    float4 finalColor = in.color * texColor;
    
    // Special effects based on particle type
    switch (in.type) {
        case 0: // Foam
            finalColor.rgb = float3(1.0, 1.0, 1.0);
            break;
            
        case 1: // Water spray
            finalColor.rgb = mix(float3(0.8, 0.9, 1.0), float3(1.0, 1.0, 1.0), texColor.a);
            break;
            
        case 2: // Smoke
            finalColor.rgb = mix(float3(0.2, 0.2, 0.2), float3(0.5, 0.5, 0.5), texColor.a);
            break;
            
        case 3: // Fire
            float heat = texColor.a;
            finalColor.rgb = mix(float3(1.0, 0.2, 0.0), float3(1.0, 1.0, 0.0), heat);
            break;
    }
    
    return finalColor;
}

// MARK: - Utility Functions

// Smooth noise function for procedural effects
float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// Rotation matrix
float3x3 rotationMatrix(float3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return float3x3(
        oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
        oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
        oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c
    );
}