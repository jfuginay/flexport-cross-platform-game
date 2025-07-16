#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures

struct Vertex {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 normal [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoords;
    float3 worldPosition;
    float3 normal;
    float3 viewDirection;
};

// MARK: - Uniform Structures

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 cameraPosition;
    float time;
    float zoom;
    float2 pan;
};

struct LightingUniforms {
    float3 sunDirection;
    float3 sunColor;
    float sunIntensity;
    float3 ambientColor;
    float ambientIntensity;
    float timeOfDay; // 0.0 = midnight, 0.5 = noon, 1.0 = midnight
};

struct OceanUniforms {
    float waveHeight;
    float waveSpeed;
    float waveFrequency;
    float foam;
    float3 shallowColor;
    float3 deepColor;
    float transparency;
};

// MARK: - World Map Vertex Shader

vertex VertexOut mapVertexShader(uint vertexID [[vertex_id]],
                                 constant Vertex *vertices [[buffer(0)]],
                                 constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    Vertex vertex = vertices[vertexID];
    float4 worldPosition = uniforms.modelMatrix * float4(vertex.position, 1.0);
    
    out.position = uniforms.modelViewProjectionMatrix * float4(vertex.position, 1.0);
    out.color = vertex.color;
    out.texCoords = vertex.texCoords;
    out.worldPosition = worldPosition.xyz;
    out.normal = normalize((uniforms.modelMatrix * float4(vertex.normal, 0.0)).xyz);
    out.viewDirection = normalize(uniforms.cameraPosition - worldPosition.xyz);
    
    return out;
}

// MARK: - World Map Fragment Shader

fragment float4 mapFragmentShader(VertexOut in [[stage_in]],
                                  constant LightingUniforms &lighting [[buffer(2)]],
                                  texture2d<float> earthTexture [[texture(0)]],
                                  texture2d<float> normalMap [[texture(1)]],
                                  texture2d<float> specularMap [[texture(2)]],
                                  texture2d<float> nightLights [[texture(3)]],
                                  texture2d<float> cloudTexture [[texture(4)]],
                                  sampler textureSampler [[sampler(0)]]) {
    
    // Sample textures
    float4 earthColor = earthTexture.sample(textureSampler, in.texCoords);
    float3 normal = normalMap.sample(textureSampler, in.texCoords).xyz * 2.0 - 1.0;
    float specular = specularMap.sample(textureSampler, in.texCoords).r;
    float4 nightLightColor = nightLights.sample(textureSampler, in.texCoords);
    float4 clouds = cloudTexture.sample(textureSampler, in.texCoords);
    
    // Calculate lighting
    float3 lightDirection = normalize(-lighting.sunDirection);
    float3 viewDirection = normalize(in.viewDirection);
    float3 reflectDirection = reflect(-lightDirection, normal);
    
    // Diffuse lighting
    float ndotl = max(dot(normal, lightDirection), 0.0);
    float3 diffuse = lighting.sunColor * lighting.sunIntensity * ndotl;
    
    // Specular lighting
    float spec = pow(max(dot(viewDirection, reflectDirection), 0.0), 32.0);
    float3 specularLight = lighting.sunColor * spec * specular;
    
    // Day/night transition
    float dayFactor = smoothstep(-0.2, 0.2, ndotl);
    float nightFactor = 1.0 - dayFactor;
    
    // Combine day and night colors
    float3 dayColor = earthColor.rgb * (diffuse + lighting.ambientColor * lighting.ambientIntensity);
    float3 nightColor = earthColor.rgb * 0.1 + nightLightColor.rgb * nightFactor;
    
    float3 finalColor = mix(nightColor, dayColor, dayFactor) + specularLight;
    
    // Apply cloud shadows and lighting
    float cloudShadow = 1.0 - clouds.a * 0.3;
    finalColor *= cloudShadow;
    finalColor = mix(finalColor, clouds.rgb, clouds.a * 0.8);
    
    return float4(finalColor, 1.0);
}

// MARK: - Ocean Wave Vertex Shader

