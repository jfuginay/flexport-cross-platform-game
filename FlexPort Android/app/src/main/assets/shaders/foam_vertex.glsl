#version 300 es

precision highp float;

in vec4 a_Position;
in vec2 a_TexCoord;

uniform mat4 u_VPMatrix;
uniform float u_Time;

out vec2 v_TexCoord;
out vec3 v_WorldPos;

void main() {
    gl_Position = u_VPMatrix * a_Position;
    v_TexCoord = a_TexCoord;
    v_WorldPos = a_Position.xyz;
}