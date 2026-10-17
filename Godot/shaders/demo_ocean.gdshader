shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture,filter_linear;
uniform sampler2D depth_tex : hint_depth_texture,filter_nearest;
uniform sampler2D reflection_tex : source_color,filter_nearest;
uniform float clock=0.0;
uniform float wave_height=0.12;
uniform float wind_strength=0.35;
uniform vec2 wind_direction=vec2(-0.916,-0.402);
uniform float rainfall=0.0;
uniform float turn_rates[2];
uniform vec4 ships[2];
uniform vec4 wake_points[48];
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
float noise(vec2 p){
    vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float paint_noise(vec2 p){
    mat2 rotate=mat2(vec2(0.80,0.60),vec2(-0.60,0.80));
    return noise(p)*0.57+noise(rotate*p*2.07+8.7)*0.28+noise(rotate*p*4.19-3.4)*0.15;
}
float swell(vec2 p){
    return wave_height*(sin(dot(p,normalize(vec2(0.78,0.63)))*6.2831853/26.0-clock*1.05)*0.58
        +sin(dot(p,normalize(vec2(-0.56,0.83)))*6.2831853/13.7-clock*1.45+1.7)*0.28
        +sin(dot(p,normalize(vec2(0.95,-0.31)))*6.2831853/8.2-clock*2.2+0.4)*0.14);
}
void vertex(){
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=swell(world.xz);
    water_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
    vec2 p=floor(water_world.xz*18.0)/18.0;
    vec2 drift=wind_direction*clock*(0.11+wind_strength*0.15);
    float broad=paint_noise(p*0.10-drift*0.18);
    float brush=paint_noise(vec2(p.x*0.42,p.y*0.67)-drift);
    vec2 grain=vec2(paint_noise(p*0.24-drift),paint_noise(p*0.27+vec2(31.7,4.0)-drift));
    vec2 slope=vec2(swell(p+vec2(0.2,0))-swell(p-vec2(0.2,0)),swell(p+vec2(0,0.2))-swell(p-vec2(0,0.2)))/0.4;
    vec2 bend=(slope*0.8+(grain-0.5)*0.45)*0.005;
    float depth=max(water_world.y-world_at(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y,0.0);
    vec2 refract_uv=clamp(SCREEN_UV+bend*smoothstep(0.0,1.0,depth),vec2(0.002),vec2(0.998));
    if(world_at(refract_uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y>water_world.y){refract_uv=SCREEN_UV;}
    vec3 bottom=texture(screen_tex,refract_uv).rgb;
    vec3 water=mix(shallow_color.rgb,deep_color.rgb,1.0-exp(-depth*0.65));
    vec3 col=mix(water,bottom*vec3(0.67,0.92,0.84),exp(-depth*4.0)*0.10);
    vec4 reflection=reflected(clamp(vec2(1.0-SCREEN_UV.x,SCREEN_UV.y)+bend*1.2,vec2(0.001),vec2(0.999)));
    float distance_to_camera=distance(water_world,INV_VIEW_MATRIX[3].xyz);
    float far_factor=mix(1.0,0.42,smoothstep(50.0,125.0,distance_to_camera));
    col=mix(col,reflection.rgb,reflection_strength*reflection.a*smoothstep(0.02,0.6,depth)*far_factor);
    col*=1.0+(broad-0.5)*0.12+(brush-0.5)*0.035+swell(p)*0.04;
    // Short irregular painted crests, with no thresholded parallel sine bands.
    float crest=smoothstep(0.62,0.80,brush)*smoothstep(0.55,0.72,paint_noise(p*0.18+drift*0.31));
    float glint=smoothstep(0.69,0.82,paint_noise(vec2(p.x*1.6,p.y*3.2)-drift*2.0))*smoothstep(0.38,0.66,broad);
    float detail=1.0-smoothstep(60.0,150.0,distance_to_camera);
    col=mix(col,foam_color.rgb,crest*(0.035+wind_strength*0.045)+glint*0.035*detail);
    float contact=(1.0-smoothstep(0.015,0.13,depth))*smoothstep(0.003,0.02,depth);
    col=mix(col,foam_color.rgb,contact*(0.08+0.13*brush));
    float wake=0.0;
    for(int j=0;j<47;j++){
        if(j==23){continue;}
        vec4 a=wake_points[j];vec4 b=wake_points[j+1];
        if(a.w<0.001||b.w<0.001||distance(p,a.xy)>10.0){continue;}
        vec2 ab=b.xy-a.xy;
        float t=clamp(dot(p-a.xy,ab)/max(dot(ab,ab),0.0001),0.0,1.0);
        float d=distance(p,a.xy+ab*t);
        float width=mix(a.z,b.z,t);float fade=mix(a.w,b.w,t);
        float fleck=paint_noise(p*1.45-drift*0.6+vec2(clock*0.13,0));
        float edge=exp(-pow((d-width*(0.68+fleck*0.38))/(0.18+fleck*0.34),2.0));
        float center=exp(-pow(d/max(width*0.63,0.1),2.0));
        float breakup=smoothstep(0.27,0.68,fleck);
        wake=max(wake,(edge*0.20*breakup+center*0.09*(0.25+breakup))*fade);
    }
    for(int j=0;j<2;j++){
        vec2 d=p-ships[j].xy;float co=cos(ships[j].z);float si=sin(ships[j].z);
        vec2 local=vec2(co*d.x-si*d.y,si*d.x+co*d.y);
        float speed=clamp(ships[j].w/5.0,0.0,1.0);
        float flow=paint_noise(vec2(local.x*1.7,local.y*2.0-clock*(1.4+speed*3.0)));
        float outside=1.0+clamp(turn_rates[j]*sign(local.x),-0.35,0.35);
        float bow_width=clamp((local.y+7.6)*0.85,0.0,2.5)*outside;
        float bow=exp(-pow((abs(local.x)-bow_width)/(0.13+speed*0.12),2.0));
        bow*=smoothstep(-7.8,-6.9,local.y)*(1.0-smoothstep(-4.8,-3.8,local.y))*speed;
        float hull_width=2.43+0.10*sin(local.y*0.4)+0.08*(flow-0.5);
        float side=exp(-pow((abs(local.x)-hull_width)/(0.12+0.13*flow),2.0));
        side*=(1.0-smoothstep(3.2,6.3,abs(local.y)))*speed*outside;
        wake=max(wake,(bow*0.32+side*0.20)*smoothstep(0.19,0.73,flow));
    }
    col=mix(col,foam_color.rgb,clamp(wake,0.0,0.36));
    // Rain is independent of swell amplitude, including rain over calm water.
    if(rainfall>0.001){
        vec2 cell=floor(p*0.75);vec2 uv=fract(p*0.75)-0.5;
        float seed=hash(cell);float phase=fract(clock*1.6+seed*5.0);
        float ring=exp(-pow((length(uv)-phase*0.42)/0.025,2.0))*(1.0-phase);
        ring*=step(1.0-rainfall*0.7,seed)*detail;
        col=mix(col,foam_color.rgb,ring*0.055*rainfall);
    }
    col*=1.0-rainfall*0.12;
    float horizon=clamp(length(p)*0.0035+rainfall*smoothstep(55.0,160.0,distance_to_camera)*0.15,0.0,0.38);
    col=mix(col,deep_color.rgb*1.6,horizon);
    ALBEDO=col;ALPHA=1.0;
}
