extends Node3D
const Pawn=preload("res://scripts/demo/pawn.gd")
const Rules=preload("res://scripts/demo/rules.gd")
const ShipVisual=preload("res://scripts/demo/ship_visual.gd")
const DeckNavigation=preload("res://scripts/demo/deck_navigation.gd")
var navigation=DeckNavigation.new()
var pawns=[]
var shots=[]
var effects
var camera
var active=false
var result=""
var growth_trait="pursuit"
var followup_cd=0.0
var protect_cd=0.0
var deployed_area=Rect2(-1.55,1.65,3.1,2.0)
var walk_area=Rect2(-1.95,-4.6,3.9,9.2)
var obstacles=[Vector3(0,0.66,0.2),Vector3(0,0.24,-4.0)]
var deck_surface={}
var water_material
var elapsed=0.0
var hits=0
var dodged_heavy=0
var interrupted=0
var reservations={}
var navigation_replans=0
var invalid_orders=0

func setup(port,fx,view: Camera3D) -> void:
	effects=fx
	camera=view
	deck_surface=JSON.parse_string(FileAccess.get_file_as_string("res://assets/demo/ship-deck-surface.json"))
	navigation.setup()
	navigation.make_pick_body(self)
	var wood=port.paint_materials.deck
	var dark=port.paint_materials.darkwood
	# The actual retained ship is the battlefield. No replacement platform or fake cabin.
	var ship=load("res://assets/demo/merchant-ship-boarding-v2.glb").instantiate()
	ship.name="ActualEnemyShip"
	ship.rotation.y=PI*0.5
	add_child(ship)
	ShipVisual.prepare(ship)
	var friendly=load("res://assets/demo/merchant-ship-boarding-v2.glb").instantiate()
	friendly.name="MooredPlayerShip"
	friendly.rotation.y=PI*0.5
	friendly.position=Vector3(-9.3,0,1.2)
	add_child(friendly)
	ShipVisual.prepare(friendly)
	_build_boarding_bridge(port,wood,dark)
	var deployment=MeshInstance3D.new()
	var grid=SurfaceTool.new()
	grid.begin(Mesh.PRIMITIVE_TRIANGLES)
	for start in range(0,navigation.floor_faces.size(),3):
		var triangle=[navigation.floor_faces[start],navigation.floor_faces[start+1],navigation.floor_faces[start+2]]
		var valid=true
		for point in triangle:
			if not navigation.is_deployment(point):valid=false;break
		if not valid:continue
		for point in triangle:
			grid.set_uv(Vector2((point.x-deployed_area.position.x)/deployed_area.size.x,1.0-(point.z-deployed_area.position.y)/deployed_area.size.y))
			grid.add_vertex(point+Vector3(0,0.045,0))
	grid.generate_normals();deployment.mesh=grid.commit()
	var deployment_paint=ShaderMaterial.new();deployment_paint.shader=load("res://shaders/demo_deployment.gdshader")
	deployment_paint.set_shader_parameter("indicators",load("res://assets/demo/ui/indicators.png"))
	deployment.material_override=deployment_paint
	deployment.name="DeploymentArea"
	deployment.position=Vector3.ZERO
	add_child(deployment)
	var water=MeshInstance3D.new()
	var ocean=PlaneMesh.new()
	ocean.size=Vector2(300,300)
	ocean.subdivide_width=120;ocean.subdivide_depth=120
	water.mesh=ocean
	water_material=port.water_material.duplicate()
	water_material.shader=load("res://shaders/demo_ocean.gdshader")
	water_material.set_shader_parameter("wave_height",0.055)
	water_material.set_shader_parameter("reflection_tex",port.reflection_view.get_texture())
	water_material.set_shader_parameter("ripple_sources",PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]))
	water.material_override=water_material
	water.layers=2
	water.position.y=0.18
	add_child(water)
	port.box(self,Vector3(0,-4.1,0),Vector3(300,0.2,300),port.paint_materials.stone)
	var info=[
		["hero","船主",0,Color("f3ecdb"),160.0,12.0,1.65,1.5,Vector3(1.0,1.6,2.2)],
		["atang","阿棠",0,Color("a9c6b5"),100.0,24.0,7.0,1.8,Vector3(-1.1,1.7,3.15)],
		["captain","船匪头目",1,Color("c3a8a0"),210.0,12.0,1.75,2.0,Vector3(1.1,1.6,-2.7)],
		["guard","随从",1,Color("b6ada3"),110.0,8.0,1.65,2.2,Vector3(-0.85,1.7,-3.65)]
	]
	for data in info:
		var pawn=Pawn.new()
		add_child(pawn)
		pawn.setup(data[0],data[1],data[2],port.retained_sprite_frames,data[3])
		pawn.maximum=data[4]
		pawn.hp=data[4]
		pawn.damage=data[5]
		pawn.technique=12.0 if pawn.key=="atang" else 10.0
		pawn.attack_range=data[6]
		pawn.interval=data[7]
		var spawn=navigation.nearest(data[8],2.0)
		pawn.position=spawn if spawn!=null else data[8]
		pawn.position.y=deck_height(pawn.position)+0.015
		pawn.anchor=pawn.position
		pawn.goal=pawn.position
		pawn.set_meta("start",pawn.position)
		pawns.append(pawn)

