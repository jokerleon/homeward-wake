extends "res://scripts/harbor.gd"

# v03 builds a new composed quay. v02 remains available as harbor.tscn.
var paint_materials: Dictionary = {}
var paint_tiles: Array[Texture2D] = []
var far_shores: Array[Sprite3D] = []
var far_land_material: StandardMaterial3D
var actor_surface: ShaderMaterial
var actor_face: MeshInstance3D
var static_faces: Array[MeshInstance3D] = []
var ship_model_loaded := false
var focus_point := Vector3(0.8,3.7,0.4)
var post_enabled := true
var still_mode := false
var pier_top := 1.84

func _ready() -> void:
	_prepare_paint()
	route=[Vector2(-7,8),Vector2(-3,6),Vector2(3,5.7),Vector2(7.8,5.7),Vector2(7.8,0.3),Vector2(7.8,5.7),Vector2(3,5.7),Vector2(-3,6)]
	for arg in OS.get_cmdline_user_args():
		if arg=="--stills":still_mode=true
		if arg=="--no-dof":post_enabled=false
	super._ready()
	name="ComposedQuay03"
	if automated_capture:ui_layer.visible=false
	print("QUAY_READY ",JSON.stringify({"version":"v03","generated_ship_loaded":ship_model_loaded,"source":"real Godot geometry and sprite scene","strong_postprocessing":false}))

func _prepare_paint() -> void:
	var atlas=load("res://assets/quay-v03/material-atlas.png") as Texture2D
	var source=atlas.get_image()
	if source.is_compressed():source.decompress()
	var cell=Vector2i(source.get_width()/2,source.get_height()/2)
	for y in range(2):
		for x in range(2):
			var tile=source.get_region(Rect2i(Vector2i(x,y)*cell,cell))
			tile.generate_mipmaps()
			paint_tiles.append(ImageTexture.create_from_image(tile))
	paint_materials["wood"]=_paint(Vector2(0,0),Color("b9a48a"),Vector2(3.3,3.3))
	paint_materials["deck"]=_paint(Vector2(0,0),Color("bba88d"),Vector2(3.0,1.75))
	paint_materials["deck"].set_shader_parameter("swap_uv",true)
	paint_materials["darkwood"]=_paint(Vector2(0,0),Color("766856"),Vector2(3.0,3.5))
	paint_materials["beam"]=_paint(Vector2(0,0),Color("63584c"),Vector2(2.8,3.4))
	paint_materials["beam"].set_shader_parameter("swap_uv",true)
	paint_materials["stone"]=_paint(Vector2(1,0),Color("939c9b"),Vector2(3.8,3.8))
	paint_materials["paving"]=_paint(Vector2(1,0),Color("b9b7a9"),Vector2(4.4,4.4))
	paint_materials["plaster"]=_paint(Vector2(1,1),Color("c5c0b0"),Vector2(5.0,4.0))
	paint_materials["roof"]=_paint(Vector2(0,1),Color("a5b2bb"),Vector2(3,3))
	paint_materials["trim"]=solid(Color("59483a"))
	paint_materials["metal"]=solid(Color("39434a"),0.79)
	paint_materials["recess"]=solid(Color("242b2b"))
	paint_materials["moss"]=solid(Color("4d6353"))

func _paint(cell: Vector2,tint: Color,tile: Vector2) -> ShaderMaterial:
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/quay_surface.gdshader")
	mat.set_shader_parameter("paint_texture",paint_tiles[int(cell.y)*2+int(cell.x)])
	mat.set_shader_parameter("tint",tint)
	mat.set_shader_parameter("meters_per_tile",tile)
	return mat

func _make_environment() -> void:
	super._make_environment()
	environment.ambient_light_color=Color("8bafbc")
	environment.ambient_light_energy=0.28
	environment.ssao_radius=1.1
	environment.ssao_intensity=1.35
	environment.ssao_detail=0.5
	environment.fog_density=0.0008
	environment.tonemap_mode=Environment.TONE_MAPPER_ACES
	environment.fog_light_color=Color("8eaaa9")
	environment.glow_enabled=false
	var sky=Sky.new()
	var sky_paint=ProceduralSkyMaterial.new()
	sky_paint.sky_top_color=Color("7f9caa")
	sky_paint.sky_horizon_color=Color("bdc4ad")
	sky_paint.ground_horizon_color=Color("bdc4ad")
	sky_paint.ground_bottom_color=Color("526b71")
	sky_paint.sky_curve=0.25
	sky.sky_material=sky_paint
	environment.background_mode=Environment.BG_SKY
	environment.sky=sky
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=32.0
	camera.far=380.0
	sun.directional_shadow_max_distance=115.0
	sun.light_angular_distance=1.0
	sun.shadow_blur=1.15

func coast(_x: float) -> float:
	return 15.0

func land_height(x: float,z: float) -> float:
	if x>=-22.0 and x<=1.45 and z>=-22.0 and z<=45.0:
		if z<=-8.0:return 2.80
		if x>=-3.2 and x<=1.2 and z<-3.0:return 1.80+(-z-3.0)/5.0
		return 1.80
	return -3.5

