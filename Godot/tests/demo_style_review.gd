extends SceneTree
var demo
var output="D:/Work/project/joker/chess/Artifacts/ReturnDemo/style-reset-20261011-v2"
var figures=[]

func _initialize() -> void:run.call_deferred()
func figure(path: String,point: Vector3,label_text: String) -> void:
	var image=Image.load_from_file(path)
	# Generated alpha contains almost invisible distant specks. Measure the
	# same alpha threshold used by the shader, not all nonzero alpha pixels.
	image.convert(Image.FORMAT_RGBA8)
	var pixels=image.get_data();var width=image.get_width()
	var low=Vector2i(image.get_size());var high=Vector2i.ZERO
	for index in range(width*image.get_height()):
		if pixels[index*4+3]>=115:
			var pixel=Vector2i(index%width,index/width)
			low=low.min(pixel);high=high.max(pixel)
	var bounds=Rect2i(low,high-low+Vector2i.ONE)
	var px=1.74/float(bounds.size.y)
	var node=MeshInstance3D.new();var mesh=QuadMesh.new();mesh.size=Vector2(image.get_size())*px;node.mesh=mesh
	var material=ShaderMaterial.new();material.shader=load("res://shaders/demo_actor.gdshader")
	material.set_shader_parameter("color_atlas",ImageTexture.create_from_image(image));node.material_override=material
	node.position=point+Vector3((image.get_width()*0.5-bounds.get_center().x)*px,(bounds.end.y-image.get_height()*0.5)*px,0)
	node.rotation.y=atan2(demo.camera.global_basis.z.x,demo.camera.global_basis.z.z)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	demo.add_child(node);figures.append(node)
	var label=Label3D.new();label.text=label_text;label.font=demo.font;label.font_size=32;label.pixel_size=0.006
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=point+Vector3.UP*2.0;label.outline_size=6
	demo.add_child(label);figures.append(label)

func capture(file: String) -> void:
	demo.port._sync_reflection()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.skip_dialogue()
	demo.port.actor.visible=false;demo.companion.visible=false;demo.gui.visible=false
	var center=Vector3(3.5,1.855,6.0)
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	var paths=["Assets/Characters/Library/ShenYan/fullset-v01/E/frames/idle/0000.png","Assets/Characters/Working/Shipmaster/shenyan-style-E-v01/source.png","Assets/Characters/Working/Atang/shenyan-style-E-v01/source.png"]
	var names=["旧沈砚 · 风格参照","船主 · 新候选","阿棠 · 新候选"]
	for i in range(3):figure("D:/Work/project/joker/chess/"+paths[i],center+right*(i-1)*2.0,names[i])
	await capture("01-gameplay-scale.png")
	demo.camera.position=center+Vector3(4.2,4.2,10.2);demo.camera.look_at(center+Vector3.UP*0.8)
	for node in figures:
		if node is MeshInstance3D:node.rotation.y=atan2(demo.camera.global_basis.z.x,demo.camera.global_basis.z.z)
	await capture("02-close-comparison.png")
	quit()
