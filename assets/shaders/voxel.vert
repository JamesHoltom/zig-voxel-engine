#version 460 core

layout (location=0) in vec3 i_vert_position;
layout (location=1) in vec2 i_vert_uv;
layout (location=2) in uint i_inst_data;

layout (location=0) out VertexData {
    vec4 colour;
    vec2 uv;
} o_vert_data;

layout (location=0) uniform mat4 u_model_view_project;

void main(){
    vec3 inst_position = vec3(float(i_inst_data & 31), float((i_inst_data >> 5) & 31), float((i_inst_data >> 10) & 31));
    vec2 inst_size = vec2(float((i_inst_data >> 15) & 31), float((i_inst_data >> 20) & 31));
    vec3 vert_position = i_vert_position;
    vec4 vert_colour = vec4(1.0);
    // vec4 vert_colour = vec4(1.0 / inst_size.x, 1.0 / inst_size.y, 1.0, 0.2);

    vert_position.xy *= inst_size;

    switch (gl_DrawID) {
        case 0: vert_position.xz = vert_position.zx; vert_position.x += 1.0; break;
        case 1: vert_position.xz = vert_position.zx; vert_position.z = inst_size.x - vert_position.z; break;
        case 2: vert_position.yz = vert_position.zy; vert_position.y += 1.0; break;
        case 3: vert_position.yz = vert_position.zy; vert_position.z = inst_size.y - vert_position.z; break;
        case 4: vert_position.x = 1.0 - vert_position.x; vert_position.xz += vec2(inst_size.x - 1.0, 1.0); break;
    }

    if (gl_DrawID == 0 && gl_InstanceID == 0) {
        vert_colour.a = 1.0;
    }

    gl_Position = u_model_view_project * vec4(inst_position + vert_position, 1.0);
    
    o_vert_data.colour = vert_colour;
    o_vert_data.uv = i_vert_uv * inst_size;
}