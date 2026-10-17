extends "res://tests/demo_style_review.gd"
func run() -> void:
	output="D:/Work/project/joker/chess/Artifacts/ReturnDemo/named-world-cast-20261012-v3"
	DirAccess.make_dir_recursive_absolute(output)
	demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir=output
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false);demo.skip_dialogue();demo.gui.visible=false
	demo.port.actor.visible=false;demo.companion.visible=false
	var center=Vector3(-6,1.815,5.8)
	demo.camera.fov=40;demo.camera.position=center+Vector3(2,7,9);demo.camera.look_at(center+Vector3.UP*.8)
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	var roster=[["Shipmaster","船主",0,"v01"],["Atang","阿棠",1,"v02"],["Captain","头目",3,"v01"],["Guard","随从",4,"v01"]]
	for item in roster:
		var point=center+right*(float(item[2])-2.0)*1.8
		figure("D:/Work/project/joker/chess/Assets/Characters/Working/"+item[0]+"/combat-style-E-"+item[3]+"/source.png",point,item[1])
		var node=figures[figures.size()-2];node.scale*=1.59/1.74;node.position=point+(node.position-point)*(1.59/1.74)
	demo.old_liang.position=center;demo.old_liang.visible=true;demo.old_liang.show_name=true
	demo.old_liang.sprite.stop();demo.old_liang.visual(demo.camera,0);demo.old_liang.health_root.visible=false;demo.old_liang.marker.visible=false
	await capture("01-named-cast.png")
	Engine.time_scale=1;quit()
