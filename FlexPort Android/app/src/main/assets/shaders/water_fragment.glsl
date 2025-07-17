#version 300 es

precision mediump float;

in vec2 v_TexCoord;
in vec3 v_WorldPos;

uniform float u_Time;

out vec4 fragColor;

void main() {
    // Ocean color gradients
    vec3 deepOcean = vec3(0.02, 0.1, 0.2);
    vec3 shallowOcean = vec3(0.05, 0.15, 0.35);
    vec3 foam = vec3(0.8, 0.9, 1.0);
    
    // Create wave patterns for color variation
    float wave1 = sin(v_TexCoord.x * 20.0 + u_Time * 2.0) * 0.5 + 0.5;
    float wave2 = cos(v_TexCoord.y * 15.0 + u_Time * 1.5) * 0.5 + 0.5;
    float wavePattern = wave1 * wave2;
    
    // Mix colors based on wave pattern
    vec3 baseColor = mix(deepOcean, shallowOcean, wavePattern);
    
    // Add foam highlights
    float foamMask = smoothstep(0.8, 1.0, wavePattern);
    vec3 finalColor = mix(baseColor, foam, foamMask * 0.3);
    
    // Add depth-based alpha
    float alpha = 0.85 + 0.15 * sin(u_Time * 0.5);
    
    fragColor = vec4(finalColor, alpha);
}