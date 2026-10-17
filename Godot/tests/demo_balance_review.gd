extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var demo=load("res://return_demo.tscn").instantiate();demo.review=true;demo.manual_review=true;demo.review_dir="D:/Work/project/joker/chess/Local/ReturnDemo/balance-review";demo.review_scene="deck"
	root.add_child(demo);demo.set_process(false);demo.set_physics_process(false)
	var records=[]
	for damage in [9.0,16.0,20.0,24.0]:
		for suppressed in [false,true]:
			demo.boarding.reset("pursuit",suppressed);demo.boarding.unit("atang").damage=damage;demo.boarding.begin();demo.fx.clear()
			var seconds=0.0
			for i in range(3600):
				seconds+=1.0/60.0;demo.boarding.tick(1.0/60.0,"");demo.fx.tick(1.0/60.0)
				if i%120==0:await process_frame
				if not demo.boarding.result.is_empty():break
			var units=[]
			for pawn in demo.boarding.pawns:units.append({"key":pawn.key,"hp":pawn.hp,"starts":pawn.attack_starts,"walked":pawn.distance_walked})
			records.append({"atang_damage":damage,"suppressed":suppressed,"seconds":seconds,"result":demo.boarding.result,"hits":demo.boarding.hits,"units":units})
			print("BALANCE_CASE "+JSON.stringify(records[-1]))
	FileAccess.open("D:/Work/project/joker/chess/Local/ReturnDemo/balance-review/player-pack-v05.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()
