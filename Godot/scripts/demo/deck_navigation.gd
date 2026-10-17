extends RefCounted

const PROFILE="res://assets/demo/merchant-ship-navigation.json"
const PICK_LAYER=16384
var profile={}
var surface={}
var ships=[Vector3.ZERO,Vector3(-9.3,0,1.2)]
var graph=AStar3D.new()
var points={}
var cells={}
var boundary=PackedVector2Array()
var deployment=PackedVector2Array()
var row_medians=[]
var spacing=0.15
var radius=0.32
var low=Vector2(-11.55,-4.95)
var columns=94
var rows=74
var floor_faces=PackedVector3Array()
var disabled=[]
var hull_obstacles=[]

func setup() -> void:
	profile=JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	surface=JSON.parse_string(FileAccess.get_file_as_string(profile.surface_source))
	spacing=float(profile.spacing)
	radius=float(profile.actor_radius)
	for p in profile.boundary_xz:boundary.append(Vector2(p[0],p[1]))
	for p in profile.deployment_xz:deployment.append(Vector2(p[0],p[1]))
	for row in range(int(surface.nz)):
		var values=[]
		for col in range(int(surface.nx)):
			var v=surface.heights[row*int(surface.nx)+col]
			if v!=null:values.append(float(v))
		values.sort()
		row_medians.append(values[values.size()/2] if not values.is_empty() else 1.6)
	for offset in ships:
		for obstacle in profile.obstacles:
			var item=obstacle.duplicate(true)
			item.center=Vector2(obstacle.center[0]+offset.x,obstacle.center[1]+offset.z)
			hull_obstacles.append(item)
		# Cabins are outside the walk surface but can obstruct ranged attacks.
		hull_obstacles.append({"kind":"box","center":Vector2(offset.x,offset.z+5.85),"size":[3.8,2.65],"height":3.9,"name":"stern-cabin"})
	_build()

func _inside(point: Vector2,polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(point,polygon)

func _source_height(point: Vector2):
	var fx=(point.x-float(surface.x_min))/float(surface.spacing)
	var fz=(point.y-float(surface.z_min))/float(surface.spacing)
	var ix=int(round(fx))
	var iz=int(round(fz))
	if ix<0 or iz<0 or ix>=int(surface.nx) or iz>=int(surface.nz):return null
	var value=surface.heights[iz*int(surface.nx)+ix]
	if value==null:return null
	if float(value)>float(row_medians[iz])+float(profile.surface_outlier_limit):return null
	return float(value)

func _bridge_height(point: Vector2):
	if abs(point.y-2.6)>0.525:return null
	if point.x>=-8.05 and point.x<=-6.7:return lerp(1.65,2.65,(point.x+8.05)/1.35)
	if point.x>=-6.7 and point.x<=-2.6:return 2.65
	if point.x>=-2.6 and point.x<=-1.2:return lerp(2.65,1.65,(point.x+2.6)/1.4)
	return null

func raw_height(point: Vector2):
	var bridge=_bridge_height(point)
	if bridge!=null:return bridge
	for offset in ships:
		var local=point-Vector2(offset.x,offset.z)
		if not _inside(local,boundary):continue
		var value=_source_height(local)
		if value!=null:return value
	return null

func _obstructed(point: Vector2,margin: float) -> bool:
	for offset in ships:
		var p=point-Vector2(offset.x,offset.z)
		for obstacle in profile.obstacles:
			var center=Vector2(obstacle.center[0],obstacle.center[1])
			if obstacle.kind=="circle":
				if p.distance_to(center)<float(obstacle.radius)+margin:return true
			else:
				var half=Vector2(obstacle.size[0],obstacle.size[1])*0.5+Vector2.ONE*margin
				if abs(p.x-center.x)<half.x and abs(p.y-center.y)<half.y:return true
	return false

func clear_position(point: Vector3) -> bool:
	var p=Vector2(point.x,point.z)
	var height=raw_height(p)
	if height==null or _obstructed(p,radius):return false
	for i in range(8):
		var sample=p+Vector2(cos(i*TAU/8.0),sin(i*TAU/8.0))*radius
		var h=raw_height(sample)
		if h==null or abs(float(h)-float(height))>0.42:return false
	return true

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi((point.x-low.x)/spacing),roundi((point.z-low.y)/spacing))

func _id(cell: Vector2i) -> int:
	return cell.y*columns+cell.x

func contains(point: Vector3) -> bool:
	return clear_position(point) and nearest(point,spacing*0.8)!=null

func height(point: Vector3) -> float:
	var value=raw_height(Vector2(point.x,point.z))
	return float(value) if value!=null else NAN

func nearest(point: Vector3,max_distance: float=0.30):
	var center=_cell(point)
	var spread=ceili(max_distance/spacing)+1
	var best=null
	var distance=max_distance
	for row in range(center.y-spread,center.y+spread+1):
		for col in range(center.x-spread,center.x+spread+1):
			var cell=Vector2i(col,row)
			if not cells.has(cell):continue
			var p=points[cells[cell]]
			var d=Vector2(point.x-p.x,point.z-p.z).length()
			if d<=distance:distance=d;best=p
	return best

func is_deployment(point: Vector3) -> bool:
	return contains(point) and _inside(Vector2(point.x,point.z),deployment)