func _build_boarding_bridge(port,wood,dark) -> void:
	var joints=[Vector3(-8.05,1.65,2.6),Vector3(-6.7,2.65,2.6),Vector3(-2.6,2.65,2.6),Vector3(-1.2,1.65,2.6)]
	for i in range(joints.size()-1):
		var a=joints[i];var b=joints[i+1];var offset=b-a
		var angle=atan2(offset.y,offset.x)
		var normal=Vector3(-sin(angle),cos(angle),0)
		var slab=port.box(self,(a+b)*0.5-normal*0.06,Vector3(offset.length(),0.12,1.05),wood)
		slab.rotation.z=angle
		if i!=1:
			for t in [0.2,0.4,0.6,0.8]:
				var cleat=port.box(self,a.lerp(b,t)+normal*0.025,Vector3(0.085,0.05,0.96),dark)
				cleat.rotation.z=angle
		for side in [-0.5,0.5]:
			port.cylinder_between(self,a+Vector3(0,0.67,side),b+Vector3(0,0.67,side),0.025,dark)
	for point in joints:
		for side in [-0.5,0.5]:port.cylinder_between(self,point+Vector3(0,0,side),point+Vector3(0,0.7,side),0.035,dark)

func deck_height(point: Vector3) -> float:
	return navigation.height(point)

func unit(key: String):
	for pawn in pawns:
		if pawn.key==key:return pawn
	return null

func reset(selected_trait: String,suppressed: bool) -> void:
	active=false
	result=""
	growth_trait=selected_trait
	followup_cd=0.0
	protect_cd=0.0
	hits=0
	dodged_heavy=0
	interrupted=0
	reservations.clear()
	navigation_replans=0
	invalid_orders=0
	for shot in shots:shot.mesh.queue_free()
	shots.clear()
	get_node("DeploymentArea").visible=true
	for pawn in pawns:
		pawn.hp=pawn.maximum
		pawn.position=pawn.get_meta("start")
		pawn.anchor=pawn.position
		pawn.goal=pawn.position
		pawn.moving_order=false
		pawn.target_key=""
		pawn.velocity=Vector3.ZERO
		pawn.action=""
		pawn.action_elapsed=0;pawn.action_duration=0;pawn.action_released=false;pawn.weapon_loaded=true
		pawn.cooldown=1.0
		pawn.skill_cd=3.0 if pawn.team==0 else 5.0
		pawn.broken=0
		pawn.hurt_left=0;pawn.hurt_elapsed=0;pawn.flash_left=0;pawn.death_time=0
		pawn.locomotion=preload("res://scripts/demo/locomotion.gd").new();pawn.locomotion_clip="idle";pawn.was_moving=false
		pawn.sprite.stop();pawn.sprite.play(pawn.direction+"_idle")
		pawn.stun=5.0 if suppressed and pawn.key=="guard" else 0.0
		pawn.surface.rotation.z=0
		pawn.route.clear();pawn.route_index=0;pawn.repath_left=0
		pawn.blocked_time=0;pawn.engagement_target="";pawn.attack_starts=0
		pawn.distance_walked=0;pawn.waiting_for_space=false

