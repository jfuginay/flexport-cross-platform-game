#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct InstanceData {
    float3x3 transform [[attribute(2)]];
    float4 textureRect [[attribute(5)]];
    float4 color [[attribute(6)]];
    float4 animationData [[attribute(7)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
    float4 color;
    float4 animationData;
};

struct SpriteUniforms {
    float4x4 viewProjectionMatrix;
    float time;
};

// MARK: - Sprite Shaders

vertex VertexOut spriteVertexShader(VertexIn in [[stage_in]],
                                    constant SpriteUniforms& uniforms [[buffer(2)]],
                                    InstanceData instance [[stage_in]],
                                    uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    // Apply instance transform
    float3 transformedPos = instance.transform * float3(in.position, 1.0);
    
    // Convert to world space (assuming 2D sprites in 3D world)
    float4 worldPos = float4(transformedPos.x, 0.0, transformedPos.y, 1.0);
    
    // Apply view-projection matrix
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Calculate texture coordinates within the texture rect
    float2 rectPos = instance.textureRect.xy;
    float2 rectSize = instance.textureRect.zw;
    out.texCoords = rectPos + in.texCoords * rectSize;
    
    // Pass through color and animation data
    out.color = instance.color;
    out.animationData = instance.animationData;
    
    return out;
}

fragment float4 spriteFragmentShader(VertexOut in [[stage_in]],
                                     texture2d<float> spriteTexture [[texture(0)]],
                                     sampler spriteSampler [[sampler(0)]]) {
    // Sample the texture
    float4 texColor = spriteTexture.sample(spriteSampler, in.texCoords);
    
    // Apply tint color and alpha
    float4 finalColor = texColor * in.color;
    
    // Discard fully transparent pixels
    if (finalColor.a < 0.01) {
        discard_fragment();
    }
    
    return finalColor;
}

// MARK: - Particle Shaders

vertex VertexOut particleVertexShader(VertexIn in [[stage_in]],
                                     constant SpriteUniforms& uniforms [[buffer(2)]],
                                     InstanceData instance [[stage_in]],
                                     uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    // Apply instance transform
    float3 transformedPos = instance.transform * float3(in.position, 1.0);
    
    // Add particle animation (float up and fade)
    float particleAge = instance.animationData.x;
    float particleSpeed = instance.animationData.y;
    transformedPos.y += particleAge * particleSpeed;
    
    // Convert to world space
    float4 worldPos = float4(transformedPos.x, 0.0, transformedPos.y, 1.0);
    
    // Apply view-projection matrix
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Texture coordinates
    out.texCoords = in.texCoords;
    
    // Fade out based on age
    float fadeOut = 1.0 - saturate(particleAge / 2.0);
    out.color = instance.color * float4(1.0, 1.0, 1.0, fadeOut);
    out.animationData = instance.animationData;
    
    return out;
}

fragment float4 particleFragmentShader(VertexOut in [[stage_in]],
                                      texture2d<float> particleTexture [[texture(0)]],
                                      sampler particleSampler [[sampler(0)]]) {
    // Sample the particle texture
    float4 texColor = particleTexture.sample(particleSampler, in.texCoords);
    
    // Apply color and fade
    float4 finalColor = texColor * in.color;
    
    // Soft particles (fade edges)
    float2 center = in.texCoords - 0.5;
    float dist = length(center) * 2.0;
    finalColor.a *= 1.0 - smoothstep(0.3, 1.0, dist);
    
    // Discard fully transparent pixels
    if (finalColor.a < 0.01) {
        discard_fragment();
    }
    
    return finalColor;
}

// MARK: - Trail Shaders

struct TrailVertex {
    float2 position [[attribute(0)]];
};

struct TrailVertexOut {
    float4 position [[position]];
    float alpha;
};

vertex TrailVertexOut trailVertexShader(TrailVertex in [[stage_in]],
                                       constant SpriteUniforms& uniforms [[buffer(1)]],
                                       uint vertexID [[vertex_id]]) {
    TrailVertexOut out;
    
    // Convert to world space
    float4 worldPos = float4(in.position.x, 0.0, in.position.y, 1.0);
    
    // Apply view-projection matrix
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Calculate alpha based on vertex position in strip
    out.alpha = 1.0 - float(vertexID % 2);
    
    return out;
}

fragment float4 trailFragmentShader(TrailVertexOut in [[stage_in]]) {
    // Wake trail color (white foam)
    float4 color = float4(0.9, 0.95, 1.0, 0.7);
    
    // Apply vertex alpha
    color.a *= in.alpha;
    
    return color;
}

// MARK: - Damage Effect Shaders

kernel void damageEffectKernel(texture2d<float, access::read> sourceTexture [[texture(0)]],
                              texture2d<float, access::write> destTexture [[texture(1)]],
                              constant float& damageLevel [[buffer(0)]],
                              constant float& time [[buffer(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
    // Read source pixel
    float4 color = sourceTexture.read(gid);
    
    // Apply damage effects based on damage level
    if (damageLevel > 0.0) {
        // Darken the texture
        color.rgb *= 1.0 - (damageLevel * 0.3);
        
        // Add scorch marks
        float noise = fract(sin(dot(float2(gid), float2(12.9898, 78.233))) * 43758.5453);
        if (noise < damageLevel * 0.3) {
            color.rgb *= 0.3;
        }
        
        // Add fire glow for severe damage
        if (damageLevel > 0.7) {
            float fireGlow = sin(time * 5.0 + float(gid.y) * 0.1) * 0.5 + 0.5;
            color.r += fireGlow * damageLevel * 0.3;
            color.g += fireGlow * damageLevel * 0.1;
        }
    }
    
    // Write result
    destTexture.write(color, gid);
}

// MARK: - Wake Effect Shaders

kernel void wakeEffectKernel(texture2d<float, access::read_write> waterTexture [[texture(0)]],
                            constant float2& shipPosition [[buffer(0)]],
                            constant float2& shipVelocity [[buffer(1)]],
                            constant float& time [[buffer(2)]],
                            uint2 gid [[thread_position_in_grid]]) {
    // Get texture dimensions
    float2 texSize = float2(waterTexture.get_width(), waterTexture.get_height());
    float2 uv = float2(gid) / texSize;
    
    // Calculate distance from ship
    float2 worldPos = uv * 100.0; // Assuming 100 unit world size
    float2 toShip = worldPos - shipPosition;
    float distToShip = length(toShip);
    
    // Wake V-shape
    float2 wakeDir = normalize(shipVelocity);
    float wakeDot = dot(normalize(toShip), -wakeDir);
    
    // Create wake pattern
    if (distToShip < 20.0 && wakeDot > 0.7) {
        float wakeIntensity = (1.0 - distToShip / 20.0) * (wakeDot - 0.7) / 0.3;
        
        // Animated wake waves
        float wavePattern = sin(distToShip * 0.5 - time * 3.0) * 0.5 + 0.5;
        wakeIntensity *= wavePattern;
        
        // Read current water color
        float4 waterColor = waterTexture.read(gid);
        
        // Add foam
        waterColor.rgb = mix(waterColor.rgb, float3(0.9, 0.95, 1.0), wakeIntensity * 0.7);
        
        // Write back
        waterTexture.write(waterColor, gid);
    }
}

// MARK: - Port Activity Shaders

vertex VertexOut portActivityVertexShader(VertexIn in [[stage_in]],
                                         constant SpriteUniforms& uniforms [[buffer(2)]],
                                         InstanceData instance [[stage_in]],
                                         constant float& activityLevel [[buffer(3)]],
                                         uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    // Apply instance transform with activity-based scaling
    float activityScale = 1.0 + activityLevel * 0.2 * sin(uniforms.time * 3.0);
    float3 scaledPos = float3(in.position * activityScale, 1.0);
    float3 transformedPos = instance.transform * scaledPos;
    
    // Convert to world space
    float4 worldPos = float4(transformedPos.x, 0.0, transformedPos.y, 1.0);
    
    // Apply view-projection matrix
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Texture coordinates
    out.texCoords = instance.textureRect.xy + in.texCoords * instance.textureRect.zw;
    
    // Pulse color based on activity
    float pulse = sin(uniforms.time * 4.0 + activityLevel * 3.14159) * 0.5 + 0.5;
    out.color = instance.color * float4(1.0, 1.0 - pulse * 0.3, 1.0 - pulse * 0.5, 1.0);
    out.animationData = instance.animationData;
    
    return out;
}

// MARK: - Loading/Unloading Animation Shaders

struct LoadingAnimationUniforms {
    float4x4 viewProjectionMatrix;
    float time;
    float progress; // 0.0 to 1.0
    float2 startPos;
    float2 endPos;
};

vertex VertexOut loadingAnimationVertexShader(VertexIn in [[stage_in]],
                                             constant LoadingAnimationUniforms& uniforms [[buffer(0)]],
                                             uint instanceID [[instance_id]]) {
    VertexOut out;
    
    // Calculate container position along loading path
    float containerProgress = float(instanceID) / 20.0 + uniforms.progress;
    containerProgress = fract(containerProgress);
    
    // Bezier curve for crane movement
    float2 controlPoint = (uniforms.startPos + uniforms.endPos) * 0.5 + float2(0, 30);
    float t = containerProgress;
    float2 pos = pow(1.0 - t, 2.0) * uniforms.startPos +
                 2.0 * (1.0 - t) * t * controlPoint +
                 pow(t, 2.0) * uniforms.endPos;
    
    // Apply position
    float4 worldPos = float4(pos.x + in.position.x * 10.0, 5.0 + sin(t * 3.14159) * 10.0, pos.y + in.position.y * 10.0, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Texture coordinates
    out.texCoords = in.texCoords;
    
    // Container colors
    float colorIndex = fract(float(instanceID) * 0.618033988749895); // Golden ratio
    out.color = float4(colorIndex, 1.0 - colorIndex * 0.5, 0.5, 1.0);
    out.animationData = float4(containerProgress, 0, 0, 0);
    
    return out;
}

// MARK: - Ship Sinking Animation

vertex VertexOut sinkingVertexShader(VertexIn in [[stage_in]],
                                    constant SpriteUniforms& uniforms [[buffer(2)]],
                                    InstanceData instance [[stage_in]],
                                    constant float& sinkProgress [[buffer(3)]],
                                    uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    // Apply instance transform
    float3 transformedPos = instance.transform * float3(in.position, 1.0);
    
    // Sinking effects
    float sinkDepth = sinkProgress * 10.0;
    float listAngle = sinkProgress * 0.3 * sin(uniforms.time * 2.0);
    
    // Apply listing (rotation around ship center)
    float2x2 listRotation = float2x2(cos(listAngle), -sin(listAngle),
                                     sin(listAngle), cos(listAngle));
    transformedPos.xy = listRotation * transformedPos.xy;
    
    // Lower the ship
    float4 worldPos = float4(transformedPos.x, -sinkDepth, transformedPos.y, 1.0);
    
    // Apply view-projection matrix
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Texture coordinates
    out.texCoords = instance.textureRect.xy + in.texCoords * instance.textureRect.zw;
    
    // Darken color as ship sinks
    out.color = instance.color * float4(1.0 - sinkProgress * 0.5);
    out.animationData = float4(sinkProgress, listAngle, 0, 0);
    
    return out;
}

// MARK: - Network Interpolation Shader

struct InterpolationUniforms {
    float4x4 viewProjectionMatrix;
    float interpolationFactor; // 0.0 to 1.0
    float2 currentPos;
    float2 targetPos;
    float currentRotation;
    float targetRotation;
};

vertex VertexOut interpolatedSpriteVertexShader(VertexIn in [[stage_in]],
                                               constant InterpolationUniforms& uniforms [[buffer(0)]],
                                               InstanceData instance [[stage_in]]) {
    VertexOut out;
    
    // Smooth interpolation using ease-in-out
    float t = uniforms.interpolationFactor;
    float smoothT = t * t * (3.0 - 2.0 * t);
    
    // Interpolate position
    float2 interpolatedPos = mix(uniforms.currentPos, uniforms.targetPos, smoothT);
    
    // Interpolate rotation (shortest path)
    float rotDiff = uniforms.targetRotation - uniforms.currentRotation;
    if (rotDiff > 3.14159) {
        rotDiff -= 2.0 * 3.14159;
    } else if (rotDiff < -3.14159) {
        rotDiff += 2.0 * 3.14159;
    }
    float interpolatedRot = uniforms.currentRotation + rotDiff * smoothT;
    
    // Apply rotation
    float2x2 rotation = float2x2(cos(interpolatedRot), -sin(interpolatedRot),
                                 sin(interpolatedRot), cos(interpolatedRot));
    float2 rotatedPos = rotation * in.position;
    
    // Apply instance transform with interpolated values
    float3 transformedPos = instance.transform * float3(rotatedPos, 1.0);
    transformedPos.xy += interpolatedPos;
    
    // Convert to world space
    float4 worldPos = float4(transformedPos.x, 0.0, transformedPos.y, 1.0);
    
    // Apply view-projection matrix
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Texture coordinates
    out.texCoords = instance.textureRect.xy + in.texCoords * instance.textureRect.zw;
    
    // Pass through color
    out.color = instance.color;
    out.animationData = float4(t, 0, 0, 0);
    
    return out;
}