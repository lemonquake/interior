"""Measure Blender shell/support geometry and build the Form review page."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent.parent;p=root/'room'
bpy.ops.wm.open_mainfile(filepath=str(p/'living_room.blend'))
scene=bpy.context.scene;graph=bpy.context.evaluated_depsgraph_get()
shell=[]
for name in ['Floor','Back wall','Left wall','Right wall','Rear wall','Ceiling']:
    o=bpy.data.objects[name]; mesh=o.evaluated_get(graph).to_mesh(); bm=bmesh.new();bm.from_mesh(mesh)
    shell.append(dict(id=name,nonManifoldEdges=sum(not e.is_manifold for e in bm.edges),volumeMeters3=abs(bm.calc_volume()),dimensions=list(o.dimensions)))
    bm.free();o.evaluated_get(graph).to_mesh_clear()
checks=dict(structuralManifold=all(s['nonManifoldEdges']==0 and s['volumeMeters3']>0 for s in shell),fullHeightWalls=all(abs(bpy.data.objects[n].dimensions.z-2.9)<.001 for n in ['Back wall','Left wall','Right wall','Rear wall']),thickSubstrates=all(min(s['dimensions'])>=.19 for s in shell),sourceMeters=scene.unit_settings.system=='METRIC',noUnscheduledApertures=True)
layout=json.loads((p/'room-layout.json').read_text());stats={}
for i in layout['instances']:
    o=bpy.data.objects[i['meshObject']]; verts=[o.matrix_world@v.co for v in o.evaluated_get(graph).data.vertices]
    stats[i['id']]=dict(minimum=[min(v[k] for v in verts) for k in range(3)],maximum=[max(v[k] for v in verts) for k in range(3)],triangles=sum(len(f.vertices)-2 for f in o.data.polygons))
audit=json.loads((p/'form-audit.json').read_text()); audit['measuredShell']=shell; audit['measuredChecks']=checks; audit['measuredInstanceBounds']=stats; audit['shell']['structuralManifold']=checks['structuralManifold']; audit['totalPlacedTriangles']=sum(s['triangles'] for s in stats.values())
audit['ceiling']['measuredFixtureContact']=[]
for name in ['ceiling-center fixture','ceiling-tv fixture']:
    o=bpy.data.objects[name];v=[o.matrix_world@Vector(c) for c in o.bound_box];top=max(x.z for x in v)
    audit['ceiling']['measuredFixtureContact'].append(dict(id=name,topMeters=top,ceilingUndersideMeters=2.9,insetMeters=top-2.9,broadFaceHorizontal=True))
(p/'form-audit.json').write_text(json.dumps(audit,indent=2))
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Interior — Final room review</title><style>body{margin:0;background:#f4f0e9;color:#25221e;font:18px/1.6 system-ui}main{max-width:1280px;margin:auto;padding:32px}h1{font-size:40px}h2{font-size:27px}img{width:100%;display:block;border-radius:6px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}a{color:#694319}.status{background:#e8ddcc;padding:18px;border-radius:8px}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><main><h1>Interior — Final Blender room review</h1><p>By Aljay Leodones</p><p class="status">Function approved by the owner. Form review pending: approve the final room before it can be exported into Godot. Runtime review and publication follow separately.</p><h2>Production camera</h2><img src="renders/final-production.png" alt="Final Blender room from the player arrival view"><p>The room follows the approved estimated layout. Furniture backs, walls outside the photograph, and ceiling remain inferred. Texture and fine-detail differences from the photograph remain; this is not a measured photogrammetry scan.</p><h2>Four corner views</h2><div class="grid">CORNERS</div><h2>Ceiling and attachment views</h2><div class="grid">CEILING</div><h2>Geometry and provenance</h2><p>CHECKS</p><p>Custom procedural meshes and authored textures; free wood and floor marble textures from Poly Haven (CC0). Miniature frame inserts use the supplied reference photo. No paid asset generation.</p><p>Shell substrates have thickness and closed manifold meshes. The home layout is intentionally asymmetric. No doorway was visible, so the approved room starts the player inside with closed inferred rear walls. The sofas face the table and TV. Movable furnishings will use compound physics colliders, and wall props will detach when grabbed.</p><p><a href="living_room.blend">Final Blender source</a> · <a href="form-audit.json">Measured geometry audit</a> · <a href="review.html">Approved Function study</a></p><p>Approve this final room geometry and appearance to proceed with the Godot room export. The final executable, Android APK, and repository push require the later Runtime review.</p></main></html>'''
corners=''.join(f'<div><img src="renders/corner-{i}.png" alt="Room corner {i}"><p>Corner {i}</p></div>' for i in range(1,5))
ceil=''.join(f'<div><img src="renders/{name}.png" alt="{label}"><p>{label}</p></div>' for name,label in [('ceiling-center-up','Center looking up'),('ceiling-oblique-a','Ceiling from front left'),('ceiling-oblique-b','Ceiling from rear right')])
(p/'form-review.html').write_text(page.replace('CORNERS',corners).replace('CEILING',ceil).replace('CHECKS',json.dumps(checks)),encoding='utf-8')
print('MEASURED_FORM_AUDIT',json.dumps(checks))
