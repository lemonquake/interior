class_name InteriorArsenal
extends RefCounted
## 0.48: the named arsenal. Every weapon here is one of the four mechanisms scripts/gun.gd knows (PROFILES:
## "pistol", "rifle", "shotgun", "sniper": how it is held, reloaded and cycled) with its own model (downloaded,
## game/assets/models/guns/<id>.glb, credits in game/licenses/THIRD_PARTY_MODELS.md) and its own figures, which
## replace the mechanism's: magazine, rate of fire, round, damage, how much of a hit goes into tearing a part off
## (`sever`), recoil, sights (`ads_fov`: how far the view closes on the sights; `ads_zone`/`ads_pace`) and, for the
## sniper rifles, the scope's powers and reticle.
##
## (A compact or bullpup weapon has its own `hip_at`: it is short ahead of the hand, so it is held further out to
## show at the frame's edge as the AR-15 does.)
##
## Extra keys gun.gd reads (none of them in PROFILES):
##   burst      rounds a pull of the trigger fires (the Corsair's three-round burst)
##   cycle      "hand" (the stock pump and bolt), "self" (semi-automatic: no pump or bolt between shots)
##   scope_min / scope_max / reticle (0 mil-dot, 1 chevron, 2 duplex) / scope_radius
##   head_pop   a hit on the head takes this much more tearing (the Eruption's .50 takes heads off)
##   slug       one heavy ball instead of buckshot
## The stock weapons keep their ids: "glock17", "ar15", "pump12", "bolt338".

const DIR := "res://assets/models/guns/"

