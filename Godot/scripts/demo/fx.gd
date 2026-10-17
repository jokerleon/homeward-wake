extends Node3D
var effects=[]
var sounds={}
var stamps=[]
var naval_stamps=[]
var wind=Vector3.ZERO
var sound_times={}

func _ready() -> void:
	var sheet=load("res://assets/demo/fx-atlas.png") as Texture2D
	for row in range(2):
		for column in range(3):
			var frame=AtlasTexture.new()
			frame.atlas=sheet
			frame.region=Rect2(column*512+8,row*512+8,496,496)
			stamps.append(frame)
	var naval=load("res://assets/demo/naval-fx.png") as Texture2D
	for index in range(8):
		var tile=AtlasTexture.new();tile.atlas=naval
		tile.region=Rect2((index%4)*384+6,floori(index/4.0)*512+6,372,500)
		tile.filter_clip=true;naval_stamps.append(tile)
	for key in ["cannon","impact","splash","swing","select","success"]:
		var path="res://assets/demo/audio/"+key+".wav"
		if ResourceLoader.exists(path):sounds[key]=load(path)

func material(color: Color) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func ball(at: Vector3,radius: float,color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new()
	var mesh=SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*2.0
	mesh.radial_segments=8
	mesh.rings=4
	node.mesh=mesh
	node.material_override=material(color)
	add_child(node)
	node.global_position=at
	return node

func cannonball(at: Vector3) -> MeshInstance3D:
	# Display radius is deliberately separate from the 0.19m collision radius.
	var node=ball(at,0.29,Color("343e3c"))
	var paint=StandardMaterial3D.new();paint.albedo_color=Color("424c48")
	paint.metallic=0.45;paint.roughness=0.43
	paint.emission_enabled=true;paint.emission=Color(0.06,0.065,0.06)
	node.material_override=paint
	return node

func naval_stamp(at: Vector3,index: int,width: float,life: float,grow: float=0.0,velocity: Vector3=Vector3.ZERO,delay: float=0.0) -> Sprite3D:
	var sprite=Sprite3D.new();sprite.texture=naval_stamps[index]
	sprite.pixel_size=width/372.0;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded=false;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite);sprite.global_position=at;sprite.visible=delay<=0
	effects.append({"node":sprite,"life":life,"total":life,"velocity":velocity,"grow":grow,"gravity":0.0,"delay":delay,"alpha":1.0})
	return sprite

func flight_streak(a: Vector3,b: Vector3) -> void:
	var length=a.distance_to(b)
	var camera=get_viewport().get_camera_3d()
	if length<0.03 or camera==null:return
	var sprite=naval_stamp((a+b)*0.5,3,minf(length,2.2),0.12)
	sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	var normal=(camera.global_position-sprite.global_position).normalized()
	var tangent=(b-a).normalized()
	var up=normal.cross(tangent).normalized()
	if up.length()<0.01:up=camera.global_basis.y
	sprite.global_basis=Basis(up.cross(normal).normalized(),up,normal)
	effects.back().alpha=0.43

func wood_chips(at: Vector3,direction: Vector3) -> void:
	for index in range(8):
		var chip=MeshInstance3D.new();var shape=BoxMesh.new()
		shape.size=Vector3(0.04,0.08+0.025*(index%4),0.035)
		chip.mesh=shape;chip.material_override=material(Color("c0a077") if index%2==0 else Color("725436"))
		add_child(chip);chip.global_position=at
		var angle=index*TAU/8.0
		var velocity=Vector3(cos(angle),1.8+float(index%3)*0.4,sin(angle))*1.6+direction*0.55
		effects.append({"node":chip,"life":0.8,"total":0.8,"velocity":velocity,"grow":0.0,"gravity":6.5,"angular":Vector3(5+index,3-index,4),"alpha":1.0})

func line(a: Vector3,b: Vector3,width: float,color: Color,life: float=0.15) -> void:
	if a.distance_to(b)<0.001:return
	var node=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=width
	mesh.bottom_radius=width
	mesh.height=a.distance_to(b)
	mesh.radial_segments=6
	node.mesh=mesh
	node.material_override=material(color)
	add_child(node)
	node.global_position=(a+b)*0.5
	var y=(b-a).normalized()
	var x=y.cross(Vector3.FORWARD).normalized()
	if x.length()<0.1:x=y.cross(Vector3.RIGHT).normalized()
	node.basis=Basis(x,y,x.cross(y).normalized())
	effects.append({"node":node,"life":life,"total":life,"velocity":Vector3.ZERO,"grow":0.0,"gravity":0.0,"alpha":color.a})

func ring(at: Vector3,radius: float,color: Color,life: float=0.7) -> void:
	var node=MeshInstance3D.new()
	var mesh=TorusMesh.new()
	mesh.inner_radius=radius*0.94
	mesh.outer_radius=radius
	mesh.rings=48
	mesh.ring_segments=6
	node.mesh=mesh
	node.material_override=material(color)
	add_child(node)
	node.global_position=at
	effects.append({"node":node,"life":life,"total":life,"velocity":Vector3.ZERO,"grow":0.15,"gravity":0.0,"alpha":color.a})

