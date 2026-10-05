# Interior 0.2 upgrade contract

Baseline source: `d5eb5c1`. Engine: Godot 4.7.2, Compatibility renderer,
GodotPhysics3D at 60 Hz. Target outputs: Windows x64 embedded EXE and Android
ARMv7/ARM64 locally debug-signed APK. The owner explicitly requested source pushed
to main and both native builds.

The owner selected Half-Life 2 as the movement/physics reference. The implementation
uses meter-scale acceleration, braking, retained airborne momentum, a buffered
jump, C crouch with head clearance, mass-dependent prop pushes and throws, and
compound collision shapes. No Valve source or assets are copied into the game.

The eight supplied family originals are frame content. They are EXIF-oriented,
uniformly resampled with full content preserved, and copied to game resources;
original files remain untouched. Source and derivative hashes accompany them.

The owner's subsequent four photographs replace the earlier inferred enclosure
and unseen room sides as the visual/layout reference. Required features are:

- Three visibly animated, skinned hamsters using connected enclosure levels via
  external clear tubes, plus wheels, hides, drinking bottles, food, bedding,
  bridge, sand and internal tunnel. Two aquariums belong below the stand.
- Left kitchen with an actual walkable opening, counter, blue lower cabinets,
  sink, barred curtained window, dish storage, stove and refrigerator.
- Rear blue paneled entry door, vertical wall slats, mirror/network equipment
  and music area; right slatted gallery wall, curtain doorway and storage.
- Existing family-room identity, eight supplied photos and all original mystery
  clues remain usable. New props have geometry and appropriate collisions.

The room dimensions remain estimates. Single photographs cannot provide exact
measurements or unseen geometry. The task targets recognizable reference details,
cohesive lighting and usable gameplay; it does not claim a measured scan.

Required checks: all engine scripts/assets import; original gameplay checks;
10,000 fixed movement/prop steps and 10,000 hamster simulation steps; actual skin
pose change rather than clip names alone; cross-level travel; head clearance,
momentum/rotation contact correctness; pause/resume/restart/teardown with stable
entity counts; 1080p/4K and mobile UI captures; cold EXE and APK smoke checks.

Desktop performance target: a 60-second representative rendered camera sweep,
after 2-second warmup, with sixteen active original furnishings and three pets;
p95 <=16.67 ms, with p99/max and slow-frame count recorded. Phone performance
requires physical hardware; emulator smoke is a compatibility check only.

Builder ownership is separated between mechanics, connected habitats, room sides
and integration. Independent source and output reviews are recorded separately.
The earlier commercial Gone Home visual comparison favored the reference; that
is not hidden or presented as a pass. The latest owner photographs define the
new bounded layout revision. No commercial-superiority or blanket 60 FPS claim
is made. Each component remains bounded to the lemondev review limits; evidence
and counters are preserved in the local work folder and final handoff.
