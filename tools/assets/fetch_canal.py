"""Pinned CC0 model downloads for the canal settlement, with checksum provenance."""
import hashlib
import json
from pathlib import Path
import requests

ROOT = Path(__file__).resolve().parents[2] / 'game/assets/models/canal'
session = requests.Session()
session.headers['User-Agent'] = 'InteriorGameAssetImport/0.16'

for asset in ['trashbag', 'wooden_crate_01']:
    response = session.get('https://api.polyhaven.com/files/' + asset, timeout=45)
    if response.status_code != 200:
        print(asset, response.status_code, flush=True)
        continue
    data = response.json()
    if 'gltf' not in data:
        continue
    spec = data['gltf']['1k']['gltf']
    folder = ROOT / asset
    folder.mkdir(parents=True, exist_ok=True)
    files = {asset + '.gltf': spec, **spec.get('include', {})}
    records = []
    for name, item in files.items():
        path = folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() and hashlib.md5(path.read_bytes()).hexdigest() == item['md5']:
            content = path.read_bytes()
        else:
            r = session.get(item['url'], timeout=90)
            r.raise_for_status()
            content = r.content
            assert hashlib.md5(content).hexdigest() == item['md5'], name
            path.write_bytes(content)
        records.append({'file': name, 'url': item['url'], 'sha256': hashlib.sha256(content).hexdigest()})
    (folder / 'source.json').write_text(json.dumps({'source': 'https://polyhaven.com/a/' + asset,
        'license': 'CC0-1.0', 'retrieved': '2026-10-08', 'files': records}, indent=2))
    print('Downloaded and verified ' + asset, flush=True)
