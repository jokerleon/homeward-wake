extends SceneTree

var results: Array[Dictionary] = []
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func check(name: String,passed: bool,detail: Variant) -> void:
	results.append({"name":name,"passed":passed,"detail":detail})
	if not passed:failed+=1

func key(code: int,pressed: bool) -> InputEventKey:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	return event

func _run() -> void:
	var scene=load("res://harbor.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.autoplay=false
	var cases=[[[KEY_D],"E"],[[KEY_D,KEY_S],"SE"],[[KEY_S],"S"],[[KEY_A,KEY_S],"SW"],[[KEY_A],"W"],[[KEY_A,KEY_W],"NW"],[[KEY_W],"N"],[[KEY_D,KEY_W],"NE"]]
	for pair in cases:
		scene.actor.position=Vector3(0,scene.walk_height(0,0),0)
		var before: Vector3=scene.actor.position
		for code in pair[0]:Input.parse_input_event(key(code,true))
		Input.flush_buffered_events()
		scene._move_actor(1.0/60.0)
		var shifted: Vector3=scene.actor.position
		check("input_"+pair[1],scene.facing==pair[1] and shifted.distance_to(before)>0.02,{"facing":scene.facing,"distance_first_frame_m":shifted.distance_to(before)})
		for code in pair[0]:Input.parse_input_event(key(code,false))
		Input.flush_buffered_events()
		scene._move_actor(1.0/60.0)
		check("release_"+pair[1],scene.actor.position.distance_to(shifted)<0.00001 and str(scene.hero.animation).ends_with("_idle"),{"animation":scene.hero.animation})
	var known: SpriteFrames=scene.hero.sprite_frames
	check("retained_clips",known.get_animation_names().size()==40,known.get_animation_names().size())
	scene.autoplay=true
	scene._unhandled_input(key(KEY_A,true))
	check("manual_input_cancels_tour",not scene.autoplay,scene.autoplay)
	scene._set_camera(1)
	scene._sync_reflection()
	var max_error=0.0
	for point in [Vector3(-5,0.18,5),Vector3(3,0.18,12),Vector3(12,0.18,9)]:
		var main: Vector2=scene.camera.unproject_position(point)/root.get_visible_rect().size
		var mirrored: Vector2=scene.reflection_camera.unproject_position(point)/Vector2(scene.reflection_view.size)
		max_error=max(max_error,abs(main.x+mirrored.x-1.0),abs(main.y-mirrored.y))
	check("water_reflection_projection",max_error<0.002,max_error)
	var deck=scene.vessel.get_node("CurvedWorkingDeck")
	var normals: PackedVector3Array=deck.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var mean_normal=Vector3.ZERO
	for n in normals:mean_normal+=n
	mean_normal/=float(normals.size())
	check("deck_faces_up",mean_normal.y>0.8,str(mean_normal))
	var ground=scene.get_node("ContinuousLandAndSeabed")
	var ground_normals: PackedVector3Array=ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check("terrain_faces_up",ground_normals[0].y>0.8,str(ground_normals[0]))
	var hull=scene.vessel.get_node("CurvedHull")
	var hull_arrays=hull.mesh.surface_get_arrays(0)
	var hull_n: PackedVector3Array=hull_arrays[Mesh.ARRAY_NORMAL]
	var hull_v: PackedVector3Array=hull_arrays[Mesh.ARRAY_VERTEX]
	var outward=0.0
	var count=0
	for i in range(hull_v.size()):
		if abs(hull_v[i].x)>1.0:
			outward+=hull_n[i].x*sign(hull_v[i].x)
			count+=1
	check("hull_faces_out",outward/float(count)>0.3,outward/float(count))
	scene.actor.position=Vector3(25,scene.walk_height(25,scene.coast(25)),scene.coast(25))
	var shore_position: Vector3=scene.actor.position
	Input.parse_input_event(key(KEY_S,true))
	Input.flush_buffered_events()
	scene._move_actor(1.0)
	Input.parse_input_event(key(KEY_S,false))
	Input.flush_buffered_events()
	check("deep_water_blocks_walk",scene.actor.position.distance_to(shore_position)<0.0001,str(scene.actor.position))
	scene.actor.position=Vector3(-8,scene.walk_height(-8,-2)+0.015,-2)
	scene.waypoint=0
	scene.autoplay=true
	var transitions=0
	var still_frames=0
	var longest_still=0
	for frame in range(1800):
		var previous: Vector3=scene.actor.position
		var previous_waypoint: int=scene.waypoint
		scene._move_actor(1.0/30.0)
		if previous_waypoint!=scene.waypoint:transitions+=1
		if scene.actor.position.distance_to(previous)<0.001:still_frames+=1
		else:still_frames=0
		longest_still=max(longest_still,still_frames)
	check("tour_returns_without_stalling",transitions>=12 and longest_still<=2,{"waypoint_transitions_in_60s":transitions,"longest_stall_frames":longest_still})
	var path=ProjectSettings.globalize_path("res://../Local/Harbor-v02/functional-checks.json")
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"failed":failed,"checks":results,"scope":"Input, projection and geometry checks only; no claim of art acceptance."},"\t"))
	print("HARBOR_CHECKS ",JSON.stringify({"failed":failed,"total":results.size(),"report":path}))
	quit(1 if failed else 0)
