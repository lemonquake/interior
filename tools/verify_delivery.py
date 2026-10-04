"""Verify GitHub's published asset digests against the local deliverables."""
from pathlib import Path
from datetime import datetime, timezone
import json, hashlib, subprocess
root=Path(__file__).resolve().parent.parent
release=json.loads((root/'.local/published-release.json').read_text(encoding='utf-8-sig'))
paths={
    'Interior.exe':root/'builds/windows/Interior.exe',
    'Interior.apk':root/'builds/android/Interior.apk',
    'Interior-Windows-x64.zip':root/'builds/Interior-Windows-x64.zip',
    'SHA256SUMS.txt':root/'builds/SHA256SUMS.txt',
}
verified=[]
assert release['tagName']=='v0.1.0' and release['publishedAt']
for name,path in paths.items():
    asset=next(item for item in release['assets'] if item['name']==name)
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    assert asset['state']=='uploaded' and asset['size']==path.stat().st_size and asset['digest']=='sha256:'+digest,name
    verified.append(dict(name=name,url=asset['url'],bytes=asset['size'],sha256=digest,githubDigestMatches=True))
receipt=dict(repository='https://github.com/lemonquake/interior',version=release['tagName'],releaseUrl=release['url'],publishedAt=release['publishedAt'],verifiedAt=datetime.now(timezone.utc).isoformat(),releaseSourceCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),assets=verified,androidSigning='Local debug key; installable APK',physicalPhoneFpsMeasured=False)
(root/'docs/delivery.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt))
