"""Check local procedural evidence without fabricating Meshy or human approvals.

Preflight readiness is distinct from an approved Function gate.
"""
from pathlib import Path
import json, sys
root=Path(__file__).resolve().parent.parent
pkg=root/'room'
def read(name):return json.loads((pkg/name).read_text(encoding='utf-8'))
brief=read('room-brief.json'); props=read('props.json'); layout=read('room-layout.json'); reviews=read('milestone-reviews.json')
errors=[]
for a in props['assets']:
    if not (pkg/a['image']['source']).is_file():errors.append('Missing studio image: '+a['id'])
    actual=sum(i['assetId']==a['id'] for i in layout['instances'])
    if actual!=a['intendedInstances']:errors.append('Instance count mismatch: '+a['id'])
    if a['sourceMethod']!='procedural-blender':errors.append('Unexpected asset method')
    if a['attempts']:errors.append('Unapproved paid service submission')
for p in ['plans/lower-room-engineering.png','plans/reflected-ceiling-engineering.png','plans/tv-wall-elevation-engineering.png','images/prop-contact-sheet.jpg','masks/openings-contact.png','renders/layout-study.png','living_room_study.blend','review.html']:
    if not (pkg/p).is_file():errors.append('Missing artifact: '+p)
if brief['creditBudget']['maximumCredits']!=0:errors.append('Paid generation budget must remain zero')
ids=[i['id'] for i in layout['instances']]
if len(set(ids))!=len(ids):errors.append('Duplicate instance IDs')
stats=read('mesh-statistics.json')
triangles=sum(stats['assets'][i['assetId']]['triangles'] for i in layout['instances'])
if triangles>brief['performanceBudget']['maxSceneTriangles']:errors.append('Prop geometry over scene budget')
approved=reviews['function']['status']=='approved' and bool(reviews['function'].get('approvedBy')) and all(a['image']['approved'] for a in props['assets'])
result=dict(preflightReady=not errors,errors=errors,humanApprovalRecorded=approved,gatePassed=not errors and approved,assetMethod='custom-procedural',chargedCredits=0,placedPropTriangles=triangles,upstreamValidatorAdaptation='Meshy pricing/task/credit fields are inapplicable to the explicitly requested free procedural pipeline; upstream output retained separately.')
(pkg/'function-preflight.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
sys.exit(1 if errors else 0)