func deploy(key: String,point: Vector3) -> bool:
	var pawn=unit(key)
	if pawn==null or pawn.team!=0 or active:return false
	if not navigation.is_deployment(point):invalid_orders+=1;return false
	var destination=navigation.nearest(point,0.24)
	if destination==null or not navigation.is_deployment(destination):invalid_orders+=1;return false
	point=destination
	point.y=deck_height(point)+0.015
	for other in pawns:
		if other!=pawn and other.team==0 and other.position.distance_to(point)<1.0:return false
	pawn.position=point
	pawn.anchor=point
	pawn.goal=point
	return true

func preview_order(key: String,point: Vector3,deployment: bool=false) -> Dictionary:
	var pawn=unit(key)
	var invalid={"valid":false,"reason":"此处无法到达","point":point,"path":PackedVector3Array()}
	if pawn==null or pawn.hp<=0:return invalid
	if not navigation.contains(point):return invalid
	var goal=navigation.nearest(point,0.24)
	if goal==null:return invalid
	goal.y=deck_height(goal)+0.015
	invalid.point=goal
	if deployment:
		if not navigation.is_deployment(point) or not navigation.is_deployment(goal):invalid.reason="超出部署范围";return invalid
		for other in pawns:
			if other!=pawn and other.team==0 and other.position.distance_to(goal)<1.0:invalid.reason="已有队员占位";return invalid
	var route=navigation.path(pawn.position,goal,[] if deployment else pawns,pawn)
	if route.is_empty():invalid.reason="通道被阻挡";return invalid
	return {"valid":true,"reason":"","point":goal,"path":route}

func begin() -> void:
	active=true
	get_node("DeploymentArea").visible=false

func move_order(key: String,point: Vector3) -> bool:
	var pawn=unit(key)
	if pawn==null or pawn.hp<=0:return false
	if not navigation.contains(point):invalid_orders+=1;return false
	var destination=navigation.nearest(point,0.24)
	if destination==null:invalid_orders+=1;return false
	var route=navigation.path(pawn.position,destination,pawns,pawn)
	if route.is_empty():invalid_orders+=1;return false
	point=destination
	point.y=deck_height(point)+0.015
	pawn.goal=point
	pawn.anchor=point
	pawn.moving_order=true
	pawn.target_key=""
	pawn.route=route;pawn.route_index=0;pawn.planned_goal=point;pawn.repath_left=0.6
	pawn.blocked_time=0;pawn.waiting_for_space=false
	# Movement responds immediately. Released bolts remain in the scene; an
		# interrupted reload stays unloaded and restarts when the fighter is still.
	pawn.action="";pawn.action_elapsed=0
	reservations[pawn.key]=point
	return true

func target_order(key: String,target: String) -> bool:
	var pawn=unit(key)
	var enemy=unit(target)
	if pawn==null or enemy==null or enemy.hp<=0 or enemy.team==pawn.team:return false
	pawn.target_key=target
	pawn.moving_order=false
	pawn.repath_left=0
	pawn.route.clear()
	return true

func skill_order(key: String) -> bool:
	var pawn=unit(key)
	if pawn==null or pawn.hp<=0 or pawn.skill_cd>0 or not pawn.action.is_empty():return false
	if pawn.weapon_class=="crossbow" and (not pawn.weapon_loaded or pawn.cooldown>0):return false
	var enemy=pick_target(pawn)
	if enemy==null or pawn.position.distance_to(enemy.position)>pawn.attack_range+0.3 or not _can_attack(pawn,enemy):return false
	start_action(pawn,enemy,true)
	return true

