extends Node3D
const Motion=preload("res://scripts/demo/character_motion.gd")
const Locomotion=preload("res://scripts/demo/locomotion.gd")
var locomotion=Locomotion.new()

var key=""
var title=""
var team=0
var weapon_class="blade"
var hp=100.0
var maximum=100.0
var damage=10.0
var technique=10.0
var attack_range=1.65
var interval=1.5
var speed=2.6
var cooldown=0.6
var skill_cd=2.0
var auto_skill=true
var broken=0.0
var stun=0.0
var anchor=Vector3.ZERO
var goal=Vector3.ZERO
var moving_order=false
var target_key=""
var velocity=Vector3.ZERO
var action=""
var action_left=0.0
var action_target=""
var action_position=Vector3.ZERO
var action_elapsed=0.0
var action_duration=0.0
var release_time=0.0
var action_released=false
var weapon_loaded=true
var shot_direction=Vector3.ZERO
var motion={}
var motion_context="combat"
var current_clip={}
var direction="E"
var hurt_left=0.0
var hurt_elapsed=0.0
var flash_left=0.0
var sprite: AnimatedSprite3D
var surface: MeshInstance3D
var material: ShaderMaterial
var marker: Sprite3D
var caption: Label3D
var tint=Color.WHITE
var selected=false
var show_name=true
var route=PackedVector3Array()
var route_index=0
var planned_goal=Vector3.ZERO
var repath_left=0.0
var blocked_time=0.0
var engagement_target=""
var attack_starts=0
var distance_walked=0.0
var waiting_for_space=false
var health_root: Node3D
var health_fill: Node3D
var base_height=0.784
var death_time=0.0
var locomotion_clip="idle"
var was_moving=false
var world_pixel_size=0.0
var sprite_pivot=Vector2.ZERO
var sprite_canvas=Vector2.ZERO
var performance=""

func setup(id: String,label: String,side: int,frames: SpriteFrames,paint: Color,context: String="combat") -> void:
	key=id
	title=label
	team=side
	weapon_class="crossbow" if id=="atang" else "blade"
	tint=paint
	motion_context=context
	var bundle=Motion.bundle(id,context)
	direction=bundle.get("default_direction","E")
	if not bundle.is_empty():tint=Color.WHITE
	elif context=="combat":tint=paint.lerp(Color.WHITE,0.55)
	motion=bundle.get("metadata",{})
	sprite=AnimatedSprite3D.new()
	sprite.sprite_frames=bundle.get("frames",frames)
	sprite.visible=false
	add_child(sprite)
	material=ShaderMaterial.new()
	material.shader=load("res://shaders/demo_actor.gdshader")
	material.set_shader_parameter("tint",tint)
	refresh_material_response()
	surface=MeshInstance3D.new()
	var mesh=QuadMesh.new()
	mesh.size=Vector2.ONE*(288.0*1.74/142.0)
	if not bundle.is_empty():
		world_pixel_size=bundle.pixel_size;sprite_pivot=bundle.pivot;sprite_canvas=bundle.canvas
		material.set_shader_parameter("frame_aspect",sprite_canvas.x/sprite_canvas.y)
		mesh.size=sprite_canvas*world_pixel_size
		base_height=(sprite_pivot.y-sprite_canvas.y*0.5)*world_pixel_size
	surface.mesh=mesh
	surface.material_override=material
	surface.position.y=base_height
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(surface)
	sprite.frame_changed.connect(_sync_frame)
	sprite.animation_changed.connect(_sync_frame)
	sprite.play(direction+"_idle")
	_sync_frame()
	var art=preload("res://scripts/demo/ui_art.gd").new()
	marker=Sprite3D.new();marker.texture=art.ground(0 if team==0 else 1)
	marker.pixel_size=1.16/marker.texture.get_width();marker.rotation.x=-PI*0.5
	marker.shaded=false;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y=0.03
	add_child(marker)
	caption=Label3D.new()
	caption.font=SystemFont.new()
	caption.font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	caption.font_size=34
	caption.pixel_size=0.0076
	caption.position.y=2.05
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate=Color("f2ead5")
	caption.outline_size=8
	add_child(caption)
	health_root=Node3D.new()
	health_root.position.y=1.91
	add_child(health_root)
	var backing=Sprite3D.new();backing.texture=art.region("health")
	backing.pixel_size=0.9/backing.texture.get_width();backing.shaded=false
	backing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_root.add_child(backing)
	health_fill=Sprite3D.new();health_fill.texture=art.region("green" if team==0 else "gold")
	health_fill.pixel_size=0.78/health_fill.texture.get_width();health_fill.shaded=false
	health_fill.scale.y=2.0
	if team==1:health_fill.modulate=Color("c56a4e")
	health_fill.position.z=0.004
	health_fill.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_root.add_child(health_fill)

