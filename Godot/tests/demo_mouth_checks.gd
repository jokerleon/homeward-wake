extends SceneTree
const Motion=preload("res://scripts/demo/character_motion.gd")
func _initialize() -> void:
	var bundle=Motion.bundle("hero","explore")
	var material=ShaderMaterial.new();material.shader=load("res://shaders/demo_actor.gdshader")
	var failures=[]
	var checks=0
	for name in bundle.metadata:
		var clip=bundle.metadata[name]
		checks+=1
		if clip.has("mouth_stability"):
			if not String(name).begins_with("S_"):failures.append("stability applied outside S")
			if clip.mouth_stability.target_rects_uv.size()!=clip.frames:failures.append("mouth/frame count mismatch")
	Motion.apply_mouth_stability(material,bundle.metadata.S_move_loop,14)
	checks+=1
	if material.get_shader_parameter("stable_mouth_enabled")!=true:failures.append("S mouth is not enabled")
	Motion.apply_mouth_stability(material,bundle.metadata.E_move_loop,14)
	checks+=1
	if material.get_shader_parameter("stable_mouth_enabled")!=false:failures.append("mouth remains enabled after turning E")
	Motion.apply_mouth_stability(material,bundle.metadata.S_idle,999)
	checks+=1
	var expected=bundle.metadata.S_idle.mouth_stability.target_rects_uv[0]
	if material.get_shader_parameter("stable_mouth_target")!=Vector4(expected[0],expected[1],expected[2],expected[3]):failures.append("stale frame index is not clamped")
	print("MOUTH_CHECKS "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