func pick_target(pawn):
	if not pawn.target_key.is_empty():
		var target=unit(pawn.target_key)
		if target!=null and target.hp>0 and pawn.position.distance_to(target.position)<12.0:return target
	if not pawn.engagement_target.is_empty():
		var engaged=unit(pawn.engagement_target)
		if engaged!=null and engaged.hp>0 and pawn.position.distance_to(engaged.position)<=pawn.attack_range and _can_attack(pawn,engaged):return engaged
	# A fighter blocked in a narrow aisle can defend against a nearby opponent
	# instead of preserving an unreachable automatic target across the hatch.
	var immediate=null
	var immediate_distance=INF
	for other in pawns:
		if other.team==pawn.team or other.hp<=0:continue
		var current=pawn.position.distance_to(other.position)
		if current<=pawn.attack_range and current<immediate_distance and _can_attack(pawn,other):
			immediate=other;immediate_distance=current
	if immediate!=null:return immediate
	var closest=null
	var distance=10000.0
	for other in pawns:
		if other.team==pawn.team or other.hp<=0:continue
		if pawn.team==0 and other.position.distance_to(pawn.anchor)>8.5:continue
		var current=pawn.position.distance_to(other.position)
		if current<distance:closest=other;distance=current
	return closest

func tick(dt: float,held_key: String) -> void:
	if not active or not result.is_empty():return
	followup_cd=max(0.0,followup_cd-dt)
	protect_cd=max(0.0,protect_cd-dt)
	for pawn in pawns:
		pawn.set_meta("previous",pawn.position)
		pawn.velocity=Vector3.ZERO
		pawn.cooldown=max(0.0,pawn.cooldown-dt)
		pawn.skill_cd=max(0.0,pawn.skill_cd-dt)
		pawn.broken=max(0.0,pawn.broken-dt)
		pawn.stun=max(0.0,pawn.stun-dt)
		pawn.repath_left=max(0.0,pawn.repath_left-dt)
	for pawn in pawns:
		if pawn.hp<=0 or pawn.stun>0:continue
		if not pawn.action.is_empty():
			pawn.action_elapsed+=dt
			pawn.action_left-=dt
			if pawn.action!="reload" and not pawn.action_released and pawn.action_elapsed>=pawn.release_time:
				pawn.action_released=true;resolve_action(pawn)
			if pawn.action_left<=0:finish_action(pawn)
			continue
		if pawn.moving_order:
			walk(pawn,pawn.goal,dt)
			if pawn.position.distance_to(pawn.goal)<0.15:pawn.moving_order=false
			continue
		if pawn.weapon_class=="crossbow" and not pawn.weapon_loaded:
			start_reload(pawn);continue
		var enemy=pick_target(pawn)
		if enemy==null:continue
		var distance=pawn.position.distance_to(enemy.position)
		var advance=distance>pawn.attack_range or not _can_attack(pawn,enemy)
		# Front-line melee closes during recovery so it does not permanently
		# reserve the entire one-person aisle at maximum weapon reach.
		if pawn.weapon_class=="blade" and pawn.cooldown>0.25 and distance>0.92:advance=true
		if advance:
			if pawn.repath_left<=0 or pawn.engagement_target!=enemy.key:_plan_engagement(pawn,enemy)
			if not pawn.route.is_empty():_follow_route(pawn,dt)
		else:
			pawn.route.clear();pawn.waiting_for_space=false
			reservations[pawn.key]=pawn.position
			var use_skill=pawn.auto_skill and pawn.skill_cd<=0 and pawn.key!=held_key and pawn.key!="guard" and (pawn.weapon_class!="crossbow" or pawn.cooldown<=0)
			if use_skill:start_action(pawn,enemy,true)
			elif pawn.cooldown<=0:start_action(pawn,enemy,false)
	for i in range(shots.size()-1,-1,-1):
		var shot=shots[i]
		var old=shot.mesh.position
		shot.mesh.position+=shot.velocity*dt
		shot.life-=dt
		if not navigation.line_of_fire(old,shot.mesh.position):
			effects.burst(to_global(shot.mesh.position),"impact")
			shot.mesh.queue_free();shots.remove_at(i);continue
		var hit=null
		var nearest=2.0
		for pawn in pawns:
			if pawn.team==shot.team or pawn.hp<=0:continue
			var previous=pawn.get_meta("previous",pawn.position)+Vector3(0,1.0,0)
			var t=Rules.hull_hit(old,shot.mesh.position,previous,pawn.position+Vector3(0,1,0),0,Vector3(0.38,0.8,0.38),0.06)
			if t>=0 and t<nearest:nearest=t;hit=pawn
		if hit!=null:
			damage_target(hit,shot.damage,shot.skill)
			if shot.skill:
				hit.broken=4.5
				if hit.action=="heavy":hit.action="";hit.stun=0.7;interrupted+=1
		if hit!=null or shot.life<=0:
			shot.mesh.queue_free()
			shots.remove_at(i)
	if unit("captain").hp<=0:result="won";active=false
	elif unit("hero").hp<=0 and unit("atang").hp<=0:result="lost";active=false

