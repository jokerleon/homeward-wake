extends SceneTree

var demo
var archer
var target
var elapsed=0.0
var output=""
var pack_root="D:/Work/project/joker/chess/Assets/Characters/Working/Atang/combat-shoot-SE-v04/pack/"
var released=false
var captures={}

func _initialize() -> void:run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate()
	demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	demo.skip_dialogue();demo.recruited=true;demo.fit="hull"
	demo.boarding.reset("pursuit",false);demo._switch_mode("deck")
	archer=demo.boarding.unit("atang");target=demo.boarding.unit("guard")
	for pawn in demo.boarding.pawns:
		pawn.visible=pawn==archer or pawn==target
		pawn.stun=999 # Isolate one authored shot while using real projectile collision.
	archer.position=Vector3(-1.15,demo.boarding.deck_height(Vector3(-1.15,0,-3.0))+0.015,-3.0)
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	var toward=demo.camera.global_basis.z;toward.y=0;toward=toward.normalized()
	target.position=archer.position+(right+toward).normalized()*2.2
	target.position.y=demo.boarding.deck_height(target.position)+0.015
	if "--close-review" in OS.get_cmdline_user_args():
		var center=(archer.position+target.position)*0.5+Vector3.UP*0.7
		demo.camera.position=center+Vector3(18,13.5,8.8)*0.45
		demo.camera.look_at(center)
	var data=JSON.parse_string(FileAccess.get_file_as_string(pack_root+"motion.json"))
	var frames=SpriteFrames.new();frames.remove_animation("default")
	archer.motion={};archer.direction="SE"
	for name in ["idle","shoot"]:
		var clip=data.clips[name].duplicate(true)
		var atlas=ImageTexture.create_from_image(Image.load_from_file(pack_root+clip.atlas))
		frames.add_animation("SE_"+name);frames.set_animation_speed("SE_"+name,24)
		frames.set_animation_loop("SE_"+name,name=="idle")
		for item in clip.rects:
			var tex=AtlasTexture.new();tex.atlas=atlas
			tex.region=Rect2(item.frame[0],item.frame[1],item.frame[2],item.frame[3])
			frames.add_frame("SE_"+name,tex)
		clip.muzzle_px=[297,110];clip.release_time=7.0/24.0
		archer.motion["SE_"+name]=clip
	archer.sprite.stop();archer.sprite.sprite_frames=frames
	archer.world_pixel_size=1.7/301.0;archer.sprite_canvas=Vector2(384,384);archer.sprite_pivot=Vector2(192,324)
	archer.surface.mesh.size=Vector2(384,384)*archer.world_pixel_size
	archer.base_height=(324-192)*archer.world_pixel_size;archer.surface.position.y=archer.base_height
	archer.tint=Color.WHITE;archer.sprite.play("SE_idle");archer._sync_frame()
	demo.boarding.active=true
	demo.toast("右前方平射候选 · 箭由 Godot 单独发射",5);demo.toast_label.visible=true

func _process(_dt: float) -> bool:
	if archer==null:return false
	var dt=1.0/30.0;elapsed+=dt
	if elapsed>=1.0 and archer.action.is_empty() and not released:demo.boarding.start_action(archer,target,false)
	if not archer.action.is_empty():
		archer.action_elapsed+=dt
		if archer.action_elapsed>=archer.release_time and not released:
			demo.boarding.resolve_action(archer);released=true
		if archer.action_elapsed>=archer.action_duration:archer.action=""
	demo.boarding.tick(dt,"")
	archer.visual(demo.camera,dt);target.visual(demo.camera,dt)
	demo.fx.tick(dt);demo.port._sync_reflection();demo._update_ui()
	if elapsed>=0.6 and not captures.has("aim"):capture("aim")
	if released and not captures.has("release"):capture("release")
	if elapsed>3.0:
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"direction":archer.direction,"release_time":archer.release_time,"independent_bolt_released":released,"source":"Review-only Working pack; not published to runtime manifest","muzzle_px":[297,110]},"\t"))
		quit()
	return false

func capture(name: String) -> void:
	captures[name]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
