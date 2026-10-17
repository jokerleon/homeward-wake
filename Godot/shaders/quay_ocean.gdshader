shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture,filter_linear;
uniform sampler2D depth_tex : hint_depth_texture,filter_nearest;
uniform sampler2D reflection_tex : source_color,filter_nearest;
uniform float clock=0.0;
uniform float water_level=0.18;
uniform float reflection_strength=0.30;
uniform vec4 deep_color : source_color=vec4(0.09,0.25,0.28,1.0);
uniform vec4 shallow_color : source_color=vec4(0.26,0.42,0.38,1.0);
uniform vec4 foam_color : source_color=vec4(0.63,0.69,0.59,1.0);
uniform vec3 ripple_sources[8];
varying vec3 water_world;

vec4 reflected(vec2 uv){
    ivec2 s=textureSize(reflection_tex,0);
    vec2 p=uv*vec2(s)-0.5;
    ivec2 q=ivec2(floor(p));
    vec2 f=fract(p);
    vec4 a=texelFetch(reflection_tex,clamp(q,ivec2(0),s-ivec2(1)),0);
    vec4 b=texelFetch(reflection_tex,clamp(q+ivec2(1,0),ivec2(0),s-ivec2(1)),0);
    vec4 c=texelFetch(reflection_tex,clamp(q+ivec2(0,1),ivec2(0),s-ivec2(1)),0);
    vec4 d=texelFetch(reflection_tex,clamp(q+ivec2(1,1),ivec2(0),s-ivec2(1)),0);
    a.rgb*=a.a;b.rgb*=b.a;c.rgb*=c.a;d.rgb*=d.a;
    vec4 r=mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
    return vec4(r.rgb/max(r.a,0.00001),r.a);
}
vec3 world_at(vec2 uv,mat4 inv_p,mat4 inv_v){
    vec4 p=inv_v*inv_p*vec4(uv*2.0-1.0,texture(depth_tex,uv).r,1.0);
    return p.xyz/p.w;
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){water_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 p=floor(water_world.xz*24.0)/24.0;
    float w1=sin(dot(p,vec2(0.45,1.35))-clock*0.65);
    float w2=sin(dot(p,vec2(-0.92,0.64))+clock*0.42);
    float w3=sin(dot(p,vec2(0.31,2.20))-clock*0.33+w1*0.55);
    vec2 bend=vec2(w1+w2*0.3,w3*0.35)*0.0028;
    float depth=max(water_level-world_at(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y,0.0);
    vec2 refract_uv=clamp(SCREEN_UV+bend*smoothstep(0.0,1.0,depth),vec2(0.002),vec2(0.998));
    if(world_at(refract_uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y>water_level){refract_uv=SCREEN_UV;}
    vec3 bottom=texture(screen_tex,refract_uv).rgb;
    vec3 water=mix(shallow_color.rgb,deep_color.rgb,1.0-exp(-depth*0.65));
    vec3 col=mix(water,bottom*vec3(0.67,0.92,0.84),exp(-depth*4.0)*0.10);
    vec4 r=reflected(clamp(vec2(1.0-SCREEN_UV.x,SCREEN_UV.y)+bend*1.2,vec2(0.001),vec2(0.999)));
    float camera_distance=distance(water_world,INV_VIEW_MATRIX[3].xyz);
    float far_reflection=mix(1.0,0.35,smoothstep(50.0,125.0,camera_distance));
    col=mix(col,r.rgb,reflection_strength*r.a*smoothstep(0.02,0.6,depth)*far_reflection);
    col*=1.0+w1*0.04+w2*0.025;
    float bands=smoothstep(1.42,1.8,w1+w3*0.72)*smoothstep(-0.4,0.7,w2);
    vec2 cells=floor(vec2(p.x*1.5,p.y*7.0));
    float sparkle=step(0.91,hash(cells))*smoothstep(0.55,0.94,w2)*smoothstep(0.55,0.91,w1);
    float horizon=clamp(length(p)*0.004,0.0,0.36);
    col=mix(col,deep_color.rgb*1.7,horizon);
    col=mix(col,foam_color.rgb,bands*0.11+sparkle*0.18);
    float contact=(1.0-smoothstep(0.015,0.12,depth))*smoothstep(0.002,0.015,depth);
    contact*=0.14+0.12*sin(p.x*2.0+p.y*3.8+clock*0.6);
    col=mix(col,foam_color.rgb,contact);
    for(int i=0;i<8;i++){
        float dist=length(p-ripple_sources[i].xy);
        float phase=mod(clock*0.34+float(i)*0.22,1.7);
        float ring=exp(-pow((dist-phase-0.1)/0.035,2.0))*exp(-dist*1.9)*ripple_sources[i].z;
        col=mix(col,foam_color.rgb,ring*0.11);
    }
    ALBEDO=col;
    ALPHA=1.0;
}
