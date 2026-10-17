"""Derive a reefed-sail boarding state from the existing painted ship. Source stays intact."""
from pathlib import Path
import hashlib
import json
import math
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'Godot/assets/quay-v03/merchant-ship-a.glb'
OUT=ROOT/'Godot/assets/demo/merchant-ship-boarding-v2.glb'
before=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
originals=[o for o in bpy.context.scene.objects if o.type=='MESH']
counts={'retained_faces':0,'furled_faces':0,'rigging_faces_replaced':0}
all_points=[o.matrix_world@v.co for o in originals for v in o.data.vertices]
fore_top=max((v for v in all_points if v.x>2.0),key=lambda p:p.z)
main_top=max(all_points,key=lambda p:p.z)
axes=[Vector((main_top.x,0,0)),Vector((fore_top.x,0,0))]

for source in originals:
    matrix=source.matrix_world.copy()
    mesh=source.data
    verts=[]; faces=[]; uvs=[]; normals=[]; material_indices=[]
    source_normals=mesh.corner_normals
    for poly in mesh.polygons:
        points=[matrix@mesh.vertices[i].co for i in poly.vertices]
        center=sum(points,Vector())/len(points)
        normal=(matrix.to_3x3()@poly.normal).normalized()
        upper=center.z>2.65
        cabin_roof=center.x<-4.65 and center.z<4.6
        bow_detail=center.x>6.1 and center.z<3.65
        fold=False
        if upper and not cabin_roof and not bow_detail:
            counts['rigging_faces_replaced']+=1
            continue
        counts['retained_faces']+=1
        start=len(verts)
        verts.extend(points)
        faces.append(tuple(range(start,start+len(points))))
        material_indices.append(poly.material_index)
        face_normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
        for loop in poly.loop_indices:
            uvs.append(tuple(mesh.uv_layers.active.data[loop].uv))
            normals.append(tuple(face_normal if fold else (matrix.to_3x3()@source_normals[loop].vector).normalized()))
    output_mesh=bpy.data.meshes.new('GEO-BoardingShip-Mesh')
    output_mesh.from_pydata(verts,[],faces)
    output_mesh.update()
    uv=output_mesh.uv_layers.new(name='UVMap')
    for i,value in enumerate(uvs):uv.data[i].uv=value
    for mat in mesh.materials:output_mesh.materials.append(mat)
    for poly,index in zip(output_mesh.polygons,material_indices):
        poly.material_index=index
        poly.use_smooth=True
    output_mesh.normals_split_custom_set(normals)
    obj=bpy.data.objects.new('GEO-BoardingShip',output_mesh)
    bpy.context.collection.objects.link(obj)
    bpy.data.objects.remove(source,do_unlink=True)

rope=bpy.data.materials.new('MAT-WorkingRigging')
rope.diffuse_color=(0.19,0.14,0.085,1)
rope.use_nodes=True
bsdf=rope.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value=rope.diffuse_color
bsdf.inputs['Roughness'].default_value=0.95
bsdf.inputs['Specular IOR Level'].default_value=0.08
def line(a,b,radius=0.025):
    a=Vector(a);b=Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=radius,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object
    obj.name='GEO-StandingRigging'
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(rope)
    for p in obj.data.polygons:p.use_smooth=True
# Rebuild functional spars and compact folded canvas, keeping the original painted hull intact.
wood=bpy.data.materials.new('MAT-PaintedMast')
wood.use_nodes=True
wood_nodes=wood.node_tree.nodes
wood_tex=wood_nodes.new('ShaderNodeTexImage')
wood_tex.image=bpy.data.images.load(str(ROOT/'Godot/assets/environment/weathered-timber.png'))
wood_tex.interpolation='Closest'
wood_shader=wood_nodes.get('Principled BSDF')
wood.node_tree.links.new(wood_tex.outputs['Color'],wood_shader.inputs['Base Color'])
wood_shader.inputs['Roughness'].default_value=0.96
wood_shader.inputs['Specular IOR Level'].default_value=0.08
canvas=bpy.data.materials.new('MAT-ReefedCanvas')
canvas.use_nodes=True
canvas_shader=canvas.node_tree.nodes.get('Principled BSDF')
canvas_shader.inputs['Base Color'].default_value=(0.62,0.48,0.28,1)
canvas_shader.inputs['Roughness'].default_value=0.98
canvas_shader.inputs['Specular IOR Level'].default_value=0.06
canvas_tex=canvas.node_tree.nodes.new('ShaderNodeTexImage')
canvas_tex.image=bpy.data.images.load(str(ROOT/'Godot/assets/quay-v03/material-atlas.png'))
canvas_tex.interpolation='Closest'
canvas.node_tree.links.new(canvas_tex.outputs['Color'],canvas_shader.inputs['Base Color'])
for axis,top in zip(axes,[main_top.z-0.15,fore_top.z-0.15]):
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=0.15,radius2=0.09,depth=top-1.5,location=(axis.x,0,(top+1.5)/2))
    mast=bpy.context.object
    mast.name='GEO-PaintedMast'
    mast.data.materials.append(wood)
    for face in mast.data.polygons:face.use_smooth=True
for left,right,height in [(-4.1,axes[0].x,5.05),(1.05,axes[1].x,4.65)]:
    length=right-left
    line((left-0.15,0,height-0.16),(right+0.18,0,height-0.16),0.07)
    for layer in range(5):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=12,location=((left+right)/2,0,height+layer*0.075))
        bundle=bpy.context.object
        bundle.name='GEO-FoldedCanvas'
        bundle.scale=(length/2,0.21,0.095)
        for vert in bundle.data.vertices:
            vert.co.y*=1+0.08*math.sin(vert.co.x*24)
        bundle.data.materials.append(canvas)
        for face in bundle.data.polygons:face.use_smooth=True
        for uv in bundle.data.uv_layers.active.data:
            uv.uv.x=0.52+uv.uv.x*0.45
            uv.uv.y=0.03+uv.uv.y*0.44
    for fraction in (0.15,0.45,0.75,0.95):
        x=left+length*fraction
        bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=(x,0,height+0.14),rotation=(0,math.pi/2,0),major_radius=0.24,minor_radius=0.025)
        tie=bpy.context.object
        tie.name='GEO-CanvasTie'
        tie.data.materials.append(rope)
for axis,top in zip(axes,[main_top.z-0.18,fore_top.z-0.15]):
    for side in (-1,1):
        for offset in (-2.3,2.3):
            line((axis.x,0,top),(max(-6.5,min(6.5,axis.x+offset)),side*2.0,1.92))

OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_yup=True,export_apply=True,
    export_materials='EXPORT',export_image_format='AUTO',export_animations=False,export_normals=True)
after=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert before==after
assert OUT.stat().st_size<15*1024*1024
record={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':before,'source_unchanged':True,
    'output':str(OUT.relative_to(ROOT)),'output_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),
    'bytes':OUT.stat().st_size,'mast_axes':[list(a) for a in axes],'counts':counts,
    'method':'Original painted hull, cabin, deck, rails and UVs retained; masts, spars, folded canvas bundles and standing rigging rebuilt for a readable boarding state using the v03 timber/paint textures.',
    'generation_tasks':0}
receipt=ROOT/'Assets/HarborTrial/demo/boarding-ship-production-v2.json'
receipt.parent.mkdir(parents=True,exist_ok=True)
receipt.write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print('BOARDING_SHIP_READY '+json.dumps(record))
