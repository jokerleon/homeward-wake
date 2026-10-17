extends Node3D
var rain: GPUParticles3D
var material: ParticleProcessMaterial
var sun
var environment
var baseline={}

func bind_environment(light,world_environment) -> void:
	sun=light;environment=world_environment
	if sun==null or environment==null:return
	baseline={"sun_energy":sun.light_energy,"sun_color":sun.light_color,"fog_enabled":environment.fog_enabled,"fog_density":environment.fog_density,"fog_color":environment.fog_light_color,"ambient":environment.ambient_light_energy}

func restore_lighting() -> void:
	if baseline.is_empty():return
	sun.light_energy=baseline.sun_energy;sun.light_color=baseline.sun_color
	environment.fog_enabled=baseline.fog_enabled;environment.fog_density=baseline.fog_density
	environment.fog_light_color=baseline.fog_color;environment.ambient_light_energy=baseline.ambient

func setup() -> void:
	if DisplayServer.get_name()=="headless":return
	rain=GPUParticles3D.new();rain.name="LocalRain"
	rain.amount=1500;rain.lifetime=1.8;rain.preprocess=1.8
	rain.visibility_aabb=AABB(Vector3(-45,-20,-45),Vector3(90,45,90))
	rain.local_coords=false;rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ParticleProcessMaterial.new()
	material.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents=Vector3(29,8,29)
	material.direction=Vector3(0,-1,0);material.spread=3
	material.initial_velocity_min=14;material.initial_velocity_max=18
	material.gravity=Vector3(0,-4,0);material.scale_min=0.7;material.scale_max=1.15
	rain.process_material=material
	var quad=QuadMesh.new();quad.size=Vector2(0.022,0.65)
	var paint=StandardMaterial3D.new();paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;paint.albedo_color=Color(0.75,0.83,0.81,0.25)
	paint.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	quad.material=paint;rain.draw_pass_1=quad
	add_child(rain);rain.emitting=false

func update_weather(state,center: Vector3) -> void:
	if not baseline.is_empty():
		sun.light_energy=baseline.sun_energy*(1.0-state.rainfall*0.35)
		sun.light_color=baseline.sun_color.lerp(Color("b7c8cf"),state.rainfall*0.48)
		environment.fog_enabled=baseline.fog_enabled or state.rainfall>0.02
		environment.fog_density=baseline.fog_density+state.rainfall*0.0014
		environment.fog_light_color=baseline.fog_color.lerp(Color("65888d"),state.rainfall*0.65)
		environment.ambient_light_energy=baseline.ambient*(1.0-state.rainfall*0.08)
	if rain==null:return
	position=Vector3(center.x,13,center.z)
	rain.emitting=state.rainfall>0.02;rain.amount_ratio=state.rainfall
	material.direction=Vector3(state.wind_direction.x*state.wind_strength*0.55,-1,state.wind_direction.y*state.wind_strength*0.55).normalized()