func walk_height(x: float,z: float) -> float:
	if x>=1.35 and x<=10.15 and z>=4.05 and z<=7.02:return pier_top
	if x>=7.18 and x<=8.42 and z>=-0.85 and z<4.05:return lerpf(1.84,2.70,(4.18-z)/5.03)
	return land_height(x,z)

func _make_ground() -> void:
	var seabed=box(self,Vector3(0,-4.1,0),Vector3(600,1.0,600),paint_materials["stone"])
	seabed.name="ContinuousLandAndSeabed"
	seabed.set_meta("reflection_exclude",true)
	box(self,Vector3(-10.25,0.50,11.5),Vector3(23.45,2.5,67.0),paint_materials["stone"])
	box(self,Vector3(-10.25,1.77,11.5),Vector3(23.4,0.06,67.0),paint_materials["paving"])
	var mainland=box(self,Vector3(-11.0,-0.45,-26.0),Vector3(26.0,6.5,12.0),paint_materials["stone"])
	mainland.set_meta("reflection_exclude",true)
	box(self,Vector3(-10.25,2.28,-15.0),Vector3(23.45,1.0,14.0),paint_materials["stone"])
	box(self,Vector3(-10.25,2.79,-15.0),Vector3(23.4,0.025,14.0),paint_materials["paving"])
	# Broad steps break the vertical terrace while preserving a navigable route.
	for i in range(10):
		var z=-3.25-float(i)*0.50
		var h=1.90+float(i)*0.10
		box(self,Vector3(-1.0,(h+1.8)*0.5,z),Vector3(4.4,h-1.8,0.51),paint_materials["paving"])
		box(self,Vector3(-1.0,h+0.012,z+0.20),Vector3(4.42,0.035,0.10),paint_materials["stone"])
	# Hand-laid edge courses and cap stones belong to the quay, not a uniform foam ring.
	for iz in range(55):
		var z=-21.5+float(iz)*1.22
		var cap_y=2.80 if z<-8 else 1.80
		box(self,Vector3(1.43,cap_y-0.10,z),Vector3(0.46,0.26,1.17),paint_materials["paving"])
		for course in range(3):
			var y=0.20+course*0.49
			box(self,Vector3(1.48,y,z+float(course%2)*0.25),Vector3(0.16,0.43,1.14),paint_materials["stone"])
	# Retaining-wall posts are concentrated around real level changes.
	for x in [-20.5,-16.8,-12.2,-8.5,-3.6,1.2]:
		box(self,Vector3(x,3.11,-7.94),Vector3(0.30,0.63,0.35),paint_materials["stone"])
	for pair in [[-21.4,-3.6]]:
		box(self,Vector3((pair[0]+pair[1])*0.5,3.18,-7.96),Vector3(pair[1]-pair[0],0.15,0.24),paint_materials["paving"])
	_make_far_shore()

func _make_far_shore() -> void:
	far_land_material=solid(Color("9bafb4"))
	far_land_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var inland=MeshInstance3D.new()
	inland.name="DistantMainland"
	var plane=PlaneMesh.new()
	plane.size=Vector2(1200,1100)
	inland.mesh=plane
	inland.material_override=far_land_material
	inland.position=Vector3(-20,0.24,-630)
	inland.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inland.set_meta("reflection_exclude",true)
	add_child(inland)
	var texture=load("res://assets/quay-v03/far-shore.png") as Texture2D
	for i in range(3):
		var shore=Sprite3D.new()
		shore.name="DistantShoreArtLayer"+str(i)
		shore.texture=texture
		shore.pixel_size=0.030
		shore.offset=Vector2(0,690.0-float(texture.get_height())*0.5)
		shore.position=Vector3(-85.16+float(i)*65.16,0.18,-72.0)
		shore.shaded=false
		shore.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		shore.alpha_scissor_threshold=0.55
		shore.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shore.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shore.modulate=Color("a4babd")
		add_child(shore)
		far_shores.append(shore)

func _make_water() -> void:
	super._make_water()
	var water=get_node("HarborWater") as MeshInstance3D
	(water.mesh as PlaneMesh).size=Vector2(600,600)
	water_material.shader=load("res://shaders/quay_ocean.gdshader")
	water_material.set_shader_parameter("deep_color",Color("23515a"))
	water_material.set_shader_parameter("shallow_color",Color("2b5958"))
	water_material.set_shader_parameter("foam_color",Color("a2b49b"))

