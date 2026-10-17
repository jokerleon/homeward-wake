extends SceneTree
var demo
var pawn
var output=""
var elapsed=0.0
var records=[]
var captured={}
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var character="Atang"
	var version="style-v04"
	for arg in OS.get_cmdline_user_args():
		if arg=="--combat-hero":character="Shipmaster"
		if arg.begins_with("--character="):character=arg.trim_prefix("--character=")
		if arg.begins_with("--motion-version="):version=arg.trim_prefix("--motion-version=")
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	demo.gui.visible=false;demo.boarding.get_node("DeploymentArea").visible=false
	for actor in demo.boarding.pawns:actor.visible=false
	pawn=demo.boarding.unit({"Atang":"atang","Shipmaster":"hero","Captain":"captain","Guard":"guard"}[character]);pawn.visible=true
	var loader=preload("res://tests/motion_review_loader.gd")
	var pack_path="D:/Work/project/joker/chess/Assets/Characters/Working/"+character+"/combat-move-E-"+version+"/"+("pack-v02" if character=="Shipmaster" and version=="style-v04" else "pack")
	if character in ["Captain","Guard"]:pack_path=pack_path.get_base_dir()+"/pack-runtime-v05"
	if not FileAccess.file_exists(pack_path+"/motion.json"):
		push_error("Candidate pack is incomplete: "+pack_path);quit(1);return
	var data=loader.pack(pack_path)
	data.pixel_size=1.59/280.0
	loader.pawn(pawn,data)
	pawn.position=Vector3(1.3,demo.boarding.deck_height(Vector3(1.3,0,-1.3)),-1.3)
	demo.camera.position=pawn.position+Vector3(7,5,10);demo.camera.look_at(pawn.position+Vector3.UP*0.8)
	Engine.time_scale=1.0
func _process(_delta: float) -> bool:
	if pawn==null:return false
	var dt=1.0/30.0;elapsed+=dt
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	pawn.velocity=right*0.6 if elapsed>=0.8 and elapsed<4.1 else Vector3.ZERO
	if elapsed>=2.5 and elapsed<4.1:pawn.velocity=-pawn.velocity
	pawn.visual(demo.camera,dt);demo.port._sync_reflection()
	records.append({"time":elapsed,"clip":String(pawn.sprite.animation),"frame":pawn.sprite.frame})
	for mark in [1.8,3.3,4.8]:
		if elapsed>=mark and not captured.has(mark):capture(mark)
	if elapsed>=5.2:
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"in-place E/W gait and phase-preserving direction change on real deck; not eight-direction completion or navigation proof","starts":pawn.locomotion.starts,"stops":pawn.locomotion.stops,"samples":records},"\t"))
		quit()
	return false
func capture(mark: float) -> void:
	captured[mark]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(str(mark)+".png"))
