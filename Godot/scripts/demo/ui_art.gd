extends RefCounted

const FRAMES="res://assets/demo/ui/frames.png"
const ICONS="res://assets/demo/ui/icons.png"
const PORTRAITS={"船主":"hero","阿棠":"atang","老梁":"old-liang","随从":"guard","船匪头目":"captain"}
const REGIONS={
	"paper":Rect2(24,32,1470,250),"panel":Rect2(36,295,750,248),
	"portrait":Rect2(798,291,202,267),"portrait_selected":Rect2(1014,291,211,270),
	"compass":Rect2(1228,287,270,279),"health":Rect2(795,568,698,73),
	"green":Rect2(84,575,615,13),"gold":Rect2(84,625,612,15),
	"normal":Rect2(37,672,489,134),"hover":Rect2(528,672,478,134),
	"pressed":Rect2(1013,672,483,134),"disabled":Rect2(37,819,489,136),
	"ready":Rect2(528,819,478,136),"danger":Rect2(1013,819,483,136)
}
const ICON_NAMES=["blade","crossbow","shield","reload","ship","rudder","cannon","ball","pressure","salvo","hull","mount","pause","play","confirm","back"]
# Source-pixel slice cuts and logical-pixel content insets are different data.
# Corners keep their authored shape; only the edges and center stretch.
const FRAME_RULES={
	"paper":{"scale":0.45,"slice":[104,66,100,64],"content":[48,32,48,32]},
	"panel":{"scale":0.5,"slice":[76,60,76,60],"content":[32,24,32,24]},
	"portrait":{"scale":0.5,"slice":[48,48,48,48],"content":[14,14,14,14]},
	"portrait_selected":{"scale":0.5,"slice":[48,48,48,48],"content":[14,14,14,14]},
	"health":{"scale":0.2,"slice":[85,28,85,28],"content":[9,5,9,5]},
	"button":{"scale":0.42,"slice":[68,54,68,54],"content":[28,12,28,12]}
}
var frame_sheet: Texture2D
var icon_sheet: Texture2D
var cache={}

func ground(index: int) -> AtlasTexture:
	var key="ground_"+str(index)
	if cache.has(key):return cache[key]
	var sheet=load("res://assets/demo/ui/indicators.png") as Texture2D
	var cell=sheet.get_size()/Vector2(3,2)
	var texture=AtlasTexture.new();texture.atlas=sheet
	texture.region=Rect2(Vector2(index%3,floori(index/3.0))*cell+Vector2(10,10),cell-Vector2(20,20))
	texture.filter_clip=true;cache[key]=texture
	return texture

func _init() -> void:
	frame_sheet=load(FRAMES);icon_sheet=load(ICONS)

func region(name: String) -> AtlasTexture:
	if cache.has(name):return cache[name]
	var texture=AtlasTexture.new();texture.atlas=frame_sheet;texture.region=REGIONS[name]
	texture.filter_clip=true;cache[name]=texture
	return texture

func icon(name: String) -> AtlasTexture:
	var key="icon_"+name
	if cache.has(key):return cache[key]
	var index=ICON_NAMES.find(name)
	if index<0:index=15
	var cell=Vector2(icon_sheet.get_size())/4.0
	var texture=AtlasTexture.new();texture.atlas=icon_sheet
	texture.region=Rect2(Vector2(index%4,floori(index/4.0))*cell+Vector2(10,10),cell-Vector2(20,20))
	texture.filter_clip=true;cache[key]=texture
	return texture

func portrait(speaker: String) -> Texture2D:
	if not PORTRAITS.has(speaker):return null
	var path="res://assets/demo/portraits/"+PORTRAITS[speaker]+".png"
	return load(path) if ResourceLoader.exists(path) else null

func button_icon(name: String) -> Texture2D:
	var key="button_icon_"+name
	if cache.has(key):return cache[key]
	var source=icon(name).get_image()
	source.resize(24,24,Image.INTERPOLATE_LANCZOS)
	var result=ImageTexture.create_from_image(source)
	cache[key]=result
	return result

