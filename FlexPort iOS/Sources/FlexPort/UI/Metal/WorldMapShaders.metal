#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// Constants
constant float PI = 3.14159265359;
constant float TWO_PI = 6.28318530718;
constant float EARTH_RADIUS = 6371.0; // km

// Vertex structures
struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float3 normal [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 worldPos;
    float3 normal;
    float2 worldCoord;
    float elevation;
};

// Uniform structures
struct Uniforms {
    float time;
    float zoom;
    float2 pan;
    float2 screenSize;
    float dayNightCycle; // 0-1, where 0.5 is noon
    float weatherIntensity; // 0-1 for weather effects
    float3 sunDirection;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
};

struct Port {
    float2 position;
    float size;
    float activity;
    float economicHealth; // 0-1
};

struct Ship {
    float2 position;
    float2 velocity;
    float size;
    float cargo; // 0-1 cargo fill level
    float type; // 0: container, 1: tanker, 2: bulk
};

struct Weather {
    float2 center;
    float radius;
    float intensity;
    float type; // 0: clear, 1: storm, 2: fog
};

// Advanced noise functions for terrain and waves
float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i + float2(0.0, 0.0));
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
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

// Realistic continent generation using real Earth data approximation
float continentShape(float2 p) {
    // Convert to spherical coordinates
    float lon = p.x * PI;
    float lat = p.y * PI * 0.5;
    
    // Major landmasses using distance fields
    float landmass = 1.0;
    
    // North America
    float2 na_center = float2(-1.8, 0.7);
    float na = length((p - na_center) * float2(0.6, 1.0)) - 0.35;
    landmass = min(landmass, na);
    
    // South America
    float2 sa_center = float2(-1.2, -0.3);
    float sa = length((p - sa_center) * float2(0.4, 0.8)) - 0.25;
    landmass = min(landmass, sa);
    
    // Africa
    float2 af_center = float2(0.3, 0.0);
    float af = length((p - af_center) * float2(0.5, 0.9)) - 0.35;
    landmass = min(landmass, af);
    
    // Europe
    float2 eu_center = float2(0.2, 0.85);
    float eu = length((p - eu_center) * float2(0.8, 0.4)) - 0.2;
    landmass = min(landmass, eu);
    
    // Asia
    float2 as_center = float2(1.5, 0.6);
    float as = length((p - as_center) * float2(1.2, 0.7)) - 0.5;
    landmass = min(landmass, as);
    
    // Australia
    float2 au_center = float2(2.3, -0.6);
    float au = length((p - au_center) * float2(0.5, 0.3)) - 0.15;
    landmass = min(landmass, au);
    
    // Add realistic coastline detail
    float coastNoise = fbm(p * 50.0, 4) * 0.03;
    landmass += coastNoise;
    
    return smoothstep(-0.02, 0.02, landmass);
}

// Height map for realistic terrain elevation
float terrainHeight(float2 p, float landMask) {
    if (landMask < 0.01) return 0.0;
    
    // Mountain ranges
    float mountains = 0.0;
    
    // Rockies
    float rockies = 1.0 - smoothstep(0.0, 0.1, abs(p.x + 1.6) - 0.05);
    rockies *= 1.0 - smoothstep(0.3, 1.2, abs(p.y - 0.5));
    mountains = max(mountains, rockies * 0.8);
    
    // Andes
    float andes = 1.0 - smoothstep(0.0, 0.05, abs(p.x + 1.2) - 0.02);
    andes *= 1.0 - smoothstep(-0.8, 0.2, p.y);
    mountains = max(mountains, andes * 0.9);
    
    // Himalayas
    float himalayas = 1.0 - smoothstep(0.0, 0.2, length(p - float2(1.2, 0.5)) - 0.1);
    mountains = max(mountains, himalayas * 1.0);
    
    // Alps
    float alps = 1.0 - smoothstep(0.0, 0.1, length(p - float2(0.2, 0.75)) - 0.05);
    mountains = max(mountains, alps * 0.6);
    
    // Add terrain detail
    float detail = fbm(p * 20.0, 5) * 0.3;
    
    return (mountains + detail * (1.0 - mountains * 0.5)) * landMask;
}

