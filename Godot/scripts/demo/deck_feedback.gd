extends Node3D
const Art=preload("res://scripts/demo/ui_art.gd")
var art=Art.new()
var board
var destination: Sprite3D
var route_marks=[]
var area: MeshInstance3D
var refresh_left=0.0
var last_key=""
var last_point=Vector3.INF
var preview={}

func setup(value) -> void:
	board=value
	destination=_mark(2,1.05)
	for i in range(48):route_marks.append(_mark(4,0.30))
	area=MeshInstance3D.new();add_child(area)
	var material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(0.71,0.69,0.39,0.10)
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	area.material_override=material;area.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clear()

func _mark(index: int,width: float) -> Sprite3D:
	var sprite=Sprite3D.new();sprite.texture=art.ground(index)
	sprite.pixel_size=width/sprite.texture.get_width()
	sprite.rotation.x=-PI*0.5;sprite.shaded=false;sprite.modulate.a=0.85
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

func clear() -> void:
	destination.visible=false;area.visible=false
	for marker in route_marks:marker.visible=false
	last_key="";preview={}

func update(key: String,point,dt: float) -> void:
	if key.is_empty() or point==null:clear();return
	refresh_left-=dt
	if key!=last_key or refresh_left<=0 or last_point.distance_to(point)>0.13:
		last_key=key;last_point=point;refresh_left=0.14
		preview=board.preview_order(key,point,not board.active)
		_draw_area(key)
		for marker in route_marks:marker.visible=false
		if preview.valid:
			var route=preview.path;var remaining=0.4;var mark_index=0
			for i in range(1,route.size()):
				var a=route[i-1];var b=route[i];var length=a.distance_to(b)
				while remaining<length and mark_index<route_marks.size():
					var mark=route_marks[mark_index];mark.visible=true
					mark.position=a.lerp(b,remaining/maxf(length,0.001))+Vector3(0,0.055,0)
					mark.rotation=Vector3(-PI*0.5,atan2(-(b.x-a.x),-(b.z-a.z)),0)
					mark_index+=1;remaining+=0.5
				remaining-=length
	destination.visible=true
	destination.texture=art.ground(2 if preview.valid else 3)
	destination.no_depth_test=not preview.valid
	destination.position=preview.point+Vector3(0,0.07,0)
	destination.modulate.a=0.76+sin(Time.get_ticks_msec()*0.006)*0.12

func _draw_area(key: String) -> void:
	var pawn=board.unit(key)
	if pawn==null:return
	var nav=board.navigation
	var reachable=nav.reachable(pawn.position,board.pawns if board.active else [],pawn)
	var build=SurfaceTool.new();build.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count=0
	for index in range(0,nav.floor_faces.size(),3):
		var triangle=[nav.floor_faces[index],nav.floor_faces[index+1],nav.floor_faces[index+2]]
		var valid=true
		for vertex in triangle:
			var cell=nav._cell(vertex)
			if not reachable.has(nav.cells.get(cell,-1)):valid=false;break
			if not board.active and not nav.is_deployment(vertex):valid=false;break
		if valid:
			for vertex in triangle:build.add_vertex(vertex+Vector3(0,0.03,0));count+=1
	area.visible=count>0
	if count>0:build.generate_normals();area.mesh=build.commit()

