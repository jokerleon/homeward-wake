shader_type spatial;
render_mode cull_disabled;
uniform sampler2D color_atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 atlas_region=vec4(0.0,0.0,1.0,1.0);
uniform vec4 tint : source_color=vec4(1.0);
uniform float frame_resolution=144.0;
void fragment(){
    vec2 frame_uv=(floor(UV*frame_resolution)+0.5)/frame_resolution;
    vec4 paint=texture(color_atlas,atlas_region.xy+frame_uv*atlas_region.zw);
    if(paint.a<0.45){discard;}
    ALBEDO=paint.rgb*tint.rgb;
    EMISSION=paint.rgb*tint.rgb*0.10;
    ROUGHNESS=0.98;
    SPECULAR=0.07;
}
