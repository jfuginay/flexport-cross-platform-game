#version 300 es

precision mediump float;

in vec2 v_TexCoord;

uniform sampler2D u_Texture;
uniform vec4 u_Color;
uniform float u_Time;

out vec4 fragColor;

void main() {
    vec4 texColor = texture(u_Texture, v_TexCoord);
    
    // Apply tint color
    vec3 finalColor = texColor.rgb * u_Color.rgb;
    
    // Add subtle animation for ships
    float pulse = sin(u_Time * 2.0) * 0.1 + 0.9;
    finalColor *= pulse;
    
    fragColor = vec4(finalColor, texColor.a * u_Color.a);
}