func _can_attack(pawn,enemy) -> bool:
	if pawn.weapon_class=="crossbow":
		var aim=_shot_path(pawn,enemy,pawn.position)
		return navigation.line_of_fire(aim.origin,aim.target)
	return navigation.melee_clear(pawn.position,enemy.position)

func _shot_path(pawn,enemy,from_point: Vector3) -> Dictionary:
	# Query the facing/anchor at a possible firing position without rotating
	# the visible actor. Equal deck heights produce a level shot; a raised
	# opponent changes only the actual world-space elevation difference.
	var facing=pawn.direction_for_offset(to_global(enemy.position)-to_global(from_point),camera)
	var offset=global_basis.inverse()*(pawn.muzzle(camera,facing)-pawn.global_position)
	return {"origin":from_point+offset,"target":enemy.position+Vector3.UP*offset.y}

func _slot_free(point: Vector3,pawn) -> bool:
	for other in pawns:
		if other==pawn or other.hp<=0:continue
		if Vector2(point.x-other.position.x,point.z-other.position.z).length()<0.76:return false
		if reservations.has(other.key) and Vector2(point.x-reservations[other.key].x,point.z-reservations[other.key].z).length()<0.72:return false
	return true

func _plan_engagement(pawn,preferred) -> void:
	reservations.erase(pawn.key)
	pawn.repath_left=0.55
	pawn.engagement_target=preferred.key
	var targets=[preferred]
	if pawn.target_key.is_empty():
		for other in pawns:
			if other!=preferred and other.hp>0 and other.team!=pawn.team:targets.append(other)
	var best_path=PackedVector3Array()
	var best_point=pawn.position
	var best_target=preferred
	var best_cost=INF
	for enemy in targets:
		var reach=pawn.attack_range-0.04
		if pawn.weapon_class=="crossbow":reach=min(reach,4.4)
		var candidates=[]
		# Use real floor samples: polar slots miss small valid regions near
		# hatch corners, ramps and railings on this narrow retained vessel.
		for snapped in navigation.points.values():
			var separation=snapped.distance_to(enemy.position)
			if separation>reach or separation<0.76 or not _slot_free(snapped,pawn):continue
			if pawn.weapon_class=="crossbow":
				var aim=_shot_path(pawn,enemy,snapped)
				if not navigation.line_of_fire(aim.origin,aim.target):continue
			elif not navigation.melee_clear(snapped,enemy.position):continue
			var crowd_cost=absf(separation-0.88)*6.0 if pawn.weapon_class=="blade" else 0.0
			candidates.append({"point":snapped,"cost":pawn.position.distance_to(snapped)+crowd_cost})
		candidates.sort_custom(func(a,b):return a.cost<b.cost)
		for candidate in candidates.slice(0,24):
			var route=navigation.path(pawn.position,candidate.point,pawns,pawn)
			if route.is_empty():continue
			var cost=navigation.route_length(route)+candidate.cost*0.4+(0.0 if enemy==preferred else 1.5)
			if cost<best_cost:best_cost=cost;best_path=route;best_point=candidate.point;best_target=enemy
	pawn.route=best_path;pawn.route_index=0;pawn.planned_goal=best_point
	pawn.engagement_target=best_target.key
	pawn.waiting_for_space=best_path.is_empty()
	if not best_path.is_empty():reservations[pawn.key]=best_point
	navigation_replans+=1

func walk(pawn,goal: Vector3,dt: float) -> void:
	if pawn.repath_left<=0 or pawn.planned_goal.distance_to(goal)>0.3 or pawn.route.is_empty():
		pawn.route=navigation.path(pawn.position,goal,pawns,pawn)
		pawn.route_index=0;pawn.planned_goal=goal;pawn.repath_left=0.55
		pawn.waiting_for_space=pawn.route.is_empty()
		if pawn.route.is_empty():return
	_follow_route(pawn,dt)

