#version 300 es

precision mediump float;

in vec4 a_Position;
in vec2 a_TexCoord;

uniform mat4 u_VPMatrix;
uniform mat4 u_ModelMatrix;

out vec2 v_TexCoord;

void main() {
    gl_Position = u_VPMatrix * u_ModelMatrix * a_Position;
    v_TexCoord = a_TexCoord;
}