## class, name, short name (pickup prompts), round, rarity (how often it is dropped: 1 common .. 3 rare), the
## figures that differ from the mechanism's.
const WEAPONS := {
	# ---------------------------------------------------------------- stock
	"glock17": {"class": "pistol", "name": "Glock 17", "file": "", "rarity": 1, "stats": {}},
	"ar15": {"class": "rifle", "name": "AR-15", "file": "", "rarity": 1, "stats": {}},
	"pump12": {"class": "shotgun", "name": "Pump 12 Gauge", "file": "", "rarity": 1, "stats": {}},
	"bolt338": {"class": "sniper", "name": ".338 Bolt Action", "file": "", "rarity": 2, "stats": {}},
	# ---------------------------------------------------------------- pistols
	# A steady service pistol: soft recoil, tight group, a light under the barrel.
	"beretta_hi91": {"class": "pistol", "name": "Beretta Hi-91", "rarity": 1, "stats": {
		"mag": 15, "interval": .13, "round": "9 mm +P", "damage": 37.0, "velocity": 390.0, "knock": 64.0, "sever": .35,
		"flip": 16.0, "punch": Vector3(.5, .35, 2.0), "spread": [.0035, .005, .03, .12], "climb": Vector2(.008, .016),
		"ads_fov": -12.0, "pitch": 1.04}},
	# The hand cannon: seven rounds of .50, slow to come back down, and a head does not survive one.
	"eruption_ad15": {"class": "pistol", "name": "Eruption AD-15", "rarity": 3, "stats": {
		"mag": 7, "interval": .62, "round": ".50 AE", "damage": 118.0, "velocity": 470.0, "drag": 520.0, "knock": 280.0,
		"sever": 1.6, "head_pop": 2.0, "pierce": true, "passes": 2, "keep": .55, "bore": 2.4,
		"flip": 52.0, "shove": Vector3(.45, 1.4, 2.4), "roll": 9.0, "omega": 22.0, "damping": .5,
		"punch": Vector3(3.6, 1.4, 6.0), "kick": 1.7, "jolt": .02, "climb": Vector2(.03, .07),
		"spread": [.005, .02, .07, .06], "impulse": 13.0, "flash": 10.0, "flash_range": 11.0, "lens": 1.0,
		"pitch": .66, "volume": 7.5, "draw": .6, "ads_fov": -9.0, "ads_pace": .55}},
	# A machine pistol: twenty rounds gone in a second and a half with the trigger held.
	"sauer_p9": {"class": "pistol", "name": "Kessler P9 Auto", "rarity": 2, "stats": {
		"mag": 20, "interval": .068, "automatic": true, "round": "9 mm", "damage": 25.0, "velocity": 360.0, "knock": 48.0,
		"sever": .22, "flip": 11.0, "punch": Vector3(.8, .7, 2.0), "climb": Vector2(.016, .014),
		"spread": [.006, .007, .06, .14], "kick_aim": .7, "pitch": 1.12, "volume": 1.6}},
	# Six in the cylinder, a heavy pull and a .357 that takes a limb off as often as not.
	"magnum_vex": {"class": "pistol", "name": "Vex .357 Revolver", "rarity": 2, "stats": {
		"mag": 6, "interval": .36, "round": ".357 Magnum", "damage": 74.0, "velocity": 440.0, "knock": 160.0, "sever": 1.05,
		"head_pop": 1.3, "flip": 36.0, "punch": Vector3(2.0, 1.0, 4.4), "kick": 1.1, "climb": Vector2(.02, .045),
		"spread": [.004, .012, .045, .08], "impulse": 9.0, "pitch": .8, "volume": 5.0, "ads_fov": -11.0}},
	# ---------------------------------------------------------------- rifles
	"gtk44": {"class": "rifle", "name": "GTK-44", "rarity": 1, "stats": {
		"mag": 30, "interval": .1, "round": "7.62x39", "damage": 54.0, "velocity": 715.0, "drag": 480.0, "knock": 125.0,
		"sever": .95, "punch": Vector3(3.5, 2.3, 5.2), "climb": Vector2(.021, .017), "kick": .45,
		"spread": [.0055, .004, .045, .1], "pitch": .74, "volume": 4.6, "ads_fov": -13.0}},
	"kestrel_k74": {"class": "rifle", "name": "Kestrel K-74", "rarity": 1, "stats": {
		"mag": 30, "interval": .092, "round": "5.45x39", "damage": 43.0, "velocity": 900.0, "knock": 92.0, "sever": .7,
		"punch": Vector3(2.1, 1.3, 3.8), "climb": Vector2(.011, .009), "spread": [.0045, .003, .032, .13],
		"pitch": .86, "ads_fov": -13.0}},
	# 1200 a minute: a hose at arm's length, nothing past thirty metres.
	"viper_v9": {"class": "rifle", "name": "Viper V9", "rarity": 2, "stats": {
		"hip_at": Vector3(.05, -.07, -.22), "mag": 25, "interval": .05, "round": ".45 ACP", "damage": 31.0, "velocity": 290.0, "drag": 260.0, "knock": 70.0,
		"sever": .35, "pierce": false, "bore": 1.0, "punch": Vector3(1.5, 1.4, 2.8), "climb": Vector2(.014, .009),
		"spread": [.006, .0035, .05, .16], "kick_aim": .8, "pitch": 1.05, "volume": 3.0, "ads_fov": -9.0, "ads_pace": .7}},
	"hornet_mp9": {"class": "rifle", "name": "Hornet MP9", "rarity": 1, "stats": {
		"hip_at": Vector3(.05, -.07, -.2), "mag": 30, "interval": .075, "round": "9 mm", "damage": 33.0, "velocity": 400.0, "drag": 380.0, "knock": 64.0,
		"sever": .35, "pierce": false, "bore": 1.0, "punch": Vector3(1.3, .9, 2.4), "climb": Vector2(.008, .006),
		"spread": [.0045, .0025, .034, .16], "pitch": 1.1, "volume": 2.8, "ads_fov": -11.0, "ads_pace": .68}},
	# A battle rifle under a fixed 3x scope (the eye goes to the glass, the sniper rifles' way): twenty heavy rounds,
	# a hard shove each.
	"bastion_s17": {"class": "rifle", "name": "Bastion S-17", "rarity": 2, "stats": {
		"mag": 20, "interval": .105, "round": "7.62x51", "damage": 66.0, "velocity": 800.0, "drag": 700.0, "knock": 170.0,
		"sever": 1.15, "passes": 2, "punch": Vector3(4.4, 2.5, 6.2), "climb": Vector2(.023, .021), "kick": .6,
		"spread": [.003, .005, .04, .09], "pitch": .68, "volume": 5.4, "ads_fov": -14.0, "ads_pace": .45,
		"ads_zone": Vector2(.03, .024), "scope": true, "scope_min": 3.0, "scope_max": 3.0, "reticle": 2, "scope_radius": .43}},
	# Eight rounds and the ping: semi-automatic and hits like a sledge.
	"garrison_m1": {"class": "rifle", "name": "Garrison M1", "rarity": 2, "stats": {
		"mag": 8, "interval": .19, "automatic": false, "round": ".30-06", "damage": 82.0, "velocity": 850.0, "drag": 800.0,
		"knock": 200.0, "sever": 1.35, "passes": 2, "punch": Vector3(4.8, 1.8, 6.0), "kick": .9, "climb": Vector2(.02, .04),
		"spread": [.0025, .006, .03, .08], "pitch": .62, "volume": 6.0, "ads_fov": -12.0}},
	# Three rounds a pull, fast and close together.
	"corsair_m4": {"class": "rifle", "name": "Corsair M4", "rarity": 1, "stats": {
		"mag": 30, "interval": .067, "automatic": false, "burst": 3, "round": "5.56 mm", "damage": 45.0, "velocity": 880.0,
		"knock": 92.0, "sever": .66, "punch": Vector3(2.3, 1.5, 4.0), "climb": Vector2(.012, .01),
		"spread": [.004, .003, .03, .14], "ads_fov": -17.0, "ads_pace": .52}},
	"sentry_sk45": {"class": "rifle", "name": "Sentry SK-45", "rarity": 1, "stats": {
		"mag": 10, "interval": .15, "automatic": false, "round": "7.62x39", "damage": 62.0, "velocity": 735.0, "drag": 500.0,
		"knock": 140.0, "sever": 1.0, "punch": Vector3(3.6, 1.5, 4.8), "climb": Vector2(.015, .03),
		"spread": [.003, .005, .03, .1], "pitch": .76, "volume": 4.8, "ads_fov": -13.0}},
	# The bullpup with the 1.5x glass: long barrel in a short gun, quick on target.
	"auger_a3": {"class": "rifle", "name": "Auger A3", "rarity": 2, "stats": {
		"hip_at": Vector3(.05, -.065, -.26), "mag": 42, "interval": .085, "round": "5.56 mm", "damage": 45.0, "velocity": 970.0, "knock": 94.0, "sever": .7,
		"punch": Vector3(2.0, 1.3, 3.6), "climb": Vector2(.01, .008), "spread": [.0035, .0028, .03, .14],
		"ads_fov": -22.0, "ads_pace": .5}},
	# Fifty in the top magazine; the small fast round goes through.
	"talon_p90": {"class": "rifle", "name": "Talon P90", "rarity": 2, "stats": {
		"hip_at": Vector3(.05, -.045, -.32), "mag": 50, "interval": .067, "round": "5.7x28", "damage": 31.0, "velocity": 715.0, "drag": 380.0, "knock": 58.0,
		"sever": .4, "pierce": true, "passes": 2, "punch": Vector3(1.1, .8, 2.2), "climb": Vector2(.007, .005),
		"spread": [.004, .0022, .03, .17], "pitch": 1.08, "volume": 3.2, "ads_fov": -12.0, "ads_pace": .7}},
	# ---------------------------------------------------------------- sniper rifles
	"longreach_m40": {"class": "sniper", "name": "Longreach M40", "rarity": 2, "stats": {
		"mag": 10, "interval": 1.1, "round": "7.62x54R", "damage": 150.0, "velocity": 820.0, "drag": 1300.0, "knock": 280.0,
		"sever": 1.6, "scope_min": 3.0, "scope_max": 9.0, "reticle": 2}},
	# Semi-automatic: ten rounds as fast as the scope comes back on, a fixed 4x with the chevron.
	"drakon_svd": {"class": "sniper", "name": "Drakon SVD", "rarity": 2, "stats": {
		"mag": 10, "interval": .32, "cycle": "self", "round": "7.62x54R", "damage": 112.0, "velocity": 830.0, "drag": 1200.0,
		"knock": 230.0, "sever": 1.35, "passes": 2, "punch": Vector3(5.4, 1.8, 4.0), "kick": 1.2,
		"scope_min": 4.0, "scope_max": 4.0, "reticle": 1}},
	# .50 BMG: five rounds, a bolt like a door, through anything it meets and whatever is behind it.
	"titan_b50": {"class": "sniper", "name": "Titan B-50", "rarity": 3, "stats": {
		"mag": 5, "interval": 1.6, "round": ".50 BMG", "damage": 340.0, "velocity": 850.0, "drag": 2400.0, "knock": 650.0,
		"sever": 3.0, "head_pop": 2.0, "passes": 5, "keep": .8, "bore": 6.0, "range": 420.0,
		"flip": 9.0, "punch": Vector3(11.0, 3.0, 7.0), "kick": 2.8, "jolt": .045, "impulse": 26.0,
		"flash": 18.0, "flash_range": 20.0, "pitch": .38, "volume": 10.0, "draw": .9, "ads_pace": .32,
		"scope_min": 5.0, "scope_max": 16.0, "reticle": 0, "scope_radius": .47}},
	# ---------------------------------------------------------------- shotguns
	# Both barrels as fast as the fingers: two shells, a wide hard spray, then the break and two more.
	"gausser_db": {"class": "shotgun", "name": "Gausser Double-Barrel", "rarity": 2, "stats": {
		"hip_at": Vector3(.05, -.08, -.24), "mag": 2, "interval": .16, "cycle": "self", "round": "12 gauge 00 buck", "pellets": 12, "pattern": .019,
		"damage": 21.0, "knock": 115.0, "sever": 1.7, "punch": Vector3(7.5, 2.8, 7.0), "kick": 1.8,
		"pitch": .52, "volume": 7.5}},
	"spartan_s12": {"class": "shotgun", "name": "Spartan S-12", "rarity": 1, "stats": {
		"mag": 8, "interval": .7, "pellets": 9, "pattern": .0095, "damage": 20.0, "knock": 88.0, "sever": 1.3}},
	# Semi-automatic: seven shells as fast as the trigger, a little wider and lighter each.
	"tempest_a14": {"class": "shotgun", "name": "Tempest A-14", "rarity": 2, "stats": {
		"mag": 7, "interval": .24, "cycle": "self", "pellets": 8, "pattern": .0125, "damage": 18.0, "knock": 75.0,
		"sever": 1.15, "punch": Vector3(5.4, 2.2, 5.4), "kick": 1.2, "pitch": .62}},
	# One lead slug: a rifle's reach out of a shotgun, and nothing standing in front of it stays whole.
	"ironside_m37": {"class": "shotgun", "name": "Ironside M37 Slug", "rarity": 2, "stats": {
		"mag": 5, "interval": .9, "round": "12 gauge slug", "slug": true, "pellets": 1, "pattern": .0012,
		"velocity": 480.0, "velocity_spread": .0, "drag": 240.0, "damage": 150.0, "knock": 340.0, "sever": 1.8,
		"pierce": true, "passes": 2, "keep": .45, "limb_pierce": true, "skip": false, "bore": 3.0,
		"spread": [.002, .006, .02, .08], "ads_fov": -12.0}},
}