func refresh_material_response() -> void:
	# The deck's gameplay view needs a small readable shadow floor. Port
	# exploration retains v03 exactly; dark legacy stand-ins need more correction
	# than the clean authored combat sprites, never a shared large emission boost.
	material.set_shader_parameter("paint_light_weight",1.0)
	material.set_shader_parameter("fill_light",(0.25 if motion.is_empty() else 0.22) if motion_context=="combat" else 0.1)
	material.set_shader_parameter("paint_midtones",(0.72 if motion.is_empty() else 0.92) if motion_context=="combat" else 1.0)

func _sync_frame() -> void:
	var frame=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) as AtlasTexture
	if frame==null:return
	var size=Vector2(frame.atlas.get_width(),frame.atlas.get_height())
	material.set_shader_parameter("color_atlas",frame.atlas)
	material.set_shader_parameter("atlas_region",Vector4(frame.region.position.x/size.x,frame.region.position.y/size.y,frame.region.size.x/size.x,frame.region.size.y/size.y))
	current_clip=motion.get(String(sprite.animation),{})
	material.set_shader_parameter("flip_x",current_clip.get("mirrored",false))
	Motion.apply_mouth_stability(material,current_clip,sprite.frame)

func motion_clip(name: String) -> Dictionary:
	return motion.get(direction+"_"+name,{})

func perform(name: String) -> void:
	if motion_context!="explore" or not sprite.sprite_frames.has_animation(direction+"_"+name):return
	performance=name
	sprite.stop();sprite.play(direction+"_"+name)

func muzzle(camera: Camera3D,facing_override: String="") -> Vector3:
	var data=motion.get((direction if facing_override.is_empty() else facing_override)+"_shoot",{})
	if data.is_empty() or not data.has("muzzle_px"):return global_position+Vector3(0,1.25,0)
	var pixel=Vector2(data.muzzle_px[0],data.muzzle_px[1]);var pivot=sprite_pivot
	if data.get("mirrored",false):pixel.x=sprite_canvas.x-pixel.x;pivot.x=sprite_canvas.x-pivot.x
	var right=camera.global_basis.x;right.y=0;right=right.normalized()
	return global_position+right*(pixel.x-pivot.x)*world_pixel_size+Vector3.UP*(pivot.y-pixel.y)*world_pixel_size

