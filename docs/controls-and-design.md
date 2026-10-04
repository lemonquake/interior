# Interior interaction design

Credit: Aljay Leodones. Estimated room proportions were approved by the owner.

E toggles holding and dropping. Left click throws the held object. F inspects the TV lock. WASD moves; mouse looks; Shift walks faster; Space jumps; Esc pauses; J opens discovered notes.

Touch uses independent move and look fingers. The left stick starts under the touch. The right side accepts look dragging, with reserved regions for Hold / Drop, Throw, Inspect, and Pause. Releasing either finger does not cancel the other. The pause menu includes the notes and graphics options.

The mystery uses the room's visible 5:08 clock. Holding the clock, table plant, and small cabinet photo reveals three notes. All notes and the code 508 are required to unlock the recording. The player can continue rearranging the room afterward.

The room shell remains fixed. Furnishings and loose decor are rigid bodies. Wall-mounted TV, frames, and shelves start attached, then detach on grabbing. Loose cushions, crib toy, and keyboard are separate bodies. Tiny components such as fan wires, chair joints, and individual petals belong to their object assemblies.

Simple compound boxes model concave furniture rather than dynamic triangle meshes. Objects retain wall and furniture collision while held, use continuous collision detection, and can sleep. A bounded velocity servo moves the held object without teleporting it through walls. The grab ray respects occluders. Objects that leave room bounds recover to their initial pose.

Android starts on Low: reduced render scale, no shadows or antialiasing, 60 FPS cap. Medium and High increase image quality. Desktop supports 120 FPS where the display and hardware allow it. The Compatibility renderer requires GLES 3 on Android. Quality choices cannot guarantee a frame rate on every device.
