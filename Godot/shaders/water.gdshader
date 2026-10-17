shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
uniform vec2 boat_position = vec2(7.0,9.5);
uniform vec2 foot_position = vec2(-50.0,-50.0);
varying vec3 world_pos;
float coast(float x) { return 3.2 + sin(x*0.17)*1.9 + sin(x*0.47)*0.35; }
float wave(vec2 p) { return sin(p.x*0.8+p.y*0.35-clock*0.65)*0.028 + sin(p.y*1.3-p.x*0.2+clock*0.44)*0.012; }
void vertex() {
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y += wave(world_pos.xz);
}
void fragment() {
    vec2 p=world_pos.xz;
    float shore_dist=max(p.y-coast(p.x),0.0);
    float shallow=exp(-shore_dist*0.43);
    vec3 deep=vec3(0.085,0.26,0.30);
    vec3 edge=vec3(0.24,0.43,0.38);
    vec3 col=mix(deep,edge,shallow*0.66);
    float band=sin(p.y*3.2 + sin(p.x*0.45)*1.3-clock*0.55);
    float break_up=sin(p.x*2.8+cos(p.y*1.1)+clock*0.13);
    float marks=smoothstep(0.93,0.995,band)*smoothstep(0.32,0.80,break_up);
    col += vec3(0.11,0.15,0.12)*marks*0.38;
    float long_waves=sin(p.x*0.6+p.y*0.75-clock*0.3);
    col += vec3(0.013,0.025,0.023)*long_waves;
    float shore_line=exp(-pow((shore_dist-0.60-sin(clock*0.55+p.x*0.35)*0.09)/0.14,2.0));
    col=mix(col,vec3(0.53,0.65,0.56),shore_line*(0.16+marks*0.20));
    vec2 b=(p-boat_position)/vec2(2.2,5.9);
    float boat_rim=exp(-pow((length(b)-1.02)/0.045,2.0));
    col=mix(col,vec3(0.62,0.72,0.63),boat_rim*0.30);
    float fd=length(p-foot_position);
    float rip=exp(-pow((fd-mod(clock*0.45,1.7))/0.045,2.0))*exp(-fd*1.4);
    col+=vec3(0.11,0.14,0.10)*rip;
    ALBEDO=col;
    ROUGHNESS=0.42;
    SPECULAR=0.36;
    vec3 n=normalize(vec3(-cos(p.x*0.8+p.y*0.35-clock*0.65)*0.045,1.0,-cos(p.y*1.3+clock*0.44)*0.035));
    NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
}
