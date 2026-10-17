extends SceneTree
const Loader=preload("res://tests/motion_review_loader.gd")
const Locomotion=preload("res://scripts/demo/locomotion.gd")
var demo
var pawn
var target
var output=""
var mode="shots"
var character="Atang"
var names=["E","SE","S","SW","W","NW","N","NE"]
var index=-1
var elapsed=0.0
var expected=Vector3.ZERO
var started=false
var emitted=0
var captured={}
var records=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
		if arg=="--moves":mode="moves"
		if arg=="--combat-hero":character="Shipmaster"
		if arg=="--combat-captain":character="Captain"
		if arg=="--combat-guard":character="Guard"
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.gui.visible=false;demo.boarding.begin()
	for actor in demo.boarding.pawns:actor.visible=false;actor.hp=0
	var key={"Atang":"atang","Shipmaster":"hero","Captain":"captain","Guard":"guard"}[character]
	pawn=demo.boarding.unit(key);target=demo.boarding.unit("hero" if key=="captain" else "captain")
	pawn.visible=true;pawn.hp=100;pawn.cooldown=100;pawn.auto_skill=false;pawn.skill_cd=100
	target.hp=1000;target.maximum=1000;target.stun=10000
	pawn.position=Vector3(1.3,demo.boarding.deck_height(Vector3(1.3,0,-1.3))+0.015,-1.3)
	demo.camera.position=pawn.position+Vector3(7,5,10);demo.camera.look_at(pawn.position+Vector3.UP*0.8)
	var version="v06" if character in ["Captain","Guard"] else "v05"
	var spec_path="D:/Work/project/joker/chess/Assets/Characters/Working/"+character+"/runtime-combat-style-"+version+"/preview-spec.json"
	Loader.pawn(pawn,Loader.load_set(JSON.parse_string(FileAccess.get_file_as_string(spec_path))))
	Engine.time_scale=1.0
	begin_case()
func begin_case() -> void:
	index+=1;elapsed=0;started=false;emitted=0;captured.clear()
	if index>=names.size():
		var success=true
		for item in records:success=success and item.passed
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"Working eight-view "+mode+" on actual deck; in-place animation and release anchors, not eight-position navigation/collision proof","records":records,"passed":success},"\t"))
		quit(0 if success else 1);return
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	var toward=demo.camera.global_basis.z;toward.y=0;toward=toward.normalized()
	expected=right*cos(index*PI/4)+toward*sin(index*PI/4)
	target.position=pawn.position+expected*4;target.hp=1000
	pawn.direction=names[index];pawn.title={"Atang":"阿棠","Shipmaster":"船主","Captain":"船匪头目","Guard":"随从"}[character]+" · "+names[index]
	pawn.action="";pawn.action_elapsed=0;pawn.weapon_loaded=true;pawn.velocity=Vector3.ZERO;pawn.cooldown=100
	pawn.locomotion=Locomotion.new();pawn.locomotion_clip="idle"
	pawn.sprite.stop();pawn.sprite.play(names[index]+"_idle");pawn._sync_frame()
	demo.fx.clear()
	demo.fx.line(pawn.global_position+Vector3.UP*.035,pawn.global_position+expected*.75+Vector3.UP*.035,.022,Color("b9d2b1"),6)
func _process(_delta: float) -> bool:
	if pawn==null or index<0 or index>=names.size():return false
	var dt=1.0/30.0;elapsed+=dt
	if mode=="moves":
		pawn.velocity=expected*.7 if elapsed>=.4 and elapsed<3.0 else Vector3.ZERO
	else:
		if elapsed>=.4 and not started:
			demo.boarding.start_action(pawn,target,false);pawn.cooldown=100;started=true
		var previous=demo.boarding.shots.size()
		demo.boarding.tick(dt,"")
		if demo.boarding.shots.size()>previous:emitted+=demo.boarding.shots.size()-previous;capture("release")
	pawn.visual(demo.camera,dt);demo.fx.tick(dt);demo.port._sync_reflection()
	if elapsed>=1.8 and not captured.has("action"):capture("action")
	if elapsed>=(4.2 if mode=="moves" else 5.8):
		var passed=pawn.direction==names[index]
		if mode=="moves":passed=passed and pawn.locomotion.starts==1 and pawn.locomotion.stops==1
		else:passed=passed and emitted==1 and pawn.weapon_loaded and absf(pawn.shot_direction.y)<.0001
		records.append({"direction":names[index],"passed":passed,"starts":pawn.locomotion.starts,"stops":pawn.locomotion.stops,"bolts":emitted,"reloaded":pawn.weapon_loaded})
		begin_case()
	return false
func capture(name: String) -> void:
	captured[name]=true
	var file=names[index]+"-"+name+".png"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))
