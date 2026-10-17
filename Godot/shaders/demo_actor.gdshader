shader_type spatial;
render_mode cull_disabled;
uniform sampler2D color_atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 atlas_region=vec4(0.0,0.0,1.0,1.0);
uniform vec4 tint : source_color=vec4(1.0);
uniform float frame_resolution=144.0;
uniform float frame_aspect=1.0;
uniform bool flip_x=false;
uniform float paint_light_weight=1.0;
uniform float fill_light=0.10;
uniform float paint_midtones=1.0;
uniform bool stable_mouth_enabled=false;
uniform sampler2D stable_mouth_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 stable_mouth_source=vec4(0.0);
uniform vec4 stable_mouth_target=vec4(0.0);
void fragment(){
    vec2 grid=vec2(frame_resolution*frame_aspect,frame_resolution);
    vec2 uv=(floor(UV*grid)+0.5)/grid;
    if(flip_x){uv.x=1.0-uv.x;}
    vec4 paint=texture(color_atlas,atlas_region.xy+uv*atlas_region.zw);
    if(paint.a<0.45){discard;}
    if(stable_mouth_enabled){
        // Preserve every body frame and its ground pivot. The small closed-mouth
        // reference moves with the head, avoiding a thin lip line blinking as
        // it crosses the body's coarse sampling grid.
        vec2 face_uv=UV;
        if(flip_x){face_uv.x=1.0-face_uv.x;}
        vec2 local=(face_uv-stable_mouth_target.xy)/max(stable_mouth_target.zw,vec2(0.00001));
        if(all(greaterThanEqual(local,vec2(0.0)))&&all(lessThanEqual(local,vec2(1.0)))){
            vec2 edge=smoothstep(vec2(0.0),vec2(0.12,0.17),local)*smoothstep(vec2(0.0),vec2(0.12,0.17),vec2(1.0)-local);
            vec3 closed=texture(stable_mouth_texture,stable_mouth_source.xy+local*stable_mouth_source.zw).rgb;
            paint.rgb=mix(paint.rgb,closed,edge.x*edge.y);
        }
    }
    // Use the retained v03/ShenYan material response. A large emission term
    // detached the newer sprites from the harbor's actual light and shadows.
    paint.rgb=pow(max(paint.rgb,vec3(0.0)),vec3(paint_midtones));
    ALBEDO=paint.rgb*tint.rgb*paint_light_weight;
    EMISSION=paint.rgb*tint.rgb*fill_light;
    ROUGHNESS=0.98;
    SPECULAR=0.07;
}
