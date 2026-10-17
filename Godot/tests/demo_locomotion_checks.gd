extends SceneTree
const Locomotion=preload("res://scripts/demo/locomotion.gd")
var failures=[]
var checks=0

func check(passed: bool,label: String) -> void:
	checks+=1
	if not passed:failures.append(label)

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var source=Image.create(1,1,false,Image.FORMAT_RGBA8);source.fill(Color.WHITE)
	var texture=ImageTexture.create_from_image(source)
	var frames=SpriteFrames.new();frames.remove_animation("default")
	for direction in ["E","SE"]:
		for phase in ["idle","move_start","move_loop","move_stop"]:
			var count={"idle":1,"move_start":8,"move_loop":24,"move_stop":6}[phase]
			if direction=="SE":count=roundi(count*1.5)
			var name=direction+"_"+phase;frames.add_animation(name);frames.set_animation_loop(name,phase in ["idle","move_loop"])
			for i in range(count):frames.add_frame(name,texture)
	var sprite=AnimatedSprite3D.new();sprite.sprite_frames=frames;root.add_child(sprite);sprite.play("E_idle")
	var controller=Locomotion.new()
	controller.update(sprite,"E",true)
	check(controller.starts==1 and sprite.animation=="E_move_start","one initial start")
	sprite.set_frame_and_progress(4,0.25)
	controller.update(sprite,"SE",true)
	check(is_equal_approx((sprite.frame+sprite.frame_progress)/12.0,4.25/8.0),"turn retains start phase across different clip lengths")
	for i in range(100):controller.update(sprite,"SE",true)
	check(controller.starts==1,"repeated movement updates do not restart start")
	sprite.pause();controller.update(sprite,"SE",true)
	check(sprite.animation=="SE_move_loop","completed start enters loop")
	sprite.set_frame_and_progress(10,0.5);controller.update(sprite,"E",true)
	check(is_equal_approx((sprite.frame+sprite.frame_progress)/24.0,10.5/36.0),"turn retains looping gait phase")
	controller.update(sprite,"E",false);sprite.set_frame_and_progress(2,0.5)
	for i in range(100):controller.update(sprite,"E",false)
	check(controller.stops==1 and sprite.frame==2 and is_equal_approx(sprite.frame_progress,0.5),"standing updates do not restart stop")
	sprite.pause();controller.update(sprite,"E",false)
	check(sprite.animation=="E_idle","completed stop returns to idle")
	controller.update(sprite,"E",true)
	check(controller.starts==2 and sprite.frame==0,"a genuine new bout starts once")
	print("LOCOMOTION_CHECKS "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
