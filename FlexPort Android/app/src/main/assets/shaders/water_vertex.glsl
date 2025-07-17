#version 300 es

precision mediump float;

in vec4 a_Position;
in vec2 a_TexCoord;

uniform mat4 u_VPMatrix;
uniform float u_Time;
uniform vec3 u_WaveParams; // amplitude, frequency, speed

out vec2 v_TexCoord;
out vec3 v_WorldPos;

void main() {
    vec4 worldPos = a_Position;
    
    // Add wave animation
    float wave1 = sin(worldPos.x * u_WaveParams.y + u_Time * u_WaveParams.z) * u_WaveParams.x;
    float wave2 = cos(worldPos.z * u_WaveParams.y * 0.7 + u_Time * u_WaveParams.z * 0.8) * u_WaveParams.x * 0.6;
    
    worldPos.y += wave1 + wave2;
    
    gl_Position = u_VPMatrix * worldPos;
    v_TexCoord = a_TexCoord;
    v_WorldPos = worldPos.xyz;
}