func stamp(at: Vector3,index: int,width: float,life: float,grow: float=0.0,velocity: Vector3=Vector3.ZERO) -> Sprite3D:
	var sprite=Sprite3D.new()
	sprite.texture=stamps[index]
	sprite.pixel_size=width/496.0
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded=false
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	add_child(sprite)
	sprite.global_position=at
	effects.append({"node":sprite,"life":life,"total":life,"velocity":velocity,"grow":grow,"gravity":0.0})
	return sprite

func burst(at: Vector3,kind: String,direction: Vector3=Vector3.ZERO) -> void:
	if kind=="cannon":
		var flash=naval_stamp(at+direction*0.28,0,1.9,0.11)
		var camera=get_viewport().get_camera_3d()
		if camera!=null and direction!=Vector3.ZERO:flash.flip_h=direction.dot(camera.global_basis.x)<0
		for index in range(3):
			naval_stamp(at+direction*(0.2+index*0.23),1,1.0+index*0.25,1.3+index*0.22,0.72,direction*(0.8-index*0.18)+Vector3(0,0.28,0)+wind*0.55,index*0.04)
	elif kind=="splash":
		# Entry, crown, falling water and foam are separate timed painted stages.
		naval_stamp(at+Vector3(0,0.82,0),4,2.05,0.26,0.7,Vector3(0,0.6,0))
		naval_stamp(at+Vector3(0,0.93,0),5,2.5,0.53,0.45,wind*0.12,0.10)
		naval_stamp(at+Vector3(0,0.94,0),6,3.0,0.68,0.20,Vector3(0,-0.35,0)+wind*0.15,0.34)
		var foam=naval_stamp(at+Vector3(0,0.04,0),7,2.6,2.4,0.28,wind*0.015,0.06)
		foam.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		foam.rotation.x=-PI*0.5
	elif kind=="hull":
		naval_stamp(at,2,1.65,0.42,0.65,direction*0.35)
		naval_stamp(at+Vector3(0,0.15,0),1,1.5,1.05,0.55,Vector3(0,0.30,0)+wind*0.35)
		wood_chips(at,direction)
	else:stamp(at,0,0.70 if kind=="impact" else 1.0,0.22,0.35)
	play("impact" if kind=="hull" else kind)

func slash(a: Vector3,b: Vector3) -> void:
	var stroke=stamp((a+b)*0.5,5,1.2,0.15)
	var camera=get_viewport().get_camera_3d()
	if camera!=null:stroke.flip_h=(b-a).dot(camera.global_basis.x)<0

func arrow(at: Vector3,direction: Vector3) -> Node3D:
	var root=Node3D.new()
	add_child(root)
	root.global_position=at
	var shaft=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=0.012
	mesh.bottom_radius=0.012
	mesh.height=0.45
	mesh.radial_segments=6
	shaft.mesh=mesh
	shaft.material_override=material(Color("ad8d60"))
	shaft.rotation.x=PI*0.5
	root.add_child(shaft)
	var head=MeshInstance3D.new()
	var tip=CylinderMesh.new()
	tip.top_radius=0
	tip.bottom_radius=0.04
	tip.height=0.11
	tip.radial_segments=4
	head.mesh=tip
	head.material_override=material(Color("c1c0b4"))
	head.position.z=-0.25
	head.rotation.x=-PI*0.5
	root.add_child(head)
	root.look_at(at+direction.normalized())
	return root

func play(kind: String) -> void:
	if DisplayServer.get_name()=="headless":return
	if not sounds.has(kind):return
	var now=Time.get_ticks_msec()
	if now-int(sound_times.get(kind,-1000))<55:return
	sound_times[kind]=now
	var audio=AudioStreamPlayer.new()
	audio.stream=sounds[kind]
	audio.volume_db=-18 if kind=="select" else -12
	if Engine.time_scale<0.2 and kind!="select":audio.pitch_scale=0.78
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func tick(dt: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var item=effects[i]
		var step=dt
		if item.get("delay",0.0)>0:
			item.delay-=dt
			if item.delay>0:continue
			step=-item.delay;item.node.visible=true
		item.life-=step
		if item.life<=0:
			item.node.queue_free()
			effects.remove_at(i)
			continue
		item.node.position+=item.velocity*step
		item.velocity.y-=step*item.get("gravity",0.0)
		item.node.scale+=Vector3.ONE*item.grow*step
		if item.has("angular"):item.node.rotation+=item.angular*step
		var alpha=clampf(item.life/item.total,0,1)*item.get("alpha",1.0)
		if item.node is Sprite3D:item.node.modulate.a=alpha
		else:item.node.material_override.albedo_color.a=alpha

func clear() -> void:
	for item in effects:item.node.queue_free()
	effects.clear()