func head(speaker: String) -> Texture2D:
	var key="head_"+speaker
	if cache.has(key):return cache[key]
	var source=portrait(speaker)
	if source==null:return null
	var result=AtlasTexture.new();result.atlas=source
	result.region=Rect2(source.get_width()*0.15,source.get_height()*0.03,source.get_width()*0.70,source.get_height()*0.49)
	result.filter_clip=true;cache[key]=result
	return result

func style(name: String="normal",_legacy_margin: float=0.0) -> StyleBoxTexture:
	var key="style_"+name
	if cache.has(key):return cache[key]
	var rules=FRAME_RULES.get(name,FRAME_RULES.button)
	var scale_factor=float(rules.scale)
	var source=region(name).get_image()
	source.resize(maxi(1,roundi(source.get_width()*scale_factor)),maxi(1,roundi(source.get_height()*scale_factor)),Image.INTERPOLATE_LANCZOS)
	var result=StyleBoxTexture.new();result.texture=ImageTexture.create_from_image(source)
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		var index={SIDE_LEFT:0,SIDE_TOP:1,SIDE_RIGHT:2,SIDE_BOTTOM:3}[side]
		result.set_texture_margin(side,float(rules.slice[index])*scale_factor)
		result.set_content_margin(side,float(rules.content[index]))
	cache[key]=result
	return result

func picture(parent: Node,texture: Texture2D,at: Vector2,extent: Vector2) -> TextureRect:
	var result=TextureRect.new()
	result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture=texture;result.position=at;result.size=extent
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func health(parent: Node,at: Vector2,extent: Vector2) -> Dictionary:
	var frame=Panel.new();frame.position=at;frame.size=extent
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel",style("health"));parent.add_child(frame)
	var inset=Vector2(9,5)
	var trail=TextureRect.new();trail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	trail.texture=region("gold");trail.modulate=Color("cb7556")
	trail.position=at+inset;trail.size=Vector2(extent.x-inset.x*2,maxf(2,extent.y-inset.y*2))
	trail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;trail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(trail)
	var fill=TextureRect.new();fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	fill.texture=region("green");fill.position=trail.position;fill.size=trail.size
	fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return {"frame":frame,"fill":fill,"trail":trail,"width":extent.x-inset.x*2,"ratio":1.0}

func update_health(bar: Dictionary,ratio: float,dt: float) -> void:
	ratio=clampf(ratio,0,1)
	bar.fill.size.x=maxf(0.001,bar.width*ratio)
	bar.fill.visible=bar.frame.visible and ratio>0
	bar.ratio=move_toward(bar.ratio,ratio,dt*0.6)
	bar.trail.size.x=maxf(0.001,bar.width*bar.ratio)
	bar.trail.visible=bar.frame.visible and bar.ratio>0

func decorate_icon_button(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var box=style(state).duplicate() as StyleBoxTexture
		box.set_content_margin(SIDE_LEFT,12);box.set_content_margin(SIDE_RIGHT,12)
		button.add_theme_stylebox_override(state,box)
	button.add_theme_constant_override("icon_max_width",26)

func decorate_button(button: Button,kind: String="") -> void:
	# A real 24px texture participates in Button's minimum-size calculation.
	# expand_icon excluded it and let long labels squeeze icons to zero width.
	button.expand_icon=false
	button.add_theme_constant_override("icon_max_width",24)
	for state in ["normal","hover","pressed","disabled"]:button.add_theme_stylebox_override(state,style(state))
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Color("f3ead4"))
	button.add_theme_color_override("font_disabled_color",Color("9d9d92"))
	button.add_theme_font_size_override("font_size",18)
	if not kind.is_empty():
		button.icon=button_icon(kind)
		button.add_theme_constant_override("icon_max_width",24)
		button.add_theme_constant_override("h_separation",7)
