extends SceneTree
var demo
var archer
var target
var output=""
var elapsed=0.0
var started=false
var captured={}
var emitted=0
var was_loaded=true
var reloaded=false
var target_hp=0.0
var samples=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.gui.visible=false
	demo.boarding.begin()
	for actor in demo.boarding.pawns:actor.visible=false;actor.hp=0
	archer=demo.boarding.unit("atang");target=demo.boarding.unit("captain")
	archer.visible=true;archer.hp=100;archer.cooldown=100;archer.skill_cd=100;archer.auto_skill=false
	target.visible=true;target.hp=1000;target.maximum=1000;target.stun=100;target.title="静止目标"
	archer.position=Vector3(-1.25,demo.boarding.deck_height(Vector3(-1.25,0,-1.3))+0.015,-1.3)
	target.position=Vector3(1.25,archer.position.y,-1.3);target_hp=target.hp
	demo.camera.position=Vector3(0,8,11);demo.camera.look_at(Vector3(0,2.1,-1.3))
	var loader=preload("res://tests/motion_review_loader.gd")
	var base="D:/Work/project/joker/chess/Assets/Characters/Working/Atang/"
	var data=loader.pack(base+"combat-move-E-style-v04/pack")
	loader.merge(data,loader.pack(base+"combat-shoot-E-style-v04/pack"))
	loader.merge(data,loader.pack(base+"combat-reload-E-style-v04/pack"))
	for direction in ["E","W"]:
		data.metadata[direction+"_shoot"].release_time=14.0/24.0
		data.metadata[direction+"_shoot"].muzzle_px=[344,109]
	data.pixel_size=1.59/280.0;loader.pawn(archer,data)
	archer.material.set_shader_parameter("paint_light_weight",1.0);archer.material.set_shader_parameter("fill_light",0.1);archer.material.set_shader_parameter("paint_midtones",1.0)
	Engine.time_scale=1.0
func _process(_delta: float) -> bool:
	if archer==null:return false
	var dt=1.0/30.0;elapsed+=dt
	if elapsed>=0.8 and not started:
		demo.boarding.start_action(archer,target,false);archer.cooldown=100;started=true
	var previous=demo.boarding.shots.size()
	demo.boarding.tick(dt,"")
	if demo.boarding.shots.size()>previous:emitted+=demo.boarding.shots.size()-previous;capture("release")
	if not was_loaded and archer.weapon_loaded:reloaded=true
	was_loaded=archer.weapon_loaded
	archer.visual(demo.camera,dt);target.visual(demo.camera,dt);demo.fx.tick(dt);demo.port._sync_reflection()
	if elapsed>=1.2 and not captured.has("aim"):capture("aim")
	if archer.action=="reload" and archer.action_elapsed>=1.0 and not captured.has("reload"):capture("reload")
	samples.append({"time":elapsed,"action":archer.action,"frame":archer.sprite.frame,"loaded":archer.weapon_loaded,"shots":demo.boarding.shots.size()})
	if elapsed>=6.2:
		var checks={"one_bolt":emitted==1,"one_damage_event":is_equal_approx(target_hp-target.hp,archer.damage),"reloaded":reloaded,"equal_height_level":absf(archer.shot_direction.y)<0.0001}
		var success=true
		for value in checks.values():success=success and value
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"E-only Working shot and reload, actual projectile/collision on retained deck; no runtime publish","checks":checks,"muzzle_px":[344,109],"release_time":14.0/24.0,"samples":samples},"\t"))
		quit(0 if success else 1)
	return false
func capture(name: String) -> void:
	captured[name]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
