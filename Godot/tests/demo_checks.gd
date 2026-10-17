extends SceneTree
const Rules=preload("res://scripts/demo/rules.gd")
var results=[]
var failures=0

func _initialize() -> void:_run.call_deferred()
func check(label: String,passed: bool,detail=null) -> void:
	results.append({"name":label,"passed":passed,"detail":detail})
	if not passed:failures+=1;push_warning(label+": "+str(detail))

func _run() -> void:
	check("swept_fast_projectile_hits_between_frames",Rules.hull_hit(Vector3(-20,1,0),Vector3(20,1,0),Vector3(0,1,0),Vector3(0,1,0),0,Vector3(2,1,7))>=0)
	check("parallel_near_miss_does_not_damage",Rules.hull_hit(Vector3(-20,1,9),Vector3(20,1,9),Vector3(0,1,0),Vector3(0,1,0),0,Vector3(2,1,7))<0)
	check("moving_target_leaves_fixed_flight_path",Rules.hull_hit(Vector3(-8,1,0),Vector3(8,1,0),Vector3(0,1,9),Vector3(0,1,12),0,Vector3(2,1,7))<0)
	var gravity=Vector3(0,-4.5,0)
	var origin=Vector3(0,2,0)
	var aim=Vector3(30,1.5,0)
	var velocity=Rules.launch_velocity(origin,aim,1.2,gravity)
	check("ballistic_trajectory_reaches_launch_aim",(origin+velocity*1.2+gravity*1.2*1.2*0.5).distance_to(aim)<0.0001)
	root.size=Vector2i(1600,900)
	var demo=load("res://return_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo.review=true # checks never write the user's save
	demo.set_process(false)
	demo.set_physics_process(false)
	demo.skip_dialogue()
	demo.talk();demo.skip_dialogue();demo.recruit();demo.choose_fit("hull")
	check("recruitment_and_fit_change_party",demo.recruited and demo.fit=="hull")
	demo.depart()
	check("sea_entry_reuses_generated_3d_ship",demo.sea.ships.size()==2 and demo.sea.ships[0].maximum==220.0)
	demo.select_ship()
	check("selecting_ship_enters_bullet_time",is_equal_approx(Engine.time_scale,0.08))
	demo.cancel_command()
	check("cancel_restores_normal_time",is_equal_approx(Engine.time_scale,1.0))
	demo.parties[0].grab_focus()
	var pause_key=InputEventKey.new()
	pause_key.keycode=KEY_SPACE;pause_key.physical_keycode=KEY_SPACE;pause_key.pressed=true
	Input.parse_input_event(pause_key)
	Input.flush_buffered_events()
	check("pause_key_works_while_gui_button_has_focus",demo.paused)
	var release_key=pause_key.duplicate()
	release_key.pressed=false
	Input.parse_input_event(release_key)
	Input.flush_buffered_events()
	if demo.paused:demo.toggle_pause()
	var boat=demo.sea.ships[0]
	boat.reload=3.2
	demo.sea.switch_ammo()
	check("ammo_switch_keeps_current_load_and_reload",boat.loaded=="hull" and boat.pending=="pressure" and is_equal_approx(boat.reload,3.2))
	demo.sea.reset("hull")
	demo.sea.special_pending=true
	demo.sea.engage()
	for batch in range(90):
		for i in range(120):demo.sea.tick(1.0/60.0)
		await process_frame
		if demo.sea.ships[1].disabled or demo.sea.ships[0].hp<=0:break
	check("automatic_naval_encounter_can_disable_enemy",demo.sea.ships[1].disabled and demo.sea.ships[0].hp>0,{"player":demo.sea.ships[0].hp,"enemy":demo.sea.ships[1].hp,"hits":demo.sea.impacts,"misses":demo.sea.misses})
	demo.sea.reset("hull")
	demo.sea.engage()
	var enemy_id=demo.sea.ships[1].node.get_instance_id()
	demo.sea.ships[1].hp=130
	boat.node.position=Vector3(-110,0,90)
	boat.goal=boat.node.position
	for i in range(480):demo.sea.tick(1.0/60.0)
	check("out_of_range_pursuit_ends_on_same_map",demo.sea.state=="sailing",demo.sea.state)
	check("escape_preserves_enemy_identity_and_damage",demo.sea.ships[1].node.get_instance_id()==enemy_id and demo.sea.ships[1].hp==130)
	var saved=demo.sea.snapshot()
	var old_goal=demo.sea.ships[0].goal
	var old_reload=demo.sea.ships[0].reload
	demo.sea.restore(saved)
	check("checkpoint_restores_course_damage_and_loading",demo.sea.ships[0].goal==old_goal and demo.sea.ships[0].reload==old_reload and demo.sea.ships[1].hp==130)
	demo.sea.reset("hull")
	demo.sea.engage()
	demo.sea.retreat()
	for batch in range(50):
		for i in range(120):demo.sea.tick(1.0/60.0)
		await process_frame
		if demo.sea.escaped>0:break
	check("retreat_order_can_sail_out_of_pursuit",demo.sea.escaped>0 and demo.sea.ships[0].hp>0,{"escaped":demo.sea.escaped,"hp":demo.sea.ships[0].hp})
	# Direct integration checks exercise actual projectile damage, not a visual-only ray.
	demo.sea.reset("hull")
	var target=demo.sea.ships[1]
	target.node.position=Vector3(0,0,0);target.previous=target.node.position;target.yaw=0
	var hp=target.hp
	demo.sea.launch(Vector3(-10,1.25,0),Vector3(40,0,0),0,"hull")
	check("launch_does_not_preapply_damage",target.hp==hp)
	demo.sea._tick_shots(0.4)
	check("direct_hit_applies_damage_once",target.hp==hp-12 and demo.sea.shots.is_empty(),target.hp)
	demo.sea._tick_shots(0.4)
	check("resolved_projectile_cannot_hit_twice",target.hp==hp-12)
	demo.sea.launch(Vector3(-10,1.25,0),Vector3(40,0,0),0,"hull")
	target.node.position.z=20;target.previous=target.node.position
	demo.sea._tick_shots(0.4)
	check("turn_or_displacement_after_launch_can_avoid_damage",target.hp==hp-12)
	demo.sea.reset("hull")
	target=demo.sea.ships[1]
	target.node.position=Vector3(12,0,0);target.previous=target.node.position;target.yaw=0
	hp=target.hp
	demo.sea.launch(Vector3(0,0.20,0),Vector3(40,-2,0),0,"hull")
	demo.sea._tick_shots(0.4)
	check("water_contact_precedes_later_hull_contact",target.hp==hp and demo.sea.shots.is_empty())
	demo.sea.reset("mount")
	demo.growth_trait="pursuit"
	demo.enter_boarding()
	check("boarding_uses_actual_ship_and_surface_data",demo.boarding.has_node("ActualEnemyShip") and demo.boarding.deck_surface.source=="res://assets/quay-v03/merchant-ship-a.glb")
	var pawn=demo.boarding.unit("hero")
	var original_spawn=pawn.position
	check("invalid_deployment_is_rejected_without_relocation",not demo.boarding.deploy("hero",Vector3(99,0,99)) and pawn.position==original_spawn)
	demo.boarding.reset("pursuit",true)
	check("naval_suppression_carries_to_boarding",demo.boarding.unit("guard").stun>0)
	var archer=demo.boarding.unit("atang")
	var shot_target=demo.boarding.unit("guard")
	var target_height=shot_target.position.y
	shot_target.position.y=archer.position.y
	demo.boarding.start_action(archer,shot_target,false)
	check("equal_height_shot_is_world_level",absf(archer.shot_direction.y)<0.0001)
	shot_target.position.y=target_height
	var contact_target_before=shot_target.position
	var right=demo.camera.global_basis.x;right.y=0;right=right.normalized()
	shot_target.position=archer.position+right*.7
	demo.boarding.start_action(archer,shot_target,false)
	check("contact_range_bolt_does_not_fire_backwards",archer.shot_direction.dot(right)>0)
	shot_target.position=contact_target_before
	demo.boarding.start_action(archer,shot_target,false)
	var committed_facing=archer.direction
	var committed_shot=archer.shot_direction
	var target_before=shot_target.position
	shot_target.position=archer.position-(target_before-archer.position)
	archer.visual(demo.camera,1.0/60.0)
	check("committed_shot_keeps_facing_when_target_crosses",archer.direction==committed_facing and archer.shot_direction==committed_shot)
	shot_target.position=target_before
	var corpse=demo.boarding.unit("hero")
	corpse.hurt(10000);demo.boarding.result="won"
	demo.boarding.update_visual(.001,"",.5)
	check("result_dialogue_finishes_death_animation",corpse.death_time>=.49)
	var frozen_death=corpse.death_time
	demo.boarding.update_visual(.001,"",0)
	check("explicit_pause_freezes_result_animation",corpse.death_time==frozen_death)
	demo.boarding.reset("pursuit",true)
	demo.begin_boarding()
	demo.fx.clear()
	demo.boarding.telegraph(Vector3(1.4,1.6,1.2),1.9,1.4)
	var marker_y=demo.fx.effects[0].node.position.y
	demo.fx.tick(0.5)
	check("telegraph_stays_on_real_deck_during_warning",abs(demo.fx.effects[0].node.position.y-marker_y)<0.001)
	var legal_goal=demo.boarding.navigation.nearest(Vector3(0.45,1.7,3.3),0.3)
	var order_accepted=demo.boarding.move_order("atang",legal_goal)
	for i in range(120):demo.boarding.tick(1.0/60.0,"")
	var anchor=demo.boarding.unit("atang").anchor
	check("manual_move_establishes_persistent_anchor",order_accepted and Vector2(anchor.x,anchor.z).distance_to(Vector2(legal_goal.x,legal_goal.z))<0.01)
	check("feet_follow_measured_ship_deck",abs(demo.boarding.unit("atang").position.y-demo.boarding.deck_height(demo.boarding.unit("atang").position)-0.015)<0.01)
	demo.boarding.reset("pursuit",true)
	demo.begin_boarding()
	for batch in range(40):
		for i in range(120):
			if demo.boarding.active:demo.boarding.tick(1.0/60.0,"")
		await process_frame
		if not demo.boarding.active:break
	check("automatic_party_can_resolve_demo_battle",demo.boarding.result=="won",{"result":demo.boarding.result,"hero_hp":demo.boarding.unit("hero").hp,"atang_hp":demo.boarding.unit("atang").hp,"captain_hp":demo.boarding.unit("captain").hp})
	demo.completed=false
	demo.battle_won();demo.skip_dialogue();demo.skip_dialogue()
	check("story_returns_to_port_with_rescued_npc",demo.mode=="port" and demo.completed and not demo.dialog_open and demo.old_liang.visible)
	demo.old_liang.position=Vector3.ZERO
	demo.retry_checkpoint()
	check("completed_checkpoint_restores_rescued_npc_on_quay",demo.old_liang.visible and demo.old_liang.position.y>1.8 and demo.completed)
	var output=ProjectSettings.globalize_path("res://../Local/ReturnDemo/checks.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"checks":results},"\t"))
	print("DEMO_CHECKS ",JSON.stringify({"failures":failures,"count":results.size(),"output":output}))
	demo.queue_free()
	await process_frame
	Engine.time_scale=1.0
	quit(0 if failures==0 else 1)
