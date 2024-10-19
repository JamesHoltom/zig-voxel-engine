#version 460 core
#extension GL_ARB_bindless_texture : require

layout (location=0) in VertexData {
    vec4 colour;
    vec2 uv;
} i_vert_data;

layout (location=0) out vec4 o_colour;

layout (location=1) uniform sampler2D u_texture;

void main() {
    o_colour = texture(u_texture, i_vert_data.uv) * i_vert_data.colour;
}