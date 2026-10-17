"""Blender-only: normalize the new HY warehouse and export a compact runtime GLB."""
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'Assets/HarborTrial/v01/Models/warehouse-a/model.glb'
output=ROOT/'Godot/assets/environment/warehouse-a.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
if not objects:raise RuntimeError('Generated asset has no mesh')
points=[obj.matrix_world@Vector(corner) for obj in objects for corner in obj.bound_box]
low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
size=high-low
factor=8.0/max(size.x,size.y)
offset=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
original_faces=sum(len(obj.data.polygons) for obj in objects)
for obj in objects:
    transform=obj.matrix_world.copy()
    obj.parent=None
    obj.matrix_world.identity()
    for vertex in obj.data.vertices:
        vertex.co=(transform@vertex.co-offset)*factor
    if original_faces>65000:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        mod=obj.modifiers.new('Runtime_Simplification','DECIMATE')
        mod.ratio=min(1.0,65000.0/original_faces)
        mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.select_set(False)
for image in bpy.data.images:
    if image.size[0] and max(image.size)>1536:
        ratio=1536.0/max(image.size)
        image.scale(round(image.size[0]*ratio),round(image.size[1]*ratio))
for mat in bpy.data.materials:
    if not mat.use_nodes:continue
    for node in mat.node_tree.nodes:
        if node.type=='BSDF_PRINCIPLED':
            for socket in node.inputs:
                if socket.name=='Metallic':socket.default_value=0.0
                if socket.name=='Roughness':socket.default_value=0.95
                if socket.name=='Specular IOR Level':socket.default_value=0.15
output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT',export_image_format='AUTO')
report={'source':str(source.relative_to(ROOT)),'output':str(output.relative_to(ROOT)),
        'original_faces':original_faces,'runtime_faces':sum(len(obj.data.polygons) for obj in objects),
        'original_size_blender_xyz':list(size),'normalized_horizontal_extent_m':8.0,
        'textures_max_side':1536,'output_bytes':output.stat().st_size,
        'source_asset_untouched':True,'authorship':'New HY-3D model; local scale/material/export processing, not newly hand-modeled geometry.'}
(ROOT/'Assets/HarborTrial/v01/Models/warehouse-a/runtime-preparation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('HARBOR_MODEL_READY '+json.dumps(report))
