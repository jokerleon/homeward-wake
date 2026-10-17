extends Node3D

var camera: Camera3D
var actor: Node3D
var hero: AnimatedSprite3D
var hero_shadow: MeshInstance3D
var vessel: Node3D
var water_material: ShaderMaterial
var cloth_materials: Array[ShaderMaterial] = []
var foliage_materials: Array[ShaderMaterial] = []
var trees: Array[Node3D] = []
var tree_bases: Array[Vector3] = []
var elapsed := 0.0
var frame_count := 0
var capture_dir := ""
var autoplay := false
var ui_layer: CanvasLayer
var label_info: Label
var preset := 1
var facing := "SE"
var moving := false
var waypoint := 0
var route := [Vector2(-8.0,-2.0), Vector2(-1.0,0.0), Vector2(3.0,3.5), Vector2(3.0,11.0), Vector2(3.0,3.5), Vector2(-1.0,0.0)]
var building_blocks: Array[Rect2] = []
var environment: Environment
var sun: DirectionalLight3D
var reflection_view: SubViewport
var reflection_camera: Camera3D
var billboards: Array[SpriteBase3D] = []
var lamps: Array[OmniLight3D] = []
var lamp_surfaces: Array[StandardMaterial3D] = []
var dusk := false
var review_tour := false
var camera_origin := Vector3.ZERO
var start_at_dusk := false
var water_debug := 0
var captures: Array[Dictionary] = []
var automated_capture := false

func coast(x: float) -> float:
	return 3.8 + sin(x*0.18)*1.9 + sin(x*0.47)*0.45 + 4.5*exp(-pow((x+13.0)/5.3,2.0))

func land_height(x: float, z: float) -> float:
	var top = 1.20 + sin(x*0.16)*0.09 + cos(z*0.15)*0.07 + max(-z-14.0,0.0)*0.10
	return lerpf(top,-3.8,smoothstep(coast(x)-0.25,coast(x)+5.2,z))

func walk_height(x: float,z: float) -> float:
	if abs(x-3.0)<1.65 and z>2.0 and z<14.0:
		return 1.26
	return land_height(x,z)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir=arg.trim_prefix("--capture-dir=")
			automated_capture=true
		if arg=="--autoplay": autoplay=true
		if arg=="--review-tour": review_tour=true
		if arg=="--dusk": start_at_dusk=true
		if arg.begins_with("--water-debug="):water_debug=int(arg.trim_prefix("--water-debug="))
	seed(87129)
	_configure_input()
	_make_environment()
	_make_ground()
	_make_water()
	_make_pier()
	_make_buildings()
	_make_trees_and_plants()
	_make_ship()
	_make_actor()
	_make_harbor_details()
	_make_ui()
	_set_camera(1)
	_make_reflection()
	_set_time_of_day(start_at_dusk)
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	print("HARBOR_READY: Godot ",Engine.get_version_info().string,"; real 3D terrain, water, structures and sprite actors")

func _configure_input() -> void:
	var bindings={"harbor_left":[KEY_A,KEY_LEFT],"harbor_right":[KEY_D,KEY_RIGHT],"harbor_up":[KEY_W,KEY_UP],"harbor_down":[KEY_S,KEY_DOWN]}
	for action in bindings:
		if InputMap.has_action(action):continue
		InputMap.add_action(action)
		for code in bindings[action]:
			var event=InputEventKey.new()
			event.physical_keycode=code
			InputMap.action_add_event(action,event)

