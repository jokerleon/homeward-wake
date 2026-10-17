shader_type spatial;
render_mode cull_disabled;

uniform sampler2D paint_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 meters_per_tile = vec2(3.0);
uniform bool use_mesh_uv = false;
uniform bool swap_uv = false;
uniform vec2 mesh_repeats = vec2(1.0);
uniform float logical_resolution = 128.0;
varying vec3 paint_position;
varying vec3 face_normal;

void vertex(){
    paint_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    face_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
    vec3 n=abs(normalize(face_normal));
    vec2 p=paint_position.xy;
    if(n.y>n.x&&n.y>n.z){p=paint_position.xz;}
    else if(n.x>n.z){p=paint_position.zy;}
    if(swap_uv){p=p.yx;}
    vec2 flow=use_mesh_uv?UV*mesh_repeats:p/meters_per_tile;
    vec2 uv=(floor(fract(flow)*logical_resolution)+0.5)/logical_resolution;
    // Each source quadrant gets its own mip chain, preventing atlas-border bleed.
    vec3 paint=textureGrad(paint_texture,uv,dFdx(flow),dFdy(flow)).rgb;
    ALBEDO=paint*tint.rgb;
    ROUGHNESS=0.95;
    SPECULAR=0.10;
}
