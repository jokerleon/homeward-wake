extends SceneTree

var demo
var output=""
var elapsed=0.0
var segment=-1
var captured={}
var records=[]
const NAMES=["E","SE","S","SW","W","NW","N","NE"]
const ACTIONS=["harbor_left","harbor_right","harbor_up","harbor_down"]

func _initialize() -> void:run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate()
	demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	demo.skip_dialogue();demo.recruited=true
	demo.port.controls_enabled=true
	assert(not demo.port.demo_motion.is_empty(),"New shipmaster exploration manifest must be loaded")

func _process(_delta: float) -> bool:
	if demo==null:return false
	var dt=1.0/30.0
	elapsed+=dt
	var next=floori(elapsed/3.2)
	if next>=8:
		for action in ACTIONS:Input.action_release(action)
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"source":"Actual input actions through demo port movement; 30fps recording","directions":records},"\t"))
		quit();return false
	if next!=segment:
		segment=next;captured={}
		demo.port.actor.position=Vector3(-2,1.815,6)
		demo.companion.position=Vector3(-0.2,1.815,6.2)
		for action in ACTIONS:Input.action_release(action)
		var vector=Vector2(cos(segment*PI/4),sin(segment*PI/4))
		if vector.x>0.1:Input.action_press("harbor_right")
		if vector.x< -0.1:Input.action_press("harbor_left")
		if vector.y>0.1:Input.action_press("harbor_down")
		if vector.y< -0.1:Input.action_press("harbor_up")
	var phase=fmod(elapsed,3.2)
	if phase>=2.0:
		for action in ACTIONS:Input.action_release(action)
	var before=demo.port.actor.position
	demo._process(dt)
	if phase>=2.1:assert(demo.port.actor.position.distance_to(before)<0.00001,"Releasing input must stop movement immediately")
	if phase>=1.8 and not captured.has("move"):
		records.append({"requested":NAMES[segment],"facing":demo.port.facing,"animation":String(demo.port.hero.animation),"position":str(demo.port.actor.position)})
		capture("move")
	if phase>=3.0 and not captured.has("stop"):capture("stop")
	return false

func capture(name: String) -> void:
	captured[name]=true
	var file=NAMES[segment]+"-"+name+".png"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))
