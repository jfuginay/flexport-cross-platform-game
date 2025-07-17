#version 300 es

precision highp float;

in vec2 v_TexCoord;
in vec3 v_WorldPos;

uniform float u_Time;

out vec4 fragColor;

// Simple noise for foam generation
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

void main() {
    vec2 foamCoord = v_TexCoord * 16.0 + u_Time * 0.1;
    
    float foam1 = noise(foamCoord);
    float foam2 = noise(foamCoord * 2.0 + vec2(100.0));
    
    float foamPattern = foam1 * 0.7 + foam2 * 0.3;
    foamPattern = smoothstep(0.3, 0.8, foamPattern);
    
    fragColor = vec4(vec3(foamPattern), foamPattern);
}