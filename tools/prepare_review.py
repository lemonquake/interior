"""Create the portable, accessible Function review page from Blender renders."""
from pathlib import Path
import json, html, hashlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

root=Path(__file__).resolve().parent.parent
pkg=root/'room'
props=json.loads((pkg/'props.json').read_text())['assets']
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
contact=Image.new('RGB',(1440,6*294),'white')
draw=ImageDraw.Draw(contact)
for i,a in enumerate(props):
    x=(i%4)*360; y=(i//4)*294
    im=Image.open(pkg/a['image']['source']).convert('RGB').resize((256,256))
    contact.paste(im,(x+52,y))
    draw.text((x+12,y+262),a['description'][:33],fill='black',font=small)
contact.save(pkg/'images/prop-contact-sheet.jpg',quality=92)
mask=Image.new('RGB',(960,240),'white')
draw=ImageDraw.Draw(mask)
draw.rectangle((10,10,950,230),outline='black',width=2)
draw.text((28,45),'Opening schedule: no openings visible in the reference photo.',fill='black',font=font)
draw.text((28,92),'The player starts inside. Unseen walls are estimated and closed.',fill='black',font=font)
draw.text((28,141),'No opening cutters or paid mesh generation are scheduled.',fill='black',font=font)
mask.save(pkg/'masks/openings-contact.png')

# White-page engineering drawings from the actual-mesh projection, preserving
# silhouettes. Architecture outlines use the shell dimensions, not prop boxes.
for name in ['lower-room','reflected-ceiling','tv-wall-elevation']:
    src=Image.open(pkg/f'plans/{name}.png').convert('RGBA')
    canvas=Image.new('RGBA',src.size,'white'); canvas.alpha_composite(src)
    gray=canvas.convert('L')
    edges=gray.filter(ImageFilter.FIND_EDGES)
    linework=ImageOps.invert(edges)
    linework=Image.blend(gray,linework,.76)
    pen=ImageDraw.Draw(linework)
    if name!='tv-wall-elevation':
        # Orthographic width is 7.35m; Blender's image aspect gives height.
        w,h=src.size; px=w/7.35
        left=w/2-3.3*px; right=w/2+3.3*px
        top=h/2-2.7*px; bottom=h/2+2.7*px
        pen.rectangle((left,top,right,bottom),outline=0,width=3)
    linework.save(pkg/f'plans/{name}-engineering.png')

cards=''.join(f'<article><img src="{a["image"]["source"]}" alt="{html.escape(a["description"])}"><h3>{html.escape(a["description"])}</h3><p>{" × ".join(str(v) for v in a["dimensionsMeters"])} m · {a["intendedInstances"]} instances</p></article>' for a in props)
stats=json.loads((pkg/'mesh-statistics.json').read_text())
layout=json.loads((pkg/'room-layout.json').read_text())
triangles=sum(stats['assets'][i['assetId']]['triangles'] for i in layout['instances'])
legend=''.join(f'<li>{html.escape(i["assetId"].replace("_"," "))}: ({i["location"][0]:.2f}, {i["location"][1]:.2f}, {i["location"][2]:.2f}) m</li>' for i in layout['instances'])
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Interior — Room study</title><style>
body{margin:0;background:#f4f0e9;color:#25221e;font:18px/1.6 system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:36px}h1{font-size:46px;margin:0}h2{font-size:28px;margin-top:45px}h3{font-size:18px;margin:12px 0 5px}p{max-width:1000px}img{display:block;width:100%;height:auto;border-radius:6px;background:white}.row{display:grid;grid-template-columns:1fr 1fr;gap:20px}.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}article{background:white;padding:14px;border-radius:8px}article p{font-size:16px}nav a{color:#593914;margin-right:20px}.status{padding:18px;background:#e8ddcc;border-radius:8px}.legend{columns:3;font-size:16px}a{color:#674517}@media(max-width:800px){.row,.cards{grid-template-columns:1fr 1fr}.legend{columns:1}main{padding:18px}}
</style><main><h1>Interior</h1><p>By Aljay Leodones · Living room study</p><p class="status">Function review pending. This is an estimated layout and custom object study. Final materials, final room construction, game asset export, and publication require later reviews.</p><nav><a href="#layout">Layout</a><a href="#plans">Plans</a><a href="#objects">Objects</a><a href="#game">Game</a></nav>
<h2 id="layout">Photo and Blender layout study</h2><div class="row"><div><img src="images/reference.png" alt="Owner supplied living room photograph"><p>Supplied reference</p></div><div><img src="renders/layout-study.png" alt="Blender reconstruction layout study"><p>Actual procedural Blender geometry; study materials and blank photo inserts</p></div></div>
<p>Estimated room bounds: 6.6 m wide × 5.4 m deep × 2.9 m high. The owner approved estimates. The visible wall, furniture relationships, and room objects are the target. Unseen side walls, rear wall, ceiling, and object backs need inference; exact 1:1 measurements cannot be established from this photo.</p>
<p>The left fabric sofa faces the table; the foreground leather sofa faces the TV. The table is the center of the seating group. The desk, crib, high chair, fan, and pet enclosure remain separate. Floor, walls, and ceiling are fixed room structure; furnishings and movable decor will use physics. Wall-mounted props can be detached when grabbed.</p>
<h2 id="plans">Engineering plans</h2><p>Object marks come from top-down orthographic renders of the actual authored meshes. Text stays outside the plan images. Coordinates below use Blender Z up, with +Y toward the TV wall.</p><div class="row"><div><img src="plans/lower-room-engineering.png" alt="Lower room engineering plan"><p>Lower-room layer</p></div><div><img src="plans/reflected-ceiling-engineering.png" alt="Reflected ceiling engineering plan"><p>Reflected-ceiling layer: two inferred flush fixtures</p></div></div><img src="plans/tv-wall-elevation-engineering.png" alt="TV wall engineering elevation"><p>TV wall elevation</p><ul class="legend">LEGEND</ul>
<p>Main movement route: beside the right edge of the table toward the fan and TV cabinet. Player collision radius: 0.24 m; height: 1.70 m. Minimum planned clear aisle: 0.65 m. Object layouts may change during play. Spawn and reset recover a usable room state.</p>
<h2>Openings</h2><img src="masks/openings-contact.png" alt="No door or window opening is visible in the reference"><p>No door or window is visible. This study starts the player inside the room and keeps inferred rear walls closed. No invented exit is presented as a copy of the real house.</p>
<h2 id="objects">Custom object references</h2><p>All 24 families below are custom procedural Blender meshes, with 40 placed instances. No paid service or credits are used. Studio images are references for approval, not completed photoreal textures.</p><div class="cards">CARDS</div>
<h2 id="game">Gameplay and performance</h2><p>Desktop: WASD movement, mouse look, E hold/drop, left click throw, J notes, Esc pause. Mobile: left movement stick, right drag to look, Hold / Drop, Throw, and Pause buttons. Mystery: find three hidden clock notes and unlock the TV recording with code 508.</p><p>There is a separate control lab in the Godot project for testing these systems while the room awaits approval. It is clearly labeled and is not the final room.</p><p>Targets: desktop 60–120 FPS and mobile 60 FPS where hardware permits. Low starts at reduced render resolution with shadows and antialiasing off; Medium and High increase resolution and smoothing. Initial placed prop geometry: TRIANGLES triangles before shell/detail geometry. Use shared meshes, simple compound colliders, sleeping rigid bodies, and bounded grabbing forces. Final FPS claims require measurements on the finished room. No Android phone is connected for a hardware measurement.</p>
<p>Free external texture: <a href="https://polyhaven.com/a/wood_floor">Wood Floor by Dimitrios Savva, Poly Haven (CC0)</a>. Download preserved under textures; final material use is pending Form review.</p>
<h2>Files and review decision</h2><p><a href="living_room_study.blend">Blender study source</a> · <a href="room-brief.json">Room brief</a> · <a href="room-layout.json">Layout manifest</a> · <a href="props.json">Object manifest</a> · <a href="milestone-reviews.json">Review record</a></p><p>Review the estimated layout and the 24 object references. An owner reply approving the layout and contact sheet can be recorded as Function approval. Form and Runtime approvals remain separate. No approval is inferred from tests, screenshots, or this page.</p></main></html>'''
(pkg/'review.html').write_text(page.replace('CARDS',cards).replace('LEGEND',legend).replace('TRIANGLES',str(triangles)),encoding='utf-8')
(pkg/'asset-provenance.json').write_text(json.dumps({'customMeshes':'tools/build_room_study.py, authored procedural geometry','reference':'Owner supplied photo, source for room only','externalTextures':[{'name':'Wood Floor','author':'Dimitrios Savva','license':'CC0','source':'https://polyhaven.com/a/wood_floor','download':'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/wood_floor/wood_floor_diff_1k.jpg','path':'textures/wood_floor_diff_1k.jpg','sha256':hashlib.sha256((pkg/'textures/wood_floor_diff_1k.jpg').read_bytes()).hexdigest()}],'paidGeneration':False},indent=2),encoding='utf-8')
print(json.dumps({'review':'room/review.html','placedPropTriangles':triangles,'assetFamilies':len(props),'instances':len(layout['instances'])}))
