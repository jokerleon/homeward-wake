extends Node3D
const Rules=preload("res://scripts/demo/rules.gd")
const ShipVisual=preload("res://scripts/demo/ship_visual.gd")
const OceanState=preload("res://scripts/demo/ocean_state.gd")
const Weather=preload("res://scripts/demo/weather_visual.gd")
var ocean=OceanState.new()
var weather_visual
var ships=[]
var shots=[]
var effects
var water_material
var state="sailing"
var escape_time=0.0
var elapsed=0.0
var suppressed=false
var special_used=false
var special_pending=false
var launched=0
var impacts=0
var misses=0
var entered=0
var escaped=0
var enemy_home=Vector3(16,0,-23)
var fit="hull"
var active=false
var gravity=Vector3(0,-4.5,0)
var wake_history=[[],[]]
var wake_timer=0.0

func setup(port,fx) -> void:
	effects=fx
	var water=MeshInstance3D.new()
	var plane=PlaneMesh.new()
	plane.size=Vector2(900,900)
	plane.subdivide_width=300;plane.subdivide_depth=300
	water.mesh=plane
	water.position.y=0.18
	water.layers=2
	water_material=port.water_material.duplicate()
	water_material.shader=load("res://shaders/demo_ocean.gdshader")
	water_material.set_shader_parameter("reflection_tex",port.reflection_view.get_texture())
	water_material.set_shader_parameter("ripple_sources",PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]))
	water.material_override=water_material
	add_child(water)
	weather_visual=Weather.new();add_child(weather_visual);weather_visual.setup()
	weather_visual.bind_environment(port.sun,port.get_world_3d().environment)
	port.box(self,Vector3(0,-4.1,0),Vector3(900,0.2,900),port.paint_materials.stone)
	for side in range(2):
		var root=Node3D.new()
		root.name="PlayerVessel" if side==0 else "RaiderVessel"
		add_child(root)
		var model=load("res://assets/quay-v03/merchant-ship-a.glb").instantiate()
		model.rotation.y=PI*0.5
		root.add_child(model)
		var color=Color("b9c7aa") if side==0 else Color("a9634b")
		port.box(root,Vector3(0,9.5,1.7),Vector3(0.95,0.48,0.03),port.solid(color))
		var barrels=[]
		for sign_side in [-1,1]:
			for z in [-1.4,0.0,1.4]:
				port.box(root,Vector3(sign_side*1.8,1.55,z),Vector3(0.6,0.25,0.55),port.paint_materials.darkwood)
				var barrel=port.cylinder_between(root,Vector3(sign_side*1.5,1.85,z),Vector3(sign_side*2.6,1.85,z),0.13,port.paint_materials.metal)
				barrels.append({"node":barrel,"rest":barrel.position,"side":sign_side})
		var label=Label3D.new()
		label.font=SystemFont.new()
		label.font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
		label.font_size=42
		label.pixel_size=0.026
		label.position=Vector3(0,12.8,0)
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate=Color("f3e8d2")
		label.outline_size=8
		root.add_child(label)
		ShipVisual.prepare(root)
		var paint=ShaderMaterial.new();paint.shader=load("res://shaders/demo_ship.gdshader")
		for part in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(part.mesh.get_surface_count()):
				var original=part.get_active_material(surface)
				if original is StandardMaterial3D:
					paint.set_shader_parameter("paint_texture",original.albedo_texture)
					paint.set_shader_parameter("base_color",original.albedo_color)
					part.set_surface_override_material(surface,paint)
		ships.append({"node":root,"model":model,"paint":paint,"label":label,"team":side,"hp":180.0,"maximum":180.0,"speed":0.0,"velocity":Vector3.ZERO,"previous":Vector3.ZERO,"yaw":0.0,"previous_yaw":0.0,"turn_rate":0.0,"reload":2.0,"loaded":"hull","pending":"hull","goal":Vector3.ZERO,"intent":"sail","windup":0.0,"disabled":false,"home":enemy_home})
		ships.back().barrels=barrels;ships.back().recoil=0.0;ships.back().firing_side=0.0;ships.back().hit_flash=0.0
	# A distant shore identifies this as the same small coastal region without creating an arena.
	var shore=Sprite3D.new()
	shore.texture=load("res://assets/quay-v03/far-shore.png")
	shore.pixel_size=0.045
	shore.position=Vector3(0,20,-125)
	shore.shaded=false
	shore.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	shore.modulate=Color("91abaa")
	shore.layers=5
	add_child(shore)

