extends RefCounted

var elapsed=0.0
var level=0.18
var wave_height=0.12
var wind_strength=0.35
var wind_direction=Vector2(-0.82,-0.36).normalized()
var rainfall=0.0
var wetness=0.0
var target_wave=0.12
var target_wind=0.35
var target_rain=0.0

func configure(waves: float,wind: float,rain: float,immediate: bool=false) -> void:
	target_wave=clampf(waves,0,0.9);target_wind=clampf(wind,0,1);target_rain=clampf(rain,0,1)
	if immediate:wave_height=target_wave;wind_strength=target_wind;rainfall=target_rain;wetness=rainfall

func tick(dt: float) -> void:
	elapsed+=dt
	wave_height=move_toward(wave_height,target_wave,dt*0.08)
	wind_strength=move_toward(wind_strength,target_wind,dt*0.12)
	rainfall=move_toward(rainfall,target_rain,dt*0.16)
	wetness=move_toward(wetness,rainfall,dt*(0.12 if rainfall>wetness else 0.015))

func height_at(point: Vector3,at_time: float=-1.0) -> float:
	var time=elapsed if at_time<0 else at_time
	var p=Vector2(point.x,point.z)
	return level+wave_height*(sin(p.dot(Vector2(0.78,0.63).normalized())*TAU/26.0-time*1.05)*0.58+sin(p.dot(Vector2(-0.56,0.83).normalized())*TAU/13.7-time*1.45+1.7)*0.28+sin(p.dot(Vector2(0.95,-0.31).normalized())*TAU/8.2-time*2.2+0.4)*0.14)

func water_hit_fraction(a: Vector3,b: Vector3,dt: float) -> float:
	var start=maxf(0,elapsed-dt)
	if a.y<=height_at(a,start):return 0.0
	var count=clampi(ceili(a.distance_to(b)/0.7),4,128)
	var previous=0.0
	for index in range(1,count+1):
		var t=float(index)/count;var point=a.lerp(b,t)
		if point.y<=height_at(point,start+dt*t):
			var low=previous;var high=t
			for step in range(8):
				var mid=(low+high)*0.5;var sample=a.lerp(b,mid)
				if sample.y>height_at(sample,start+dt*mid):low=mid
				else:high=mid
			return high
		previous=t
	return 2.0

func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("clock",elapsed)
	material.set_shader_parameter("wave_height",wave_height)
	material.set_shader_parameter("wind_strength",wind_strength)
	material.set_shader_parameter("wind_direction",wind_direction)
	material.set_shader_parameter("rainfall",rainfall)
	material.set_shader_parameter("water_level",level)

func snapshot() -> Dictionary:
	return {"time":elapsed,"wave":wave_height,"wind":wind_strength,"rain":rainfall,"wet":wetness,"target_wave":target_wave,"target_wind":target_wind,"target_rain":target_rain}

func restore(data: Dictionary) -> void:
	elapsed=data.get("time",0);wave_height=data.get("wave",0.12);wind_strength=data.get("wind",0.35);rainfall=data.get("rain",0);wetness=data.get("wet",0)
	target_wave=data.get("target_wave",wave_height);target_wind=data.get("target_wind",wind_strength);target_rain=data.get("target_rain",rainfall)