struct OceanVertex {
    float3 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct OceanVertexOut {
    float4 position [[position]];
    float2 texCoords;
    float3 worldPosition;
    float3 normal;
    float3 viewDirection;
    float waveHeight;
};

vertex OceanVertexOut oceanVertexShader(uint vertexID [[vertex_id]],
                                        constant OceanVertex *vertices [[buffer(0)]],
                                        constant Uniforms &uniforms [[buffer(1)]],
                                        constant OceanUniforms &oceanUniforms [[buffer(2)]]) {
    OceanVertexOut out;
    
    OceanVertex vertex = vertices[vertexID];
    float3 position = vertex.position;
    
    // Generate wave displacement
    float2 worldPos = position.xz;
    float wave1 = sin(worldPos.x * oceanUniforms.waveFrequency + uniforms.time * oceanUniforms.waveSpeed) * oceanUniforms.waveHeight;
    float wave2 = sin(worldPos.y * oceanUniforms.waveFrequency * 0.7 + uniforms.time * oceanUniforms.waveSpeed * 1.3) * oceanUniforms.waveHeight * 0.5;
    float wave3 = sin((worldPos.x + worldPos.y) * oceanUniforms.waveFrequency * 1.2 + uniforms.time * oceanUniforms.waveSpeed * 0.8) * oceanUniforms.waveHeight * 0.3;
    
    position.y += wave1 + wave2 + wave3;
    out.waveHeight = wave1 + wave2 + wave3;
    
    // Calculate normal from wave derivatives
    float eps = 0.1;
    float wave1_dx = cos(worldPos.x * oceanUniforms.waveFrequency + uniforms.time * oceanUniforms.waveSpeed) * oceanUniforms.waveFrequency * oceanUniforms.waveHeight;
    float wave2_dy = cos(worldPos.y * oceanUniforms.waveFrequency * 0.7 + uniforms.time * oceanUniforms.waveSpeed * 1.3) * oceanUniforms.waveFrequency * 0.7 * oceanUniforms.waveHeight * 0.5;
    
    out.normal = normalize(float3(-wave1_dx, 1.0, -wave2_dy));
    
    float4 worldPosition = uniforms.modelMatrix * float4(position, 1.0);
    out.position = uniforms.modelViewProjectionMatrix * float4(position, 1.0);
    out.texCoords = vertex.texCoords;
    out.worldPosition = worldPosition.xyz;
    out.viewDirection = normalize(uniforms.cameraPosition - worldPosition.xyz);
    
    return out;
}

// MARK: - Ocean Fragment Shader

fragment float4 oceanFragmentShader(OceanVertexOut in [[stage_in]],
                                    constant LightingUniforms &lighting [[buffer(2)]],
                                    constant OceanUniforms &oceanUniforms [[buffer(3)]],
                                    texture2d<float> foamTexture [[texture(0)]],
                                    texture2d<float> normalTexture [[texture(1)]],
                                    sampler textureSampler [[sampler(0)]]) {
    
    // Sample textures
    float4 foam = foamTexture.sample(textureSampler, in.texCoords * 10.0);
    float3 waterNormal = normalTexture.sample(textureSampler, in.texCoords * 5.0).xyz * 2.0 - 1.0;
    
    // Combine wave normal with texture normal
    float3 normal = normalize(in.normal + waterNormal * 0.3);
    
    // Calculate lighting
    float3 lightDirection = normalize(-lighting.sunDirection);
    float3 viewDirection = normalize(in.viewDirection);
    float3 reflectDirection = reflect(-lightDirection, normal);
    
    // Fresnel effect
    float fresnel = pow(1.0 - max(dot(normal, viewDirection), 0.0), 3.0);
    
    // Water color based on depth
    float depth = smoothstep(-2.0, 2.0, in.waveHeight);
    float3 waterColor = mix(oceanUniforms.deepColor, oceanUniforms.shallowColor, depth);
    
    // Specular reflection
    float spec = pow(max(dot(viewDirection, reflectDirection), 0.0), 64.0);
    float3 specularLight = lighting.sunColor * spec * fresnel;
    
    // Foam
    float foamFactor = smoothstep(0.8, 1.0, abs(in.waveHeight)) * oceanUniforms.foam;
    waterColor = mix(waterColor, foam.rgb, foamFactor);
    
    // Final color
    float3 finalColor = waterColor + specularLight;
    float alpha = mix(oceanUniforms.transparency, 1.0, fresnel);
    
    return float4(finalColor, alpha);
}

// MARK: - Ship Trail Particle System

struct ParticleVertex {
    float3 position [[attribute(0)]];
    float2 size [[attribute(1)]];
    float4 color [[attribute(2)]];
    float rotation [[attribute(3)]];
    float life [[attribute(4)]];
};

struct ParticleVertexOut {
    float4 position [[position]];
    float2 texCoords [[point_coord]];
    float4 color;
    float life;
};

vertex ParticleVertexOut particleVertexShader(uint vertexID [[vertex_id]],
                                              constant ParticleVertex *vertices [[buffer(0)]],
                                              constant Uniforms &uniforms [[buffer(1)]]) {
    ParticleVertexOut out;
    
    ParticleVertex particle = vertices[vertexID];
    out.position = uniforms.modelViewProjectionMatrix * float4(particle.position, 1.0);
    out.color = particle.color;
    out.life = particle.life;
    
    return out;
}

fragment float4 particleFragmentShader(ParticleVertexOut in [[stage_in]],
                                       texture2d<float> particleTexture [[texture(0)]],
                                       sampler textureSampler [[sampler(0)]]) {
    
    float4 textureColor = particleTexture.sample(textureSampler, in.texCoords);
    float4 finalColor = in.color * textureColor;
    
    // Fade based on particle life
    finalColor.a *= smoothstep(0.0, 0.1, in.life) * smoothstep(1.0, 0.8, in.life);
    
    return finalColor;
}

// MARK: - Port Visualization Shaders

struct PortVertex {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float4 color [[attribute(3)]];
};

struct PortVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoords;
    float4 color;
    float3 viewDirection;
};

