shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float clock = 0.0;
uniform float tree_height = 7.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.94,0.98,0.95,1.0);
void vertex() {
    float branch = pow(clamp(VERTEX.y/tree_height,0.0,1.0),1.6);
    VERTEX.x += sin(clock*0.65+phase)*0.055*branch;
    VERTEX.z += cos(clock*0.47+phase)*0.025*branch;
}
void fragment() {
    vec4 paint=texture(albedo_tex,UV);
    if(paint.a < 0.53) { discard; }
    ALBEDO=paint.rgb*tint.rgb;
    ROUGHNESS=0.97;
    SPECULAR=0.08;
}
