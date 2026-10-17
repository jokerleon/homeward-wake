extends SceneTree
const Loader=preload("res://tests/motion_review_loader.gd")
var records=[]
var failures=0
var candidate=false
var output="D:/Work/project/joker/chess/Local/ReturnDemo/combat-balance-20261013.json"

func _initialize() -> void:run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--candidate-enemies":candidate=true
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var demo=load("res://return_demo.tscn").instantiate()
	demo.review=true;demo.manual_review=true;demo.review_scene="deck"
	demo.review_dir=output.get_base_dir()
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	if candidate:
		for character in ["Captain","Guard"]:
			var spec="D:/Work/project/joker/chess/Assets/Characters/Working/"+character+"/runtime-combat-style-v06/preview-spec.json"
			Loader.pawn(demo.boarding.unit("captain" if character=="Captain" else "guard"),Loader.load_set(JSON.parse_string(FileAccess.get_file_as_string(spec))))
	for rate in [30,60]:
		for trait_name in ["pursuit","guard"]:
			for suppression in [false,true]:
				demo.boarding.reset(trait_name,suppression);demo.boarding.begin();demo.fx.clear()
				var elapsed=0.0
				for frame in range(rate*60):
					elapsed+=1.0/rate;demo.boarding.tick(1.0/rate,"");demo.fx.tick(1.0/rate)
					if frame%(rate*2)==0:await process_frame
					if not demo.boarding.result.is_empty():break
				var units=[]
				for pawn in demo.boarding.pawns:
					units.append({"key":pawn.key,"hp":pawn.hp,"attacks":pawn.attack_starts,"walked":pawn.distance_walked})
				var passed=demo.boarding.result=="won" and demo.boarding.unit("guard").attack_starts>=2
				if not passed:failures+=1
				records.append({"fps":rate,"trait":trait_name,"suppressed":suppression,"seconds":elapsed,"result":demo.boarding.result,"hits":demo.boarding.hits,"units":units,"passed":passed})
				print("COMBAT_BALANCE_CASE "+JSON.stringify(records[-1]))
	var report={"candidate_enemies":candidate,"scope":"Default automatic combat for both growth choices and naval suppression states at 30/60 Hz, real authored action durations. Not all placements or final game balance.","count":records.size(),"failures":failures,"records":records}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT_BALANCE_CHECKS "+JSON.stringify({"count":records.size(),"failures":failures}))
	demo.queue_free();await process_frame;quit(0 if failures==0 else 1)
