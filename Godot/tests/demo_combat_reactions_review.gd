extends SceneTree
const Loader=preload("res://tests/motion_review_loader.gd")
var demo
var pawn
var target
var output=""
var index=-1
var elapsed=0.0
var events={}
var records=[]
var hit_frames={}
var actors=["hero","atang"]
var enemies=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
		if arg=="--enemies":enemies=true;actors=["captain","guard"]
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.gui.visible=false
	for character in (["Captain","Guard"] if enemies else ["Shipmaster","Atang"]):
		var key={"Shipmaster":"hero","Atang":"atang","Captain":"captain","Guard":"guard"}[character]
		var version="v06" if enemies else "v05"
		var path="D:/Work/project/joker/chess/Assets/Characters/Working/"+character+"/runtime-combat-style-"+version+"/preview-spec.json"
		Loader.pawn(demo.boarding.unit(key),Loader.load_set(JSON.parse_string(FileAccess.get_file_as_string(path))))
	target=demo.boarding.unit("hero" if enemies else "captain")
	Engine.time_scale=1
	begin_case()
func begin_case() -> void:
	index+=1;elapsed=0;events.clear();hit_frames.clear()
	if index>=actors.size():
		var success=true
		for item in records:success=success and item.passed
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"E attack and E/W reaction candidates on retained deck, reset-state verification; no eight-direction death animation claim","records":records,"passed":success},"\t"))
		quit(0 if success else 1);return
	demo.boarding.reset("pursuit",false);demo.boarding.begin()
	for actor in demo.boarding.pawns:actor.visible=false;actor.hp=0
	pawn=demo.boarding.unit(actors[index]);pawn.visible=true;pawn.hp=100;pawn.maximum=100;pawn.cooldown=100;pawn.skill_cd=100;pawn.auto_skill=false
	var point=demo.boarding.navigation.nearest(Vector3(1.3,1.7,-3.6),1.0)
	if point==null:push_error("Reaction fixture has no clear deck point");quit(1);return
	pawn.position=point;pawn.position.y=demo.boarding.deck_height(pawn.position)+.015
	demo.camera.position=Vector3(0,8,-12);demo.camera.look_at(pawn.position+Vector3.UP*.8)
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	target.visible=false;target.hp=1000;target.maximum=1000;target.stun=1000
	target.position=pawn.position+right*1.3;target.position.y=pawn.position.y
	pawn.direction="E";pawn.sprite.play("E_idle")
	demo.fx.clear()
func _process(_delta: float) -> bool:
	if pawn==null or index>=actors.size():return false
	var dt=1.0/30.0;elapsed+=dt
	if elapsed>=.5 and not events.has("attack"):
		events.attack=true
		if pawn.weapon_class=="blade":demo.boarding.start_action(pawn,target,false);pawn.cooldown=100
	if elapsed>=2.0 and not events.has("hurt"):events.hurt=true;pawn.action="";pawn.hurt(1)
	if elapsed>=3.0 and not events.has("down"):events.down=true;pawn.hurt(10000)
	if elapsed>=1.8:target.visible=false
	# Exercise the same action/release functions without automatic route planning
	# moving the art fixture behind a mast during the reaction comparison.
	if not pawn.action.is_empty():
		pawn.action_elapsed+=dt;pawn.action_left-=dt
		if not pawn.action_released and pawn.action_elapsed>=pawn.release_time:
			pawn.action_released=true;demo.boarding.resolve_action(pawn)
		if pawn.action_left<=0:demo.boarding.finish_action(pawn)
	pawn.visual(demo.camera,dt);target.visual(demo.camera,dt);demo.fx.tick(dt);demo.port._sync_reflection()
	if String(pawn.sprite.animation).ends_with("_hit"):hit_frames[pawn.sprite.frame]=true
	for mark in [1.05,2.15,3.7,5.2]:
		if elapsed>=mark and not events.has(mark):capture(mark)
	if elapsed>=5.8:
		var down_complete=String(pawn.sprite.animation).ends_with("_down") and pawn.sprite.frame==pawn.sprite.sprite_frames.get_frame_count(pawn.sprite.animation)-1
		var key=pawn.key
		demo.boarding.reset("pursuit",false)
		var reset_clean=pawn.hp==pawn.maximum and pawn.hurt_left==0 and pawn.death_time==0 and pawn.locomotion.phase=="idle"
		records.append({"character":key,"hit_frames_seen":hit_frames.size(),"down_finished":down_complete,"reset_clean":reset_clean,"passed":hit_frames.size()>1 and down_complete and reset_clean})
		begin_case()
	return false
func capture(mark: float) -> void:
	events[mark]=true
	var file=pawn.key+"-"+str(mark)+".png"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))