vertex PortVertexOut portVertexShader(uint vertexID [[vertex_id]],
                                      constant PortVertex *vertices [[buffer(0)]],
                                      constant Uniforms &uniforms [[buffer(1)]]) {
    PortVertexOut out;
    
    PortVertex vertex = vertices[vertexID];
    float4 worldPosition = uniforms.modelMatrix * float4(vertex.position, 1.0);
    
    out.position = uniforms.modelViewProjectionMatrix * float4(vertex.position, 1.0);
    out.worldPosition = worldPosition.xyz;
    out.normal = normalize((uniforms.modelMatrix * float4(vertex.normal, 0.0)).xyz);
    out.texCoords = vertex.texCoords;
    out.color = vertex.color;
    out.viewDirection = normalize(uniforms.cameraPosition - worldPosition.xyz);
    
    return out;
}

fragment float4 portFragmentShader(PortVertexOut in [[stage_in]],
                                   constant LightingUniforms &lighting [[buffer(2)]],
                                   texture2d<float> diffuseTexture [[texture(0)]],
                                   texture2d<float> normalMap [[texture(1)]],
                                   texture2d<float> roughnessMap [[texture(2)]],
                                   sampler textureSampler [[sampler(0)]]) {
    
    // Sample textures
    float4 diffuse = diffuseTexture.sample(textureSampler, in.texCoords);
    float3 normal = normalMap.sample(textureSampler, in.texCoords).xyz * 2.0 - 1.0;
    float roughness = roughnessMap.sample(textureSampler, in.texCoords).r;
    
    // PBR lighting calculation
    float3 lightDirection = normalize(-lighting.sunDirection);
    float3 viewDirection = normalize(in.viewDirection);
    float3 halfVector = normalize(lightDirection + viewDirection);
    
    // Diffuse
    float ndotl = max(dot(normal, lightDirection), 0.0);
    float3 diffuseLight = lighting.sunColor * lighting.sunIntensity * ndotl;
    
    // Specular (simplified PBR)
    float ndoth = max(dot(normal, halfVector), 0.0);
    float spec = pow(ndoth, (1.0 - roughness) * 128.0);
    float3 specularLight = lighting.sunColor * spec * (1.0 - roughness);
    
    // Ambient
    float3 ambient = lighting.ambientColor * lighting.ambientIntensity;
    
    // Final color
    float3 finalColor = (diffuse.rgb * in.color.rgb) * (diffuseLight + ambient) + specularLight;
    
    return float4(finalColor, diffuse.a * in.color.a);
}

