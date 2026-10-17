extends RefCounted

# Continuous relative-motion segment against an oriented hull expanded by the ball radius.
# Both endpoints are expressed relative to the moving hull; no hit is committed at launch.
static func segment_box(a: Vector3,b: Vector3,half: Vector3) -> float:
	var lo=0.0
	var hi=1.0
	var d=b-a
	for axis in range(3):
		if abs(d[axis])<0.000001:
			if abs(a[axis])>half[axis]:return -1.0
		else:
			var first=(-half[axis]-a[axis])/d[axis]
			var last=(half[axis]-a[axis])/d[axis]
			if first>last:
				var swap=first
				first=last
				last=swap
			lo=max(lo,first)
			hi=min(hi,last)
			if lo>hi:return -1.0
	return lo

static func hull_hit(a: Vector3,b: Vector3,previous: Vector3,current: Vector3,yaw: float,half: Vector3,radius: float=0.18) -> float:
	var inverse=Basis(Vector3.UP,yaw).inverse()
	return segment_box(inverse*(a-previous),inverse*(b-current),half+Vector3.ONE*radius)

static func launch_velocity(origin: Vector3,aim: Vector3,flight: float,gravity: Vector3) -> Vector3:
	return (aim-origin)/flight-gravity*flight*0.5

static func broadside(forward: Vector3,to_target: Vector3) -> bool:
	return to_target.length()>0.01 and abs(forward.dot(to_target.normalized()))<0.62

static func safe_point(p: Vector3,area: Rect2,obstacles: Array) -> Vector3:
	p.x=clamp(p.x,area.position.x,area.end.x)
	p.z=clamp(p.z,area.position.y,area.end.y)
	for obstacle in obstacles:
		var delta=Vector2(p.x,p.z)-Vector2(obstacle.x,obstacle.z)
		var radius=obstacle.y+0.42
		if delta.length()<radius:
			if delta.length()<0.001:delta=Vector2.RIGHT
			delta=delta.normalized()*radius
			p.x=obstacle.x+delta.x
			p.z=obstacle.z+delta.y
	return p
