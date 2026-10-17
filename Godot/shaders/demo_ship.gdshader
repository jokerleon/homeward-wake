shader_type spatial;
render_mode cull_disabled;
uniform sampler2D paint_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform vec4 base_color : source_color=vec4(1.0);
uniform float clock=0.0;
uniform float wind_strength=0.35;
uniform vec3 wind_local=vec3(0.0,0.0,1.0);
uniform float wetness=0.0;
uniform float hit_flash=0.0;
void vertex(){
    vec3 pigment=textureLod(paint_texture,UV,0.0).rgb;
    float canvas=smoothstep(3.7,5.8,VERTEX.y)*smoothstep(0.50,0.76,pigment.r)*smoothstep(0.43,0.64,pigment.g);
    float flutter=sin(VERTEX.x*2.15+VERTEX.y*3.6-clock*2.3)*0.035+sin(VERTEX.y*1.1-clock*1.1)*0.045;
    VERTEX+=wind_local*canvas*flutter*wind_strength;
}
void fragment(){
    vec4 paint=texture(paint_texture,UV)*base_color;
    ALBEDO=paint.rgb*mix(1.0,0.87,wetness);
    ROUGHNESS=mix(0.96,0.52,wetness);
    SPECULAR=mix(0.08,0.24,wetness);
    EMISSION=paint.rgb*hit_flash*0.18;
}