// Gerstner wave function for realistic ocean waves
float3 gerstnerWave(float2 p, float time, float waveLength, float amplitude, float2 direction) {
    float k = TWO_PI / waveLength;
    float omega = sqrt(9.81 * k); // Deep water waves
    float phase = dot(direction, p) * k - omega * time;
    
    float x = -direction.x * amplitude * sin(phase);
    float z = -direction.y * amplitude * sin(phase);
    float y = amplitude * cos(phase);
    
    return float3(x, y, z);
}

// Multi-octave Gerstner waves for ocean surface
float3 oceanSurface(float2 p, float time) {
    float3 wave = float3(0.0);
    
    // Primary swell
    wave += gerstnerWave(p, time, 100.0, 2.0, normalize(float2(1.0, 0.3)));
    wave += gerstnerWave(p, time, 70.0, 1.5, normalize(float2(-0.7, 0.7)));
    
    // Secondary waves
    wave += gerstnerWave(p, time * 1.1, 50.0, 0.8, normalize(float2(0.3, 1.0)));
    wave += gerstnerWave(p, time * 1.2, 30.0, 0.5, normalize(float2(-0.5, -0.8)));
    
    // Capillary waves
    wave += gerstnerWave(p, time * 2.0, 10.0, 0.2, normalize(float2(0.8, -0.2)));
    wave += gerstnerWave(p, time * 2.3, 7.0, 0.1, normalize(float2(-0.3, 0.9)));
    
    return wave;
}

// Weather effects
float weatherEffect(float2 p, constant Weather* weather, uint weatherCount, float time) {
    float effect = 0.0;
    
    for (uint i = 0; i < weatherCount && i < 10; i++) {
        float dist = length(p - weather[i].center);
        
        if (weather[i].type == 1.0) { // Storm
            // Rotating storm clouds
            float angle = atan2(p.y - weather[i].center.y, p.x - weather[i].center.x);
            float spiral = sin(angle * 5.0 - time * 2.0 + dist * 10.0) * 0.5 + 0.5;
            float stormMask = 1.0 - smoothstep(0.0, weather[i].radius, dist);
            effect = max(effect, stormMask * spiral * weather[i].intensity);
        } else if (weather[i].type == 2.0) { // Fog
            float fogMask = 1.0 - smoothstep(weather[i].radius * 0.5, weather[i].radius, dist);
            float fogNoise = fbm(p * 10.0 + time * 0.1, 3);
            effect = max(effect, fogMask * fogNoise * weather[i].intensity * 0.7);
        }
    }
    
    return effect;
}

// Vertex shader
vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // Calculate world coordinates with zoom and pan
    out.worldCoord = (in.texCoord - 0.5) / uniforms.zoom + uniforms.pan;
    out.texCoord = in.texCoord;
    
    // Get terrain elevation
    float landMask = 1.0 - continentShape(out.worldCoord);
    out.elevation = terrainHeight(out.worldCoord, landMask);
    
    // Apply elevation to vertex position for 3D terrain
    float4 worldPos = in.position;
    worldPos.y += out.elevation * 0.1 * (1.0 / uniforms.zoom);
    
    // Ocean waves
    if (landMask < 0.5) {
        float3 wave = oceanSurface(out.worldCoord * 100.0, uniforms.time);
        worldPos.y += wave.y * 0.01 * (1.0 / uniforms.zoom);
        worldPos.xz += wave.xz * 0.005 * (1.0 / uniforms.zoom);
    }
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldPos = worldPos.xyz;
    out.normal = normalize(in.normal); // Will be modified in fragment shader
    
    return out;
}

