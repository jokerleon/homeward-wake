extends SceneTree

var demo
var output=""
var records=[]

func _initialize() -> void:run.call_deferred()

func capture(name: String) -> void:
	demo.toast_label.visible=demo.toast_time>0
	demo.companion.health_root.visible=false
	demo.port._sync_reflection()
	demo._update_ui()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
	records.append({"file":name,"mode":demo.mode,"selected":demo.selected,"dialogue":demo.dialog_open,"source":"actual Godot viewport and graphical assets"})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-review-dir="):output=arg.trim_prefix("--art-review-dir=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate()
	demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo)
	demo.skip_dialogue()
	demo.set_process(false);demo.set_physics_process(false)
	demo.recruited=true;demo.fit="mount"
	demo.port.actor.position=Vector3(4.2,1.855,6.1)
	demo.companion.position=Vector3(5.6,1.855,6.1)
	demo.companion.direction="S";demo.companion.visual(demo.camera,0)
	demo.companion.health_root.visible=false
	demo.port._update_billboards();demo.port._sync_reflection()
	demo._refresh_main_action()
	await capture("00-exploration.png")
	demo.camera.position=Vector3(12.5,7.1,20.5)
	demo.camera.look_at(Vector3(4.9,2.5,6.1))
	demo.companion.visual(demo.camera,0)
	demo.port._update_billboards();demo.port._sync_reflection()
	await capture("01-character-scale-close.png")
	demo.port._set_camera(2)
	demo.show_dialogue([["阿棠","他们走不远。你肯开船，我就上炮位。"]],Callable())
	await capture("02-dialogue.png")
	demo.skip_dialogue()
	demo.growth_choice()
	await capture("03-growth-choice.png")
	demo._close_choice();demo.growth_trait="pursuit"
	demo.sea.reset("mount");demo.enter_boarding();demo.toast_time=0
	demo.boarding.update_visual(0,"")
	await capture("04-deployment.png")
	demo.select_pawn("atang")
	demo.deck_feedback.update("atang",demo.boarding.navigation.nearest(Vector3(0.75,1.7,3.3),0.5),0.1)
	demo.boarding.update_visual(0,"atang")
	await capture("05-deployment-valid.png")
	demo.deck_feedback.update("atang",Vector3(0,1.7,0.35),0.1)
	await capture("06-deployment-invalid.png")
	demo.boarding.begin();demo.select_pawn("atang")
	demo.boarding.update_visual(0,"atang")
	demo.deck_feedback.update("atang",demo.boarding.navigation.nearest(Vector3(1.2,1.7,-2.0),0.5),0.1)
	await capture("07-character-orders.png")
	demo._switch_mode("sea");demo.sea.reset("mount")
	demo._update_sea_camera(1.0);demo.sea.tick(0.1)
	demo.select_ship()
	await capture("08-naval-orders.png")
	demo.sea.ocean.configure(0.06,0.25,0.8,true)
	demo.sea.tick(0.1)
	await create_timer(1.1,true,false,true).timeout
	await capture("09-rain-calm-water.png")
	demo.sea.ocean.configure(0.5,0.9,0.0,true)
	demo.sea.tick(0.1)
	await capture("10-windy-high-water.png")
	demo.toggle_pause()
	await capture("11-pause.png")
	var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"static graphical layout and character-scale fixtures; not normal-speed gameplay proof","captures":records},"\t"))
	Engine.time_scale=1.0
	quit()