// MARK: - Trade Route Animation Shader

struct RouteVertex {
    float3 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
    float progress [[attribute(2)]];
};

struct RouteVertexOut {
    float4 position [[position]];
    float2 texCoords;
    float progress;
    float intensity;
};

vertex RouteVertexOut routeVertexShader(uint vertexID [[vertex_id]],
                                        constant RouteVertex *vertices [[buffer(0)]],
                                        constant Uniforms &uniforms [[buffer(1)]]) {
    RouteVertexOut out;
    
    RouteVertex vertex = vertices[vertexID];
    out.position = uniforms.modelViewProjectionMatrix * float4(vertex.position, 1.0);
    out.texCoords = vertex.texCoords;
    out.progress = vertex.progress;
    
    // Animate intensity based on time and progress
    float wave = sin(vertex.progress * 10.0 - uniforms.time * 5.0);
    out.intensity = smoothstep(-1.0, 1.0, wave);
    
    return out;
}

fragment float4 routeFragmentShader(RouteVertexOut in [[stage_in]]) {
    
    // Animated trade route line
    float3 routeColor = float3(0.2, 0.8, 1.0); // Cyan
    float alpha = in.intensity * smoothstep(0.0, 0.1, in.progress) * smoothstep(1.0, 0.9, in.progress);
    
    return float4(routeColor * in.intensity, alpha);
}

// MARK: - Advanced Particle System Shaders

struct Particle {
    float3 position;
    float3 velocity;
    float life;
    float maxLife;
    float size;
    float4 color;
    uint type;
    uint active;
};

struct EmitterData {
    float3 position;
    float3 velocity;
    float emissionRate;
    float particleLifetime;
    float size;
    float4 color;
    uint type;
    uint active;
};

struct ParticleUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 cameraPosition;
    float deltaTime;
    float time;
};

// Random number generation
float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

float3 random3(float3 st) {
    return float3(
        random(st.xy),
        random(st.yz),
        random(st.zx)
    );
}