func visual(camera: Camera3D,dt: float) -> void:
	if sprite==null:return
	if hurt_left>0:hurt_elapsed+=dt
	hurt_left=max(0.0,hurt_left-dt)
	flash_left=max(0.0,flash_left-dt)
	surface.rotation.y=atan2(camera.global_basis.z.x,camera.global_basis.z.z)
	var clip="idle"
	if velocity.length()>0.05 and action.is_empty():
		direction=Locomotion.facing(velocity,camera,direction)
		clip="move_loop"
	elif hurt_left>0:clip="hit"
	var animation=direction+"_"+clip
	if not motion.is_empty():
		var moving_now=velocity.length()>0.05 and action.is_empty() and hp>0
		if action.is_empty() and performance.is_empty() and (hurt_left<=0 or moving_now) and hp>0:
			locomotion_clip=locomotion.update(sprite,direction,moving_now)
		was_moving=moving_now
		clip=locomotion_clip
		if not performance.is_empty():
			if not sprite.is_playing():performance=""
			else:clip=performance
		if hurt_left>0 and action.is_empty() and not moving_now:clip="hit"
		if not action.is_empty():clip="shoot" if weapon_class=="crossbow" and action!="reload" else ("reload" if action=="reload" else ("heavy" if action=="heavy" else "attack"))
		if hp<=0:clip="down";death_time+=dt
		animation=direction+"_"+clip
		if not sprite.sprite_frames.has_animation(animation):
			var side="W" if direction in ["W","SW","NW"] else "E"
			var reaction=side+"_"+clip
			animation=reaction if clip in ["hit","down","attack","heavy"] and sprite.sprite_frames.has_animation(reaction) else direction+"_idle"
	if sprite.animation!=animation:sprite.play(animation)
	sprite.speed_scale=1.0 if dt>0 else 0.0
	if not motion.is_empty() and (not action.is_empty() or hp<=0 or clip=="hit"):
		var clock=death_time if hp<=0 else (hurt_elapsed if clip=="hit" else action_elapsed)
		sprite.pause()
		sprite.frame=clampi(floori(clock*sprite.sprite_frames.get_animation_speed(animation)),0,sprite.sprite_frames.get_frame_count(animation)-1)
	elif not motion.is_empty() and not sprite.is_playing() and clip in ["idle","move_loop"]:sprite.play(animation)
	material.set_shader_parameter("tint",tint.lerp(Color(1.6,1.3,0.9),min(flash_left*5.0,0.6)))
	# Temporary motion emphasis. This is not a generated/accepted attack animation.
	surface.position.y=base_height+sin(action_left*12.0)*0.035 if not action.is_empty() and motion.is_empty() else base_height
	marker.visible=hp>0
	marker.scale=Vector3.ONE*(1.18 if selected else 0.82)
	marker.modulate.a=0.95 if selected else 0.52
	health_root.visible=hp>0
	health_root.rotation.y=surface.rotation.y
	health_fill.scale.x=max(hp/maximum,0.001)
	health_fill.position.x=-(1.0-hp/maximum)*0.39
	caption.text=title if show_name or selected else ""
	if broken>0:caption.text="破势" if caption.text.is_empty() else caption.text+"  破势"
	if action=="heavy" and not action_released:caption.text="蓄力重击！"
	if hp<=0:
		caption.text="已倒下" if show_name or selected else ""
		if motion.is_empty():surface.rotation.z=0.8;surface.position.y=0.45
		# Authored prone poses already communicate defeat. Keep their painted
		# clothing readable in deck shadows instead of crushing it to black.
		material.set_shader_parameter("tint",tint*(0.82 if not motion.is_empty() else 0.5))

func face_target(target: Vector3,camera: Camera3D) -> void:
	direction=direction_for_offset(target-global_position,camera)

func direction_for_offset(offset: Vector3,camera: Camera3D) -> String:
	if weapon_class=="crossbow":
		offset.y=0
		if offset.length()<0.05:return direction
		var right=camera.global_basis.x;right.y=0
		var back=camera.global_basis.z;back.y=0
		var index=posmod(roundi(atan2(offset.dot(back.normalized()),offset.dot(right.normalized()))/(PI/4.0)),8)
		return ["E","SE","S","SW","W","NW","N","NE"][index]
	var side=offset.dot(camera.global_basis.x)
	return ("E" if side>0 else "W") if abs(side)>0.05 else direction

func hurt(amount: float) -> void:
	hp=max(0.0,hp-amount)
	var reaction=motion_clip("hit")
	if reaction.is_empty():reaction=motion.get(("W" if direction in ["W","SW","NW"] else "E")+"_hit",{})
	hurt_left=float(reaction.get("duration",0.28));hurt_elapsed=0.0
	flash_left=0.16
	if hp<=0:action="";death_time=0
