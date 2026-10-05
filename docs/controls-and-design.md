# Interior interaction design

Credit: Aljay Leodones. The room follows the owner's photographs using estimated proportions.

WASD moves and the mouse looks. Hold Shift to sprint, Space to jump and C to crouch. E toggles holding; left click throws; F inspects the TV; Esc pauses and J opens discovered notes. Movement accelerates, brakes and retains momentum in the air. Buffered jumps and a short coyote interval improve response at edges. Standing after crouching requires space above the capsule.

Touch uses independent move and look fingers. Sprint stays active while held, Jump queues one jump and Crouch toggles stance. Hold / Drop, Throw, Inspect and Pause have their own touch regions. Pausing clears move, look and sprint input so fingers cannot stick across menus.

The mystery uses the visible 5:08 clock. Holding the clock, table plant and small cabinet photo reveals three notes. All notes and code 508 are required to unlock the recording. The player can continue rearranging the room afterward.

The structural shell remains fixed. Original furnishings and loose decor are rigid bodies. Wall-mounted original props detach when grabbed. Tiny parts such as petals and fan wires belong to their object assemblies. New architectural details are fixed, while the six loose kitchen props are rigid bodies.

Compound shapes approximate furniture, including fan foot/pole/guard and thin-frame geometry. Props use continuous collision detection and material-dependent friction and damping. Contact pushes use velocity at the physical contact, including angular motion about the center of mass. Held props follow a bounded velocity servo and retain collisions with the room. Throw strength depends on mass. Non-finite bodies or objects falling below the level recover to their original pose.

The three pets use a downloaded hamster mesh with an authored skin rig and animation clips. Their state machine chooses playground activities, idles and connected-tube travel. This is authored animal behavior rather than a biological simulation. The two lower aquariums have moving fish, glass and water surfaces; they do not simulate fluids.

Low graphics reduces render scale, shadows and antialiasing. The Compatibility renderer requires GLES 3 on Android. Desktop measurements and Android emulator checks do not establish performance on a physical phone.