func _make_pier() -> void:
	var timber=paint_materials["deck"]
	var dark=paint_materials["darkwood"]
	box(self,Vector3(5.77,1.66,5.55),Vector3(8.82,0.30,2.94),dark)
	for ix in range(25):
		var x=1.55+float(ix)*0.35
		var plank=box(self,Vector3(x,1.824,5.55),Vector3(0.332,0.07,3.00),timber)
		plank.rotation.z=sin(float(ix)*1.71)*0.004
		if ix%5==0:
			for z in [4.35,6.73]:
				box(self,Vector3(x,1.864,z),Vector3(0.045,0.014,0.047),paint_materials["metal"])
	for x in [2.0,4.7,7.3,9.7]:
		for z in [4.13,6.96]:
			cylinder_between(self,Vector3(x,-2.0,z),Vector3(x,2.30,z),0.14,dark)
			box(self,Vector3(x,2.31,z),Vector3(0.32,0.09,0.32),timber)
			_rope_ring(self,Vector3(x,2.10,z),0.19,0.035)
	# One mooring rail leaves a clear lane for the moving character.
	for i in range(3):
		_rope(self,Vector3(2.0+i*2.55,2.19,6.96),Vector3(4.55+i*2.55,2.19,6.96),0.035,0.15)
	_make_lantern(Vector3(2.0,1.84,4.13),2.4)
	_make_lantern(Vector3(9.7,1.84,6.96),2.0)
	# A physical gangway joins the pier to the near ship rail.
	var a=Vector3(7.8,1.84,4.18)
	var b=Vector3(7.8,2.70,-0.85)
	var gangway=box(self,(a+b)*0.5-Vector3(0,0.055,0),Vector3(1.24,0.11,a.distance_to(b)),timber)
	gangway.name="BoardingGangway"
	gangway.rotation.x=atan2(b.y-a.y,a.z-b.z)
	for i in range(23):
		var point=a.lerp(b,float(i)/22.0)
		var tread=box(self,point+Vector3(0,0.028,0),Vector3(1.22,0.05,0.08),dark)
		tread.rotation.x=gangway.rotation.x
	for side in [-1.0,1.0]:
		var offset=Vector3(side*0.60,0,0)
		for t in [0.0,0.5,1.0]:
			var p=a.lerp(b,t)+offset
			cylinder_between(self,p,p+Vector3(0,0.75,0),0.045,dark)
		_rope(self,a+offset+Vector3(0,0.72,0),b+offset+Vector3(0,0.72,0),0.030,0.11)

func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,uvs: Array=[]) -> void:
	var normal=(c-a).cross(b-a).normalized()
	var coords=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)] if uvs.is_empty() else uvs
	var points=[a,b,c,d]
	for index in [0,1,2,0,2,3]:
		st.set_normal(normal)
		st.set_uv(coords[index])
		st.add_vertex(points[index])

func _finish_mesh(st: SurfaceTool,parent: Node3D,mesh_name: String,mat: Material) -> MeshInstance3D:
	var mesh=MeshInstance3D.new()
	mesh.name=mesh_name
	mesh.mesh=st.commit()
	mesh.material_override=mat
	parent.add_child(mesh)
	return mesh

func _roof(parent: Node3D,base: Vector3,width: float,depth: float,rise: float,mat: Material) -> void:
	var roofmat=mat.duplicate() as ShaderMaterial
	roofmat.set_shader_parameter("use_mesh_uv",true)
	roofmat.set_shader_parameter("mesh_repeats",Vector2(width/2.7,depth/3.1))
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for iy in range(10):
			var t0=float(iy)/10.0
			var t1=float(iy+1)/10.0
			for ix in range(8):
				var u0=float(ix)/8.0
				var u1=float(ix+1)/8.0
				var a=_roof_point(base,width,depth,rise,u0,t0,side)
				var b=_roof_point(base,width,depth,rise,u1,t0,side)
				var c=_roof_point(base,width,depth,rise,u1,t1,side)
				var d=_roof_point(base,width,depth,rise,u0,t1,side)
				if side>0:_face(st,a,b,c,d,[Vector2(u0,t0),Vector2(u1,t0),Vector2(u1,t1),Vector2(u0,t1)])
				else:_face(st,b,a,d,c,[Vector2(u1,t0),Vector2(u0,t0),Vector2(u0,t1),Vector2(u1,t1)])
		for ix in range(32):
			var u=float(ix)/31.0
			var e=_roof_point(base,width,depth,rise,u,1.0,side)
			cylinder_between(parent,e+Vector3(0,0,-side*0.16),e+Vector3(0,0,side*0.15),0.075,paint_materials["trim"])
		for edge in [0.0,1.0]:
			for i in range(10):
				var a=_roof_point(base,width,depth,rise,edge,float(i)/10.0,side)
				var b=_roof_point(base,width,depth,rise,edge,float(i+1)/10.0,side)
				cylinder_between(parent,a+Vector3(0,0.06,0),b+Vector3(0,0.06,0),0.10,paint_materials["roof"])
	_finish_mesh(st,parent,"CurvedTileRoof",roofmat)
	cylinder_between(parent,base+Vector3(-width*0.50,rise+0.05,0),base+Vector3(width*0.50,rise+0.05,0),0.13,paint_materials["roof"])
	for side in [-1.0,1.0]:
		cylinder_between(parent,base+Vector3(side*width*0.46,rise+0.05,0),base+Vector3(side*width*0.55,rise+0.34,0),0.12,paint_materials["roof"])

func _roof_point(base: Vector3,width: float,depth: float,rise: float,u: float,t: float,side: float) -> Vector3:
	var lift=pow(max(t-0.72,0.0)/0.28,2.0)*0.23
	var corner=pow(abs(u-0.5)*2.0,6.0)*pow(t,3.0)*0.26
	return base+Vector3((u-0.5)*width,rise*pow(1.0-t,1.40)+lift+corner,side*t*depth*0.5)

