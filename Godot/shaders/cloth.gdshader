shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth_color : source_color = vec4(0.79,0.70,0.51,1.0);
uniform float clock = 0.0;
void vertex() { VERTEX.z += sin(UV.y*3.0+clock*0.7)*sin(UV.x*3.14159)*0.09; }
void fragment() {
    float panel = floor(UV.y*6.0);
    float tone = sin(panel*2.7)*0.065 + sin(UV.x*9.0+UV.y*12.0)*0.018;
    float seam = smoothstep(0.43,0.50,abs(fract(UV.y*6.0)-0.5));
    float edge = 1.0-smoothstep(0.015,0.05,min(UV.x,1.0-UV.x));
    float fold = pow(abs(sin(UV.x*9.4248+UV.y*0.4)),5.0)*0.055;
    ALBEDO=cloth_color.rgb*(1.0+tone-seam*0.19-edge*0.22-fold);
    ROUGHNESS=0.98;
    SPECULAR=0.08;
}
