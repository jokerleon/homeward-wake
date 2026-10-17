extends SceneTree

const Pawn=preload("res://scripts/demo/pawn.gd")
var failures=0
var count=0

func check(value: bool,label: String) -> void:
	count+=1
	if not value:failures+=1;push_error(label)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var pawn=Pawn.new()
	root.add_child(pawn)
	pawn.weapon_class="crossbow"
	var camera=Camera3D.new()
	root.add_child(camera)
	var names=["E","SE","S","SW","W","NW","N","NE"]
	# Ground-plane yaw is independent of camera pitch and target elevation.
	for yaw in [0.0,0.7,-1.3]:
		for pitch in [-0.25,-0.65]:
			camera.rotation=Vector3(pitch,yaw,0)
			var right=camera.global_basis.x;right.y=0;right=right.normalized()
			var toward=camera.global_basis.z;toward.y=0;toward=toward.normalized()
			for i in range(8):
				var target=(right*cos(i*PI/4)+toward*sin(i*PI/4))*5
				for height in [-2.0,0.0,3.0]:
					pawn.face_target(target+Vector3.UP*height,camera)
					check(pawn.direction==names[i],"Ground direction "+names[i])
	pawn.direction="SE"
	pawn.face_target(pawn.global_position+Vector3.UP*3,camera)
	check(pawn.direction=="SE","No horizontal offset retains facing")
	# Mirror a muzzle around its authored pivot, without altering its height.
	pawn.world_pixel_size=0.01;pawn.sprite_canvas=Vector2(384,384);pawn.sprite_pivot=Vector2(192,324)
	pawn.motion={"SE_shoot":{"muzzle_px":[260,180]},"SW_shoot":{"muzzle_px":[260,180],"mirrored":true}}
	pawn.direction="SE";var front_right=pawn.muzzle(camera)-pawn.global_position
	pawn.direction="SW";var front_left=pawn.muzzle(camera)-pawn.global_position
	check(is_equal_approx(front_right.y,front_left.y),"Mirroring preserves authored release height")
	check(Vector2(front_right.x,front_right.z).is_equal_approx(-Vector2(front_left.x,front_left.z)),"Mirroring reflects horizontal muzzle offset")
	print("DEMO_FACING_CHECKS "+JSON.stringify({"count":count,"failures":failures}))
	pawn.queue_free();camera.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
