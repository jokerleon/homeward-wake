extends SceneTree
const Motion=preload("res://scripts/demo/character_motion.gd")
var materials=[]
var bundle
var frame_index=0
var output="D:/Work/project/joker/chess/Artifacts/ReturnDemo/mouth-review-20261012"

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world=Node3D.new();root.add_child(world)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.0
	camera.position=Vector3(0,1.05,10);world.add_child(camera);camera.look_at(Vector3(0,1.05,0));camera.current=true
	RenderingServer.set_default_clear_color(Color("27353b"))
	bundle=Motion.bundle("hero","explore")
	for i in range(2):
		var node=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=bundle.canvas*bundle.pixel_size;node.mesh=quad
		node.position=Vector3(-1.05 if i==0 else 1.05,(bundle.pivot.y-bundle.canvas.y*0.5)*bundle.pixel_size,0)
		var material=ShaderMaterial.new();material.shader=load("res://shaders/demo_actor.gdshader")
		material.set_shader_parameter("paint_light_weight",0);material.set_shader_parameter("fill_light",1)
		node.material_override=material;world.add_child(node);materials.append(material)
	var canvas=CanvasLayer.new();root.add_child(canvas)
	var label=Label.new();label.text="左：原采样　　右：嘴部稳定\n同一套迈步原帧与播放速度";label.position=Vector2(350,24)
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",24);canvas.add_child(label)

func _process(_delta: float) -> bool:
	if bundle==null:return false
	var clip="S_move_loop"
	var count=bundle.frames.get_frame_count(clip)
	var index=frame_index%count
	var frame=bundle.frames.get_frame_texture(clip,index) as AtlasTexture
	var size=Vector2(frame.atlas.get_size())
	for i in range(2):
		materials[i].set_shader_parameter("color_atlas",frame.atlas)
		materials[i].set_shader_parameter("atlas_region",Vector4(frame.region.position.x/size.x,frame.region.position.y/size.y,frame.region.size.x/size.x,frame.region.size.y/size.y))
		if i==1:Motion.apply_mouth_stability(materials[i],bundle.metadata[clip],index)
	if frame_index==14:capture()
	frame_index+=1
	if frame_index>=count*3:quit()
	return false

func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("render-comparison.png"))
