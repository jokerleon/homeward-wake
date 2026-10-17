extends RefCounted
static var cache={}
static var detail_textures={}
const MIRRORS={"W":"E","SW":"SE","NW":"NE"}
const DIRECTIONS=["E","SE","S","SW","W","NW","N","NE"]

static func bundle(character: String,state: String) -> Dictionary:
	var key=character+"/"+state
	if cache.has(key):return cache[key]
	var path="res://assets/demo/characters/"+character+"/"+state+"/motion-set.json"
	if not FileAccess.file_exists(path):return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:return {}
	var frames=SpriteFrames.new();frames.remove_animation("default")
	var metadata={}
	for direction in DIRECTIONS:
		var source=MIRRORS.get(direction,direction)
		if not data.directions.has(source):continue
		var clips=data.directions[source].clips
		for clip_name in clips:
			var clip=clips[clip_name];var animation=direction+"_"+clip_name
			frames.add_animation(animation);frames.set_animation_loop(animation,clip.loop)
			frames.set_animation_speed(animation,clip.fps)
			var atlas=load(clip.atlas) as Texture2D
			for item in clip.rects:
				var rect=item.frame
				var texture=AtlasTexture.new();texture.atlas=atlas;texture.region=Rect2(rect[0],rect[1],rect[2],rect[3]);texture.filter_clip=true
				frames.add_frame(animation,texture)
			var info=clip.duplicate(true);info.mirrored=MIRRORS.has(direction);info.source_direction=source
			metadata[animation]=info
	var result={"frames":frames,"metadata":metadata,"canvas":Vector2(data.canvas[0],data.canvas[1]),"pivot":Vector2(data.pivot_px[0],data.pivot_px[1]),"pixel_size":float(data.pixel_size),"state":state,"default_direction":data.get("default_direction","E")}
	cache[key]=result
	return result

static func apply_mouth_stability(material: ShaderMaterial,clip: Dictionary,frame: int) -> void:
	var detail=clip.get("mouth_stability",{})
	material.set_shader_parameter("stable_mouth_enabled",not detail.is_empty())
	if detail.is_empty():return
	var path=String(detail.reference_texture)
	if not detail_textures.has(path):
		var reference=load(path) as Texture2D
		var image=reference.get_image()
		if image.is_compressed():image.decompress()
		image.generate_mipmaps()
		detail_textures[path]=ImageTexture.create_from_image(image)
	var target=detail.target_rects_uv[clampi(frame,0,detail.target_rects_uv.size()-1)]
	var source=detail.reference_rect_uv
	material.set_shader_parameter("stable_mouth_texture",detail_textures[path])
	material.set_shader_parameter("stable_mouth_target",Vector4(target[0],target[1],target[2],target[3]))
	material.set_shader_parameter("stable_mouth_source",Vector4(source[0],source[1],source[2],source[3]))
