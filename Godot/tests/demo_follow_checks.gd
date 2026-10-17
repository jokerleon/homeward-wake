extends SceneTree
var demo
var elapsed=0.0
var samples=[]
var starts=0
var stops=0
var last_clip=""
var expect_stable=false
var output="D:/Work/project/joker/chess/Local/ReturnDemo/follow-baseline.json"
var pilot=false
var captured=false

func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--style-pilot":pilot=true
		if arg=="--expect-stable":expect_stable=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true
	demo.review_dir=output.get_base_dir();root.add_child(demo)
	demo.set_process(false);demo.set_physics_process(false)
	demo.skip_dialogue();demo.recruited=true;demo.port.controls_enabled=false
	if pilot:
		var loader=preload("res://tests/motion_review_loader.gd")
		loader.port(demo.port,loader.pack("D:/Work/project/joker/chess/Assets/Characters/Working/Shipmaster/explore-move-E-style-v02/pack"))
		loader.pawn(demo.companion,loader.pack("D:/Work/project/joker/chess/Assets/Characters/Working/Atang/explore-move-E-style-v02/pack"))
	demo.port.actor.position=Vector3(-6,1.815,8)
	demo.companion.position=Vector3(-7.8,1.815,8)

func _process(_delta: float) -> bool:
	if demo==null:return false
	var dt=1.0/60.0;elapsed+=dt
	# Two sustained straight walks with real stops, on the open quay foreground.
	if elapsed<4.0 or (elapsed>=5.5 and elapsed<7.0):demo.port.actor.position.x+=2.2*dt
	demo._process(dt)
	if DisplayServer.get_name()!="headless" and elapsed>3.0 and not captured:
		captured=true;capture()
	var clip=String(demo.companion.sprite.animation)
	if clip!=last_clip:
		if clip.ends_with("_move_start"):starts+=1
		if clip.ends_with("_move_stop"):stops+=1
		last_clip=clip
	samples.append({"time":elapsed,"clip":clip,"frame":demo.companion.sprite.frame,"speed":demo.companion.velocity.length(),"gap":demo.companion.position.distance_to(demo.port.actor.position)})
	if elapsed>=9.0:
		var passed=starts<=2 and stops<=2 and demo.companion.velocity.length()<0.05
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"starts":starts,"stops":stops,"passed":passed,"samples":samples},"\t"))
		print("FOLLOW_CHECK "+JSON.stringify({"starts":starts,"stops":stops,"passed":passed}))
		quit(0 if passed or not expect_stable else 1)
	return false

func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.get_base_dir().path_join("follow-pilot.png"))