func _follow_route(pawn,dt: float) -> void:
	while pawn.route_index<pawn.route.size() and pawn.position.distance_to(pawn.route[pawn.route_index])<0.10:
		pawn.route_index+=1
	if pawn.route_index>=pawn.route.size():pawn.route.clear();return
	var goal=pawn.route[pawn.route_index]
	var vector=goal-pawn.position
	vector.y=0
	if vector.length()<0.001:return
	var point=pawn.position+vector.normalized()*minf(pawn.speed*dt,vector.length())
	for other in pawns:
		if other==pawn or other.hp<=0:continue
		var delta=Vector2(point.x-other.position.x,point.z-other.position.z)
		if delta.length()<0.67:
			pawn.blocked_time+=dt
			pawn.waiting_for_space=true
			if pawn.blocked_time>0.22:pawn.repath_left=0;pawn.route.clear()
			return
	if not navigation.contains(point):pawn.repath_left=0;pawn.route.clear();return
	point.y=deck_height(point)+0.015
	pawn.velocity=(point-pawn.position)/maxf(dt,0.0001)
	pawn.distance_walked+=pawn.position.distance_to(point)
	pawn.position=point
	pawn.blocked_time=0;pawn.waiting_for_space=false

func start_action(pawn,enemy,skill: bool) -> void:
	pawn.attack_starts+=1
	pawn.face_target(enemy.global_position,camera)
	pawn.action_target=enemy.key
	pawn.action_position=enemy.position
	pawn.action="attack"
	pawn.action_left=0.25
	pawn.cooldown=pawn.interval
	if skill:
		pawn.action="skill"
		pawn.skill_cd=8.0 if pawn.key=="hero" else 10.0
		pawn.action_left=0.38
		if pawn.key=="captain":
			pawn.action="heavy"
			pawn.action_left=1.4
			pawn.skill_cd=9.0
	pawn.action_elapsed=0;pawn.action_released=false
	pawn.action_duration=pawn.action_left
	pawn.release_time=pawn.action_left
	var clip=pawn.motion_clip("shoot" if pawn.weapon_class=="crossbow" else ("heavy" if pawn.action=="heavy" else "attack"))
	if not clip.is_empty():
		pawn.action_duration=float(clip.duration);pawn.action_left=pawn.action_duration
		pawn.release_time=float(clip.get("release_time",pawn.action_duration*0.45))
	if pawn.action=="heavy":telegraph(pawn.action_position,1.9,pawn.release_time)
	# The projectile aim is fixed at commitment. Moving targets can leave this
	# direction; the frozen animation never emits a bolt toward its own back.
	var aim=_shot_path(pawn,enemy,pawn.position)
	pawn.shot_direction=aim.target-aim.origin
	var toward=enemy.position-pawn.position;toward.y=0
	var shot_flat=Vector3(pawn.shot_direction.x,0,pawn.shot_direction.z)
	# At contact range the opponent can overlap the authored bow tip. Keep
	# travel forward; the swept collision still resolves the actual overlap.
	if not toward.is_zero_approx() and shot_flat.dot(toward)<=0:
		pawn.shot_direction.x=toward.x;pawn.shot_direction.z=toward.z

func start_reload(pawn) -> void:
	pawn.action="reload";pawn.action_elapsed=0;pawn.action_released=false
	pawn.action_duration=0.9;pawn.action_left=pawn.action_duration
	var clip=pawn.motion_clip("reload")
	if not clip.is_empty():pawn.action_duration=float(clip.duration);pawn.action_left=pawn.action_duration

func finish_action(pawn) -> void:
	if pawn.action=="reload":pawn.weapon_loaded=true
	pawn.action="";pawn.action_elapsed=0
	if pawn.weapon_class=="crossbow" and not pawn.weapon_loaded and not pawn.moving_order:start_reload(pawn)

