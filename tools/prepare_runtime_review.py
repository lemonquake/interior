"""Package observed runtime evidence without granting any human approval."""
from pathlib import Path
from datetime import datetime, timezone
import json, hashlib, struct, html
from PIL import Image

root = Path(__file__).resolve().parent.parent
room = root / 'room'
runtime = room / 'runtime'
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf-8')

manifest = read(runtime / 'export-manifest.json')
brief = read(room / 'room-brief.json')
layout = read(room / 'room-layout.json')
review = read(room / 'milestone-reviews.json')
review['roomId'] = brief['roomId']
write(room / 'milestone-reviews.json', review)
benchmarks = []
for quality in ['low','medium','high']:
    text = (root / '.local' / f'benchmark-export-{quality}.log').read_text(encoding='utf-8-sig')
    lines = [line for line in text.splitlines() if line.startswith('INTERIOR_BENCHMARK ')]
    if not lines or 'ERROR:' in text:
        raise RuntimeError('Missing or failed exported benchmark: ' + quality)
    benchmark = json.loads(lines[-1].split(' ',1)[1])
    benchmark.update(qualityName=quality, medianFps=round(1000/benchmark['median_frame_ms'],1), slowestOnePercentFps=round(1000/benchmark['p99_frame_ms'],1), viewport=[1280,720], warmupSeconds=2, sampleSeconds=20)
    benchmarks.append(benchmark)
write(runtime / 'desktop-performance.json', dict(measuredAt=datetime.now(timezone.utc).isoformat(), source='Exported Windows EXE, VSync disabled, 120 FPS cap, real wall-clock frame durations', hardware='NVIDIA GeForce RTX 4060', runs=benchmarks, limits='A bounded camera sweep and sixteen active bodies; not an exhaustive worst-case test. No physical low-tier Android FPS claim.'))

binary = (root / 'game/assets/living_room.glb').read_bytes()
length, chunk_type = struct.unpack_from('<II', binary, 12)
assert chunk_type == 0x4e4f534a
gltf = json.loads(binary[20:20+length])
color_primitives = sum('COLOR_0' in primitive['attributes'] for mesh in gltf['meshes'] for primitive in mesh['primitives'])
fixtures = [{**fixture, 'location':[fixture['location'][0], fixture['location'][2], -fixture['location'][1]]} for fixture in layout['fixtures']]
fixtures_match = all(a['id']==b['id'] and all(abs(x-y)<1e-5 for x,y in zip(a['location'],b['location'])) and a['watts']==b['watts'] for a,b in zip(fixtures,manifest['fixtures'])) and len(fixtures)==len(manifest['fixtures'])
android = read(runtime / 'android-smoke.json')
assert android['apkSha256'] == sha(root/'builds/android/Interior.apk'), 'Android smoke test APK hash differs from delivery APK'
tests = read(runtime / 'integration-results.json')
texture_bytes = 0
for path in (root/'game/assets').glob('living_room_*.jpg'):
    with Image.open(path) as image:
        texture_bytes += int(image.width*image.height*4*4/3)
checks = {
    'sourceHashMatches':sha(room/'living_room.blend') == manifest['sourceSha256'],
    'glbHashMatches':sha(root/'game/assets/living_room.glb') == manifest['glbSha256'],
    'triangleBudget':manifest['geometryTriangles'] <= brief['performanceBudget']['maxSceneTriangles'],
    'assetBytesBudget':len(binary) <= brief['performanceBudget']['maxVLowBytes'],
    'decodedTextureBudget':texture_bytes <= brief['performanceBudget']['maxHighTextureBytes'],
    'fixtureManifestMatches':fixtures_match,
    'staticVertexLightingPresent':color_primitives > 0,
    'integrationPassed':all(result['passed'] for result in tests.values()),
    'desktopTargetInMeasuredScenario':all(run['p99_frame_ms']<1000/60 and run['objects']==48 and run['scene']=='living-room' for run in benchmarks),
    'androidSmokePassed':android['passed'],
}
assert all(checks.values()), checks
artifacts = {}
for path in [root/'builds/windows/Interior.exe',root/'builds/android/Interior.apk']:
    artifacts[path.name] = dict(path=str(path.relative_to(root)).replace('\\','/'), bytes=path.stat().st_size, sha256=sha(path))
