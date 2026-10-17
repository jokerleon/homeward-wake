shader_type spatial;
uniform sampler2D stone_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.49,0.52,0.43,1.0);
varying vec3 pos;
varying vec3 world_pos;
void vertex() { pos=VERTEX; world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 tex=texture(stone_tex,(pos.xz+pos.y*0.4)*0.21).rgb;
    float low=1.0-smoothstep(0.1,0.7,world_pos.y);
    ALBEDO=mix(tint.rgb*mix(vec3(0.7),tex*1.45,0.65),tint.rgb*0.44,low*0.55);
    ROUGHNESS=0.95;
    SPECULAR=0.12;
}
