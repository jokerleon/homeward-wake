shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.31,0.20,0.12,1.0);
uniform float bands = 7.0;
uniform sampler2D wood_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool textured = false;
uniform vec2 texture_scale = vec2(1.0,1.0);
void fragment() {
    float seam=smoothstep(0.46,0.5,abs(fract(UV.y*bands)-0.5));
    float grain=sin(UV.x*43.0+sin(UV.y*29.0)*0.8)*0.016;
    vec3 painted=texture(wood_tex,UV*texture_scale).rgb;
    ALBEDO=wood_color.rgb*(1.0-seam*0.22+grain);
    if(textured) { ALBEDO=painted*wood_color.rgb*2.2; }
    ROUGHNESS=0.9;
    SPECULAR=0.14;
}
