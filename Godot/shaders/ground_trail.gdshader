shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/harbor_shape.gdshaderinc"
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz;
    float d = min(segment_dist(p,vec2(-23.0,-17.0),vec2(-11.0,-2.4)),segment_dist(p,vec2(-11.0,-2.4),vec2(2.4,0.4)));
    d = min(d,segment_dist(p,vec2(2.4,0.4),vec2(3.0,7.0)));
    d = min(d,segment_dist(p,vec2(-10.0,-2.4),vec2(7.0,-8.5)));
    float irregular = sin(p.x*2.1 + sin(p.y*1.5))*0.13 + sin(p.y*3.9)*0.06;
    float road = 1.0 - smoothstep(0.85,1.65,d+irregular);
    float shore = smoothstep(coast(p.x)-1.5,coast(p.x)+0.45,p.y);
    float plaza = 1.0-smoothstep(1.8,3.8,length(p-vec2(-5.0,-1.5)));
    float cover = max(max(road,shore),plaza*0.7);
    vec3 grass = texture(grass_tex,p*0.135).rgb * vec3(0.62,0.72,0.58);
    grass=mix(grass,vec3(0.085,0.135,0.062),0.18);
    vec3 path = texture(ground_tex,p*0.24).rgb * vec3(0.79,0.79,0.72);
    vec3 base = mix(grass,path,cover);
    float bank=(1.0-smoothstep(0.8,1.16,world_pos.y))*shore;
    vec3 earth=texture(ground_tex,p*0.30).rgb*vec3(0.48,0.50,0.43);
    base=mix(base,earth,bank*0.75);
    float wet = 1.0-smoothstep(0.24,0.72,world_pos.y);
    base *= mix(vec3(1.0),vec3(0.58,0.69,0.64),wet*0.65);
    ALBEDO = base;
    ROUGHNESS = mix(0.98,0.68,wet);
    SPECULAR = 0.12;
}