func _make_buildings() -> void:
	_house(Vector3(-8.2,1.8,-4.0),8.4,5.6,2,0.02)
	_house(Vector3(-17.0,2.8,-13.0),7.6,5.6,1,0.12)
	_house(Vector3(-5.0,2.8,-17.3),6.3,5.0,1,-0.12)
	_house(Vector3(-6.5,1.8,18.4),6.2,6.0,1,0.0)
	# A low boundary wall ties the buildings together and directs the path.
	box(self,Vector3(-17.0,2.52,2.0),Vector3(8.0,1.45,0.28),paint_materials["plaster"])
	box(self,Vector3(-17.0,3.31,2.0),Vector3(8.25,0.18,0.52),paint_materials["roof"])
	building_blocks.append(Rect2(-21.1,1.70,8.2,0.60))
	_make_lantern(Vector3(-3.2,1.8,-0.25),2.6)
	_make_lantern(Vector3(-12.5,1.8,-0.15),2.6)

func _house(where: Vector3,width: float,depth: float,stories: int,yaw: float) -> void:
	var root=Node3D.new()
	root.name="QuayHall"
	root.position=where
	root.rotation.y=yaw
	add_child(root)
	var wall=paint_materials["plaster"]
	var wood=paint_materials["wood"]
	var beam=paint_materials["beam"]
	var plinth=paint_materials["stone"]
	var h=2.85
	var total=h*stories
	box(root,Vector3(0,0.16,0),Vector3(width+0.40,0.32,depth+0.40),plinth)
	box(root,Vector3(0,total*0.5+0.3,0),Vector3(width,total,depth),wall)
	for x in [-width*0.48,0.0,width*0.48]:
		for z in [-depth*0.50,depth*0.51]:
			box(root,Vector3(x,total*0.5+0.28,z),Vector3(0.20,total+0.12,0.24),beam)
			box(root,Vector3(x,0.43,z),Vector3(0.38,0.33,0.39),plinth)
	for level in range(stories):
		var y=0.3+level*h
		for band in [0.12,2.61]:
			box(root,Vector3(0,y+band,depth*0.52),Vector3(width+0.12,0.15,0.17),beam)
			for side in [-1.0,1.0]:
				box(root,Vector3(side*width*0.502,y+band,0),Vector3(0.18,0.15,depth+0.16),beam)
		for x in [-width*0.31,width*0.31]:
			_window(root,Vector3(x,y+1.39,depth*0.506),width*0.21,1.47,0.0)
		for side in [-1.0,1.0]:
			for z in [-depth*0.27,depth*0.27]:
				_window(root,Vector3(side*width*0.505,y+1.37,z),depth*0.26,1.43,side*PI*0.5)
	# Broad central door recess and step form the focus of the frontage.
	box(root,Vector3(0,1.37,depth*0.508),Vector3(1.72,2.14,0.07),paint_materials["recess"])
	for x in [-0.90,0.90]:box(root,Vector3(x,1.44,depth*0.54),Vector3(0.17,2.39,0.20),wood)
	box(root,Vector3(0,2.62,depth*0.54),Vector3(2.08,0.23,0.22),beam)
	for x in [-0.48,0.48]:
		box(root,Vector3(x,1.36,depth*0.524),Vector3(0.78,2.02,0.08),paint_materials["darkwood"])
		for zbar in [0.75,1.95]:
			box(root,Vector3(x,zbar,depth*0.542),Vector3(0.76,0.075,0.08),wood)
	for i in range(2):
		box(root,Vector3(0,0.10-i*0.055,depth*0.5+0.32+i*0.29),Vector3(2.68+i*0.32,0.17,0.52),plinth)
	if stories>1:
		box(root,Vector3(0,h+0.27,depth*0.5+0.58),Vector3(width+0.14,0.18,1.33),wood)
		for i in range(16):
			var x=-width*0.48+float(i)/15.0*width*0.96
			box(root,Vector3(x,h+0.86,depth*0.5+1.12),Vector3(0.075,1.06,0.08),beam)
		for y in [h+0.39,h+0.82,h+1.31]:
			box(root,Vector3(0,y,depth*0.5+1.12),Vector3(width+0.22,0.10,0.11),wood)
		for x in [-width*0.46,width*0.46]:
			box(root,Vector3(x,1.58,depth*0.5+1.02),Vector3(0.17,2.84,0.17),beam)
			cylinder_between(root,Vector3(x,2.18,depth*0.5+0.99),Vector3(x,2.98,depth*0.5+0.19),0.078,wood)
		_roof(root,Vector3(0,h+1.34,depth*0.5+0.63),width+0.85,2.45,0.48,paint_materials["roof"])
	_roof(root,Vector3(0,total+0.34,0),width+1.48,depth+1.85,1.32,paint_materials["roof"])
	# End-wall timber diagonals show structure under the roof slope.
	for side in [-1.0,1.0]:
		for z in [-depth*0.43,depth*0.43]:
			cylinder_between(root,Vector3(side*width*0.505,total+0.30,z),Vector3(side*width*0.505,total+1.33,0),0.085,beam)
	building_blocks.append(Rect2(Vector2(where.x-width*0.52,where.z-depth*0.54),Vector2(width*1.04,depth*1.08)))

