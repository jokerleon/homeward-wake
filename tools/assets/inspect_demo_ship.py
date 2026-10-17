"""Read-only surface probe of the retained runtime ship in an isolated Blender process."""
from pathlib import Path
import json
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "Godot/assets/quay-v03/merchant-ship-a.glb"))
vertices = []
triangles = []
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    obj.data.calc_loop_triangles()
    offset = len(vertices)
    vertices += [obj.matrix_world @ v.co for v in obj.data.vertices]
    triangles += [tuple(offset + i for i in t.vertices) for t in obj.data.loop_triangles]
bvh = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
probes = []
for long_axis in (-6,-4,-2,0,2,4,6):
    for cross_axis in (-1.8,-0.9,0,0.9,1.8):
        location, normal, _, _ = bvh.ray_cast(Vector((long_axis,cross_axis,4.0)),Vector((0,0,-1)),7)
        if location is not None:
            probes.append({"x":long_axis,"y":cross_axis,"height":round(location.z,3),"normal_z":round(normal.z,3)})
data={"bounds":[[min(p[i] for p in vertices) for i in range(3)],[max(p[i] for p in vertices) for i in range(3)]],"probes":probes,"source_unchanged":True}
out=ROOT / "Local/ReturnDemo/ship-surface-probe.json"
out.write_text(json.dumps(data,indent=2),encoding="utf-8")
print(json.dumps(data))
for lower,upper in [(12.3,13.0),(10.0,10.3),(8.0,8.2)]:
    points=[p for p in vertices if lower<p.z<upper]
    print('UPPER',lower,len(points),[[round(min(p[i] for p in points),3),round(max(p[i] for p in points),3)] for i in range(3)])
spacing=0.15
x_min=-1.95
z_min=-4.8
nx=27
nz=65
heights=[]
for iz in range(nz):
    for ix in range(nx):
        # Godot model is rotated +90 degrees about Y for a -Z bow.
        gx=x_min+ix*spacing
        gz=z_min+iz*spacing
        location,normal,_,_=bvh.ray_cast(Vector((-gz,-gx,2.35)),Vector((0,0,-1)),1.2)
        heights.append(round(location.z,4) if location is not None and normal.z>0.45 and location.z>1.2 else None)
surface={"source":"res://assets/quay-v03/merchant-ship-a.glb","rotation_y_degrees":90,"x_min":x_min,"z_min":z_min,"spacing":spacing,"nx":nx,"nz":nz,"heights":heights}
surface_out=ROOT / "Godot/assets/demo/ship-deck-surface.json"
surface_out.parent.mkdir(parents=True,exist_ok=True)
surface_out.write_text(json.dumps(surface,separators=(',',':')),encoding="utf-8")
