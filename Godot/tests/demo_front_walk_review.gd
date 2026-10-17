extends SceneTree
var demo
var elapsed=0.0
var captured={}
var output=""
var candidate=false
var records=[]

func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--candidate":candidate=true
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	demo.skip_dialogue();demo.port.controls_enabled=true
	if candidate:
		var loader=preload("res://tests/motion_review_loader.gd")
		loader.port(demo.port,loader.pack("D:/Work/project/joker/chess/Assets/Characters/Working/Shipmaster/explore-move-S-style-v03/pack","S"))
	demo.port.actor.position=Vector3(-5,1.815,3.5)
	demo.port.facing="S";demo.port.hero.play("S_idle")
	demo.companion.visible=false
	demo.port._set_camera(3)
	demo.toast("船主正面步态 · 前后迈步原速检查",5)

func _process(_delta: float) -> bool:
	if demo==null:return false
	var dt=1.0/30.0;elapsed+=dt
	if elapsed>=0.4 and elapsed<3.0:Input.action_press("harbor_down")
	else:Input.action_release("harbor_down")
	demo._process(dt)
	records.append({"time":elapsed,"clip":String(demo.port.hero.animation),"frame":demo.port.hero.frame,"position":str(demo.port.actor.position)})
	if elapsed>1.2 and not captured.has("forward-step"):capture("forward-step")
	if elapsed>1.65 and not captured.has("alternate-step"):capture("alternate-step")
	if elapsed>3.8:
		Input.action_release("harbor_down")
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"starts":demo.port.locomotion.starts,"stops":demo.port.locomotion.stops,"direction":demo.port.facing,"source":"Actual port input, camera preset3, fixed root; candidate override" if candidate else "Published runtime S clip", "samples":records},"\t"))
		quit()
	return false

func capture(name: String) -> void:
	captured[name]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
