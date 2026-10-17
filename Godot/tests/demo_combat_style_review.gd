extends "res://tests/demo_style_review.gd"
func run() -> void:
	var character="Shipmaster" if "--combat-hero" in OS.get_cmdline_user_args() else "Atang"
	var version="v01" if character=="Shipmaster" else "v02"
	output="D:/Work/project/joker/chess/Artifacts/ReturnDemo/combat-style-"+character.to_lower()+"-E-20261012"
	assert(not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output;demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.gui.visible=false
	for pawn in demo.boarding.pawns:pawn.visible=false
	demo.boarding.get_node("DeploymentArea").visible=false
	var center=Vector3(1.3,demo.boarding.deck_height(Vector3(1.3,0,-1.3)),-1.3)
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	figure("D:/Work/project/joker/chess/Assets/Characters/Library/ShenYan/fullset-v01/E/frames/idle/0000.png",center,"旧沈砚 · 风格参照")
	figure("D:/Work/project/joker/chess/Assets/Characters/Working/"+character+"/combat-style-E-"+version+"/source.png",center,("船主" if character=="Shipmaster" else "阿棠")+" · 战斗候选")
	# Crouched posture is lower than the 1.74 m upright reference, not enlarged.
	var candidate=figures[2]
	var point=center
	candidate.scale*=1.59/1.74;candidate.position=point+(candidate.position-point)*(1.59/1.74)
	figures[2].visible=false;figures[3].visible=false
	await capture("01-gameplay-reference.png")
	figures[0].visible=false;figures[1].visible=false;figures[2].visible=true;figures[3].visible=true
	await capture("02-gameplay-candidate.png")
	demo.camera.position=center+Vector3(7,5,10);demo.camera.look_at(center+Vector3.UP*0.8)
	for node in figures:
		if node is MeshInstance3D:node.rotation.y=atan2(demo.camera.global_basis.z.x,demo.camera.global_basis.z.z)
	await capture("03-close-candidate.png")
	figures[0].visible=true;figures[1].visible=true;figures[2].visible=false;figures[3].visible=false
	await capture("04-close-reference.png")
	Engine.time_scale=1.0;quit()
