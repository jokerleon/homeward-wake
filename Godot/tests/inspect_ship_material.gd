extends SceneTree
func _initialize() -> void:
	var model=load("res://assets/quay-v03/merchant-ship-a.glb").instantiate()
	root.add_child(model)
	print("ROOT ",model.get_class())
	for node in model.find_children("*","MeshInstance3D",true,false):
		print("MESH ",node.name," override=",node.material_override)
		for i in range(node.mesh.get_surface_count()):
			var mat=node.get_active_material(i)
			print("SURFACE ",i," ",mat.get_class()," cull=",mat.cull_mode if mat is BaseMaterial3D else -1," transparent=",mat.transparency if mat is BaseMaterial3D else -1)
	quit()
