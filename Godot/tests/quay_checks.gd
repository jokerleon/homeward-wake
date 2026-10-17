extends SceneTree
var results: Array[Dictionary]=[]
var failures=0
func _initialize()->void:_run.call_deferred()
func check(title: String,pass_test: bool,detail: Variant)->void:
	results.append({"name":title,"passed":pass_test,"detail":detail})
	if not pass_test:failures+=1
func key(code: int,pressed: bool)->InputEventKey:
	var event=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	return event
func _run()->void:
	root.size=Vector2i(1600,900)
	var s=load("res://quay.tscn").instantiate()
	root.add_child(s)
	await process_frame
	s.set_process(false)
	s.autoplay=false
	var cases=[[[KEY_D],"E"],[[KEY_D,KEY_S],"SE"],[[KEY_S],"S"],[[KEY_A,KEY_S],"SW"],[[KEY_A],"W"],[[KEY_A,KEY_W],"NW"],[[KEY_W],"N"],[[KEY_D,KEY_W],"NE"]]
	for pair in cases:
		s.actor.position=Vector3(-5,1.815,8)
		var old: Vector3=s.actor.position
		for code in pair[0]:Input.parse_input_event(key(code,true))
		Input.flush_buffered_events()
		s._move_actor(1.0/60.0)
		var moved: Vector3=s.actor.position
		check("immediate_"+pair[1],s.facing==pair[1] and moved.distance_to(old)>0.02,{"facing":s.facing,"distance":moved.distance_to(old)})
		for code in pair[0]:Input.parse_input_event(key(code,false))
		Input.flush_buffered_events()
		s._move_actor(1.0/60.0)
		check("release_"+pair[1],s.actor.position.distance_to(moved)<0.00001 and str(s.hero.animation).ends_with("_idle"),str(s.hero.animation))
	check("generated_ship_present",s.ship_model_loaded,s.ship_model_loaded)
	check("retained_40_clips",s.hero.sprite_frames.get_animation_names().size()==40,s.hero.sprite_frames.get_animation_names().size())
	s.autoplay=true
	s._unhandled_input(key(KEY_A,true))
	check("manual_interrupts_tour",not s.autoplay,s.autoplay)
	s._set_camera(1)
	var error=0.0
	for p in [Vector3(2,0.18,9),Vector3(6,0.18,2),Vector3(14,0.18,1)]:
		var a: Vector2=s.camera.unproject_position(p)/root.get_visible_rect().size
		var b: Vector2=s.reflection_camera.unproject_position(p)/Vector2(s.reflection_view.size)
		error=max(error,abs(a.x+b.x-1.0),abs(a.y-b.y))
	check("perspective_reflection_matches",error<0.002,error)
	s.actor.position=Vector3(1.42,1.815,9)
	var coast: Vector3=s.actor.position
	Input.parse_input_event(key(KEY_D,true))
	Input.flush_buffered_events()
	s._move_actor(0.1)
	Input.parse_input_event(key(KEY_D,false))
	Input.flush_buffered_events()
	check("water_blocks_walking",s.actor.position.distance_to(coast)<0.001,str(s.actor.position))
	var original_route=s.route.duplicate()
	s.actor.position=Vector3(-1,1.815,-2.5)
	s.route=[Vector2(-1,-9.2)]
	s.waypoint=0
	s.autoplay=true
	for i in range(150):s._move_actor(1.0/30.0)
	check("walks_up_real_stairs",s.actor.position.z<-8.8 and s.actor.position.y>2.79,str(s.actor.position))
	s.actor.position=Vector3(-8,1.815,-7.8)
	s.route=[Vector2(-8,-8.8)]
	for i in range(30):s._move_actor(1.0/30.0)
	check("cannot_step_through_retaining_wall",s.actor.position.z>-8.0 and s.actor.position.y<2.0,str(s.actor.position))
	s.route=original_route
	s.actor.position=Vector3(-7,1.815,8)
	s.waypoint=0
	var transitions=0
	var longest_stall=0
	var stall=0
	var reached_gangway=false
	for frame in range(1800):
		var old: Vector3=s.actor.position
		var old_waypoint: int=s.waypoint
		s._move_actor(1.0/30.0)
		if s.waypoint!=old_waypoint:transitions+=1
		if s.actor.position.distance_to(old)<0.001:stall+=1
		else:stall=0
		longest_stall=max(longest_stall,stall)
		if s.actor.position.x>7.1 and s.actor.position.z<1.0 and s.actor.position.y>2.3:reached_gangway=true
	check("tour_reaches_gangway_and_returns",reached_gangway and transitions>=16 and longest_stall<=2,{"reached_gangway":reached_gangway,"transitions":transitions,"longest_stall":longest_stall})
	s.post_enabled=false
	s._apply_focus()
	check("focus_can_be_disabled",not s.camera.attributes.dof_blur_far_enabled and not s.camera.attributes.dof_blur_near_enabled,true)
	s._unhandled_input(key(KEY_P,true))
	check("focus_only_affects_far_range",s.camera.attributes.dof_blur_far_enabled and not s.camera.attributes.dof_blur_near_enabled and is_equal_approx(s.camera.attributes.dof_blur_far_distance,65.0),s.camera.attributes.dof_blur_amount)
	var out=ProjectSettings.globalize_path("res://../Local/Harbor-v03/functional-checks.json")
	var file=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"failed":failures,"checks":results,"scope":"Navigation, retained clips, model presence, focus controls and reflection projection; never an art score."},"\t"))
	print("QUAY_CHECKS ",JSON.stringify({"failed":failures,"total":results.size(),"report":out}))
	quit(1 if failures else 0)