func reset(selected_fit: String) -> void:
	fit=selected_fit
	state="sailing"
	escape_time=0
	elapsed=0
	ocean.elapsed=0
	ocean.configure(0.12,0.35,0,true)
	suppressed=false
	special_used=false
	special_pending=false
	wake_history=[[],[]]
	wake_timer=0.0
	for shot in shots:shot.mesh.queue_free()
	shots.clear()
	for ship in ships:
		ship.hp=220.0 if ship.team==0 and fit=="hull" else 180.0
		ship.maximum=ship.hp
		ship.node.position=Vector3(-17,0,28) if ship.team==0 else enemy_home
		ship.previous=ship.node.position
		ship.yaw=0.0 if ship.team==0 else PI
		ship.node.rotation.y=ship.yaw
		ship.speed=0.0
		ship.velocity=Vector3.ZERO
		ship.reload=3.0 if ship.team==0 else 5.0
		ship.loaded="hull"
		ship.pending="hull"
		ship.goal=Vector3(-17,0,-38) if ship.team==0 else enemy_home+Vector3(0,0,12)
		ship.intent="sail" if ship.team==0 else "patrol"
		ship.windup=0.0
		ship.disabled=false
		ship.recoil=0.0;ship.hit_flash=0.0
	active=true

func direction(yaw: float) -> Vector3:
	return Vector3(-sin(yaw),0,-cos(yaw))

func move_order(point: Vector3) -> void:
	ships[0].goal=Vector3(point.x,0,point.z)
	ships[0].intent="sail"

func engage() -> void:
	ships[0].intent="engage"
	if not ships[1].disabled:_enter_combat()

func retreat() -> void:
	var away=ships[0].node.position-ships[1].node.position
	if away.length()<0.1:away=Vector3.BACK
	ships[0].goal=ships[0].node.position+away.normalized()*130.0
	ships[0].intent="retreat"

func switch_ammo() -> void:
	ships[0].pending="pressure" if ships[0].pending=="hull" else "hull"

func special() -> bool:
	if special_used or ships[1].disabled:return false
	special_pending=true
	return true

func _enter_combat() -> void:
	if state=="sailing":entered+=1
	state="combat"
	escape_time=0.0
	ships[1].intent="engage"

