shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 world_pos;

float coast(float x) { return 3.2 + sin(x * 0.17) * 1.9 + sin(x * 0.47) * 0.35; }
float segment_dist(vec2 p, vec2 a, vec2 b) {
    vec2 v = b - a;
    return length(p - a - v * clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz;
    float d = min(segment_dist(p,vec2(-23.0,-17.0),vec2(-11.0,-3.2)),segment_dist(p,vec2(-11.0,-3.2),vec2(1.8,0.5)));
    d = min(d,segment_dist(p,vec2(1.8,0.5),vec2(3.0,7.0)));
    d = min(d,segment_dist(p,vec2(-11.0,-3.2),vec2(6.0,-9.0)));
    float irregular = sin(p.x*2.1 + sin(p.y*1.5))*0.09 + sin(p.y*3.9)*0.06;
    float road = 1.0 - smoothstep(1.05,1.85,d+irregular);
    float shore = smoothstep(coast(p.x)-1.3,coast(p.x)+0.5,p.y);
    float plaza = 1.0-smoothstep(2.1,3.8,length(p-vec2(-6.0,-1.5)));
    float cover = max(max(road,shore),plaza*0.84);
    vec3 grass = texture(grass_tex,p*0.115).rgb * vec3(0.90,0.98,0.92);
    vec3 path = texture(ground_tex,p*0.20).rgb * vec3(0.95,0.94,0.90);
    vec3 base = mix(grass,path,cover);
    float depth = smoothstep(0.4,-2.8,world_pos.y);
    ALBEDO = mix(base,base*vec3(0.55,0.68,0.65),depth*0.5);
    ROUGHNESS = 0.96;
    SPECULAR = 0.12;
}
