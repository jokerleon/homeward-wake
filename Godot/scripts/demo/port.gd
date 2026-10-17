extends "res://scripts/quay.gd"
const Motion=preload("res://scripts/demo/character_motion.gd")
const Locomotion=preload("res://scripts/demo/locomotion.gd")
var locomotion=Locomotion.new()
var actual_velocity=Vector3.ZERO
var controls_enabled=false
var retained_sprite_frames: SpriteFrames
var demo_motion={}
var demo_locomotion="idle"
var demo_was_moving=false

func _ready() -> void:
	super._ready()
	ui_layer.visible=false
	_set_camera(2)
	actor.position=Vector3(-2.0,1.815,6.0)
	retained_sprite_frames=hero.sprite_frames
	var bundle=Motion.bundle("hero","explore")
	if not bundle.is_empty():
		demo_motion=bundle.metadata
		hero.sprite_frames=bundle.frames
		hero.pixel_size=bundle.pixel_size
		var quad=QuadMesh.new();quad.size=bundle.canvas*bundle.pixel_size
		actor_face.mesh=quad
		actor_face.position=Vector3((bundle.canvas.x*0.5-bundle.pivot.x)*bundle.pixel_size,(bundle.pivot.y-bundle.canvas.y*0.5)*bundle.pixel_size,0)
		actor_surface.shader=load("res://shaders/demo_actor.gdshader")
		actor_surface.set_shader_parameter("tint",Color.WHITE)
		hero.play("E_idle")
		_sync_actor_paint()

func _move_actor(delta: float) -> void:
	# Keep the retained quay collision and heights, while selecting this demo's
	# explicit exploration state. Position changes never wait for a clip to end.
	var right=camera.global_basis.x;right.y=0;right=right.normalized()
	var back=camera.global_basis.z;back.y=0;back=back.normalized()
	var input=Input.get_vector("harbor_left","harbor_right","harbor_up","harbor_down") if controls_enabled else Vector2.ZERO
	var velocity=(right*input.x+back*input.y)*2.2
	var next=actor.position+velocity*minf(delta,0.1)
	var height=walk_height(next.x,next.z)+0.015
	var blocked=height<0.45 or abs(height-actor.position.y)>0.25
	for rect in building_blocks:
		if rect.grow(0.15).has_point(Vector2(next.x,next.z)):blocked=true
	if not blocked:actor.position=Vector3(next.x,height,next.z)
	else:velocity=Vector3.ZERO
	moving=velocity.length()>0.05
	actual_velocity=velocity
	if moving:
		facing=Locomotion.facing(velocity,camera,facing)
	if demo_motion.is_empty():
		hero.play(facing+("_move_loop" if moving else "_idle"))
		hero.speed_scale=velocity.length()/1.8 if moving else 1.0
	else:
		demo_locomotion=locomotion.update(hero,facing,moving)
		demo_was_moving=moving
	var p=actor.position
	var on_stair=p.x>=-3.2 and p.x<=1.2 and p.z<-3 and p.z>-8
	var on_gangway=p.x>=7.18 and p.x<=8.42 and p.z<4.05
	hero_shadow.visible=not(on_stair or on_gangway)
	hero_shadow.position=p+Vector3(0,0.016,0)

func _sync_actor_paint() -> void:
	super._sync_actor_paint()
	if actor_surface!=null and not demo_motion.is_empty():
		actor_surface.set_shader_parameter("flip_x",demo_motion.get(String(hero.animation),{}).get("mirrored",false))
		Motion.apply_mouth_stability(actor_surface,demo_motion.get(String(hero.animation),{}),hero.frame)

func _unhandled_input(_event: InputEvent) -> void:
	pass
