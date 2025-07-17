#version 300 es

precision highp float;

// Input from vertex shader
in vec2 v_TexCoord;
in vec3 v_WorldPos;
in vec3 v_Normal;
in vec3 v_ViewDirection;
in float v_FoamFactor;
in vec2 v_FlowDirection;

// Uniforms
uniform float u_Time;
uniform vec3 u_SunDirection;
uniform sampler2D u_FoamTexture;
uniform sampler2D u_CausticsTexture;
uniform int u_PerformanceLevel;

// Output
out vec4 fragColor;

const float PI = 3.14159265359;

// Ocean color constants
const vec3 DEEP_OCEAN = vec3(0.01, 0.05, 0.15);
const vec3 SHALLOW_OCEAN = vec3(0.02, 0.12, 0.25);
const vec3 SURFACE_OCEAN = vec3(0.05, 0.18, 0.35);
const vec3 FOAM_COLOR = vec3(0.85, 0.92, 1.0);
const vec3 CAUSTICS_COLOR = vec3(0.8, 0.9, 1.0);

// Noise functions for procedural details
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Fresnel reflection calculation
float fresnel(vec3 normal, vec3 viewDir, float f0) {
    float cosTheta = max(dot(normal, viewDir), 0.0);
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

// Subsurface scattering approximation
vec3 subsurfaceScattering(vec3 normal, vec3 lightDir, vec3 viewDir, vec3 color) {
    float transmittance = max(0.0, -dot(normal, lightDir));
    float scatterStrength = pow(transmittance, 2.0);
    return color * scatterStrength * 0.3;
}

void main() {
    // Normalize inputs
    vec3 normal = normalize(v_Normal);
    vec3 viewDir = normalize(v_ViewDirection);
    vec3 lightDir = normalize(u_SunDirection);
    
    // Animated texture coordinates with flow
    vec2 flowTexCoord = v_TexCoord + v_FlowDirection * u_Time * 0.1;
    vec2 foamTexCoord = v_TexCoord * 8.0 + v_FlowDirection * u_Time * 0.2;
    
    // Base ocean color with depth variation
    float depth = clamp(-v_WorldPos.y * 0.1, 0.0, 1.0);
    vec3 baseColor = mix(SURFACE_OCEAN, DEEP_OCEAN, depth);
    
    // Add procedural noise for color variation
    float colorNoise = fbm(v_WorldPos.xz * 0.01 + u_Time * 0.05);
    baseColor = mix(baseColor, SHALLOW_OCEAN, colorNoise * 0.3);
    
    // Lighting calculations
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    
    // Diffuse lighting with subsurface scattering
    vec3 diffuse = baseColor * NdotL;
    vec3 subsurface = subsurfaceScattering(normal, lightDir, viewDir, baseColor);
    
    // Specular reflection (Blinn-Phong)
    vec3 halfVector = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, halfVector), 0.0);
    float specularPower = mix(32.0, 128.0, float(u_PerformanceLevel) / 3.0);
    float specular = pow(NdotH, specularPower);
    
    // Fresnel effect
    float fresnelFactor = fresnel(normal, viewDir, 0.02);
    
    // Foam effects
    vec3 foamSample = vec3(1.0); // Default white foam
    if (u_PerformanceLevel > 0) {
        foamSample = texture(u_FoamTexture, foamTexCoord).rgb;
    }
    
    float foamMask = v_FoamFactor;
    // Add noise-based foam for wave crests
    float foamNoise = fbm(v_WorldPos.xz * 0.1 + u_Time * 0.3);
    foamMask = max(foamMask, smoothstep(0.8, 1.0, foamNoise) * 0.5);
    
    vec3 foamContribution = FOAM_COLOR * foamSample * foamMask;
    
    // Caustics effects (higher performance levels only)
    vec3 causticsContribution = vec3(0.0);
    if (u_PerformanceLevel > 1) {
        vec2 causticsCoord = v_WorldPos.xz * 0.05 + u_Time * 0.1;
        vec3 causticsSample = texture(u_CausticsTexture, causticsCoord).rgb;
        float causticsStrength = max(0.0, NdotL) * (1.0 - depth) * 0.5;
        causticsContribution = CAUSTICS_COLOR * causticsSample * causticsStrength;
    }
    
    // Combine all lighting contributions
    vec3 finalColor = diffuse + subsurface;
    finalColor += specular * fresnelFactor * 0.8;
    finalColor += foamContribution;
    finalColor += causticsContribution;
    
    // Atmospheric perspective (distance fog)
    float distance = length(v_WorldPos - vec3(0.0)); // Assume camera at origin for simplicity
    float fogFactor = exp(-distance * 0.001);
    vec3 fogColor = vec3(0.7, 0.8, 0.9);
    finalColor = mix(fogColor, finalColor, fogFactor);
    
    // Time-based transparency variation
    float alphaVariation = 0.85 + 0.1 * sin(u_Time * 0.5);
    float alpha = mix(0.8, 1.0, fresnelFactor) * alphaVariation;
    
    // HDR tone mapping (simple Reinhard)
    finalColor = finalColor / (finalColor + vec3(1.0));
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    fragColor = vec4(finalColor, alpha);
}