// Fragment shader
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]],
                             constant Port* ports [[buffer(2)]],
                             constant Ship* ships [[buffer(3)]],
                             constant uint& portCount [[buffer(4)]],
                             constant uint& shipCount [[buffer(5)]],
                             constant Weather* weather [[buffer(6)]],
                             constant uint& weatherCount [[buffer(7)]]) {
    float2 uv = in.worldCoord;
    
    // Get land/ocean mask
    float landMask = 1.0 - continentShape(uv);
    float oceanDepth = 1.0 - landMask;
    
    // Calculate normal from height gradients
    float2 grad = float2(
        terrainHeight(uv + float2(0.001, 0.0), landMask) - terrainHeight(uv - float2(0.001, 0.0), landMask),
        terrainHeight(uv + float2(0.0, 0.001), landMask) - terrainHeight(uv - float2(0.0, 0.001), landMask)
    );
    float3 normal = normalize(float3(-grad.x * 100.0, 1.0, -grad.y * 100.0));
    
    // Ocean surface normal from waves
    if (oceanDepth > 0.5) {
        float3 wave1 = oceanSurface((uv + float2(0.001, 0.0)) * 100.0, uniforms.time);
        float3 wave2 = oceanSurface((uv - float2(0.001, 0.0)) * 100.0, uniforms.time);
        float3 wave3 = oceanSurface((uv + float2(0.0, 0.001)) * 100.0, uniforms.time);
        float3 wave4 = oceanSurface((uv - float2(0.0, 0.001)) * 100.0, uniforms.time);
        
        float2 waveGrad = float2(wave1.y - wave2.y, wave3.y - wave4.y);
        normal = normalize(float3(-waveGrad.x * 50.0, 1.0, -waveGrad.y * 50.0));
    }
    
    // Lighting calculation
    float3 lightDir = normalize(uniforms.sunDirection);
    float NdotL = max(dot(normal, lightDir), 0.0);
    float3 viewDir = normalize(float3(0.0, 1.0, 1.0)); // Simple view direction
    float3 halfDir = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfDir), 0.0);
    
    // Day/night cycle
    float daylight = smoothstep(0.0, 0.1, uniforms.dayNightCycle) * smoothstep(1.0, 0.9, uniforms.dayNightCycle);
    float3 sunColor = mix(float3(1.0, 0.6, 0.3), float3(1.0, 0.95, 0.8), daylight);
    float3 skyColor = mix(float3(0.05, 0.05, 0.2), float3(0.5, 0.7, 1.0), daylight);
    
    // Base colors
    float3 deepWater = float3(0.004, 0.016, 0.047) * (0.3 + daylight * 0.7);
    float3 shallowWater = float3(0.02, 0.15, 0.3) * (0.5 + daylight * 0.5);
    float3 beachSand = float3(0.9, 0.85, 0.7);
    float3 grass = float3(0.2, 0.5, 0.15);
    float3 rock = float3(0.5, 0.45, 0.4);
    float3 snow = float3(0.95, 0.95, 0.98);
    
    // Terrain coloring based on elevation
    float3 terrainColor;
    if (in.elevation < 0.02) {
        terrainColor = mix(beachSand, grass, smoothstep(0.0, 0.02, in.elevation));
    } else if (in.elevation < 0.5) {
        terrainColor = mix(grass, rock, smoothstep(0.02, 0.5, in.elevation));
    } else {
        terrainColor = mix(rock, snow, smoothstep(0.5, 0.8, in.elevation));
    }
    
    // Ocean coloring with depth
    float3 oceanColor = mix(shallowWater, deepWater, smoothstep(0.0, 0.1, oceanDepth));
    
    // Blend ocean and terrain
    float coastBlend = smoothstep(-0.01, 0.01, landMask - 0.5);
    float3 baseColor = mix(oceanColor, terrainColor, coastBlend);
    
    // Apply lighting
    float3 diffuse = baseColor * NdotL * sunColor;
    float3 ambient = baseColor * skyColor * 0.3;
    float3 color = diffuse + ambient;
    
    // Ocean specular highlights
    if (oceanDepth > 0.5) {
        float specular = pow(NdotH, 32.0) * (1.0 - weatherEffect(uv, weather, weatherCount, uniforms.time));
        color += sunColor * specular * 0.8;
        
        // Subsurface scattering effect
        float3 subsurface = shallowWater * 0.5 * max(0.0, dot(-normal, lightDir));
        color += subsurface * (1.0 - oceanDepth);
    }
    
    // Add foam at coastlines
    float coastDist = abs(landMask - 0.5);
    if (coastDist < 0.05) {
        float foam = noise(uv * 200.0 + float2(uniforms.time * 2.0, 0.0));
        foam *= noise(uv * 150.0 - float2(0.0, uniforms.time * 1.5));
        foam = smoothstep(0.3, 0.7, foam);
        color = mix(color, float3(0.95, 0.98, 1.0), foam * (1.0 - coastDist / 0.05) * 0.7);
    }
    
    // Weather effects
    float weatherIntensity = weatherEffect(uv, weather, weatherCount, uniforms.time);
    if (weatherIntensity > 0.0) {
        // Darken for storms
        color *= (1.0 - weatherIntensity * 0.5);
        
        // Add rain/fog effect
        float rainNoise = noise(uv * 500.0 + float2(0.0, uniforms.time * 50.0));
        color = mix(color, float3(0.7, 0.75, 0.8), weatherIntensity * rainNoise * 0.3);
    }
    
    // Draw ports with enhanced visuals
    for (uint i = 0; i < portCount && i < 20; i++) {
        float2 portPos = ports[i].position;
        float dist = length(in.texCoord - portPos);
        
        if (dist < 0.03 / uniforms.zoom) {
            // Port glow based on economic health
            float3 portColor = mix(float3(0.8, 0.2, 0.1), float3(0.1, 0.8, 0.2), ports[i].economicHealth);
            float pulse = sin(uniforms.time * 3.0 + float(i)) * 0.2 + 0.8;
            
            // Inner circle
            float portAlpha = 1.0 - smoothstep(0.0, 0.015 / uniforms.zoom, dist);
            color = mix(color, portColor * pulse, portAlpha * 0.9);
            
            // Activity rings
            float ring1 = abs(dist - 0.02 / uniforms.zoom);
            float ring2 = abs(dist - 0.025 / uniforms.zoom);
            
            if (ring1 < 0.001 / uniforms.zoom) {
                color = mix(color, portColor * 1.5, 0.6);
            }
            if (ring2 < 0.001 / uniforms.zoom && ports[i].activity > 0.5) {
                float movingRing = sin(uniforms.time * 5.0 - dist * 100.0) * 0.5 + 0.5;
                color = mix(color, float3(1.0, 1.0, 0.5), movingRing * 0.4);
            }
        }
    }
    
    // Enhanced ship rendering
    for (uint i = 0; i < shipCount && i < 100; i++) {
        float2 shipPos = ships[i].position;
        float2 shipVel = normalize(ships[i].velocity);
        float dist = length(in.texCoord - shipPos);
        
        if (dist < 0.015 / uniforms.zoom) {
            // Ship direction
            float angle = atan2(shipVel.y, shipVel.x);
            float2 rotatedCoord = in.texCoord - shipPos;
            
            // Rotate to ship space
            float c = cos(-angle);
            float s = sin(-angle);
            float2 localCoord = float2(
                rotatedCoord.x * c - rotatedCoord.y * s,
                rotatedCoord.x * s + rotatedCoord.y * c
            );
            
            // Ship shape based on type
            bool inShip = false;
            float3 shipColor = float3(0.9, 0.9, 0.95);
            
            if (ships[i].type < 0.5) { // Container ship - rectangular
                inShip = abs(localCoord.x) < 0.008 / uniforms.zoom && 
                        abs(localCoord.y) < 0.003 / uniforms.zoom;
                shipColor = mix(float3(0.7, 0.7, 0.8), float3(0.9, 0.4, 0.1), ships[i].cargo);
            } else if (ships[i].type < 1.5) { // Tanker - rounded
                float shipDist = length(localCoord * float2(1.0, 3.0));
                inShip = shipDist < 0.008 / uniforms.zoom;
                shipColor = float3(0.3, 0.3, 0.4);
            } else { // Bulk carrier - wide
                inShip = abs(localCoord.x) < 0.01 / uniforms.zoom && 
                        abs(localCoord.y) < 0.004 / uniforms.zoom;
                shipColor = float3(0.6, 0.5, 0.4);
            }
            
            if (inShip) {
                // Add ship details
                float shipLight = NdotL * 0.5 + 0.5;
                color = mix(color, shipColor * shipLight, 0.95);
                
                // Cargo indicators
                if (localCoord.x > 0.002 / uniforms.zoom && ships[i].cargo > 0.5) {
                    color = mix(color, float3(1.0, 0.5, 0.0), 0.3);
                }
            }
            
            // Wake effect with foam
            float wakeDist = length(float2(localCoord.x + 0.015 / uniforms.zoom, localCoord.y));
            if (wakeDist < 0.025 / uniforms.zoom && localCoord.x < 0) {
                float wakeAlpha = 1.0 - wakeDist / (0.025 / uniforms.zoom);
                wakeAlpha *= smoothstep(0.0, -0.02 / uniforms.zoom, localCoord.x);
                
                // Turbulent wake
                float wakeNoise = noise(float2(localCoord.x * 100.0, localCoord.y * 200.0 + uniforms.time * 10.0));
                wakeAlpha *= (0.5 + wakeNoise * 0.5);
                
                color = mix(color, float3(0.9, 0.95, 1.0), wakeAlpha * 0.6);
            }
        }
    }
    
    // Trade routes with animated flow
    for (uint i = 0; i < portCount && i < 20; i++) {
        for (uint j = i + 1; j < portCount && j < 20; j++) {
            float2 p1 = ports[i].position;
            float2 p2 = ports[j].position;
            
            // Great circle route approximation
            float2 lineDir = normalize(p2 - p1);
            float lineLength = length(p2 - p1);
            float2 toPoint = in.texCoord - p1;
            float projLength = dot(toPoint, lineDir);
            
            if (projLength >= 0 && projLength <= lineLength) {
                float2 projection = p1 + lineDir * projLength;
                float dist = length(in.texCoord - projection);
                
                if (dist < 0.002 / uniforms.zoom) {
                    // Animated flow particles
                    float flow = fract(projLength * 50.0 - uniforms.time * 2.0);
                    float particle = smoothstep(0.4, 0.5, flow) * smoothstep(0.6, 0.5, flow);
                    
                    float3 routeColor = mix(float3(0.3, 0.5, 1.0), float3(0.1, 1.0, 0.5), 
                                          (ports[i].economicHealth + ports[j].economicHealth) * 0.5);
                    
                    color = mix(color, routeColor, particle * 0.5 * (1.0 - dist / (0.002 / uniforms.zoom)));
                }
            }
        }
    }
    
    // Atmospheric fog for distance
    float fogAmount = smoothstep(0.5, 2.0, length(in.worldCoord));
    color = mix(color, skyColor * 0.8, fogAmount * 0.3);
    
    // Night lights for cities
    if (daylight < 0.5 && landMask > 0.5) {
        for (uint i = 0; i < portCount && i < 20; i++) {
            float2 portPos = ports[i].position;
            float dist = length(uv - portPos);
            if (dist < 0.1) {
                float cityGlow = exp(-dist * 20.0) * (1.0 - daylight);
                color += float3(1.0, 0.9, 0.6) * cityGlow * ports[i].economicHealth;
            }
        }
    }
    
    return float4(color, 1.0);
}

// Compute shader for particle systems (weather, ship wakes)
kernel void updateParticles(device float4* particles [[buffer(0)]],
                          constant Uniforms& uniforms [[buffer(1)]],
                          uint gid [[thread_position_in_grid]]) {
    float4 particle = particles[gid];
    
    // Update position based on velocity
    particle.xy += particle.zw * 0.016; // 60 FPS timestep
    
    // Wrap around world
    if (particle.x > 1.0) particle.x -= 2.0;
    if (particle.x < -1.0) particle.x += 2.0;
    if (particle.y > 1.0) particle.y -= 2.0;
    if (particle.y < -1.0) particle.y += 2.0;
    
    particles[gid] = particle;
}