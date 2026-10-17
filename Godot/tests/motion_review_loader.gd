extends RefCounted

static func merge(base: Dictionary,extra: Dictionary) -> void:
	assert(base.canvas==extra.canvas and base.pivot==extra.pivot)
	for animation in extra.metadata:
		if base.metadata.has(animation):continue
		base.frames.add_animation(animation)
		base.frames.set_animation_speed(animation,extra.frames.get_animation_speed(animation))
		base.frames.set_animation_loop(animation,extra.frames.get_animation_loop(animation))
		for frame in range(extra.frames.get_frame_count(animation)):
			base.frames.add_frame(animation,extra.frames.get_frame_texture(animation,frame))
		base.metadata[animation]=extra.metadata[animation]

static func pack(folder: String,source_direction: String="E") -> Dictionary:
	var data=JSON.parse_string(FileAccess.get_file_as_string(folder+"/motion.json"))
	var frames=SpriteFrames.new();frames.remove_animation("default")
	var metadata={}
	for name in data.clips:
		var clip=data.clips[name]
		var atlas=ImageTexture.create_from_image(Image.load_from_file(folder+"/"+clip.atlas))
		var directions=[source_direction]
		var mirror={"E":"W","SE":"SW","NE":"NW"}.get(source_direction,"")
		if not mirror.is_empty():directions.append(mirror)
		for direction in directions:
			var animation=direction+"_"+name
			frames.add_animation(animation);frames.set_animation_speed(animation,clip.fps);frames.set_animation_loop(animation,clip.loop)
			for item in clip.rects:
				var texture=AtlasTexture.new();texture.atlas=atlas
				texture.region=Rect2(item.frame[0],item.frame[1],item.frame[2],item.frame[3]);texture.filter_clip=true
				frames.add_frame(animation,texture)
			var info=clip.duplicate(true);info.mirrored=direction in ["W","SW","NW"];metadata[animation]=info
	return {"frames":frames,"metadata":metadata,"canvas":Vector2(data.canvas[0],data.canvas[1]),"pivot":Vector2(data.pivot_px[0],data.pivot_px[1]),"pixel_size":1.74/142.0,"default_direction":source_direction}

static func load_set(spec: Dictionary) -> Dictionary:
	var frames=SpriteFrames.new();frames.remove_animation("default")
	var result={"frames":frames,"metadata":{},"canvas":Vector2(spec.canvas[0],spec.canvas[1]),"pivot":Vector2(spec.pivot_px[0],spec.pivot_px[1]),"pixel_size":float(spec.pixel_size),"default_direction":"E"}
	var loaded={}
	for direction in spec.directions:
		for name in spec.directions[direction]:
			var definition=spec.directions[direction][name]
			var folder="D:/Work/project/joker/chess/"+String(definition.pack).get_base_dir()
			var key=folder+"/"+direction
			if not loaded.has(key):merge(result,pack(folder,direction));loaded[key]=true
			var views=[direction]
			var mirror={"E":"W","SE":"SW","NE":"NW"}.get(direction,"")
			if not mirror.is_empty():views.append(mirror)
			for view in views:
				var clip=result.metadata[view+"_"+name]
				if definition.has("muzzle_px"):clip.muzzle_px=definition.muzzle_px
				if definition.has("release_source_frame"):
					for index in range(clip.rects.size()):
						if int(clip.rects[index].source_frame)>=int(definition.release_source_frame):
							clip.release_time=float(index)/float(clip.fps);break
	return result

static func pawn(target,data: Dictionary) -> void:
	target.motion=data.metadata;target.sprite.stop();target.sprite.sprite_frames=data.frames
	target.refresh_material_response()
	target.sprite_canvas=data.canvas;target.sprite_pivot=data.pivot;target.world_pixel_size=data.pixel_size
	target.material.set_shader_parameter("frame_aspect",data.canvas.x/data.canvas.y)
	target.surface.mesh.size=data.canvas*data.pixel_size
	target.base_height=(data.pivot.y-data.canvas.y*0.5)*data.pixel_size;target.surface.position.y=target.base_height
	target.tint=Color.WHITE;target.direction="E";target.sprite.play("E_idle");target._sync_frame()

static func port(target,data: Dictionary) -> void:
	target.demo_motion=data.metadata;target.hero.stop();target.hero.sprite_frames=data.frames
	target.hero.pixel_size=data.pixel_size;target.actor_face.mesh.size=data.canvas*data.pixel_size
	target.actor_face.position=Vector3(0,(data.pivot.y-data.canvas.y*0.5)*data.pixel_size,0)
	target.facing=data.get("default_direction","E");target.hero.play(target.facing+"_idle");target._sync_actor_paint()