func _window(parent: Node3D,where: Vector3,width: float,height: float,yaw: float) -> void:
	var root=Node3D.new()
	root.position=where
	root.rotation.y=yaw
	parent.add_child(root)
	var frame=paint_materials["wood"]
	var backing=solid(Color("55554a"))
	box(root,Vector3(0,0,0.055),Vector3(width,height,0.05),backing)
	for x in [-width*0.5,width*0.5]:box(root,Vector3(x,0,0.10),Vector3(0.11,height+0.2,0.12),paint_materials["beam"])
	for y in [-height*0.5,height*0.5]:box(root,Vector3(0,y,0.10),Vector3(width+0.19,0.11,0.13),paint_materials["beam"])
	for i in range(5):
		var x=-width*0.4+float(i)*width*0.20
		box(root,Vector3(x,0,0.11),Vector3(0.04,height,0.06),frame)
	for y in [-height*0.27,0.0,height*0.27]:
		box(root,Vector3(0,y,0.12),Vector3(width,0.04,0.055),frame)

func _make_trees_and_plants() -> void:
	var texture=load("res://assets/quay-v03/broadleaf-tree.png") as Texture2D
	var size=Vector2(texture.get_width(),texture.get_height())
	var sites=[Vector3(-18.8,8.8,-2.2),Vector3(-18.7,8.1,-19),Vector3(-1.6,7.0,-20.5),Vector3(-5.0,8.0,20.5)]
	for i in range(sites.size()):
		var p=sites[i]
		var at=Vector3(p.x,land_height(p.x,p.z)+0.015,p.z)
		var sprite=_sprite(at,texture,p.y,Vector2(size.x*0.51,size.y*0.966))
		var mat=ShaderMaterial.new()
		mat.shader=load("res://shaders/quay_foliage.gdshader")
		mat.set_shader_parameter("albedo_tex",texture)
		mat.set_shader_parameter("tree_height",p.y)
		mat.set_shader_parameter("phase",float(i)*1.71)
		mat.set_shader_parameter("tint",Color("bbc6ac") if i!=3 else Color("7b9990"))
		sprite.material_override=mat
		foliage_materials.append(mat)
		trees.append(sprite)
		tree_bases.append(at)
		_shadow(at+Vector3(0,0.015,0),Vector2(3.4,2.2),0.25)
		_planter(at+Vector3(0,0.10,0),Vector2(2.2,1.5))
	# Low vegetation is tucked into the architecture rather than scattered on the route.
	for p in [Vector3(-12.0,1.8,2.4),Vector3(-11.2,1.8,2.6),Vector3(-0.2,1.8,-5.8)]:
		var shrub=_sprite(p,texture,1.28,Vector2(size.x*0.51,size.y*0.82))
		shrub.modulate=Color("9cac87")
		shrub.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_planter(p,Vector2(1.55,0.83))

func _planter(where: Vector3,size: Vector2) -> void:
	for x in [-size.x*0.5,size.x*0.5]:
		box(self,where+Vector3(x,0.14,0),Vector3(0.13,0.28,size.y+0.15),paint_materials["stone"])
	for z in [-size.y*0.5,size.y*0.5]:
		box(self,where+Vector3(0,0.14,z),Vector3(size.x,0.28,0.13),paint_materials["stone"])
	box(self,where+Vector3(0,0.20,0),Vector3(size.x-0.15,0.06,size.y-0.12),solid(Color("39493b")))

func _make_ship() -> void:
	var path="res://assets/quay-v03/merchant-ship-a.glb"
	if ResourceLoader.exists(path):
		vessel=Node3D.new()
		vessel.name="MerchantShip"
		vessel.position=Vector3(8.2,0,-3.5)
		vessel.rotation_degrees.y=-12.0
		add_child(vessel)
		var model=load(path).instantiate()
		vessel.add_child(model)
		ship_model_loaded=true
	else:
		# Interim composition reference only. Final capture must use the actual model.
		super._make_ship()
		vessel.position=Vector3(8.2,0,-3.5)
		vessel.rotation.y=PI*0.5-0.20
		vessel.scale=Vector3.ONE*1.32
	# Mooring lines refer to the physical pier and the near ship rail.
	_rope(self,Vector3(7.3,2.13,4.13),Vector3(7.2,2.60,-0.6),0.035,0.32)
	_rope(self,Vector3(2.0,2.13,4.13),Vector3(1.8,2.6,-2.1),0.035,0.28)

func _rope_ring(parent: Node3D,where: Vector3,radius: float,thickness: float) -> void:
	var torus=TorusMesh.new()
	torus.inner_radius=radius-thickness
	torus.outer_radius=radius+thickness
	torus.rings=16
	torus.ring_segments=6
	var mesh=MeshInstance3D.new()
	mesh.mesh=torus
	mesh.material_override=solid(Color("988465"))
	mesh.position=where
	parent.add_child(mesh)

func _rope(parent: Node3D,a: Vector3,b: Vector3,radius: float,sag: float) -> void:
	var mat=solid(Color("9f8966"))
	for i in range(12):
		var t0=float(i)/12.0
		var t1=float(i+1)/12.0
		var p0=a.lerp(b,t0)-Vector3.UP*sin(t0*PI)*sag
		var p1=a.lerp(b,t1)-Vector3.UP*sin(t1*PI)*sag
		cylinder_between(parent,p0,p1,radius,mat)