func telegraph(center: Vector3,radius: float,life: float) -> void:
	for i in range(40):
		var a=center+Vector3(cos(float(i)*TAU/40),0,sin(float(i)*TAU/40))*radius
		var b=center+Vector3(cos(float(i+1)*TAU/40),0,sin(float(i+1)*TAU/40))*radius
		if not navigation.contains(a) or not navigation.contains(b):continue
		a.y=deck_height(a)+0.045
		b.y=deck_height(b)+0.045
		effects.line(to_global(a),to_global(b),0.027,Color(0.78,0.35,0.21,0.88),life)

func resolve_action(pawn) -> void:
	var action=pawn.action
	if action=="heavy":
		var connected=false
		for target in pawns:
			if target.team!=pawn.team and target.hp>0 and target.position.distance_to(pawn.action_position)<1.9:
				damage_target(target,30,false);connected=true
		effects.burst(to_global(pawn.action_position+Vector3(0,0.3,0)),"impact")
		if not connected:dodged_heavy+=1
		return
	var enemy=unit(pawn.action_target)
	if enemy==null or enemy.hp<=0:return
	if pawn.weapon_class=="crossbow":
		if not pawn.weapon_loaded:return
		pawn.weapon_loaded=false
		var origin=to_local(pawn.muzzle(camera))
		var aim=origin+pawn.shot_direction
		var mesh=effects.arrow(to_global(origin),(aim-origin).normalized())
		mesh.reparent(self)
		shots.append({"mesh":mesh,"velocity":(aim-origin).normalized()*17.0,"life":1.2,"team":pawn.team,"damage":pawn.damage+pawn.technique*0.6 if action=="skill" else pawn.damage,"skill":action=="skill"})
	else:
		if pawn.position.distance_to(enemy.position)>pawn.attack_range+0.5:return
		if not _can_attack(pawn,enemy):return
		var damage=pawn.damage*1.5+pawn.technique*0.48 if action=="skill" else pawn.damage
		if pawn.key=="hero" and growth_trait=="pursuit" and enemy.broken>0 and followup_cd<=0:
			damage+=14
			followup_cd=4.0
			effects.ring(enemy.global_position+Vector3(0,0.06,0),0.8,Color("d9c27d"),0.4)
		damage_target(enemy,damage,action=="skill")
		effects.slash(pawn.global_position+Vector3(0,1.2,0),enemy.global_position+Vector3(0,0.75,0))
		effects.play("swing")

func damage_target(pawn,amount: float,_special: bool) -> void:
	if pawn.team==0 and growth_trait=="guard" and protect_cd<=0:
		var hero=unit("hero")
		if hero.hp>0 and hero.position.distance_to(pawn.position)<3.3:
			amount*=0.45
			protect_cd=4.0
			effects.ring(pawn.global_position+Vector3(0,0.08,0),0.85,Color("adc6b4"),0.55)
	pawn.hurt(amount)
	hits+=1
	effects.burst(pawn.global_position+Vector3(0,1.0,0),"impact")

func update_visual(dt: float,selected_key: String,presentation_dt: float=-1.0) -> void:
	elapsed+=dt
	water_material.set_shader_parameter("clock",elapsed)
	var settling=not result.is_empty() and presentation_dt>=0
	var visual_dt=presentation_dt if settling else dt
	if settling:
		# Finish visible recovery/death during the result dialogue without
		# resolving any new attacks. Explicit user pause still supplies zero.
		for i in range(shots.size()-1,-1,-1):
			var shot=shots[i];var previous=shot.mesh.position
			shot.mesh.position+=shot.velocity*visual_dt;shot.life-=visual_dt
			if shot.life<=0 or not navigation.line_of_fire(previous,shot.mesh.position):
				shot.mesh.queue_free();shots.remove_at(i)
	for pawn in pawns:
		if settling:
			pawn.velocity=Vector3.ZERO
			if pawn.hp>0 and not pawn.action.is_empty():
				pawn.action_elapsed+=visual_dt;pawn.action_left-=visual_dt;pawn.action_released=true
				if pawn.action_left<=0:finish_action(pawn)
		pawn.selected=pawn.key==selected_key
		pawn.show_name=not active and result.is_empty()
		pawn.visual(camera,visual_dt)
		if settling and pawn.hp>0 and pawn.action.is_empty():
			pawn.sprite.speed_scale=1.0/maxf(Engine.time_scale,.001) if visual_dt>0 else 0
