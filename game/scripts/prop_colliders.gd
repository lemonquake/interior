class_name InteriorPropColliders
extends RefCounted

## Compound shapes preserve the empty space beside stems, necks and stands.
static func shapes_for(actor: Dictionary) -> Array:
	match str(actor.assetId):
		"standing_fan":
			return [_cylinder(Vector3(0,.025,0), .23,.05),
				_cylinder(Vector3(0,.60,0), .025,1.16),
				_cylinder(Vector3(0,1.30,.025), .305,.18, Vector3.FORWARD)]
		"bass_guitar":
			return [_box(Vector3(0,.28,0),Vector3(.32,.44,.115)),
				_box(Vector3(.05,.43,0),Vector3(.24,.25,.10)),
				_box(Vector3(0,.78,0),Vector3(.046,.69,.027)),
				_box(Vector3(0,1.16,0),Vector3(.067,.16,.038))]
		"monitor":
			return [_box(Vector3(0,.25,0),Vector3(.61,.36,.042)),
				_cylinder(Vector3(0,.13,-.03),.023,.18),
				_box(Vector3(0,.015,0),Vector3(.22,.03,.16))]
		"woven_tray":
			# A broad flat support gives GodotPhysics a stable contact manifold.
			# Thin cylinder/convex caps kept the stacked pot and tissue box awake.
			return [_box(Vector3(0,.028,0),Vector3(.48,.056,.48))]
		"fish_bowl":
			return [{"kind":"sphere","center":[0,.15,0],"radius":.182}]
		"tissue_box":
			return [_box(Vector3(0,.05,0),Vector3(.24,.10,.15))]
	return actor.colliders

static func _box(center: Vector3, size: Vector3) -> Dictionary:
	return {"center":[center.x,center.y,center.z],"size":[size.x,size.y,size.z]}

static func _cylinder(center: Vector3, radius: float, height: float, axis := Vector3.UP) -> Dictionary:
	return {"kind":"cylinder","center":[center.x,center.y,center.z],"radius":radius,"height":height,"axis":[axis.x,axis.y,axis.z]}
