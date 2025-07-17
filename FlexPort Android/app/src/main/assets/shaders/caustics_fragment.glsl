#version 300 es

precision highp float;

in vec2 v_TexCoord;
in vec3 v_WorldPos;
in vec3 v_SunDir;

uniform float u_Time;

out vec4 fragColor;

// Caustics pattern generation
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
    vec2 causticsCoord = v_TexCoord * 8.0 + u_Time * 0.05;
    
    // Generate caustics pattern using multiple noise layers
    float caustics1 = noise(causticsCoord + vec2(u_Time * 0.1));
    float caustics2 = noise(causticsCoord * 2.0 - vec2(u_Time * 0.08));
    float caustics3 = noise(causticsCoord * 4.0 + vec2(u_Time * 0.12));
    
    float causticsPattern = caustics1 * 0.5 + caustics2 * 0.3 + caustics3 * 0.2;
    causticsPattern = smoothstep(0.2, 0.9, causticsPattern);
    
    // Modulate by sun direction strength
    float sunStrength = max(0.0, v_SunDir.y);
    causticsPattern *= sunStrength;
    
    fragColor = vec4(vec3(causticsPattern), causticsPattern * 0.6);
}