func _make_harbor_details() -> void:
	var wood=paint_materials["wood"]
	var edge=paint_materials["beam"]
	for p in [Vector3(-1.0,1.8,4.1),Vector3(-0.95,1.8,3.25),Vector3(-2.0,1.8,3.55),Vector3(-12.6,1.8,-0.25)]:
		_make_crate(p,wood,edge)
	_make_crate(Vector3(-1.1,2.54,3.5),wood,edge)
	for p in [Vector3(-11.8,1.8,-0.15),Vector3(-11.9,1.8,0.65),Vector3(-10.9,1.8,0.23),Vector3(-0.1,1.8,1.8)]:
		_make_barrel(p,wood,paint_materials["metal"])
	for p in [Vector3(-1.3,1.85,7.8),Vector3(8.7,1.90,4.65)]:
		for i in range(4):_rope_ring(self,p+Vector3(0,float(i)*0.025,0),0.32+float(i)*0.06,0.027)
	# A small cloth awning belongs to the unloading yard.
	for x in [-13.0,-9.5]:
		for z in [1.8,4.2]:
			cylinder_between(self,Vector3(x,1.8,z),Vector3(x,4.7,z),0.07,edge)
	var canvas=ShaderMaterial.new()
	canvas.shader=load("res://shaders/cloth.gdshader")
	canvas.set_shader_parameter("cloth_color",Color("9b9470"))
	cloth_materials.append(canvas)
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(12):
		var u0=float(i)/12.0
		var u1=float(i+1)/12.0
		var x0=lerpf(-13.2,-9.3,u0)
		var x1=lerpf(-13.2,-9.3,u1)
		var sag0=sin(u0*PI)*0.16
		var sag1=sin(u1*PI)*0.16
		_face(st,Vector3(x0,4.75-sag0,1.6),Vector3(x1,4.75-sag1,1.6),Vector3(x1,4.40-sag1,4.4),Vector3(x0,4.40-sag0,4.4),[Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,1)])
		_face(st,Vector3(x1,4.40-sag1,4.4),Vector3(x0,4.40-sag0,4.4),Vector3(x0,4.18-sag0,4.43),Vector3(x1,4.18-sag1,4.43))
	_finish_mesh(st,self,"LoadingAwning",canvas)
	_rope(self,Vector3(-13.2,4.72,1.6),Vector3(-13.2,4.38,4.4),0.022,0.12)
	_rope(self,Vector3(-9.3,4.72,1.6),Vector3(-9.3,4.38,4.4),0.022,0.12)
	for x in [-12.6,-11.5,-10.4]:_make_crate(Vector3(x,1.8,2.7),wood,edge)
	# Vertical pilings in the foreground provide depth without covering the activity lane.
	for at in [Vector3(1.45,1.8,11.2),Vector3(1.45,1.8,-3.1)]:
		cylinder_between(self,at-Vector3(0,2.7,0),at+Vector3(0,0.58,0),0.23,paint_materials["darkwood"])
		_rope_ring(self,at+Vector3(0,0.37,0),0.25,0.04)

func _make_actor() -> void:
	super._make_actor()
	actor.position=Vector3(-7,1.815,8)
	hero.visible=false
	actor_surface=ShaderMaterial.new()
	actor_surface.shader=load("res://shaders/quay_actor.gdshader")
	actor_surface.set_shader_parameter("tint",Color("f3ecdb"))
	var quad=QuadMesh.new()
	quad.size=Vector2.ONE*288.0*hero.pixel_size
	actor_face=MeshInstance3D.new()
	actor_face.name="RetainedMotionPixelPresentation"
	actor_face.mesh=quad
	actor_face.material_override=actor_surface
	actor_face.position=Vector3(0,64.0*hero.pixel_size,0)
	actor_face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	actor.add_child(actor_face)
	hero.frame_changed.connect(_sync_actor_paint)
	hero.animation_changed.connect(_sync_actor_paint)
	_sync_actor_paint()
	hero.play("E_idle")
	_add_scale_figure(Vector3(-10.2,1.82,-0.4),"S_idle",Color("adbdc1"))
	_add_scale_figure(Vector3(-5.8,2.81,-9.2),"SE_idle",Color("c4bfb0"))

func _sync_actor_paint() -> void:
	if actor_surface==null:return
	var frame=hero.sprite_frames.get_frame_texture(hero.animation,hero.frame) as AtlasTexture
	if frame==null:return
	var atlas=frame.atlas
	var dimensions=Vector2(atlas.get_width(),atlas.get_height())
	actor_surface.set_shader_parameter("color_atlas",atlas)
	actor_surface.set_shader_parameter("atlas_region",Vector4(frame.region.position.x/dimensions.x,frame.region.position.y/dimensions.y,frame.region.size.x/dimensions.x,frame.region.size.y/dimensions.y))