## Which weapon ids belong to a mechanism class.
static func of_class(cls: String) -> Array:
	var out: Array = []
	for id: String in WEAPONS:
		if str(WEAPONS[id]["class"]) == cls:
			out.append(id)
	return out

## "pistol" for "glock17" or "eruption_ad15"; an old class name passes straight through to its stock weapon's class.
static func class_of(id: String) -> String:
	if WEAPONS.has(id):
		return str(WEAPONS[id]["class"])
	return id if id in ["pistol", "rifle", "shotgun", "sniper"] else ""

## The stock weapon of a class ("rifle" -> "ar15"); a weapon id passes through.
static func resolve(id: String) -> String:
	if WEAPONS.has(id):
		return id
	return {"pistol": "glock17", "rifle": "ar15", "shotgun": "pump12", "sniper": "bolt338"}.get(id, "")

static func display_name(id: String) -> String:
	var key := resolve(id)
	return str(WEAPONS[key]["name"]) if key != "" else "weapon"

static func model_path(id: String) -> String:
	var key := resolve(id)
	if key == "" or str((WEAPONS[key] as Dictionary).get("file", key)) == "":
		return ""
	return DIR + key + ".glb"

static func stats(id: String) -> Dictionary:
	var key := resolve(id)
	return WEAPONS[key]["stats"] if key != "" else {}

static func is_stock(id: String) -> bool:
	return model_path(id) == ""

## A random weapon id, rare ones less often. `classes` limits it ([] = all).
static func pick(rng: RandomNumberGenerator, classes: Array = []) -> String:
	var pool: Array = []
	var weights: Array = []
	var total := 0.0
	for id: String in WEAPONS:
		if not classes.is_empty() and not WEAPONS[id]["class"] in classes:
			continue
		var w: float = [0.0, 3.0, 1.8, .7][int(WEAPONS[id]["rarity"])]
		pool.append(id)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return pool[i]
	return pool[-1] if not pool.is_empty() else "glock17"

## Rounds a box holds for a class: small, medium, large.
const AMMO_BOX := {"pistol": [12, 24, 45], "rifle": [30, 60, 120], "shotgun": [8, 16, 30], "sniper": [5, 10, 20]}
## Healthkits: small, medium, large (HP back).
## 0.58: doubled with the survivors' health (Mission.MAX_HP 200): each kit is the same share of the bar as before.
const KITS := {"small": [40, 60], "medium": [80, 120], "large": [150, 200]}
const KIT_NAMES := {"small": "Small healthkit", "medium": "Healthkit", "large": "Large trauma kit"}