func tick(dt: float) -> void:
	if not active:return
	elapsed+=dt
	ocean.tick(dt);ocean.apply(water_material)
	effects.wind=Vector3(ocean.wind_direction.x,0,ocean.wind_direction.y)*ocean.wind_strength
	var distance=ships[0].node.position.distance_to(ships[1].node.position)
	if state=="sailing" and distance<44.0 and not ships[1].disabled:_enter_combat()
	for ship in ships:ship.previous=ship.node.position;ship.previous_yaw=ship.yaw
	for ship in ships:
		var enemy=ships[1-ship.team]
		ship.reload=max(0.0,ship.reload-dt)
		if ship.hp<=0 or ship.disabled:
			ship.speed=move_toward(ship.speed,0.0,dt*2)
			ship.velocity=Vector3.ZERO
			_update_vessel_float(ship,dt)
			continue
		var desired=ship.goal-ship.node.position
		desired.y=0.0 # Wave heave must not create a steering direction at a reached goal.
		var wanted_speed=5.5 if ship.team==0 else 4.5
		if ship.intent=="engage":
			var toward=enemy.node.position-ship.node.position
			var tangent=Vector3(-toward.z,0,toward.x).normalized()
			var range_correction=toward.normalized()*clamp((toward.length()-27.0)/12.0,-1.3,1.0)
			desired=(tangent+range_correction).normalized()
			wanted_speed=3.0 if toward.length()<36 else wanted_speed
			if enemy.disabled:
				ship.intent="sail"
				ship.goal=enemy.node.position+Vector3(-12,0,0)
		elif desired.length()<2.2:
			wanted_speed=0.0
			if ship.intent=="patrol":ship.goal=ship.home+Vector3(0,0,14 if ship.node.position.z<ship.home.z else -14)
		if desired.length()>0.1:
			var yaw=atan2(-desired.x,-desired.z)
			ship.yaw=rotate_toward(ship.yaw,yaw,dt*0.53)
		var forward=direction(ship.yaw)
		ship.speed=move_toward(ship.speed,wanted_speed,dt*1.6)
		var movement=forward*ship.speed*dt
		var next=ship.node.position+movement
		# Conservative proximity steering prevents either hull from driving through the other.
		if next.distance_to(enemy.node.position)<11.0 and movement.dot(enemy.node.position-ship.node.position)>0:
			ship.yaw+=dt*0.8
			movement*=0.15
		ship.node.position+=movement
		ship.velocity=movement/max(dt,0.00001)
		_update_vessel_float(ship,dt)
	# Fire only after both vessels have their current transforms, so visual
	# muzzle positions, predicted aims and swept collision share one frame.
	for ship in ships:
		var enemy=ships[1-ship.team]
		var forward=direction(ship.yaw)
		if ship.hp<=0 or ship.disabled:continue
		if state!="sailing" and ship.intent!="retreat" and ship.intent!="return" and not enemy.disabled:
			var offset=enemy.node.position-ship.node.position
			var can_shoot=offset.length()<43.0 and Rules.broadside(forward,offset)
			if ship.reload<=0 and can_shoot and ship.windup<=0:ship.windup=0.85
			if ship.windup>0:
				ship.windup-=dt
				if ship.windup<=0 and can_shoot:fire(ship)
		else:ship.windup=0
	_tick_shots(dt)
	distance=ships[0].node.position.distance_to(ships[1].node.position)
	if ships[1].hp<=45.0 and not ships[1].disabled:
		ships[1].disabled=true
		ships[1].intent="disabled"
		state="disabled"
	if not ships[1].disabled and state!="sailing":
		if ships[1].node.position.distance_to(enemy_home)>105.0:ships[1].intent="return";ships[1].goal=enemy_home
		var separated=distance>67.0 or (ships[1].intent=="return" and distance>45.0)
		if separated and shots.is_empty():escape_time+=dt
		else:escape_time=0.0
		if escape_time>=6.0:
			state="sailing"
			escaped+=1
			ships[1].intent="return"
			ships[1].goal=enemy_home
			ships[0].intent="sail"
			# HP, loading, ammo, special use, and the same enemy instance are deliberately retained.
	for ship in ships:
		if ship.intent=="return" and ship.node.position.distance_to(enemy_home)<3.0:ship.intent="patrol"
		var label="归舟" if ship.team==0 else "陌生帆船"
		ship.label.text=label+"  "+str(int(ceil(ship.hp)))+"/"+str(int(ship.maximum))
		if ship.disabled:ship.label.text+="\n已停航 · 可接舷"
		elif ship.windup>0:ship.label.text+="\n炮口正在转向！"
	water_material.set_shader_parameter("ships",PackedVector4Array([Vector4(ships[0].node.position.x,ships[0].node.position.z,ships[0].yaw,ships[0].velocity.length()),Vector4(ships[1].node.position.x,ships[1].node.position.z,ships[1].yaw,ships[1].velocity.length())]))
	water_material.set_shader_parameter("turn_rates",PackedFloat32Array([ships[0].turn_rate,ships[1].turn_rate]))
	weather_visual.update_weather(ocean,ships[0].node.position)
	_update_wakes(dt)