func _add_scale_figure(where: Vector3,animation: String,tint: Color) -> void:
	var texture=hero.sprite_frames.get_frame_texture(animation,0) as AtlasTexture
	var mat=actor_surface.duplicate() as ShaderMaterial
	var dimensions=Vector2(texture.atlas.get_width(),texture.atlas.get_height())
	mat.set_shader_parameter("color_atlas",texture.atlas)
	mat.set_shader_parameter("atlas_region",Vector4(texture.region.position.x/dimensions.x,texture.region.position.y/dimensions.y,texture.region.size.x/dimensions.x,texture.region.size.y/dimensions.y))
	mat.set_shader_parameter("tint",tint)
	var figure=MeshInstance3D.new()
	figure.name="TemporaryScaleFigure"
	figure.mesh=actor_face.mesh
	figure.material_override=mat
	figure.position=where+Vector3(0,64.0*hero.pixel_size,0)
	figure.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(figure)
	static_faces.append(figure)
	_shadow(where+Vector3(0,0.018,0),Vector2(0.75,0.48),0.30)

func _update_billboards() -> void:
	super._update_billboards()
	if actor_face!=null:actor_face.rotation.y=atan2(camera.global_basis.z.x,camera.global_basis.z.z)
	for face in static_faces:face.rotation.y=atan2(camera.global_basis.z.x,camera.global_basis.z.z)

func _make_reflection() -> void:
	super._make_reflection()
	reflection_camera.projection=camera.projection
	reflection_camera.fov=camera.fov
	reflection_camera.far=camera.far
	water_material.set_shader_parameter("ripple_sources",PackedVector3Array([Vector3(2,4.13,1),Vector3(2,6.96,1),Vector3(4.7,4.13,0.7),Vector3(4.7,6.96,0.7),Vector3(7.3,4.13,1),Vector3(7.3,6.96,1),Vector3(9.7,4.13,0.7),Vector3(9.7,6.96,0.7)]))
	_sync_reflection()

func _sync_reflection() -> void:
	if reflection_camera==null:return
	reflection_camera.projection=camera.projection
	reflection_camera.fov=camera.fov
	super._sync_reflection()

func _set_time_of_day(evening: bool) -> void:
	dusk=evening
	var sky_paint=environment.sky.sky_material as ProceduralSkyMaterial
	sky_paint.sky_top_color=Color("1a304c") if evening else Color("7f9caa")
	sky_paint.sky_horizon_color=Color("536e82") if evening else Color("bdc4ad")
	sky_paint.ground_horizon_color=sky_paint.sky_horizon_color
	far_land_material.albedo_color=Color("334b65") if evening else Color("9bafb4")
	for shore in far_shores:shore.modulate=Color("52718a") if evening else Color("a4babd")
	if evening:
		sun.rotation_degrees=Vector3(-23,-30,0)
		sun.light_color=Color("b9cbe2")
		sun.light_energy=0.38
		environment.ambient_light_color=Color("728baf")
		environment.ambient_light_energy=0.35
		environment.fog_light_color=Color("617c91")
		water_material.set_shader_parameter("deep_color",Color("173b50"))
		water_material.set_shader_parameter("shallow_color",Color("204555"))
	else:
		sun.rotation_degrees=Vector3(-38,-42,0)
		sun.light_color=Color("ffe2b2")
		sun.light_energy=1.65
		environment.ambient_light_color=Color("8bafbc")
		environment.ambient_light_energy=0.28
		environment.fog_light_color=Color("8eaaa9")
		water_material.set_shader_parameter("deep_color",Color("23515a"))
		water_material.set_shader_parameter("shallow_color",Color("2b5958"))
	for lamp in lamps:lamp.light_energy=3.6 if evening else 0.42
	for mat in lamp_surfaces:mat.emission_energy_multiplier=2.0 if evening else 0.15
	environment.glow_enabled=false
	var attributes=camera.attributes as CameraAttributesPractical
	attributes.dof_blur_near_enabled=false
	attributes.dof_blur_far_enabled=false
	_apply_focus()

func _apply_focus() -> void:
	var a=camera.attributes as CameraAttributesPractical
	a.dof_blur_near_enabled=false
	a.dof_blur_far_enabled=post_enabled
	a.dof_blur_far_distance=65.0
	a.dof_blur_far_transition=32.0
	a.dof_blur_amount=0.025

func _set_camera(value: int) -> void:
	preset=value
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=30.0
	if value==1:
		focus_point=Vector3(0.8,3.7,0.4)
		camera.position=Vector3(14.5,14.5,35.5)
	elif value==2:
		focus_point=Vector3(4.0,3.4,2.2)
		camera.position=Vector3(12.5,12.0,29.8)
	else:
		focus_point=actor.position+Vector3(0,1.1,0)
		camera.position=actor.position+Vector3(7,6.1,17.0)
	camera.look_at(focus_point)
	camera_origin=camera.position
	_update_billboards()
	_sync_reflection()
	_apply_focus()

func _make_ui() -> void:
	super._make_ui()
	label_info.text="岸台 · 视觉试片 03\nWASD 移动   1 / 2 / 3 镜头   T 昼暮   P 远景焦外   G 漫步   Tab 隐藏文字"

