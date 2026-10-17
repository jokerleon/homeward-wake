extends SceneTree
var demo
var output=""
var elapsed=0.0
var captures={}
var changed_weather=false
var turned=false
var wake_witness={}
var witness_point=Vector2.ZERO
var initial_yaw=0.0
var stopped_yaw=0.0
var stopped_heading_recorded=false
var rain_heave=0.0
var dry_heave=0.0
var checks=[]

func _initialize() -> void:run.call_deferred()
func check(name: String,value: bool,detail=null) -> void:checks.append({"name":name,"passed":value,"detail":detail})
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.skip_dialogue()
	demo.recruited=true;demo.fit="mount";demo._switch_mode("sea");demo.sea.reset("mount")
	demo.sea.ships[0].node.position=Vector3.ZERO;demo.sea.ships[0].yaw=0
	demo.sea.ships[1].node.position=Vector3(200,0,200);demo.sea.ships[1].disabled=true
	demo.sea.ships[1].node.visible=false
	demo.sea.move_order(Vector3(0,0,-120));demo.sea.ocean.configure(0.06,0.3,0.85,true)
	demo.toast("降雨与低浪",5);demo.toast_label.visible=true

func _process(_delta: float) -> bool:
	if demo==null:return false
	var dt=1.0/30.0;elapsed+=dt
	var sea=demo.sea;var ship=sea.ships[0]
	if elapsed>4 and not changed_weather:
		changed_weather=true;sea.ocean.configure(0.55,0.85,0)
		demo.toast("雨停、风浪渐强 · 甲板逐渐变干",8)
	if elapsed>8 and not turned:
		turned=true;initial_yaw=ship.yaw
		wake_witness=sea.wake_history[0][0];witness_point=wake_witness.point
		sea.move_order(ship.node.position+Vector3(65,0,0))
	if elapsed>12:sea.move_order(ship.node.position) # Controlled hold fixture, not a destination-braking test.
	sea.tick(dt);demo.fx.tick(dt)
	if elapsed<4:rain_heave=maxf(rain_heave,absf(ship.node.position.y))
	if elapsed>11:dry_heave=maxf(dry_heave,absf(ship.node.position.y))
	if elapsed>16 and not stopped_heading_recorded:stopped_heading_recorded=true;stopped_yaw=ship.yaw
	demo.camera.position=ship.node.position+Vector3(22,21,30);demo.camera.look_at(ship.node.position+Vector3.UP*2)
	demo.port._sync_reflection();demo._update_ui();demo.toast_label.visible=true
	if elapsed>3.5 and not captures.has("rain-low-waves"):
		check("rain_does_not_force_large_waves",sea.ocean.rainfall>0.8 and rain_heave<0.07,{"rain":sea.ocean.rainfall,"heave":rain_heave})
		capture("rain-low-waves")
	if elapsed>11.5 and not captures.has("dry-waves-turn"):
		check("large_waves_can_continue_without_rain",sea.ocean.rainfall<0.01 and sea.ocean.wave_height>0.5)
		check("wetness_persists_after_rain",sea.ocean.wetness>0.5,sea.ocean.wetness)
		check("history_wake_stays_in_world_during_turn",wake_witness.point==witness_point and absf(wrapf(ship.yaw-initial_yaw,-PI,PI))>0.4)
		capture("dry-waves-turn")
	if elapsed>24 and not captures.has("stopped-wake-faded"):
		var maximum=0.0
		for point in sea.water_material.get_shader_parameter("wake_points"):maximum=maxf(maximum,point.w)
		check("stopped_ship_does_not_turn_from_vertical_heave",absf(wrapf(ship.yaw-stopped_yaw,-PI,PI))<0.0001)
		check("stopped_travel_wake_fades",ship.velocity.length()<0.01 and maximum<0.001,maximum)
		check("wave_height_changes_actual_buoyancy",dry_heave>rain_heave*2,{"rain_heave":rain_heave,"dry_heave":dry_heave})
		demo.toast("停船后的历史尾迹已淡出",5);capture("stopped-wake-faded")
	if elapsed>24.3:
		var passed=true
		for item in checks:passed=passed and item.passed
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":passed,"stop_fixture":"Continuously requests current position; verifies stopped wake and heading, not general destination braking."},"\t"))
		print("WEATHER_REVIEW "+JSON.stringify({"passed":passed,"checks":checks}))
		quit(0 if passed else 1)
	return false

func capture(name: String) -> void:
	captures[name]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
