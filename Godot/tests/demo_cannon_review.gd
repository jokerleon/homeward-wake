extends SceneTree

var demo
var output=""
var elapsed=0.0
var scenario=-1
var launched=false
var captured={}
var records=[]
var failures=0
var impact_time=-1.0
var splash_time=-1.0
const NAMES=["direct-hit","hull-graze","water-first"]

func _initialize() -> void:run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate()
	demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo)
	demo.set_process(false);demo.set_physics_process(false)
	demo.skip_dialogue();demo.recruited=true;demo.fit="hull"
	demo._switch_mode("sea")
	demo.camera.position=Vector3(-25,24,32)
	demo.camera.look_at(Vector3(-5,2,0));demo.camera.size=36
	begin_case()

func begin_case() -> void:
	scenario+=1;elapsed=0;launched=false;captured={};impact_time=-1;splash_time=-1
	demo.fx.clear();demo.sea.reset("hull")
	demo.sea.ocean.configure(0,0.25,0,true)
	for ship in demo.sea.ships:
		ship.node.position=Vector3(-22,0,0) if ship.team==0 else Vector3.ZERO
		ship.previous=ship.node.position;ship.yaw=0;ship.node.rotation=Vector3.ZERO
		ship.velocity=Vector3.ZERO
	demo.toast(NAMES[scenario],4)
	demo.toast_label.visible=true

func _process(_delta: float) -> bool:
	if demo==null:return false
	var dt=1.0/30.0
	elapsed+=dt
	demo.sea.ocean.tick(dt);demo.sea.ocean.apply(demo.sea.water_material)
	if not launched and elapsed>=0.5:
		var origin=Vector3(-10,1.85,7.6 if scenario==1 else 0.0)
		var velocity=Vector3(28,0,0)
		if scenario==2:origin=Vector3(-10,0.85,0);velocity=Vector3(28,-3,0)
		demo.sea.launch(origin,velocity,0,"hull")
		demo.fx.burst(origin,"cannon",velocity.normalized())
		launched=true
	demo.sea._tick_shots(dt);demo.fx.tick(dt)
	for ship in demo.sea.ships:demo.sea._update_vessel_float(ship,dt)
	demo.port._sync_reflection();demo._update_ui()
	if launched and not captured.has("flight"):capture("flight")
	if demo.sea.impacts>0 and impact_time<0:impact_time=elapsed
	if demo.sea.misses>0 and splash_time<0:splash_time=elapsed
	if impact_time>=0 and elapsed-impact_time>=0.1 and not captured.has("impact"):capture("impact")
	if splash_time>=0 and elapsed-splash_time>=0.16 and not captured.has("splash"):capture("splash")
	if elapsed>3.5:
		var hp=demo.sea.ships[1].hp
		var passed=(hp==168 and demo.sea.impacts==1) if scenario==0 else (hp==180 and demo.sea.misses==1 and demo.sea.impacts==0)
		if not passed:failures+=1
		records.append({"case":NAMES[scenario],"hp":hp,"impacts":demo.sea.impacts,"water":demo.sea.misses,"passed":passed})
		if scenario<2:
			# Counters are lifetime telemetry in the scene, so reset only the test counters.
			demo.sea.impacts=0;demo.sea.misses=0
			begin_case()
		else:
			FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"results":records,"failures":failures,"fps":30},"\t"))
			quit(0 if failures==0 else 1)
	return false

func capture(suffix: String) -> void:
	captured[suffix]=true
	var name=NAMES[scenario]+"-"+suffix+".png"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
