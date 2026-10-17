shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D indicators : source_color,filter_linear_mipmap,repeat_disable;
void fragment(){
    vec2 uv=vec2(2.0/3.0,0.5)+clamp(UV,vec2(0.015),vec2(0.985))*vec2(1.0/3.0,0.5);
    vec4 paint=texture(indicators,uv);
    ALBEDO=mix(vec3(0.22,0.43,0.40),paint.rgb,paint.a);
    ALPHA=max(paint.a*0.92,0.045);
}
