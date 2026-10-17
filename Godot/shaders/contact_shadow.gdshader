shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform float opacity=0.28;
void fragment(){float d=length((UV-0.5)*2.0); ALBEDO=vec3(0.05,0.075,0.06); ALPHA=(1.0-smoothstep(0.15,1.0,d))*opacity;}
