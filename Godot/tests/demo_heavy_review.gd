extends SceneTree
const Loader=preload("res://tests/motion_review_loader.gd")
var demo
var captain
var hero
var archer
var output=""
var cases=["hit","dodge","interrupt"]
var index=-1
var elapsed=0.0
var events={}
var records=[]
var cue=0.0
var title: Label

func _initialize() -> void:run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true
	demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.gui.visible=false
	captain=demo.boarding.unit("captain");hero=demo.boarding.unit("hero");archer=demo.boarding.unit("atang")
	var spec="D:/Work/project/joker/chess/Assets/Characters/Working/Captain/runtime-combat-style-v06/preview-spec.json"
	Loader.pawn(captain,Loader.load_set(JSON.parse_string(FileAccess.get_file_as_string(spec))))
	demo.camera.position=Vector3(8,10,12);demo.camera.look_at(Vector3(0,1.6,-1.7))
	title=Label.new();title.position=Vector2(24,24);title.add_theme_font_size_override("font_size",24);root.add_child(title)
	Engine.time_scale=1.0;begin_case()

func place(pawn,point: Vector3) -> void:
	var snapped=demo.boarding.navigation.nearest(point,.8)
	assert(snapped!=null)
	pawn.position=snapped+Vector3.UP*.015;pawn.anchor=pawn.position;pawn.goal=pawn.position

func begin_case() -> void:
	index+=1;elapsed=0;events.clear()
	if index>=cases.size():
		var success=true
		for item in records:success=success and item.passed
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"Authored heavy cue, one damage event, actual movement dodge and real bolt interruption on measured deck; candidate captain pack","passed":success,"records":records},"\t"))
		quit(0 if success else 1);return
	demo.boarding.reset("pursuit",false);demo.boarding.begin();demo.fx.clear()
	for pawn in demo.boarding.pawns:
		pawn.auto_skill=false;pawn.cooldown=100;pawn.skill_cd=100;pawn.visible=pawn.key!="guard"
		pawn.hp=1000;pawn.maximum=1000;pawn.stun=100
	demo.boarding.unit("guard").hp=0
	place(captain,Vector3(1.35,0,-3.5));place(hero,Vector3(1.35,0,-2.15));place(archer,Vector3(1.35,0,-.8))
	# Hit/dodge cases isolate one recipient. Keeping the archer beside the
	# hero would correctly add a second AoE hit and obscure the dodge result.
	archer.visible=cases[index]=="interrupt"
	if cases[index]!="interrupt":archer.hp=0
	captain.stun=0;demo.boarding.start_action(captain,hero,true);captain.cooldown=100;captain.skill_cd=100
	cue=captain.release_time
	title.text={"hit":"重击：蓄力后命中一次","dodge":"重击：按真实路径移出落点","interrupt":"重击：独立弩矢命中并打断"}[cases[index]]

func _process(_delta: float) -> bool:
	if demo==null or index>=cases.size():return false
	var dt=1.0/30.0;elapsed+=dt
	if cases[index]=="dodge" and elapsed>=cue-.85 and not events.has("move"):
		hero.stun=0;events.move=demo.boarding.move_order("hero",Vector3(1.35,0,.65))
	if cases[index]=="interrupt" and elapsed>=.25 and not events.has("shot"):
		events.shot=true;archer.stun=0;demo.boarding.start_action(archer,captain,true);archer.cooldown=100;archer.skill_cd=100
	demo.boarding.tick(dt,"");demo.boarding.update_visual(dt,"");demo.fx.tick(dt);demo.port._sync_reflection()
	for mark in [.7,2.0,2.7]:
		if elapsed>=mark and not events.has(mark):capture(mark)
	if elapsed>=cue+.95:
		var passed=false
		if cases[index]=="hit":passed=hero.hp==970 and demo.boarding.hits==1
		if cases[index]=="dodge":passed=events.get("move",false) and hero.hp==1000 and hero.distance_walked>1.9 and demo.boarding.dodged_heavy==1
		if cases[index]=="interrupt":passed=hero.hp==1000 and demo.boarding.interrupted==1 and captain.hp<1000 and demo.boarding.hits==1
		records.append({"case":cases[index],"release_time":cue,"hero_hp":hero.hp,"captain_hp":captain.hp,"hits":demo.boarding.hits,"dodged":demo.boarding.dodged_heavy,"interrupted":demo.boarding.interrupted,"hero_walked":hero.distance_walked,"passed":passed})
		begin_case()
	return false

func capture(mark: float) -> void:
	events[mark]=true
	var path=output.path_join(cases[index]+"-"+str(mark)+".png")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
