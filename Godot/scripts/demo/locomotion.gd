extends RefCounted

var moving=false
var phase="idle"
var starts=0
var stops=0
const DIRECTIONS=["E","SE","S","SW","W","NW","N","NE"]

static func facing(velocity: Vector3,camera: Camera3D,current: String) -> String:
	if velocity.length()<0.05:return current
	var right=camera.global_basis.x;right.y=0;right=right.normalized()
	var toward=camera.global_basis.z;toward.y=0;toward=toward.normalized()
	var angle=atan2(velocity.dot(toward),velocity.dot(right))
	var previous=DIRECTIONS.find(current)
	# Keep a little angular overlap so following a moving leader cannot flutter
	# between two views at a sector boundary.
	if previous>=0 and absf(wrapf(angle-previous*PI/4,-PI,PI))<=PI/8+deg_to_rad(5):return current
	return DIRECTIONS[posmod(roundi(angle/(PI/4)),8)]

func update(sprite: AnimatedSprite3D,direction: String,wants_move: bool,rate: float=1.0) -> String:
	var entered=false
	if wants_move!=moving:
		moving=wants_move;entered=true
		phase="move_start" if moving else "move_stop"
		if moving:starts+=1
		else:stops+=1
	elif phase in ["move_start","move_stop"] and not sprite.is_playing():
		phase="move_loop" if moving else "idle"
	var animation=direction+"_"+phase
	if not sprite.sprite_frames.has_animation(animation):
		phase="move_loop" if moving else "idle"
		animation=direction+"_"+phase
	if sprite.animation!=animation or entered:
		var same_phase=not entered and String(sprite.animation).ends_with("_"+phase)
		var progress=0.0
		if same_phase:
			progress=(sprite.frame+sprite.frame_progress)/maxf(sprite.sprite_frames.get_frame_count(sprite.animation),1)
		sprite.play(animation)
		if entered:sprite.set_frame_and_progress(0,0)
		elif same_phase:
			# A turn changes the view, not the gait phase. Never restart a step
			# just because the target crossed a direction boundary.
			var frame=progress*sprite.sprite_frames.get_frame_count(animation)
			sprite.set_frame_and_progress(floori(frame),fmod(frame,1.0))
	elif not sprite.is_playing() and phase in ["idle","move_loop"]:sprite.play(animation)
	sprite.speed_scale=rate
	return phase