func _update_vessel_float(ship,dt: float) -> void:
	var position=ship.node.position
	var forward=direction(ship.yaw);var right=Vector3(-forward.z,0,forward.x)
	ship.node.position.y=ocean.height_at(position)-ocean.level
	var pitch=atan2(ocean.height_at(position+forward*3.0)-ocean.height_at(position-forward*3.0),6.0)
	var roll=atan2(ocean.height_at(position+right*1.8)-ocean.height_at(position-right*1.8),3.6)
	ship.node.rotation=Vector3(pitch,ship.yaw,-roll)
	ship.turn_rate=wrapf(ship.yaw-ship.previous_yaw,-PI,PI)/maxf(dt,0.001)
	ship.paint.set_shader_parameter("clock",elapsed)
	ship.paint.set_shader_parameter("wetness",ocean.wetness)
	ship.paint.set_shader_parameter("wind_strength",ocean.wind_strength)
	ship.paint.set_shader_parameter("wind_local",ship.model.global_basis.inverse()*Vector3(ocean.wind_direction.x,0,ocean.wind_direction.y))
	ship.hit_flash=maxf(0,ship.hit_flash-dt)
	ship.paint.set_shader_parameter("hit_flash",ship.hit_flash/0.18)
	_update_cannon_recoil(ship,dt)

func _update_cannon_recoil(ship,dt: float) -> void:
	ship.recoil=maxf(0,ship.recoil-dt*3.4)
	for barrel in ship.barrels:
		barrel.node.position=barrel.rest
		if barrel.side==ship.firing_side:barrel.node.position.x-=barrel.side*0.19*ship.recoil*ship.recoil

func _update_wakes(dt: float) -> void:
	wake_timer+=dt
	for history in wake_history:
		for point in history:point.age+=dt
	if wake_timer>=0.32:
		wake_timer=0.0
		for ship in ships:
			var history=wake_history[ship.team]
			if ship.velocity.length()>0.2:
				var stern=ship.node.position+Basis(Vector3.UP,ship.yaw)*Vector3(0,0,6.3)
				if history.is_empty() or history[0].point.distance_to(Vector2(stern.x,stern.z))>0.12:history.push_front({"point":Vector2(stern.x,stern.z),"age":0.0,"speed":ship.velocity.length()})
			while history.size()>24:history.pop_back()
	var points=PackedVector4Array()
	points.resize(48)
	points.fill(Vector4.ZERO)
	for side in range(2):
		for i in range(wake_history[side].size()):
			var point=wake_history[side][i]
			points[side*24+i]=Vector4(point.point.x,point.point.y,1.3+point.age*0.22,max(0.0,1.0-point.age/8.0)*min(point.speed/4.5,1.0))
	water_material.set_shader_parameter("wake_points",points)

func fire(ship) -> void:
	var target=ships[1-ship.team]
	if target.disabled:return
	var local=Basis(Vector3.UP,ship.yaw).inverse()*(target.node.position-ship.node.position)
	var side=sign(local.x)
	if side==0:side=1.0
	var special_shot=ship.team==0 and special_pending and not special_used
	var ammo=ship.loaded
	for z in [-1.4,0.0,1.4]:
		var origin=ship.node.transform*Vector3(side*2.65,1.85,z)
		var flight=clamp(origin.distance_to(target.node.position)/28.0,0.55,2.0)
		var aim=target.node.position+Vector3(0,1.4,0)+target.velocity*flight*0.72
		# Fixed deterministic salvo spread. No target reference is used to steer a launched ball.
		aim+=Basis(Vector3.UP,target.yaw)*Vector3(z*0.18,0,z*0.30)
		launch(origin,Rules.launch_velocity(origin,aim,flight,gravity),ship.team,ammo,special_shot)
		effects.burst(to_global(origin),"cannon",(aim-origin).normalized())
	ship.reload=6.6 if ship.team==0 and fit=="mount" else (8.0 if ship.team==0 else 10.0)
	ship.loaded=ship.pending
	ship.windup=0.0
	ship.recoil=1.0;ship.firing_side=side;_update_cannon_recoil(ship,0)
	if special_shot:special_used=true;special_pending=false

func launch(origin: Vector3,velocity: Vector3,team: int,ammo: String,suppressive: bool=false) -> void:
	var node=effects.cannonball(to_global(origin))
	node.reparent(self)
	shots.append({"mesh":node,"velocity":velocity,"team":team,"ammo":ammo,"suppressive":suppressive,"life":5.0,"history":[origin],"trail_left":0.0})
	launched+=1

