extends RefCounted

static func prepare(root: Node3D) -> void:
	for node in root.find_children("*","MeshInstance3D",true,false):
		node.layers=5 # visible to the same planar water reflection used by harbor v03
		for surface in range(node.mesh.get_surface_count()):
			var original=node.get_active_material(surface)
			if original is StandardMaterial3D:
				var material=original.duplicate()
				# The generated sail is a thin surface; its painted back must remain visible at sea.
				material.cull_mode=BaseMaterial3D.CULL_DISABLED
				node.set_surface_override_material(surface,material)