// Particle update compute shader
kernel void updateParticles(device Particle *particles [[buffer(0)]],
                           device atomic_uint *particleCount [[buffer(1)]],
                           constant EmitterData *emitters [[buffer(2)]],
                           constant ParticleUniforms &uniforms [[buffer(3)]],
                           uint id [[thread_position_in_grid]]) {
    
    if (id >= 10000) return; // Max particles
    
    Particle particle = particles[id];
    
    if (particle.active) {
        // Update existing particle
        particle.life -= uniforms.deltaTime;
        
        if (particle.life <= 0) {
            particle.active = 0;
            atomic_fetch_sub_explicit(particleCount, 1, memory_order_relaxed);
        } else {
            // Update position
            particle.position += particle.velocity * uniforms.deltaTime;
            
            // Apply gravity and drag based on particle type
            switch (particle.type) {
                case 0: // Water
                    particle.velocity.y -= 9.8 * uniforms.deltaTime;
                    particle.velocity *= 0.98; // Slight drag
                    break;
                case 1: // Smoke
                    particle.velocity.y += 2.0 * uniforms.deltaTime; // Rise
                    particle.velocity *= 0.95; // More drag
                    break;
                case 2: // Steam
                    particle.velocity.y += 1.0 * uniforms.deltaTime; // Gentle rise
                    particle.velocity *= 0.92; // Significant drag
                    break;
                case 3: // Spark
                    particle.velocity.y -= 5.0 * uniforms.deltaTime; // Light gravity
                    particle.velocity *= 0.99; // Minimal drag
                    break;
                case 4: // Foam
                    particle.velocity *= 0.9; // Heavy drag
                    break;
                case 5: // Wake
                    particle.velocity *= 0.85; // Dissipate quickly
                    break;
            }
            
            // Update alpha based on life remaining
            float lifeRatio = particle.life / particle.maxLife;
            particle.color.a = particle.color.a * lifeRatio;
            
            // Update size based on particle type and life
            if (particle.type == 1 || particle.type == 2) { // Smoke/Steam
                particle.size *= 1.01; // Grow over time
            }
        }
        
        particles[id] = particle;
    } else {
        // Try to spawn new particle from emitters
        for (uint i = 0; i < 100; i++) { // Max emitters
            EmitterData emitter = emitters[i];
            if (!emitter.active) continue;
            
            // Simple emission probability
            float emissionProbability = emitter.emissionRate * uniforms.deltaTime / 60.0;
            float rand = random(float2(id + uniforms.time, i + uniforms.time));
            
            if (rand < emissionProbability) {
                // Spawn new particle
                particle.position = emitter.position;
                particle.velocity = emitter.velocity + (random3(float3(id, i, uniforms.time)) - 0.5) * 2.0;
                particle.life = emitter.particleLifetime;
                particle.maxLife = emitter.particleLifetime;
                particle.size = emitter.size * (0.8 + random(float2(id, uniforms.time)) * 0.4);
                particle.color = emitter.color;
                particle.type = emitter.type;
                particle.active = 1;
                
                particles[id] = particle;
                atomic_fetch_add_explicit(particleCount, 1, memory_order_relaxed);
                break;
            }
        }
    }
}

// Particle vertex shader
vertex VertexOut particleAdvancedVertexShader(uint vertexID [[vertex_id]],
                                              constant Particle *particles [[buffer(0)]],
                                              constant ParticleUniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    Particle particle = particles[vertexID];
    
    if (!particle.active) {
        // Hide inactive particles
        out.position = float4(0, 0, -1000, 1);
        out.color = float4(0);
        out.texCoords = float2(0);
        out.worldPosition = float3(0);
        out.normal = float3(0, 1, 0);
        out.viewDirection = float3(0);
        return out;
    }
    
    // Billboard the particle to face the camera
    float3 toCamera = normalize(uniforms.cameraPosition - particle.position);
    float3 up = float3(0, 1, 0);
    float3 right = normalize(cross(up, toCamera));
    up = cross(toCamera, right);
    
    // Create billboard quad
    float2 quad[4] = {
        float2(-0.5, -0.5),
        float2( 0.5, -0.5),
        float2( 0.5,  0.5),
        float2(-0.5,  0.5)
    };
    
    uint quadIndex = vertexID % 4;
    float2 offset = quad[quadIndex] * particle.size;
    
    float3 worldPos = particle.position + right * offset.x + up * offset.y;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(worldPos, 1.0);
    out.color = particle.color;
    out.texCoords = quad[quadIndex] + 0.5; // Convert to 0-1 range
    out.worldPosition = worldPos;
    out.normal = toCamera;
    out.viewDirection = toCamera;
    
    return out;
}

// Advanced particle fragment shader with type-based rendering
fragment float4 particleAdvancedFragmentShader(VertexOut in [[stage_in]],
                                               texture2d<float> particleTexture [[texture(0)]],
                                               sampler textureSampler [[sampler(0)]]) {
    
    float4 textureColor = particleTexture.sample(textureSampler, in.texCoords);
    float4 finalColor = in.color * textureColor;
    
    // Distance-based alpha fade
    float distanceToCenter = length(in.texCoords - 0.5) * 2.0;
    finalColor.a *= smoothstep(1.0, 0.5, distanceToCenter);
    
    // Soft particle effect (fade near geometry)
    // This would require depth buffer access in a more complete implementation
    
    return finalColor;
}