"""Project gate checker for the user-requested free procedural asset pipeline."""
from pathlib import Path
import json,sys,hashlib
root=Path(__file__).resolve().parent.parent;p=root/'room'
gate=sys.argv[1] if len(sys.argv)>1 else 'form'
review=json.loads((p/'milestone-reviews.json').read_text())
audit=json.loads((p/'form-audit.json').read_text())
errors=[]
for key,val in audit['measuredChecks'].items():
    if not val:errors.append('Failed measured Form check: '+key)
for name in ['final-production.png','corner-1.png','corner-2.png','corner-3.png','corner-4.png','ceiling-center-up.png','ceiling-oblique-a.png','ceiling-oblique-b.png']:
    if not (p/'renders'/name).is_file():errors.append('Missing render: '+name)
for name in ['function','form']+(['runtime'] if gate=='runtime' else []):
    r=review[name]
    if r['status']!='approved' or not r.get('approvedBy') or not r.get('approvedAt'):errors.append('Explicit owner approval pending: '+name)
if gate=='runtime':
    for name in ['game/assets/living_room.glb','game/assets/room_manifest.json','builds/windows/Interior.exe','builds/android/Interior.apk']:
        if not (root/name).is_file():errors.append('Missing delivery artifact: '+name)
    runtime=p/'runtime'
    if not (runtime/'runtime-audit.json').is_file():
        errors.append('Missing native runtime audit')
    else:
        native=json.loads((runtime/'runtime-audit.json').read_text())
        for name,passed in native['checks'].items():
            if not passed:errors.append('Failed native runtime check: '+name)
        for name,artifact in native['artifacts'].items():
            path=root/artifact['path']
            if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()!=artifact['sha256']:
                errors.append('Delivery hash changed after testing: '+name)
        manifest=json.loads((runtime/'export-manifest.json').read_text())
        for filename,field in [('room/living_room.blend','sourceSha256'),('game/assets/living_room.glb','glbSha256')]:
            if hashlib.sha256((root/filename).read_bytes()).hexdigest()!=manifest[field]:errors.append('Room asset hash mismatch: '+filename)
    for name in ['living-room-play.png','living-room-menu.png','android-play.png','android-held.png','android-pause.png']:
        if not (runtime/name).is_file():errors.append('Missing native runtime capture: '+name)
result=dict(gate=gate,passed=not errors,errors=errors,adaptation='Procedural Blender sources replace Meshy task/credit requirements; human reviews remain required.',blenderSourceSha256=hashlib.sha256((p/'living_room.blend').read_bytes()).hexdigest())
(p/f'{gate}-gate-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result));sys.exit(1 if errors else 0)
