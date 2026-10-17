"""Blender-only runtime preparation; source HY model is preserved byte-for-byte."""
from pathlib import Path
import json
import hashlib
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Assets/HarborTrial/v03/Models/merchant-ship-a/model.glb'
OUT = ROOT / 'Godot/assets/quay-v03/merchant-ship-a.glb'
RECORD = SOURCE.parent / 'runtime-preparation.json'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

before = sha(SOURCE)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ Vector(v) for o in objects for v in o.bound_box]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
size = high-low
scale = 16.0 / max(size.x,size.y)
offset = Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
source_faces = sum(len(o.data.polygons) for o in objects)
images = []
for obj in objects:
    transform = obj.matrix_world.copy()
    obj.parent = None
    obj.data.transform(transform)
    obj.matrix_world.identity()
    for v in obj.data.vertices:
        v.co = (v.co-offset)*scale
        v.co.z -= 1.70
    obj.name = 'GEO-MerchantShip'
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if source_faces > 100000:
        mod = obj.modifiers.new('Runtime_SilhouettePreservingReduction','DECIMATE')
        mod.ratio = 100000.0/source_faces
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)

for im in bpy.data.images:
    if not im.size[0]:
        continue
    original = list(im.size)
    if max(im.size) > 1536:
        ratio = 1536.0/max(im.size)
        im.scale(round(im.size[0]*ratio),round(im.size[1]*ratio))
    images.append({'name':im.name,'original_dimensions':original,'runtime_dimensions':list(im.size)})

for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE':
            node.interpolation='Closest'
        if node.type=='BSDF_PRINCIPLED':
            node.inputs['Metallic'].default_value=0.0
            node.inputs['Roughness'].default_value=0.94
            node.inputs['Specular IOR Level'].default_value=0.08

OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_yup=True,
    export_apply=True,export_materials='EXPORT',export_image_format='AUTO',
    export_animations=False,export_normals=True,export_tangents=False)
after = sha(SOURCE)
if before != after:
    raise RuntimeError('Source GLB changed unexpectedly')
if OUT.stat().st_size > 15*1024*1024:
    raise RuntimeError('Runtime GLB exceeds the 15 MiB packaging ceiling')
record = {
    'source':str(SOURCE.relative_to(ROOT)),
    'source_sha256':before,
    'source_untouched':True,
    'output':str(OUT.relative_to(ROOT)),
    'output_sha256':sha(OUT),
    'output_bytes':OUT.stat().st_size,
    'source_faces':source_faces,
    'runtime_faces':sum(len(o.data.polygons) for o in objects),
    'source_size_blender_xyz':list(size),
    'horizontal_length_m':16.0,
    'keel_height_m':-1.70,
    'material':'Authored image-to-3D texture, matte response and nearest sampling; no PBR generation',
    'texture_export':images,
    'authorship':'Tencent HY-3D model from an original built-in imagegen reference; local normalization, reduction and GLB preparation'
}
RECORD.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('QUAY_SHIP_READY '+json.dumps(record,ensure_ascii=False))