func _build() -> void:
	graph.clear();points.clear();cells.clear();floor_faces.clear()
	for row in range(rows):
		for col in range(columns):
			var point=Vector3(low.x+col*spacing,0,low.y+row*spacing)
			if not clear_position(point):continue
			point.y=height(point)
			var cell=Vector2i(col,row)
			var id=_id(cell)
			graph.add_point(id,point)
			points[id]=point;cells[cell]=id
	for cell in cells:
		for delta in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
			var other=cell+delta
			if not cells.has(other):continue
			if delta.x!=0 and delta.y!=0:
				if not cells.has(cell+Vector2i(delta.x,0)) or not cells.has(cell+Vector2i(0,delta.y)):continue
			var a=points[cells[cell]];var b=points[cells[other]]
			if abs(a.y-b.y)<=0.36 and segment_clear(a,b):graph.connect_points(cells[cell],cells[other])
	# Tiny islands caused by missing/outlier source triangles are not usable
	# spawn/placement surfaces. Keep every connected floor region with real area.
	var seen={}
	var remove=[]
	for id in graph.get_point_ids():
		if seen.has(id):continue
		var pending=[id];var region=[];seen[id]=true
		while not pending.is_empty():
			var current=pending.pop_back();region.append(current)
			for neighbor in graph.get_point_connections(current):
				if not seen.has(neighbor):seen[neighbor]=true;pending.append(neighbor)
		if region.size()<12:remove.append_array(region)
	for id in remove:
		cells.erase(_cell(points[id]));points.erase(id);graph.remove_point(id)
	for cell in cells:
		var right=cell+Vector2i(1,0)
		var back=cell+Vector2i(0,1)
		var corner=cell+Vector2i(1,1)
		if cells.has(right) and cells.has(back) and cells.has(corner):
			if not graph.are_points_connected(cells[cell],cells[right]) or not graph.are_points_connected(cells[cell],cells[back]):continue
			if not graph.are_points_connected(cells[right],cells[corner]) or not graph.are_points_connected(cells[back],cells[corner]):continue
			var vertices=[points[cells[cell]],points[cells[right]],points[cells[back]],points[cells[corner]]]
			if not clear_position((vertices[0]+vertices[3])*0.5):continue
			for index in [0,2,1,1,2,3]:floor_faces.append(vertices[index])

func make_pick_body(parent: Node3D) -> void:
	var body=StaticBody3D.new()
	body.name="WalkableDeckPickSurface"
	body.collision_layer=PICK_LAYER
	body.collision_mask=0
	var collision=CollisionShape3D.new()
	var shape=ConcavePolygonShape3D.new()
	shape.set_faces(floor_faces)
	shape.backface_collision=true
	collision.shape=shape
	body.add_child(collision)
	parent.add_child(body)

func _restore_disabled() -> void:
	for id in disabled:graph.set_point_disabled(id,false)
	disabled.clear()

func path(start: Vector3,goal: Vector3,units: Array=[],mover=null) -> PackedVector3Array:
	_restore_disabled()
	var a=nearest(start,0.5);var b=nearest(goal,0.3)
	if a==null or b==null:return PackedVector3Array()
	var start_id=cells[_cell(a)]
	var end_id=cells[_cell(b)]
	_mark_units(units,mover,start_id)
	if graph.is_point_disabled(end_id):_restore_disabled();return PackedVector3Array()
	var route=graph.get_point_path(start_id,end_id)
	_restore_disabled()
	return route

func _mark_units(units: Array,mover,start_id: int) -> void:
	for unit in units:
		if unit==mover or unit.hp<=0:continue
		var center=_cell(unit.position)
		for z in range(center.y-5,center.y+6):
			for x in range(center.x-5,center.x+6):
				var cell=Vector2i(x,z)
				if not cells.has(cell):continue
				var id=cells[cell]
				if id==start_id:continue
				var p=points[id]
				if Vector2(p.x-unit.position.x,p.z-unit.position.z).length()<0.69:
					if not graph.is_point_disabled(id):graph.set_point_disabled(id,true);disabled.append(id)

func reachable(start: Vector3,units: Array=[],mover=null) -> Dictionary:
	_restore_disabled()
	var origin=nearest(start,0.5)
	if origin==null:return {}
	var first=cells[_cell(origin)]
	_mark_units(units,mover,first)
	var found={first:true};var pending=[first]
	while not pending.is_empty():
		var current=pending.pop_back()
		for next in graph.get_point_connections(current):
			if not found.has(next) and not graph.is_point_disabled(next):found[next]=true;pending.append(next)
	_restore_disabled()
	return found

func route_length(route: PackedVector3Array) -> float:
	var total=0.0
	for i in range(1,route.size()):total+=route[i-1].distance_to(route[i])
	return total

func segment_clear(a: Vector3,b: Vector3) -> bool:
	var steps=maxi(1,ceili(a.distance_to(b)/0.08))
	for i in range(steps+1):
		if not clear_position(a.lerp(b,float(i)/steps)):return false
	return true

func melee_clear(a: Vector3,b: Vector3) -> bool:
	# Weapon reach is not a walking corridor: the attacker's body does not need
	# to fit at every point between two fighters. Still reject water and cover.
	if not line_of_fire(a+Vector3(0,0.9,0),b+Vector3(0,0.9,0)):return false
	var steps=maxi(1,ceili(a.distance_to(b)/0.1))
	for i in range(steps+1):
		var point=a.lerp(b,float(i)/steps)
		if raw_height(Vector2(point.x,point.z))==null:return false
	return abs(a.y-b.y)<0.85

func line_of_fire(a: Vector3,b: Vector3) -> bool:
	var count=maxi(1,ceili(a.distance_to(b)/0.12))
	for i in range(1,count):
		var point=a.lerp(b,float(i)/count)
		for obstacle in hull_obstacles:
			if point.y>float(obstacle.height)+0.03:continue
			var delta=Vector2(point.x,point.z)-obstacle.center
			if obstacle.kind=="circle":
				if delta.length()<float(obstacle.radius)+0.045:return false
			else:
				if abs(delta.x)<float(obstacle.size[0])*0.5 and abs(delta.y)<float(obstacle.size[1])*0.5:return false
	return true
