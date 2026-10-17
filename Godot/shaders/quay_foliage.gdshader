shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform float clock=0.0;
uniform float tree_height=7.0;
uniform float phase=0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float logical_resolution=288.0;
void vertex(){
    float branch=pow(clamp(VERTEX.y/tree_height,0.0,1.0),2.0);
    VERTEX.x+=sin(clock*0.55+phase)*0.042*branch;
    VERTEX.z+=sin(clock*0.38+phase)*0.020*branch;
}
void fragment(){
    vec2 uv=(floor(UV*logical_resolution)+0.5)/logical_resolution;
    vec4 paint=textureGrad(albedo_tex,uv,dFdx(UV),dFdy(UV));
    if(paint.a<0.55){discard;}
    ALBEDO=paint.rgb*tint.rgb;
    ROUGHNESS=0.99;
    SPECULAR=0.05;
}