func _tick_shots(dt: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var shot=shots[i]
		var old=shot.mesh.position
		var next=old+shot.velocity*dt+gravity*dt*dt*0.5
		shot.velocity+=gravity*dt
		shot.life-=dt
		var target=ships[1-shot.team]
		var center=Vector3(0,1.25,0)
		var t=Rules.hull_hit(old,next,target.previous+center,target.node.position+center,target.yaw,Vector3(2.25,1.45,7.1),0.19)
		var water_t=ocean.water_hit_fraction(old,next,dt)
		var hit=t>=0 and t<water_t and target.hp>0
		if hit:
			var damage=6.0 if shot.ammo=="pressure" or shot.suppressive else 12.0
			target.hp=max(0.0,target.hp-damage)
			if shot.team==0 and (shot.ammo=="pressure" or shot.suppressive):suppressed=true
			impacts+=1
			target.hit_flash=0.18
			effects.burst(to_global(old.lerp(next,t)),"hull",shot.velocity.normalized())
		elif water_t<=1.0 or shot.life<=0:
			misses+=1
			var splash=old.lerp(next,clamp(water_t,0.0,1.0))
			splash.y=ocean.height_at(splash)+0.02
			effects.burst(to_global(splash),"splash")
		else:
			shot.mesh.position=next
			shot.history.append(next)
			while shot.history.size()>5:shot.history.pop_front()
			shot.trail_left-=dt
			if shot.trail_left<=0:
				effects.flight_streak(to_global(shot.history[0]),to_global(next));shot.trail_left=0.045
		if hit or water_t<=1.0 or shot.life<=0:
			shot.mesh.queue_free()
			shots.remove_at(i)

func can_board() -> bool:
	return ships[1].disabled and ships[0].hp>0 and shots.is_empty() and ships[0].node.position.distance_to(ships[1].node.position)<20.0

func close_to_board() -> void:
	ships[0].intent="sail"
	ships[0].goal=ships[1].node.position+Vector3(-14,0,0)

func snapshot() -> Dictionary:
	var data={"fit":fit,"state":state,"suppressed":suppressed,"special_used":special_used,"special_pending":special_pending,"escape_time":escape_time,"elapsed":elapsed,"weather":ocean.snapshot(),"ships":[]}
	for ship in ships:
		data.ships.append({"position":[ship.node.position.x,ship.node.position.y,ship.node.position.z],"goal":[ship.goal.x,ship.goal.y,ship.goal.z],"yaw":ship.yaw,"speed":ship.speed,"intent":ship.intent,"windup":ship.windup,"hp":ship.hp,"maximum":ship.maximum,"reload":ship.reload,"loaded":ship.loaded,"pending":ship.pending,"disabled":ship.disabled})
	return data

func restore(data: Dictionary) -> void:
	reset(data.get("fit","hull"))
	state=data.get("state","sailing")
	suppressed=data.get("suppressed",false)
	special_used=data.get("special_used",false)
	special_pending=data.get("special_pending",false)
	escape_time=data.get("escape_time",0.0)
	elapsed=data.get("elapsed",0.0)
	ocean.restore(data.get("weather",{}))
	for i in range(min(ships.size(),data.ships.size())):
		var saved=data.ships[i]
		var ship=ships[i]
		ship.node.position=Vector3(saved.position[0],saved.position[1],saved.position[2])
		ship.previous=ship.node.position
		var goal=saved.get("goal",saved.position)
		ship.goal=Vector3(goal[0],goal[1],goal[2])
		ship.yaw=saved.yaw
		ship.node.rotation.y=ship.yaw
		ship.speed=saved.get("speed",0.0)
		ship.velocity=direction(ship.yaw)*ship.speed
		ship.windup=saved.get("windup",0.0)
		ship.hp=saved.hp
		ship.maximum=saved.maximum
		ship.reload=saved.reload
		ship.loaded=saved.loaded
		ship.pending=saved.pending
		ship.disabled=saved.disabled
		ship.intent=saved.get("intent","disabled" if ship.disabled else ("engage" if state=="combat" else "sail"))
