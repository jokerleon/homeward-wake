shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D reflection_tex : source_color, filter_nearest;
uniform float clock = 0.0;
uniform float water_level = 0.18;
uniform float reflection_strength = 0.24;
uniform int debug_view = 0;
uniform vec4 deep_color : source_color = vec4(0.11, 0.28, 0.30, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.37, 0.55, 0.45, 1.0);
uniform vec4 foam_color : source_color = vec4(0.70, 0.78, 0.66, 1.0);
uniform vec3 ripple_sources[8];
varying vec3 world_pos;

vec4 reflection_sample(vec2 uv) {
    // A transparent SubViewport retains sky RGB outside silhouettes. Filter alpha-weighted
    // texels explicitly so that those hidden sky colors cannot draw bright contour halos.
    ivec2 size=textureSize(reflection_tex,0);
    vec2 pixel=uv*vec2(size)-0.5;
    ivec2 base=ivec2(floor(pixel));
    vec2 t=fract(pixel);
    vec4 a=texelFetch(reflection_tex,clamp(base,ivec2(0),size-ivec2(1)),0);
    vec4 b=texelFetch(reflection_tex,clamp(base+ivec2(1,0),ivec2(0),size-ivec2(1)),0);
    vec4 c=texelFetch(reflection_tex,clamp(base+ivec2(0,1),ivec2(0),size-ivec2(1)),0);
    vec4 d=texelFetch(reflection_tex,clamp(base+ivec2(1,1),ivec2(0),size-ivec2(1)),0);
    a.rgb*=a.a; b.rgb*=b.a; c.rgb*=c.a; d.rgb*=d.a;
    vec4 blended=mix(mix(a,b,t.x),mix(c,d,t.x),t.y);
    return vec4(blended.rgb/max(blended.a,0.00001),blended.a);
}

vec3 scene_world(vec2 uv, mat4 inverse_projection, mat4 inverse_view) {
    // Godot Forward+ reversed Z; the inverse projection also supports orthographic cameras.
    float depth = texture(depth_tex, uv).r;
    vec4 p = inverse_view * inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
    return p.xyz / p.w;
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = floor(world_pos.xz * 32.0) / 32.0;
    float a = sin(dot(p,vec2(0.71,1.13)) - clock*0.68);
    float b = sin(dot(p,vec2(-1.21,0.57)) + clock*0.46);
    float c = sin(dot(p,vec2(0.28,2.13)) - clock*0.31 + a*0.48);
    vec2 bend = vec2(a+b*0.42, c*0.57+b*0.35) * 0.0024;
    float depth = max(water_level - scene_world(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y, 0.0);
    vec2 refract_uv = clamp(SCREEN_UV+bend*smoothstep(0.0,0.8,depth),vec2(0.002),vec2(0.998));
    if(scene_world(refract_uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y > water_level) { refract_uv = SCREEN_UV; }
    vec3 bottom = texture(screen_tex,refract_uv).rgb;
    vec3 water = mix(shallow_color.rgb,deep_color.rgb,1.0-exp(-depth*0.52));
    vec3 col = mix(water,bottom*vec3(0.74,0.96,0.86),exp(-depth*1.00)*0.76);
    vec2 reflect_uv = vec2(1.0-SCREEN_UV.x,SCREEN_UV.y) + bend*1.35;
    vec4 reflection_pixel = reflection_sample(clamp(reflect_uv,vec2(0.001),vec2(0.999)));
    vec3 reflected = reflection_pixel.rgb;
    float fresnel = 0.72 + 0.28*pow(1.0-clamp(dot(normalize(VIEW),NORMAL),0.0,1.0),3.0);
    col = mix(col,reflected,reflection_strength*fresnel*smoothstep(0.05,0.8,depth)*reflection_pixel.a);
    col *= 1.0 + a*0.037 + b*0.021;
    float crest = smoothstep(1.58,1.80,a+c*0.83)*smoothstep(0.15,0.75,b);
    col = mix(col,foam_color.rgb,crest*0.085);
    float edge = (1.0-smoothstep(0.025,0.15,depth)) * smoothstep(0.003,0.018,depth);
    edge *= 0.25+0.18*sin(p.x*2.5+p.y*3.8+clock*0.7);
    col = mix(col,foam_color.rgb,clamp(edge,0.0,0.6));
    for(int i=0;i<8;i++) {
        vec2 offset=p-ripple_sources[i].xy;
        float dist=length(offset);
        float phase=mod(clock*0.40+float(i)*0.21,1.75);
        float ring=exp(-pow((dist-phase-0.13)/0.035,2.0))*exp(-dist*1.85)*ripple_sources[i].z;
        col=mix(col,foam_color.rgb,ring*0.16);
    }
    ALBEDO=col;
    if(debug_view==1) { ALBEDO=vec3(clamp(depth/4.0,0.0,1.0)); }
    if(debug_view==2) { ALBEDO=water; }
    if(debug_view==3) { ALBEDO=reflected; }
    ALPHA=1.0;
}