func _move_actor(delta: float) -> void:
	var velocity=Vector3.ZERO
	var right=camera.global_basis.x
	right.y=0
	right=right.normalized()
	var back=camera.global_basis.z
	back.y=0
	back=back.normalized()
	if autoplay:
		var target=route[waypoint]
		var pos=Vector2(actor.position.x,actor.position.z)
		if pos.distance_to(target)<0.15:waypoint=(waypoint+1)%route.size()
		else:
			var step=(target-pos).normalized()*1.8
			velocity=Vector3(step.x,0,step.y)
	else:
		var input=Input.get_vector("harbor_left","harbor_right","harbor_up","harbor_down")
		velocity=(right*input.x+back*input.y)*2.2
	var next=actor.position+velocity*minf(delta,0.1)
	var height=walk_height(next.x,next.z)+0.015
	var blocked=height<0.45 or abs(height-actor.position.y)>0.25
	for rect in building_blocks:
		if rect.grow(0.15).has_point(Vector2(next.x,next.z)):blocked=true
	if not blocked:actor.position=Vector3(next.x,height,next.z)
	else:velocity=Vector3.ZERO
	if velocity.length()>0.05:
		# Heading is relative to camera yaw. Projected screen slopes collapse
		# diagonal directions at a low camera pitch and must not select animations.
		var index=posmod(int(round(atan2(velocity.dot(back),velocity.dot(right))/(PI/4.0))),8)
		facing=["E","SE","S","SW","W","NW","N","NE"][index]
		var clip=facing+"_move_loop"
		if hero.animation!=clip:hero.play(clip)
		hero.speed_scale=velocity.length()/1.8
	else:
		var clip=facing+"_idle"
		if hero.animation!=clip:hero.play(clip)
		hero.speed_scale=1.0
	var p=actor.position
	var on_stair=p.x>=-3.2 and p.x<=1.2 and p.z<-3 and p.z>-8
	var on_gangway=p.x>=7.18 and p.x<=8.42 and p.z<4.05
	hero_shadow.visible=not(on_stair or on_gangway)
	hero_shadow.position=p+Vector3(0,0.016,0)

func _process(delta: float) -> void:
	elapsed+=delta
	frame_count+=1
	water_material.set_shader_parameter("clock",elapsed)
	for mat in cloth_materials:mat.set_shader_parameter("clock",elapsed)
	for mat in foliage_materials:mat.set_shader_parameter("clock",elapsed)
	vessel.position.y=sin(elapsed*0.65)*0.022
	vessel.rotation.z=sin(elapsed*0.43)*0.003
	_move_actor(delta)
	if preset==3:
		camera_origin=actor.position+Vector3(7,6.1,17.0)
		camera.position=camera_origin
		camera.look_at(actor.position+Vector3(0,1.1,0))
	if review_tour:
		camera.position=camera_origin+camera.global_basis.x*sin(elapsed*0.18)*0.34
	_update_billboards()
	_sync_reflection()
	if automated_capture:
		if still_mode:
			if frame_count==40:_capture("01-quay-day.png")
			if frame_count==100:_set_camera(2)
			if frame_count==130:_capture("02-ship-and-pier.png")
			if frame_count==190:_set_time_of_day(true)
			if frame_count==225:_capture("03-quay-dusk.png")
			if frame_count==270:_set_camera(3)
			if frame_count==300:_capture("04-actor-contact.png")
			if frame_count==330:_write_report()
		else:
			if frame_count==90:_capture("01-quay-day.png")
			if frame_count==230:_capture("02-walk-to-pier.png")
			if frame_count==360:_set_camera(2)
			if frame_count==430:_capture("03-ship-and-pier.png")
			if frame_count==540:_set_time_of_day(true)
			if frame_count==625:_capture("04-dusk.png")
			if frame_count==700:_set_camera(3)
			if frame_count==760:_capture("05-contact.png")
			if frame_count==835:_set_camera(1)
			if frame_count==890:_capture("06-dusk-wide.png")
			if frame_count==900:_write_report()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_P:
		post_enabled=not post_enabled
		_apply_focus()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.fov=max(camera.fov-1.0,24.0)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.fov=min(camera.fov+1.0,42.0)
		_sync_reflection()
		return
	if event is InputEventKey and event.pressed and event.keycode==KEY_F12:
		if capture_dir.is_empty():capture_dir=ProjectSettings.globalize_path("res://../Artifacts/Harbor-v03/manual")
		DirAccess.make_dir_recursive_absolute(capture_dir)
		_capture("manual-"+str(Time.get_ticks_msec())+".png")
		return
	super._unhandled_input(event)

func _write_report() -> void:
	var report={
		"version":"v03",
		"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(),
		"source":"Actual Godot viewport, never a generated scene backdrop",
		"seconds":elapsed,
		"frame":frame_count,
		"generated_ship_loaded":ship_model_loaded,
		"camera_projection":"perspective",
		"camera_fov":camera.fov,
		"far_dof":{"enabled":post_enabled,"amount":0.025,"start":65.0,"transition":32.0},
		"near_dof":false,
		"glow":false,
		"actor_position":str(actor.position),
		"captures":captures,
		"character":"Retained MiniMax movement; runtime pixel sampling only, Library images unchanged; no per-frame volume normals yet",
		"scope":"Composed visual trial, not a combat or world-editor implementation",
		"timing_note":"Fixed-step capture records normal-speed animation, not a wall-clock FPS benchmark"
	}
	var file=FileAccess.open(capture_dir.path_join("capture-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("QUAY_REPORT ",capture_dir)
