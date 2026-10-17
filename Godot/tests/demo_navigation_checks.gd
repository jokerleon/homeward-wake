extends SceneTree
const Pawn=preload("res://scripts/demo/pawn.gd")
var results=[]
var failures=0

func _initialize() -> void:run.call_deferred()
func check(label: String,passed: bool,detail=null) -> void:
	results.append({"name":label,"passed":passed,"detail":detail})
	if not passed:failures+=1;push_warning(label+": "+str(detail))

func run() -> void:
	var demo=load("res://return_demo.tscn").instantiate()
	demo.review=true
	demo.review_dir="D:/Work/project/joker/chess/Local/ReturnDemo/revision-navigation"
	root.add_child(demo)
	demo.set_process(false);demo.set_physics_process(false)
	await process_frame
	var board=demo.boarding
	var nav=board.navigation
	check("ship_profile_builds_connected_floor_data",nav.graph.get_point_count()>500 and nav.floor_faces.size()>1000,nav.graph.get_point_count())
	check("mast_and_cabin_are_not_walkable",not nav.contains(Vector3(0,0,0.35)) and not nav.contains(Vector3(0,0,6)))
	check("open_water_is_not_walkable",not nav.contains(Vector3(-4.5,0,-2)))
	check("isolated_sample_is_not_a_placement",not nav.contains(Vector3(1.5,0,2.1)))
	var deck_to_deck=nav.path(Vector3(-1.35,0,3),Vector3(-8.1,0,3))
	var raised=false
	var valid=not deck_to_deck.is_empty()
	for point in deck_to_deck:
		valid=valid and nav.contains(point)
		if point.y>2.4:raised=true
	check("both_ships_connected_over_real_raised_gangway",valid and raised,{"points":deck_to_deck.size(),"raised":raised})
	check("reverse_gangway_route_exists",not nav.path(Vector3(-8.1,0,3),Vector3(-1.35,0,3)).is_empty())
	var every_edge_safe=true
	for id in nav.graph.get_point_ids():
		for neighbor in nav.graph.get_point_connections(id):
			if id<neighbor and not nav.segment_clear(nav.points[id],nav.points[neighbor]):every_edge_safe=false
	check("all_path_edges_fit_the_actual_body_clearance",every_edge_safe)
	board.reset("pursuit",false)
	var hero=board.unit("hero")
	var before=hero.position
	check("invalid_deployment_is_rejected_without_teleport",not board.deploy("hero",Vector3(99,0,99)) and hero.position==before)
	check("mast_movement_order_is_rejected",not board.move_order("hero",Vector3(0,0,0.35)) and hero.position==before)
	check("movement_preview_rejects_same_mast",not board.preview_order("hero",Vector3(0,0,0.35)).valid)
	var valid_goal=nav.nearest(Vector3(0.45,1.7,3.3),0.3)
	var preview=board.preview_order("atang",valid_goal)
	check("accepted_preview_matches_actual_navigation_route",preview.valid and board.move_order("atang",valid_goal) and board.unit("atang").route==preview.path)
	check("mast_blocks_crossbow_line_of_fire",not nav.line_of_fire(Vector3(-1.4,2.8,0.3487),Vector3(1.4,2.8,0.3487)))
	check("clear_crossbow_line_remains_available",nav.line_of_fire(Vector3(-1.25,2.9,2.4),Vector3(1.25,2.9,2.4)))
	var original_pawns=board.pawns.duplicate()
	board.pawns=[hero]
	var from=nav.nearest(Vector3(-1.35,1.6,3),0.3)
	var goal=nav.nearest(Vector3(-8.1,1.6,3),0.3)
	hero.position=from+Vector3(0,0.015,0)
	hero.route.clear();hero.repath_left=0
	var all_valid=true
	for i in range(900):
		hero.repath_left=maxf(0,hero.repath_left-1.0/60.0)
		board.walk(hero,goal,1.0/60.0)
		all_valid=all_valid and nav.contains(hero.position)
		if hero.position.distance_to(goal)<0.16:break
	check("actual_pawn_crosses_gangway_without_leaving_surface",all_valid and hero.position.distance_to(goal)<0.2,{"end":str(hero.position),"goal":str(goal)})
	board.pawns=original_pawns
	for suppressed in [false,true]:
		board.reset("pursuit",suppressed);board.begin()
		var min_separation=99.0
		for i in range(2100):
			board.tick(1.0/60.0,"")
			for a in range(board.pawns.size()):
				for b in range(a+1,board.pawns.size()):
					if board.pawns[a].hp>0 and board.pawns[b].hp>0:min_separation=minf(min_separation,board.pawns[a].position.distance_to(board.pawns[b].position))
			if not board.result.is_empty():break
		check("guard_participates_"+str(suppressed),board.unit("guard").attack_starts>=2,{"attacks":board.unit("guard").attack_starts,"walked":board.unit("guard").distance_walked})
		check("group_retains_body_spacing_"+str(suppressed),min_separation>=0.64,min_separation)
		check("battle_still_completes_"+str(suppressed),board.result=="won",board.result)
	# Eight occupants on the same retained small ship, with front and ranged roles.
	board.reset("pursuit",false)
	var extra=[]
	for i in range(4):
		var pawn=Pawn.new();board.add_child(pawn)
		pawn.setup("test-unit-"+str(i),"队员",0 if i<2 else 1,demo.port.hero.sprite_frames,Color.WHITE)
		pawn.auto_skill=false
		pawn.weapon_class="crossbow" if i%2==1 else "blade"
		pawn.attack_range=6.0 if pawn.weapon_class=="crossbow" else 1.65
		pawn.interval=1.8;pawn.damage=3
		board.pawns.append(pawn);extra.append(pawn)
	var starts=[Vector3(1.35,0,2.3),Vector3(-1.35,0,3.2),Vector3(1.25,0,-2.4),Vector3(-1.25,0,-2.4),Vector3(-1.35,0,1.65),Vector3(0.6,0,3.6),Vector3(-0.6,0,-3.4),Vector3(0.6,0,-3.4)]
	board.reservations.clear()
	for i in range(8):
		var pawn=board.pawns[i]
		pawn.position=nav.nearest(starts[i],0.7)+Vector3(0,0.015,0)
		pawn.hp=2000;pawn.maximum=2000;pawn.damage=3;pawn.auto_skill=false
		pawn.anchor=pawn.position;pawn.goal=pawn.position;pawn.route.clear();pawn.repath_left=0
		pawn.attack_starts=0;pawn.engagement_target=""
	board.begin()
	var remained_valid=true
	for frame in range(2400):
		board.tick(1.0/60.0,"")
		for pawn in board.pawns:remained_valid=remained_valid and nav.contains(pawn.position)
	var attacks=[]
	for pawn in board.pawns:attacks.append(pawn.attack_starts)
	var states=[]
	for pawn in board.pawns:
		var target=board.pick_target(pawn)
		states.append({"key":pawn.key,"position":str(pawn.position),"goal":str(pawn.planned_goal),"target":target.key if target!=null else "","distance":pawn.position.distance_to(target.position) if target!=null else -1,"can_attack":board._can_attack(pawn,target) if target!=null else false,"route":pawn.route.size(),"route_index":pawn.route_index,"waiting":pawn.waiting_for_space,"attacks":pawn.attack_starts})
	check("eight_person_mixed_group_stays_on_ship",remained_valid,attacks)
	var participating=0
	for value in attacks:
		if value>0:participating+=1
	check("eight_person_mixed_group_can_engage",participating==8,states)
	var file=FileAccess.open("D:/Work/project/joker/chess/Local/ReturnDemo/revision-navigation/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"count":results.size(),"failures":failures,"results":results},"\t"))
	print("DEMO_NAVIGATION_CHECKS "+JSON.stringify({"count":results.size(),"failures":failures,"results":results}))
	demo.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
