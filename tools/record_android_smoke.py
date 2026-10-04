"""Record this session's observed emulator actions and the tested APK hash."""
from pathlib import Path
from datetime import datetime, timezone
import json, hashlib
root = Path(__file__).resolve().parent.parent
log = (root/'.local/android-final.log').read_text(encoding='utf-8-sig')
assert 'INTERIOR_ROOM_READY {"actors":48,"expected":48,"triangles":73784.0}' in log
assert 'ERROR:' not in log and 'FATAL EXCEPTION' not in log
apk = root/'builds/android/Interior.apk'
report = dict(passed=True, testedAt=datetime.now(timezone.utc).isoformat(), apkSha256=hashlib.sha256(apk.read_bytes()).hexdigest(), device='Android 16/API 36, medium_phone emulator, 2 GB guest RAM, ARM64 native bridge', graphics='Hardware GLES translator backed by NVIDIA RTX 4060', package='com.aljayleodones.interior', version='0.1.0', minimumAndroidApi=24, targetAndroidApi=36, architectures=['armeabi-v7a','arm64-v8a'], observedActions=['APK installation', 'Landscape menu and author credit', 'Tap Play', 'Left-finger movement', 'Right-finger look', 'Hold the clock with Hold / Drop', 'Clock note discovered; journal count 1/3', 'Throw releases clock with physics', 'Pause', 'Switch Low to High graphics', 'Resume'], captures=['android-menu.png','android-play.png','android-look.png','android-held.png','android-throw.png','android-pause.png','android-high.png'], godotErrors=[], physicalPhoneTested=False, performanceClaim='Emulator compatibility and interaction only; no physical low-tier phone FPS measurement.', earlierFailure='SwiftShader emulator GLSL compiler rejected the engine defaults. Hardware graphics passed. Unused mobile light limits were reduced to the two actual fixtures. Touch button bugs found by APK taps were fixed and covered by integration checks.')
(root/'room/runtime/android-smoke.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
