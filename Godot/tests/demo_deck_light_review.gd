extends SceneTree
var demo
var output=""
var records=[]
var original_tints=[Color("f3ecdb"),Color("a9c6b5"),Color("c3a8a0"),Color("b6ada3")]
func _initialize() -> void:run.call_deferred()
func capture(name: String) -> void:
	demo.boarding.update_visual(0,"");demo._update_ui();demo.port._sync_reflection()
	await create_timer(0.25,true,false,true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
	records.append(name+".png")
func response(original: bool) -> void:
	for i in range(demo.boarding.pawns.size()):
		var pawn=demo.boarding.pawns[i]
		pawn.tint=original_tints[i] if original else original_tints[i].lerp(Color.WHITE,0.55)
		pawn.material.set_shader_parameter("paint_light_weight",0.48 if original else 1.0)
		pawn.material.set_shader_parameter("fill_light",0.48 if original else 0.25)
		pawn.material.set_shader_parameter("paint_midtones",1.0 if original else 0.72)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--light-review-dir="):output=arg.trim_prefix("--light-review-dir=")
	assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	for pawn in demo.boarding.pawns:pawn.sprite.pause()
	response(true);await capture("01-gameplay-before")
	response(false);await capture("02-gameplay-after")
	demo.camera.position=demo.boarding.pawns[0].position+Vector3(4,3.5,7)
	demo.camera.look_at(demo.boarding.pawns[0].position+Vector3.UP*0.85);demo.gui.visible=false
	response(true);await capture("03-close-before")
	response(false);await capture("04-close-after")
	FileAccess.open(output.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"same-pose GPU comparison; combat stand-ins only; no new art acceptance","captures":records},"\t"))
	Engine.time_scale=1.0;quit()