func _make_environment() -> void:
	var world=WorldEnvironment.new()
	var env=Environment.new()
	environment=env
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("839c9b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("b5cbc6")
	env.ambient_light_energy=0.50
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled=true
	env.ssao_radius=1.1
	env.ssao_intensity=1.1
	env.ssao_detail=0.35
	env.fog_enabled=true
	env.fog_light_color=Color("9aaea5")
	env.fog_density=0.0007
	env.glow_enabled=false
	world.environment=env
	add_child(world)
	sun=DirectionalLight3D.new()
	sun.name="Daylight"
	sun.rotation_degrees=Vector3(-51,-38,0)
	sun.light_color=Color("fff1d3")
	sun.light_energy=1.15
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=90.0
	sun.light_angular_distance=2.2
	sun.shadow_blur=1.7
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.2
	camera.far=180.0
	camera.current=true
	add_child(camera)
	var attributes=CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled=false
	camera.attributes=attributes

func _make_ground() -> void:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx=101
	var nz=85
	for iz in range(nz):
		for ix in range(nx):
			var x=-40.0+float(ix)*0.8
			var z=-34.0+float(iz)*0.8
			st.set_uv(Vector2(x,z))
			st.add_vertex(Vector3(x,land_height(x,z),z))
	for iz in range(nz-1):
		for ix in range(nx-1):
			var i=iz*nx+ix
			for index in [i,i+1,i+nx,i+1,i+nx+1,i+nx]: st.add_index(index)
	st.generate_normals()
	var mesh=MeshInstance3D.new()
	mesh.name="ContinuousLandAndSeabed"
	mesh.mesh=st.commit()
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/ground_trail.gdshader")
	mat.set_shader_parameter("grass_tex",load("res://assets/environment/grass.png"))
	mat.set_shader_parameter("ground_tex",load("res://assets/environment/ground.png"))
	mesh.material_override=mat
	add_child(mesh)

func _make_water() -> void:
	var mesh=MeshInstance3D.new()
	mesh.name="HarborWater"
	mesh.layers=2
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane=PlaneMesh.new()
	plane.size=Vector2(100,100)
	plane.subdivide_width=80
	plane.subdivide_depth=80
	mesh.mesh=plane
	mesh.position=Vector3(0,0.18,10)
	water_material=ShaderMaterial.new()
	water_material.shader=load("res://shaders/water_depth.gdshader")
	water_material.set_shader_parameter("debug_view",water_debug)
	mesh.material_override=water_material
	add_child(mesh)

func solid(color: Color,roughness: float=0.92) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=roughness
	mat.metallic_specular=0.15
	return mat

func box(parent: Node3D,where: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	var m=BoxMesh.new()
	m.size=size
	n.mesh=m
	n.material_override=mat
	n.position=where
	parent.add_child(n)
	return n

func cylinder_between(parent: Node3D,a: Vector3,b: Vector3,radius: float,mat: Material) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=radius*0.92
	mesh.bottom_radius=radius
	mesh.height=a.distance_to(b)
	mesh.radial_segments=10
	n.mesh=mesh
	n.material_override=mat
	parent.add_child(n)
	n.position=(a+b)*0.5
	var y=(b-a).normalized()
	var x=y.cross(Vector3.FORWARD).normalized()
	if x.length()<0.1: x=y.cross(Vector3.RIGHT).normalized()
	var z=x.cross(y).normalized()
	n.basis=Basis(x,y,z)
	return n

func _make_pier() -> void:
	var wood=_timber(Color("b4a186"),Vector2(1.0,3.0))
	var post=solid(Color("66563e"))
	box(self,Vector3(3,1.11,7.9),Vector3(3.3,0.22,11.8),wood)
	for i in range(24):
		box(self,Vector3(3,1.245,2.15+i*0.49),Vector3(3.34,0.035,0.035),post)
	for z in [3.0,6.3,9.6,13.0]:
		for x in [1.48,4.52]:
			cylinder_between(self,Vector3(x,-1.5,z),Vector3(x,1.65,z),0.12,post)
	for x in [1.48,4.52]:
		cylinder_between(self,Vector3(x,1.55,3.0),Vector3(x,1.55,13.0),0.045,post)

func _make_buildings() -> void:
	_add_building(Vector3(-7,0,-6.8),7.8,0.0)
	_add_building(Vector3(6.8,0,-9.5),6.5,-0.14)
	_add_building(Vector3(-20,0,-17.5),5.8,0.22)

func _add_building(where: Vector3,width: float,yaw: float) -> void:
	var root=Node3D.new()
	root.name="Warehouse"
	root.position=Vector3(where.x,land_height(where.x,where.z),where.z)
	root.rotation.y=yaw
	add_child(root)
	var path="res://assets/environment/warehouse-a.glb"
	if ResourceLoader.exists(path):
		var model=load(path).instantiate()
		root.add_child(model)
		root.scale=Vector3.ONE*(width/8.0)
	else:
		# Internal block-out only, automatically replaced by the generated GLB.
		box(root,Vector3(0,2.5,0),Vector3(width,5.0,width*0.6),solid(Color("b9b399")))
	building_blocks.append(Rect2(Vector2(where.x-width*0.44,where.z-width*0.40),Vector2(width*0.88,width*0.80)))

func _shadow(where: Vector3,size: Vector2,opacity: float) -> MeshInstance3D:
	var node=MeshInstance3D.new()
	node.name="ContactShadow"
	node.set_meta("reflection_exclude",true)
	var mesh=PlaneMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.position=where
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/contact_shadow.gdshader")
	mat.set_shader_parameter("opacity",opacity)
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _sprite(where: Vector3,texture: Texture2D,height: float,pivot: Vector2,region: Rect2=Rect2()) -> Sprite3D:
	var sprite=Sprite3D.new()
	sprite.texture=texture
	var size=Vector2(texture.get_width(),texture.get_height())
	if region.size.x>0:
		sprite.region_enabled=true
		sprite.region_rect=region
		size=region.size
	sprite.pixel_size=height/size.y
	sprite.offset=Vector2(size.x*0.5-pivot.x,pivot.y-size.y*0.5)
	sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold=0.73
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded=true
	sprite.modulate=Color(0.92,0.96,0.93,1)
	sprite.position=where
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(sprite)
	billboards.append(sprite)
	return sprite

func _make_trees_and_plants() -> void:
	var places=[Vector3(-17,8.7,2.8),Vector3(-17.5,7.0,-9),Vector3(-14,7.2,-21),Vector3(-3,7.0,-19),Vector3(11,8.0,-18),Vector3(18,7.4,-11),Vector3(17,7.8,1.1),Vector3(-22,9.0,7)]
	for p in places:
		var willow=p.x in [-17.0,17.0,-3.0]
		var texture=load("res://assets/environment/waterside-willow.png" if willow else "res://assets/environment/coastal-tree-a.png")
		var size=Vector2(texture.get_width(),texture.get_height())
		var pos=Vector3(p.x,land_height(p.x,p.z)+0.03,p.z)
		var root_x=0.65 if willow else 0.53
		var tree=_sprite(pos,texture,p.y,Vector2(size.x*root_x,size.y*0.965))
		var foliage=ShaderMaterial.new()
		foliage.shader=load("res://shaders/foliage.gdshader")
		foliage.set_shader_parameter("albedo_tex",texture)
		foliage.set_shader_parameter("tree_height",p.y)
		foliage.set_shader_parameter("phase",p.x*0.72)
		foliage.set_shader_parameter("tint",Color("e3edda"))
		tree.material_override=foliage
		foliage_materials.append(foliage)
		if p.x>0:
			tree.flip_h=true
			tree.offset.x=-tree.offset.x
		trees.append(tree)
		tree_bases.append(pos)
		_shadow(pos+Vector3(0,0.013,0),Vector2(4.1,2.3),0.30)
	var atlas=load("res://assets/environment/plants.png")
	var cell=Vector2(atlas.get_width()/2.0,atlas.get_height()/2.0)
	var clumps=[Vector2(-15,-3),Vector2(-15,0),Vector2(-12,1),Vector2(-10,1.7),Vector2(-4,2.4),Vector2(0,3.4),Vector2(8,3.8),Vector2(10,3.9),Vector2(14,3.6),Vector2(16,0),Vector2(11,-9),Vector2(-1,-11),Vector2(-13,-8),Vector2(-22,-5)]
	for i in range(clumps.size()):
		var p=clumps[i]
		var kind=i%4
		var origin=Vector2(float(kind%2)*cell.x,float(kind/2)*cell.y)
		var h=[1.20,0.70,1.25,1.0][kind]
		var sprite=_sprite(Vector3(p.x,land_height(p.x,p.y)+0.015,p.y),atlas,h,Vector2(cell.x*0.5,cell.y*0.93),Rect2(origin,cell))
		sprite.flip_h=i%3==0

func _make_ship() -> void:
	vessel=Node3D.new()
	vessel.name="CoastalVessel"
	vessel.position=Vector3(7.5,0.0,9.0)
	vessel.rotation.y=-0.10
	add_child(vessel)
	var hull_mat=_timber(Color("80725b"),Vector2(2.5,1.0))
	hull_mat.set_shader_parameter("bands",9.0)
	var rail=solid(Color("4c3526"))
	var deck=_timber(Color("b5a183"),Vector2(1.0,2.5))
	var zs=[-5.3,-4.5,-3.2,-1.2,1.3,3.2,4.5,5.1]
	var ws=[0.12,0.9,1.55,1.72,1.72,1.45,1.1,0.45]
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(zs.size()):
		for k in range(13):
			var a=float(k)/12.0*PI
			st.set_uv(Vector2(float(j)/7.0,float(k)/12.0))
			st.add_vertex(Vector3(cos(a)*ws[j],1.18-sin(a)*1.75+abs(zs[j])*0.07,zs[j]))
	for j in range(7):
		for k in range(12):
			var i=j*13+k
			for index in [i,i+1,i+13,i+1,i+14,i+13]:st.add_index(index)
	st.generate_normals()
	var mesh=MeshInstance3D.new()
	mesh.mesh=st.commit()
	mesh.material_override=hull_mat
	mesh.name="CurvedHull"
	vessel.add_child(mesh)
	var deck_surface=SurfaceTool.new()
	deck_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(zs.size()):
		for side in [-1.0,1.0]:
			deck_surface.set_uv(Vector2((side+1.0)*0.5,float(j)/7.0))
			deck_surface.add_vertex(Vector3(side*ws[j]*0.95,1.20+abs(zs[j])*0.045,zs[j]))
	for j in range(7):
		var i=j*2
		for index in [i,i+1,i+2,i+1,i+3,i+2]:deck_surface.add_index(index)
	deck_surface.generate_normals()
	var deck_mesh=MeshInstance3D.new()
	deck_mesh.name="CurvedWorkingDeck"
	deck_mesh.mesh=deck_surface.commit()
	deck_mesh.material_override=deck
	vessel.add_child(deck_mesh)
	for side in [-1,1]:
		for j in range(1,7):
			var a=Vector3(side*ws[j],1.48+abs(zs[j])*0.07,zs[j])
			var b=Vector3(side*ws[j+1],1.48+abs(zs[j+1])*0.07,zs[j+1])
			cylinder_between(vessel,a,b,0.065,rail)
			cylinder_between(vessel,a-Vector3(0,0.5,0),a,0.045,rail)
	box(vessel,Vector3(0,2.02,3.1),Vector3(2.08,1.40,2.25),hull_mat)
	box(vessel,Vector3(0,2.80,3.1),Vector3(2.48,0.13,2.55),deck)
	for x in [-1.15,1.15]:
		for z in [2.45,3.3,3.95]:
			box(vessel,Vector3(x*0.91,2.13,z),Vector3(0.025,0.52,0.40),solid(Color("263a35")))
			box(vessel,Vector3(x*0.93,2.13,z),Vector3(0.045,0.045,0.43),rail)
	for x in [-0.97,0.97]:
		for z in [2.02,4.2]:box(vessel,Vector3(x,2.06,z),Vector3(0.10,1.5,0.10),rail)
	box(vessel,Vector3(0,1.99,4.24),Vector3(0.66,1.28,0.025),rail)
	box(vessel,Vector3(0,2.05,4.26),Vector3(0.49,1.03,0.027),hull_mat)
	# Stern tiller and working hatch; all remain original fictional visual geometry.
	box(vessel,Vector3(0,0.65,5.12),Vector3(0.18,1.55,0.63),hull_mat)
	box(vessel,Vector3(0,1.48,0.25),Vector3(1.20,0.22,1.5),hull_mat)
	var rope=solid(Color("807258"))
	for x in [-1.35,1.35]:
		cylinder_between(vessel,Vector3(0,6.85,-1.45),Vector3(x,1.48,-3.5),0.017,rope)
		cylinder_between(vessel,Vector3(0,5.48,2.65),Vector3(x*0.75,1.6,4.35),0.017,rope)
	_make_sail(-1.45,6.7,3.5,rail)
	_make_sail(2.65,5.3,2.6,rail)

func _make_sail(z: float,top: float,width: float,wood: Material) -> void:
	cylinder_between(vessel,Vector3(0,1.1,z),Vector3(0,top+0.45,z),0.095,wood)
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom=2.0
	for iy in range(7):
		var t=float(iy)/6.0
		var y=lerpf(bottom,top,t)
		var span=lerpf(width,width*0.62,t)
		for ix in range(7):
			var u=float(ix)/6.0
			st.set_uv(Vector2(u,t))
			st.add_vertex(Vector3((u-0.18)*span,y,z+sin(u*PI)*0.27))
		for rib in range(6):
			var u0=float(rib)/6.0
			var u1=float(rib+1)/6.0
			cylinder_between(vessel,Vector3((u0-0.18)*span,y,z+sin(u0*PI)*0.27+0.065),Vector3((u1-0.18)*span,y,z+sin(u1*PI)*0.27+0.065),0.024,wood)
	for iy in range(6):
		for ix in range(6):
			var i=iy*7+ix
			for index in [i,i+7,i+1,i+1,i+7,i+8]:st.add_index(index)
	st.generate_normals()
	var mesh=MeshInstance3D.new()
	mesh.mesh=st.commit()
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/cloth.gdshader")
	mat.set_shader_parameter("cloth_color",Color("c8b58b"))
	mesh.material_override=mat
	cloth_materials.append(mat)
	vessel.add_child(mesh)

func _make_actor() -> void:
	actor=Node3D.new()
	actor.name="ShenYanVisualRuler"
	actor.position=Vector3(-8,walk_height(-8,-2),-2)
	add_child(actor)
	hero=AnimatedSprite3D.new()
	hero.name="EightDirectionSprite"
	hero.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	hero.shaded=true
	hero.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	hero.alpha_scissor_threshold=0.45
	hero.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero.pixel_size=1.94/142.0
	hero.offset=Vector2(0,64)
	hero.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var frames=SpriteFrames.new()
	frames.remove_animation("default")
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/hero.json"))
	for direction in data.directions:
		var pack=data.directions[direction]
		for clip_name in pack.clips:
			var clip=pack.clips[clip_name]
			var name=direction+"_"+clip_name
			frames.add_animation(name)
			frames.set_animation_speed(name,clip.fps)
			frames.set_animation_loop(name,clip.loop)
			var atlas=load(clip.atlas)
			for rect in clip.rects:
				var texture=AtlasTexture.new()
				texture.atlas=atlas
				texture.region=Rect2(rect.frame[0],rect.frame[1],rect.frame[2],rect.frame[3])
				frames.add_frame(name,texture)
	hero.sprite_frames=frames
	actor.add_child(hero)
	billboards.append(hero)
	hero.play("SE_idle")
	hero_shadow=_shadow(actor.position+Vector3(0,0.02,0),Vector2(0.78,0.52),0.38)

func _make_ui() -> void:
	ui_layer=CanvasLayer.new()
	add_child(ui_layer)
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	var title=Label.new()
	title.text="栖 潮 港"
	title.position=Vector2(34,24)
	title.add_theme_font_override("font",font)
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("eee5cc"))
	title.add_theme_color_override("font_shadow_color",Color(0.03,0.07,0.06,0.7))
	title.add_theme_constant_override("shadow_offset_y",2)
	ui_layer.add_child(title)
	label_info=Label.new()
	label_info.text="架空港口 · 视觉试片\nWASD 移动   滚轮缩放   1 / 2 / 3 镜头   T 昼暮   G 漫步   Tab 隐藏文字"
	label_info.position=Vector2(36,62)
	label_info.add_theme_font_override("font",font)
	label_info.add_theme_font_size_override("font_size",14)
	label_info.add_theme_color_override("font_color",Color("ddd9c8"))
	label_info.add_theme_color_override("font_shadow_color",Color(0.03,0.05,0.04,0.85))
	label_info.add_theme_constant_override("shadow_offset_y",1)
	ui_layer.add_child(label_info)

func _update_billboards() -> void:
	# One upright orientation for the main, reflection and shadow views.
	# Automatic per-pass billboarding would turn these flat silhouettes toward each light.
	var yaw=atan2(camera.global_basis.z.x,camera.global_basis.z.z)
	for sprite in billboards: sprite.rotation.y=yaw

func _make_reflection() -> void:
	for node in find_children("*","GeometryInstance3D",true,false):
		if node.name not in ["ContinuousLandAndSeabed","HarborWater"] and not node.get_meta("reflection_exclude",false):
			node.layers=5
	reflection_view=SubViewport.new()
	reflection_view.name="WaterReflection"
	reflection_view.size=Vector2i(800,450)
	reflection_view.transparent_bg=true
	reflection_view.world_3d=get_world_3d()
	reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	reflection_view.msaa_3d=Viewport.MSAA_DISABLED
	add_child(reflection_view)
	reflection_camera=Camera3D.new()
	reflection_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	reflection_camera.cull_mask=4
	reflection_camera.near=0.1
	reflection_camera.far=180
	reflection_camera.current=true
	reflection_view.add_child(reflection_camera)
	water_material.set_shader_parameter("reflection_tex",reflection_view.get_texture())
	water_material.set_shader_parameter("ripple_sources",PackedVector3Array([
		Vector3(1.48,6.3,1.0),Vector3(4.52,6.3,0.8),Vector3(1.48,9.6,0.8),Vector3(4.52,9.6,1.0),
		Vector3(1.48,13.0,0.7),Vector3(4.52,13.0,0.8),Vector3(7.5,4.1,0.6),Vector3(7.5,14.1,0.6)]))
	_sync_reflection()

func _sync_reflection() -> void:
	if reflection_camera==null:return
	var b=camera.global_basis
	var mirror=Vector3(1,-1,1)
	# Reflection changes handedness; flip horizontal image to restore a valid camera basis.
	reflection_camera.global_basis=Basis(-b.x*mirror,b.y*mirror,b.z*mirror)
	reflection_camera.global_position=camera.global_position*mirror+Vector3(0,0.36,0)
	reflection_camera.size=camera.size
	reflection_camera.keep_aspect=camera.keep_aspect

func _make_harbor_details() -> void:
	var rock_places=[Vector4(-12.5,6.3,1.7,0.60),Vector4(-10.7,6.1,1.1,0.45),Vector4(-14.1,7.6,1.3,0.42),Vector4(-7.7,4.6,0.9,0.42),Vector4(-5.6,4.2,0.65,0.32),Vector4(-3.0,4.8,1.0,0.30),Vector4(11.5,6.5,1.6,0.55),Vector4(13.1,6.1,1.0,0.46),Vector4(15.0,4.8,1.5,0.44),Vector4(16.3,3.9,0.75,0.40),Vector4(-14.0,0.7,0.85,0.48)]
	for i in range(rock_places.size()):
		var p=rock_places[i]
		_make_rock(Vector3(p.x,max(land_height(p.x,p.y),-0.25),p.y),Vector3(p.z,p.w,p.z*0.73),i)
	var timber=_timber(Color("a2957d"),Vector2.ONE)
	var beam=solid(Color("443b2f"))
	var stone=solid(Color("7e8274"))
	for i in range(3):
		box(self,Vector3(-7,1.06+float(i)*0.08,-3.0-float(i)*0.27),Vector3(4.4,0.17,0.6),stone)
	# Small landing and a cargo corner leave the central pier lane clear.
	box(self,Vector3(0.5,1.10,3.3),Vector3(2.5,0.22,2.2),timber)
	for z in [2.5,4.1]:cylinder_between(self,Vector3(-0.7,-0.8,z),Vector3(-0.7,1.52,z),0.12,beam)
	for p in [Vector3(-0.2,1.25,2.7),Vector3(-0.1,1.25,3.6),Vector3(-2.0,land_height(-2,1),1)]:
		_make_crate(p,timber,beam)
	for p in [Vector3(-3.0,land_height(-3,0.3),0.3),Vector3(-3.6,land_height(-3.6,0.1),0.1),Vector3(4.0,1.25,4.6)]:
		_make_barrel(p,timber,beam)
	_make_lantern(Vector3(1.48,1.26,3.1),2.1)
	_make_lantern(Vector3(4.52,1.26,12.8),1.9)
	_make_lantern(Vector3(-4.1,land_height(-4.1,-2.9),-2.9),2.4)
	_make_lantern(Vector3(6.1,land_height(6.1,-5.9),-5.9),2.2)
	# A canvas cover and a few crates give the warehouse frontage a readable purpose.
	for x in [-3.3,-0.7]:
		for z in [-4.5,-2.6]:cylinder_between(self,Vector3(x,1.2,z),Vector3(x,3.5,z),0.065,beam)
	var canopy=box(self,Vector3(-2,3.5,-3.5),Vector3(2.95,0.09,2.2),solid(Color("887551")))
	canopy.rotation.z=-0.045
	_make_crate(Vector3(-2.7,land_height(-2.7,-3.7),-3.7),timber,beam)
	_make_crate(Vector3(-1.6,land_height(-1.6,-4),-4),timber,beam)

func _make_rock(where: Vector3,extent: Vector3,variant: int) -> void:
	var sphere=SphereMesh.new()
	sphere.radial_segments=12
	sphere.rings=6
	sphere.radius=1.0
	sphere.height=2.0
	var arr=sphere.get_mesh_arrays()
	var points: PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
	for i in range(points.size()):
		var v=points[i]
		var dent=1.0+sin(v.x*4.3+float(variant))*cos(v.z*3.1)*0.13
		v*=dent
		v.y=max(v.y,-0.4)
		points[i]=v
	arr[Mesh.ARRAY_VERTEX]=points
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	var n=MeshInstance3D.new()
	n.name="ShoreRock"
	n.mesh=mesh
	n.position=where
	n.scale=extent
	n.rotation.y=float(variant)*0.77
	var material=ShaderMaterial.new()
	material.shader=load("res://shaders/stone.gdshader")
	material.set_shader_parameter("stone_tex",load("res://assets/environment/ground.png"))
	n.material_override=material
	add_child(n)

func _timber(tint: Color,scale_uv: Vector2) -> ShaderMaterial:
	var material=ShaderMaterial.new()
	material.shader=load("res://shaders/wood.gdshader")
	material.set_shader_parameter("wood_color",tint)
	material.set_shader_parameter("wood_tex",load("res://assets/environment/weathered-timber.png"))
	material.set_shader_parameter("textured",true)
	material.set_shader_parameter("texture_scale",scale_uv)
	return material

func _make_crate(where: Vector3,wood: Material,edge: Material) -> void:
	var root=Node3D.new()
	add_child(root)
	root.position=where
	box(root,Vector3(0,0.37,0),Vector3(0.78,0.74,0.73),wood)
	building_blocks.append(Rect2(Vector2(where.x-0.37,where.z-0.35),Vector2(0.74,0.70)))
	for y in [0.12,0.63]:
		for z in [-0.38,0.38]:box(root,Vector3(0,y,z),Vector3(0.87,0.09,0.055),edge)
	for x in [-0.36,0.36]:box(root,Vector3(x,0.765,0),Vector3(0.075,0.04,0.77),edge)

func _make_barrel(where: Vector3,wood: Material,edge: Material) -> void:
	var n=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=0.27
	mesh.bottom_radius=0.29
	mesh.height=0.77
	mesh.radial_segments=12
	n.mesh=mesh
	n.material_override=wood
	n.position=where+Vector3(0,0.385,0)
	add_child(n)
	building_blocks.append(Rect2(Vector2(where.x-0.27,where.z-0.27),Vector2(0.54,0.54)))
	for h in [0.14,0.61]:
		var hoop=MeshInstance3D.new()
		var torus=TorusMesh.new()
		torus.inner_radius=0.268
		torus.outer_radius=0.30
		torus.rings=16
		torus.ring_segments=6
		hoop.mesh=torus
		hoop.material_override=edge
		hoop.position=where+Vector3(0,h,0)
		add_child(hoop)

func _make_lantern(where: Vector3,height: float) -> void:
	var root=Node3D.new()
	root.name="PierLantern"
	root.position=where
	add_child(root)
	var wood=solid(Color("4e3c29"))
	cylinder_between(root,Vector3.ZERO,Vector3(0,height+0.18,0),0.065,wood)
	cylinder_between(root,Vector3(0,height+0.12,0),Vector3(0.48,height+0.12,0),0.045,wood)
	var paper=solid(Color("d6b976"))
	paper.emission_enabled=true
	paper.emission=Color("ffbf59")
	lamp_surfaces.append(paper)
	box(root,Vector3(0.40,height-0.30,0),Vector3(0.32,0.52,0.30),paper)
	for y in [height-0.58,height-0.02]:box(root,Vector3(0.40,y,0),Vector3(0.40,0.06,0.36),wood)
	for x in [0.245,0.555]:
		for z in [-0.147,0.147]:box(root,Vector3(x,height-0.30,z),Vector3(0.026,0.50,0.026),wood)
	var light=OmniLight3D.new()
	light.position=where+Vector3(0.4,height-0.40,0.12)
	light.light_color=Color("ffbb68")
	light.omni_range=5.8
	light.omni_attenuation=1.65
	light.shadow_enabled=true
	light.shadow_bias=0.07
	add_child(light)
	lamps.append(light)

func _set_time_of_day(evening: bool) -> void:
	dusk=evening
	if evening:
		environment.ambient_light_color=Color("879fb9")
		environment.ambient_light_energy=0.57
		environment.background_color=Color("6c8292")
		environment.fog_light_color=Color("708793")
		sun.light_color=Color("c5d5e8")
		sun.light_energy=0.32
		sun.rotation_degrees=Vector3(-28,-38,0)
		water_material.set_shader_parameter("deep_color",Color("233e4d"))
		water_material.set_shader_parameter("shallow_color",Color("516f72"))
		water_material.set_shader_parameter("foam_color",Color("859da5"))
	else:
		environment.ambient_light_color=Color("b3c7c6")
		environment.ambient_light_energy=0.50
		environment.background_color=Color("839c9b")
		environment.fog_light_color=Color("9aaea5")
		sun.light_color=Color("fff0d2")
		sun.light_energy=1.15
		sun.rotation_degrees=Vector3(-51,-38,0)
		water_material.set_shader_parameter("deep_color",Color("214b55"))
		water_material.set_shader_parameter("shallow_color",Color("799e81"))
		water_material.set_shader_parameter("foam_color",Color("b9c9b2"))
	for light in lamps:light.light_energy=2.8 if evening else 0.0
	for mat in lamp_surfaces:mat.emission_energy_multiplier=2.1 if evening else 0.04

func _set_camera(value: int) -> void:
	preset=value
	if value==1:
		camera.position=Vector3(21,23,35)
		camera.size=27.0
		camera.look_at(Vector3(-2,1,0.5))
	elif value==2:
		camera.position=Vector3(18,14,27)
		camera.size=18.5
		camera.look_at(Vector3(2,1.2,5))
	else:
		camera.position=actor.position+Vector3(10,8,14)
		camera.size=9.0
		camera.look_at(actor.position+Vector3(0,0.9,0))
	camera_origin=camera.position
	_update_billboards()

func _process(delta: float) -> void:
	elapsed+=delta
	frame_count+=1
	water_material.set_shader_parameter("clock",elapsed)
	for mat in cloth_materials: mat.set_shader_parameter("clock",elapsed)
	for mat in foliage_materials:mat.set_shader_parameter("clock",elapsed)
	vessel.position.y=sin(elapsed*0.7)*0.035
	vessel.rotation.z=sin(elapsed*0.51)*0.008
	_move_actor(delta)
	if preset==3:
		camera_origin=actor.position+Vector3(10,8,14)
		camera.position=camera_origin
	if review_tour:
		camera.position=camera_origin+camera.global_basis.x*sin(elapsed*0.22)*0.70
	_sync_reflection()
	if automated_capture and not capture_dir.is_empty():
		if review_tour:
			if frame_count==120:_capture("01-harbor.png")
			if frame_count==235:_capture("02-motion.png")
			if frame_count==240:_set_camera(2)
			if frame_count==330:_capture("03-shore-and-ship.png")
			if frame_count==480:_set_time_of_day(true)
			if frame_count==590:_capture("04-dusk-water.png")
			if frame_count==650:_set_camera(3)
			if frame_count==740:_capture("05-actor-light.png")
			if frame_count==830:_set_camera(1)
			if frame_count==860:_capture("06-dusk-harbor.png")
			if frame_count==900:_write_report()
		else:
			if frame_count==50:_capture("01-harbor.png")
			if frame_count==130:_capture("02-motion.png")
			if frame_count==220:_set_camera(2)
			if frame_count==250:_capture("03-shore-and-ship.png")
			if frame_count==320:_set_time_of_day(true)
			if frame_count==370:_capture("04-dusk-water.png")
			if frame_count==430:_set_camera(3)
			if frame_count==470:_capture("05-actor-light.png")
			if frame_count==500:_write_report()

func _move_actor(delta: float) -> void:
	var velocity=Vector3.ZERO
	if autoplay:
		var target=route[waypoint]
		var v=Vector2(actor.position.x,actor.position.z)
		if v.distance_to(target)<0.18: waypoint=(waypoint+1)%route.size()
		else:
			var step=(target-v).normalized()*1.8
			velocity=Vector3(step.x,0,step.y)
	else:
		var input=Input.get_vector("harbor_left","harbor_right","harbor_up","harbor_down")
		if input.length()>0:
			input=input.normalized()
			var right=camera.global_basis.x;right.y=0;right=right.normalized()
			var back=camera.global_basis.z;back.y=0;back=back.normalized()
			velocity=(right*input.x+back*input.y)*2.2
	var next=actor.position+velocity*delta
	var blocked=walk_height(next.x,next.z)<0.45
	for rect in building_blocks:
		if rect.grow(0.15).has_point(Vector2(next.x,next.z)):blocked=true
	if not blocked:
		actor.position=Vector3(next.x,walk_height(next.x,next.z)+0.015,next.z)
	else:velocity=Vector3.ZERO
	if velocity.length()>0.05:
		var origin=camera.unproject_position(actor.global_position)
		var screen=camera.unproject_position(actor.global_position+velocity)-origin
		var index=posmod(int(round(atan2(screen.y,screen.x)/(PI/4.0))),8)
		facing=["E","SE","S","SW","W","NW","N","NE"][index]
		var name=facing+"_move_loop"
		if hero.animation!=name:hero.play(name)
		hero.speed_scale=velocity.length()/1.8
	else:
		var name=facing+"_idle"
		if hero.animation!=name:hero.play(name)
		hero.speed_scale=1.0
	hero_shadow.position=actor.position+Vector3(0,0.016,0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT]:autoplay=false
		if event.keycode==KEY_1:_set_camera(1)
		if event.keycode==KEY_2:_set_camera(2)
		if event.keycode==KEY_3:_set_camera(3)
		if event.keycode==KEY_T:_set_time_of_day(not dusk)
		if event.keycode==KEY_G:autoplay=not autoplay
		if event.keycode==KEY_TAB:ui_layer.visible=not ui_layer.visible
		if event.keycode==KEY_F12:
			if capture_dir.is_empty():capture_dir=ProjectSettings.globalize_path("res://../Artifacts/Harbor-v02/manual")
			DirAccess.make_dir_recursive_absolute(capture_dir)
			_capture("manual-"+str(Time.get_ticks_msec())+".png")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=max(camera.size-1.0,7.0)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=min(camera.size+1.0,34.0)

func _capture(filename: String) -> void:
	var record={"file":filename,"request_frame":frame_count,"simulation_seconds":elapsed,"camera":preset,"dusk":dusk,"actor_position":str(actor.position)}
	await RenderingServer.frame_post_draw
	var image=get_viewport().get_texture().get_image()
	var path=capture_dir.path_join(filename)
	image.save_png(path)
	captures.append(record)
	if filename=="01-harbor.png" and water_debug==3:
		reflection_view.get_texture().get_image().save_png(capture_dir.path_join("reflection-buffer.png"))
	print("GODOT_CAPTURE ",path)

func _write_report() -> void:
	var report={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"source":"Godot viewport, not a generated scene image","frame":frame_count,"seconds":elapsed,"window_size":str(get_viewport().get_visible_rect().size),"actor_position":str(actor.position),"asset_house_loaded":ResourceLoader.exists("res://assets/environment/warehouse-a.glb"),"motion":"Depth-aware water and scene reflection, anchored foliage, cloth, boat bob, eight-direction sprite frames","review_tour":review_tour,"captures":captures,"timing_note":"Captures/movie use a fixed simulation timestep. They do not constitute a wall-clock FPS benchmark.","scope":"visual prototype; no combat, shipping gameplay, or general world editor"}
	var file=FileAccess.open(capture_dir.path_join("capture-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
