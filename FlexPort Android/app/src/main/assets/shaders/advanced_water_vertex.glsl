#version 300 es

precision highp float;

// Input attributes
in vec4 a_Position;
in vec2 a_TexCoord;

// Uniforms
uniform mat4 u_VPMatrix;
uniform float u_Time;
uniform vec3 u_CameraPosition;
uniform vec2 u_WindDirection;
uniform float u_WindStrength;

// Wave parameters (supporting up to 8 wave layers)
uniform int u_WaveCount;
uniform float u_WaveAmplitudes[8];
uniform float u_WaveWavelengths[8];
uniform float u_WaveSpeeds[8];
uniform vec2 u_WaveDirections[8];
uniform float u_WaveSteepnesses[8];
uniform float u_WavePhases[8];

uniform int u_PerformanceLevel; // 0=LOW, 1=MEDIUM, 2=HIGH, 3=ULTRA

// Output to fragment shader
out vec2 v_TexCoord;
out vec3 v_WorldPos;
out vec3 v_Normal;
out vec3 v_ViewDirection;
out float v_FoamFactor;
out vec2 v_FlowDirection;

const float PI = 3.14159265359;

// Gerstner wave function for realistic wave displacement
vec3 gerstnerWave(vec2 position, float amplitude, float wavelength, float speed, vec2 direction, float steepness, float phase) {
    float frequency = 2.0 * PI / wavelength;
    float phaseShift = speed * frequency;
    float theta = dot(direction, position) * frequency + u_Time * phaseShift + phase;
    
    float c = cos(theta);
    float s = sin(theta);
    
    // Gerstner wave displacement
    vec3 wave;
    wave.x = steepness * amplitude * direction.x * c;
    wave.z = steepness * amplitude * direction.y * c;
    wave.y = amplitude * s;
    
    return wave;
}

// Calculate wave normal for lighting
vec3 gerstnerWaveNormal(vec2 position, float amplitude, float wavelength, float speed, vec2 direction, float steepness, float phase) {
    float frequency = 2.0 * PI / wavelength;
    float phaseShift = speed * frequency;
    float theta = dot(direction, position) * frequency + u_Time * phaseShift + phase;
    
    float c = cos(theta);
    float s = sin(theta);
    
    // Calculate partial derivatives for normal
    float dDx = -frequency * steepness * amplitude * direction.x * direction.x * s;
    float dDz = -frequency * steepness * amplitude * direction.y * direction.y * s;
    float dDy = frequency * amplitude * c;
    
    return vec3(-dDx, 1.0 - dDy, -dDz);
}

void main() {
    vec2 worldPos = a_Position.xz;
    vec3 totalDisplacement = vec3(0.0);
    vec3 totalNormal = vec3(0.0, 1.0, 0.0);
    float totalFoam = 0.0;
    vec2 totalFlow = vec2(0.0);
    
    // Apply multiple wave layers based on performance level
    int waveLimit = min(u_WaveCount, u_PerformanceLevel + 2);
    
    for (int i = 0; i < waveLimit && i < 8; i++) {
        // Calculate individual wave contribution
        vec3 waveDisplacement = gerstnerWave(
            worldPos,
            u_WaveAmplitudes[i],
            u_WaveWavelengths[i],
            u_WaveSpeeds[i],
            u_WaveDirections[i],
            u_WaveSteepnesses[i],
            u_WavePhases[i]
        );
        
        vec3 waveNormal = gerstnerWaveNormal(
            worldPos,
            u_WaveAmplitudes[i],
            u_WaveWavelengths[i],
            u_WaveSpeeds[i],
            u_WaveDirections[i],
            u_WaveSteepnesses[i],
            u_WavePhases[i]
        );
        
        totalDisplacement += waveDisplacement;
        totalNormal += waveNormal;
        
        // Calculate foam based on wave steepness and amplitude
        float waveIntensity = u_WaveAmplitudes[i] * u_WaveSteepnesses[i];
        totalFoam += waveIntensity * 0.5;
        
        // Calculate flow direction for texture animation
        totalFlow += u_WaveDirections[i] * u_WaveAmplitudes[i] * 0.1;
    }
    
    // Apply wind influence
    vec2 windInfluence = u_WindDirection * u_WindStrength * 0.1;
    totalDisplacement.xz += windInfluence * sin(u_Time * 0.5);
    totalFlow += windInfluence;
    
    // Final world position
    vec3 finalPosition = a_Position.xyz + totalDisplacement;
    
    // Transform to clip space
    gl_Position = u_VPMatrix * vec4(finalPosition, 1.0);
    
    // Pass data to fragment shader
    v_TexCoord = a_TexCoord;
    v_WorldPos = finalPosition;
    v_Normal = normalize(totalNormal);
    v_ViewDirection = normalize(u_CameraPosition - finalPosition);
    v_FoamFactor = clamp(totalFoam, 0.0, 1.0);
    v_FlowDirection = totalFlow;
}