report = dict(measuredAt=datetime.now(timezone.utc).isoformat(), checks=checks, artifacts=artifacts, actorCount=len(manifest['actors']), triangles=manifest['geometryTriangles'], meshCount=len(gltf['meshes']), textureCount=len(gltf['textures']), decodedTextureUpperBoundBytesWithMipmaps=texture_bytes, staticColorPrimitives=color_primitives, lighting=manifest['staticLighting'], humanRuntimeApproval=review['runtime']['status'], correctionsAfterFormApproval=['Added the visible black side storage rack and adjusted its bins and plants.', 'Separated loose cushions, crib toy, keyboard, and display rack as physics assemblies.', 'Replaced broad collision boxes with measured compound supports.', 'Preserved the initial arrangement until touch; contacts wake unattached furnishings.'], limitations=['Estimated dimensions and unseen geometry from one photograph.', 'Procedural approximation retains layout and object identity; fine shapes and materials differ.', 'Low-tier physical phone performance remains unmeasured.', 'Android is signed with a local debug key for installation, not Play Store release signing.'])
write(runtime/'runtime-audit.json',report)
final = read(room/'final-report.json')
final.update(formChecks=read(room/'form-audit.json')['measuredChecks'], runtimeChecks=dict(checks), reviewRenders=dict(corners=[f'renders/corner-{i}.png' for i in range(1,5)], ceiling=[f'renders/{name}.png' for name in ['ceiling-center-up','ceiling-oblique-a','ceiling-oblique-b']]), limitations=report['limitations'])
final['gates'] = {gate:review[gate]['status']=='approved' for gate in ['function','form','runtime']}
final['runtimeChecks']['loadedApplicationCapture'] = 'runtime/living-room-play.png'
write(room/'final-report.json',final)
review['runtime']['evidence'] = ['runtime/living-room-menu.png','runtime/living-room-play.png','runtime/android-menu.png','runtime/android-play.png','runtime/android-held.png','runtime/android-throw.png','runtime/android-pause.png','runtime/integration-results.json','runtime/desktop-performance.json','runtime/android-smoke.json','runtime/runtime-audit.json']
write(room/'milestone-reviews.json',review)
table = ''.join(f"<tr><td>{b['qualityName'].title()}</td><td>{b['medianFps']}</td><td>{b['slowestOnePercentFps']}</td></tr>" for b in benchmarks)
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Interior — Playable game review</title><style>body{margin:0;background:#f4f0e9;color:#25221e;font:18px/1.6 system-ui}main{max-width:1280px;margin:auto;padding:32px}h1{font-size:38px}h2{font-size:27px}img{width:100%;display:block;border-radius:6px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}a{color:#694319}.status{background:#e8ddcc;padding:18px;border-radius:8px}table{border-collapse:collapse;width:100%}td,th{text-align:left;border-bottom:1px solid #c7b9a5;padding:12px}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><main><h1>Interior — Playable game review</h1><p>By Aljay Leodones</p><p class="status">Room layout and Blender model approved. The EXE and APK are built and tested. Owner review of the playable game is pending before the GitHub push and downloadable release.</p><h2>Windows game</h2><img src="runtime/living-room-play.png" alt="Actual exported Windows game, High graphics"><p>Actual exported EXE at the initial first-person camera, 1280 × 720. High enables dynamic shadows and 4× antialiasing. WASD moves, the mouse looks, E holds or drops, left click throws, F inspects the TV, J opens notes, and Esc pauses.</p><img src="runtime/living-room-menu.png" alt="Actual game menu with author credit and graphics selector"><h2>Android game</h2><p>The ARM APK loads and accepts touches in an Android 16 emulator using hardware graphics. This confirms install and interaction compatibility; its displayed FPS is not evidence of low-tier phone performance. Android starts on Low; Medium and High increase resolution and antialiasing.</p><div class="grid"><div><img src="runtime/android-play.png" alt="APK running with mobile controls"><p>Left touch movement and right touch look; Hold / Drop, Throw, Inspect, and Pause buttons.</p></div><div><img src="runtime/android-held.png" alt="Touch grab discovers the clock note"><p>A real touch grab discovers a clue. The same button drops the held object.</p></div><div><img src="runtime/android-throw.png" alt="APK after throwing the clock"><p>Throw releases the clock with an impulse. The room and furniture retain collisions.</p></div><div><img src="runtime/android-pause.png" alt="APK pause menu"><p>Pause, Resume, Notes, Restart, and three graphics settings.</p></div></div><h2>Measured desktop performance</h2><p>Exported EXE on NVIDIA RTX 4060, 1280 × 720, 120 FPS cap, VSync disabled, 2-second warmup and 20 seconds of real frame timings. Scenario: camera sweep with sixteen furniture bodies repeatedly activated.</p><table><tr><th>Graphics</th><th>Median FPS</th><th>Slowest 1% equivalent FPS</th></tr>TABLE</table><p>The room contains 48 physics assemblies and 73,784 triangles. Compound collisions, sleeping bodies, static vertex lighting, 1K/512 textures, and mobile quality options keep its workload small. All 104 integration assertions and the four-second settling check pass. No universal 60–120 FPS guarantee is made.</p><h2>Room and physics details</h2><p>Estimated room dimensions: 6.6 × 5.4 × 2.9 m. Unseen walls, backs, and ceiling are inferred. Fine shapes and materials differ from the photograph. Furnishings preserve their initial arrangement until grabbed, pushed, or touched by an active body; then they simulate normally. Wall decorations detach when grabbed. Structural walls, floor, ceiling, and tiny components within an assembly stay together.</p><p>Find three object notes and use the clock's time at the TV to solve the mystery; then continue rearranging the room. Technical support fixes add the photographed side rack and separate loose components. The runtime fixture positions match the Blender lighting bake. The Android APK is locally debug-signed for installation.</p><p><a href="runtime/runtime-audit.json">Build hashes and runtime audit</a> · <a href="runtime/desktop-performance.json">Performance measurements</a> · <a href="runtime/integration-results.json">Integration checks</a> · <a href="runtime/android-smoke.json">Android interaction check</a> · <a href="living_room.blend">Blender source</a> · <a href="form-review.html">Approved model review</a></p><p>The EXE is in builds/windows/Interior.exe; the APK is in builds/android/Interior.apk in the workspace. Open them from the links in the chat. Approve the playable game and builds to proceed with the repository push and downloadable GitHub release.</p></main></html>'''
(room/'runtime-review.html').write_text(page.replace('TABLE',table), encoding='utf-8')
if review['runtime']['status'] == 'approved':
    approved_page = page.replace('TABLE',table).replace('Owner review of the playable game is pending before the GitHub push and downloadable release.', 'The owner approved the playable game and builds for publication.').replace('Approve the playable game and builds to proceed with the repository push and downloadable GitHub release.', 'The playable game and builds were approved for the repository push and downloadable GitHub release.')
    (room/'runtime-review.html').write_text(approved_page, encoding='utf-8')
print(json.dumps(report))
