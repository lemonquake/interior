extends Node3D
const Shine := preload("res://scripts/pickup_shine.gd")
const Street := preload("res://scripts/coop/street.gd")
const Figure := preload("res://scripts/coop/figure.gd")
const W := Street.CANAL
const C := Street.BANK
const INFECTED := [
	"tambay", "obrero", "tanod", "kuya", "nanay", "dalaga", "estudyante",
	"doktor", "nars", "pasyente", "matadero", "pulis", "pari", "tindera",
	"drayber", "mekaniko", "opisina", "bumbero", "sundalo", "atleta", "lola",
	"lolo", "bata_hoodie", "tulog", "tindero_vest", "biker", "pormal",
	"kusinero", "rider", "nobya", "guro", "mangingisda", "karpintero", "negosyante",
	"jogger", "boxer", "madre", "guwardiya", "turista", "janitor", "panadero",
	"labandera", "kolehiyala", "skater", "barbero", "magsasaka", "pulis_swat", "mayaman",
	"tricycle", "kargador", "pasyente_f", "estudyante_m", "tinderong_isda", "musikero", "mananahi",
	"bombero_f", "biktima_sunog",
	# 0.50: the PILCST students (the school spawns only these).
	"pilcst_m1", "pilcst_m2", "pilcst_m3", "pilcst_m4", "pilcst_m5", "pilcst_f1", "pilcst_f2", "pilcst_f3", "pilcst_f4", "pilcst_f5",
	# 0.51: PILCST's faculty (three men, three women) and maintenance staff.
	"teacher_m1", "teacher_m2", "teacher_m3", "teacher_f1", "teacher_f2", "teacher_f3", "janitor_s1", "janitor_s2",
	# 0.68: the hospital's staff and patients (build_zombies.py `lab_*`).
	"lab_surgeon_m", "lab_surgeon_f", "lab_scientist_m", "lab_scientist_f", "lab_hazmat", "lab_cleanroom", "lab_paramedic",
	"lab_guard", "lab_patient_f", "lab_burned", "lab_head_nurse", "lab_morgue",
]
const STUDENT_FIRST := 57
const TEACHER_FIRST := 67
const JANITOR_FIRST := 73
const LAB_FIRST := 75
## 0.51: the town's infected that came to the school: parents who came for their children, the drivers, the vendors
## at the gate, a guard (indices into INFECTED).
const PARENTS := [4, 5, 13, 14, 16, 24, 26, 33, 37, 41, 47, 48]
## 0.51 (host): the most infected alive at once in the school (whatever is asleep, hunting or just out of a door).
const SCHOOL_CEILING := 34
const OBJECTIVES := ["Dodong is waiting outside the courtyard gate. Speak to him.",
	"Stay close to Dodong. Protect him on the way home.", "Take the Gate Keys beside the altar.",
	"Follow the north walk to the ramp and the road gate.", "Get up Store Road and everyone inside Olivar Family Mart.",
	"Hold the mart. Drag the tables into the doorway.", "Someone is calling from the back office.",
	"Listen to Jonna.", "Out the back door and through the service gate. Follow the backstreets north to the college.",
	"Speak to the wounded guard behind the school gate.",
	"Get to the fifth floor and find the survivors. The students blocked the stairs: cross each floor to the next way up.",
	"Listen to Ma'am Teves.",
	"Lights off. Everyone inside room 501, and stay still until the horde has passed.",
	"Get the students out: the fire exit at the far end of the corridor. Stay low and quiet. A shot will bring the whole horde.",
	"The way down is gone. Find another way off the second floor.",
	"Across the school field to the rear gate. Bring the students.",
	"Outer Street.",
	"Down the river road to the bridge, everyone.",
	"Across the bridge", "Get to the hospital's roof.", "The flare is up over the hospital.", "Mission failed"]
## 0.63: after Heavy-arm, Outer Street (scripts/coop/outer_street.gd: its objectives run from mission flags):
## stage 16 explore & restore Breaker A + Breaker B -> stage 17 Evac Gate opens & convergence assault ->
## stage 18 WON (past z > 748.0), stage 19 FAILED. Anything that stops when the mission is over checks `stage>=OVER`.
## 0.68: past the bridge, its board, then the hospital (scripts/coop/hospital.gd: stage 18, its objectives from flags):
## stage 19 WON (the flare on the roof), 20 FAILED.
const HOSPITAL := 18
const OVER := 19
const WON := 19
const FAILED := 20
const SCHOOL := preload("res://scripts/coop/school.gd")
const ESCAPE := preload("res://scripts/coop/escape.gd")
const OUTER_STREET := preload("res://scripts/coop/outer_street.gd")
## 0.68: the hospital past the bridge, and Doctor Lucky's body.
const HOSPITAL_SCRIPT := preload("res://scripts/coop/hospital.gd")
const LUCKY_BODY := preload("res://scripts/coop/lucky_body.gd")
const LUCKY_KIND := 901
## 0.53: Heavy-arm, at the rear gate (scripts/coop/heavyarm.gd runs the fight; this is his body).
const HEAVY_BODY := preload("res://scripts/coop/heavyarm_body.gd")
const HEAVY_KIND := 900
## 0.55: the Nichols property, for the debug teleports (`places`).
const NICHOLS := preload("res://scripts/nichols_property.gd")
const END_TITLE := "The flare is up over the hospital"
## 0.50: the school's story, shown to everyone as the squad nears its back gate (session.gd draws it; the host turns
## the pages, E skips one).
const STORY_TITLE := "PROF. IVAN LAWRENCE COLLEGE OF SCIENCE AND TECHNOLOGY"
const STORY := [
	"Prof. Ivan Lawrence opened this school in 2009 in two rented rooms above a hardware store. Science and technology for the young people of the barangays, he said, and no student turned away for a tuition he could cover himself. By 2026 it was five storeys and four thousand students, senior high and college.",
	"Aljay knew him from the beginning. Ivan used to call him past midnight about a leaking roof or a scholarship fund that had run dry, and Aljay always picked up. The little star on the school's crest is the one the two of them argued about for a week.",
	"Three days ago, at lunch, a first-year collapsed in the cafeteria: burning with fever, coughing blood. The clinic called for an ambulance. None came. By the time the bell rang for the afternoon classes the boy was on his feet again, and the nurse who had been holding him down was not.",
	"Ivan ordered the gates locked to keep the street out and the students in, for their own safety. For one hour it was the right call. But the sickness was already inside with them, and the gates he had locked held four thousand people in a building made of corridors.",
	"Nobody has heard from Ivan since the first night. The radio says there are still survivors inside. And every night since, a light has come on in a fifth-floor window.",
]
## 0.50: Rommel, the night guard, at the school's back gate. "{P}" is whoever spoke to him.
const GUARD_TALK := [
	["Rommel", "You came through the backstreets? Diyos ko... I thought the whole city was gone."],
	["{P}", "You're hurt. Who are you?"],
	["Rommel", "Rommel. Night guard. Eleven years on this gate. Sir Ivan hired me himself."],
	["Rommel", "When it started he told me: nobody in, nobody out, until the ambulances come. So I locked it. I locked it with four thousand kids inside."],
	["{P}", "Is anyone still alive in there?"],
	["Rommel", "The fifth floor. Last night a light came on in a classroom up there, west side. Someone flashed it three times. They're waiting for someone."],
	["Rommel", "I tried to go up. The kids piled their desks into the stairs to stop the others following them. Only one way is open from each floor. You'll have to cross every floor to find it."],
	["{P}", "And Sir Ivan?"],
	["Rommel", "He went up after them the first night, with a fire extinguisher and his keys. He never came down."],
	["Rommel", "They're not sick anymore, the students. They're fast, and they don't stop. Don't let them follow you up the stairs."],
	["{P}", "Come with us."],
	["Rommel", "Look at my arm. You know what this is. I'll hold the gate behind you for as long as I'm still me. Please. Bring those children out."],
]
const BackOffice := preload("res://scripts/coop/back_office.gd")
## 0.44: what Jonna tells them. "{P}" is whoever spoke to her (their survivor's name).
const TALK := [
	["Jonna", "Salamat sa Diyos. You're real. When the shooting stopped I prayed it was you out there and not them."],
	["{P}", "You're hurt. What happened here?"],
	["Jonna", "Three nights ago it was only the news. A fight at Bankerohan market, people biting. By morning the barangay was ringing the bell and nobody knew why."],
	["Jonna", "Then it was everywhere at once. The ambulances stopped coming. The soldiers came in yesterday and made the mart their supply point. They held that door all night."],
	["Jonna", "When the front glass went they pushed the customers to the back. I got this door shut. The others... I heard them. I could not open it."],
	["{P}", "Let me look at that."],
	["Jonna", "Leave it. It's the fridge glass, not a bite. I tied it off. If I stand too long the room turns, that's all."],
	["Jonna", "Listen to me. That radio on the desk. Last night someone came on the barangay channel, a teacher. There are survivors at the college up north, the Prof. Ivan Lawrence College, five hundred metres from here. The gates are shut. They have water and a generator."],
	["{P}", "Then we take the main road. It runs straight there."],
	["Jonna", "No. The main road is finished. Cars on top of cars, fires, and them, hundreds of them. You won't drive it and you won't walk it."],
	["Jonna", "Go out the back. The service gate opens on the old backstreets behind the shops: the pawnshop, the bakery, the Avenida arcade. They're narrow, but they run all the way to the school's back gate."],
	["{P}", "Come with us."],
	["Jonna", "I would slow you down and you know it. Lock this door behind you. If the radio comes back I'll tell them you're coming. Go, before the night gets any older."],
]
## 0.46: healthkits: how many one survivor carries, how long a patch-up takes (held F on yourself, held E on a
## teammate, who cannot move meanwhile), and what it gives back.
const MAX_KITS := 3
## 0.58: a survivor's full health (was 100: the owner asked for twice as much). CRITICAL_HP and below: limping,
## no running, and the teammate tag turns red (session.gd `update_avatars`).
const MAX_HP := 200
const CRITICAL_HP := 60
const HEAL_TIME := 3.0
const HEAL_MIN := 80
const HEAL_MAX := 140
## 0.46: frag grenades left where the fighting was (street-local; each is one grenade, taken with E).
const GRENADE_SPOTS := [Vector3(5.9, 0, 67.65), Vector3(.55, 0, 59.2), Vector3(-1.45, 0, 49.65), Vector3(8.9, -3.15, -6.9),
	Vector3(5.55, .9, 72.75), Vector3(41.8, 0, 205.8)]
## 0.46: the backstreets (street-local), kept when the run leaves the mart behind; everything wholly outside goes.
const KEEP_LO := Vector3(-16, -30, 70)
## (0.53: to z 625, the whole college: its field ends at 600, the street beyond the rear gate at 616. At 560 the far
## half of the field was put away when the squad left the mart behind.)
const KEEP_HI := Vector3(240, 60, 860)
## 0.41: the dead already in the street when the team arrives (every peer's own, never synced): where they lie, who.
const VICTIMS := [[Vector3(1.0,0,12.2),1,.4],[Vector3(-3.0,0,26.7),4,2.1],[Vector3(.5,0,49.9),2,3.0],[Vector3(-5.2,0,71.9),0,1.2]]
## 0.41: where the unaware stand about on Store Road (a few of these each run).
const ROAD_SPOTS := [Vector3(.4,0,5.4),Vector3(-1.2,0,15.6),Vector3(2.1,0,21.5),Vector3(-2.3,0,35.2),Vector3(1.6,0,38.6),
	Vector3(0,0,44.4),Vector3(8.4,0,31.6),Vector3(-6.4,0,42.6),Vector3(-3.1,0,51.4),Vector3(2.6,0,52.4),Vector3(3.8,0,25.0),
	Vector3(-3.9,0,19.2)]
var session
var street: Node3D
var guide
## 0.44: Jonna, in the back office: where she walks to her seat, who she is talking to, the conversation's clock.
var jonna
var jonna_step := 0
var talker := 0
var talk_index := -1
var talk_wait := 0.0
var office_wait := 0.0
## Tests: print every hit the infected land.
var log_hits := false
## 0.52 tests: print what woke each one the survivors' senses wake.
var log_wakes := false
var hit_log := []   # [player, from the back, back door down, metres]
var route: Array[Vector3] = []
var waypoint := 0
var stage := 0
## 0.66: 200 (was 135): his walk from the courtyard gate is about three times the old one from the far bank.
var guide_hp := 200
var flags := {}
var enemies := {}
var drops := {}
var drop_nodes := {}
var corpses: Array = []
var victims: Array = []
var next_id := 0
var _variant_bag: Array[int] = []
var wave_left := 0
var wave_total := 0
var next_spawn := 2.0
var pressure := 0.0
var threat := 0.0
var nav := InteriorZombieNav.new()
var awake_houses := {}
var pursuit_anchor := 1
var music := AudioStreamPlayer.new()
var text_line := ""
var say_time := 0.0
var rng := RandomNumberGenerator.new()
var ambient_tick := 0.0
## 0.40: debug menu (host): the infected cannot hurt anyone. (0.55: nothing can: Heavy-arm and blasts check it too.)
var harmless := false
## 0.55 (tests): blows refused because the squad is invulnerable (the infected's, Heavy-arm's, blasts).
var blocked_hits := 0
## 0.41 (host): who is dragging which table [index, grab point on it], how loud each survivor is moving, who is
## about to wake, the last stand's clock and the back door.
var draggers := {}
var moving := {}
var pending_wake: Array = []
var sense_wait := 0.0
var stage_time := 0.0
var back_left := 0
var breach_at := 30.0
var back_wait := 0.0
var underfoot: Array = []
var kick_wait := 0.0
## 0.46 (host): patch-ups under way: target id -> [healer id, seconds so far].
var healing := {}
var next_drop := 100000
## 0.48: the map is scattered with weapons, ammunition and healthkits as the waypoint graph (scripts/waypoints.gd)
## reaches each part of it: one roll per 22 m square, only on places joined to where the players stand.
const BUCKET := 22.0
var _seeded := {}
var _seed_wait := 3.0
var _way_wait := 0.0
## 0.49: the mart siege could not end. It waited for every wave to be put down AND for `enemies` to be empty, but
## (1) the back group hammering at a shut, braced back door stand outside the walls where nobody can see or reach
## them, (2) a wave whose spawn kept failing (a player standing in the spawn ground) never counted down, and (3) any
## straggler stuck out of reach kept the list from emptying. `_mop_up` settles all three.
var _mop_wait := 0.0
var _spawn_fails := 0
var _back_fails := 0
var _stage_log := 0.0
## 0.48: T: a shove (host: when each survivor may shove again).
## 0.49: arm's length (it was 1.9 m and threw whole groups about): one shove, one body, a step back.
const SHOVE_REACH := 1.3
var _shove_ready := {}
var nade_nodes := {}
var _nade_scene: PackedScene
## 0.46 (every peer): the world behind the team has been put away (see `_leave_behind`).
var cleaned := false
## 0.49: the run in chapters. When Jonna has told them what she knows she pulls the mart's front shutter down and
## padlocks it (`flags.lockup` 1 walking out, 2 pulling it down, 3 the padlock, 4 shut, 5 the run has moved on);
## everything outside the mart and the ways ahead is put away on every peer (`front_shut`), and the chapter's
## leaderboard comes up (`flags.board`) with a READY for each survivor. While it is up the backstreets are woken
## (`wake_ahead`): they are built with the street but kept put away (hidden, silent; their ground stays solid
## under the dead lying there) until the run reaches them. When every survivor is ready the run goes on.
const FRONT_SPOT := Vector3(.35, 0, 57.35)
const SHUTTER_TIME := 3.8
var front_shut := false
var ahead_awake := false
var _ahead_dead: Array = []
var _jonna_route: Array[Vector3] = []
var _lock_wait := 0.0
## 0.50: the school (school.gd, built with the backstreets' wake on every peer), Rommel the guard, the story's clock,
## the floors reached (flags "floor<k>"), when the next students come, and whether the backstreets were put away.
var school
var rommel
var story_wait := 0.0
var school_wait := 0.0
var school_unloaded := false
## 0.52: the way out with the survivors of 501 (every peer).
var escape
## 0.63: Outer Street (every peer; built at the chapter board after Heavy-arm).
var outer_street = null
## 0.68: the hospital (every peer; built at the long bridge's chapter board).
var hospital = null

## 0.66 (owner: "move Dodong Sikma outside the gate of the player's house at the beginning so he will lead you to his
## house from there"): he waits just outside the courtyard gate and walks the squad there: up the lane, west along
## the road and over the canal bridge, up the near bank, across the plank bridge, down the far bank and into the
## warren, then on through it as before. World points, each leg found on the ground with zombie_nav's search and
## pulled straight where a body fits the whole way (tests/dodong_gate_probe.gd prints them).
const GATE_SPOT := Vector3(14.4, -2.91, 4.4)
const GATE_WALK := [Vector3(14.40, -2.91, 4.40), Vector3(18.90, -2.78, 6.90), Vector3(18.90, -2.78, 9.30),
	Vector3(18.62, -2.78, 9.90), Vector3(18.30, -2.78, 11.10), Vector3(18.30, -2.78, 15.30), Vector3(12.30, -2.91, 16.50),
	Vector3(11.10, -2.91, 16.50), Vector3(4.50, -2.78, 15.62), Vector3(1.95, -2.78, 15.90), Vector3(-7.50, -2.91, 17.10),
	Vector3(-51.45, -2.10, 20.70), Vector3(-51.30, -2.10, 38.70), Vector3(-53.10, -2.10, 59.70), Vector3(-80.10, -2.10, 58.65),
	Vector3(-80.85, -2.10, 57.90), Vector3(-76.50, -2.15, 40.50), Vector3(-74.10, -3.92, 28.50), Vector3(-75.30, -3.89, 12.90),
	Vector3(-75.62, -3.65, 12.30), Vector3(-75.90, -3.40, 11.70), Vector3(-76.50, -2.92, 11.10)]
## Where the warren part of `route` begins (its own waypoints counted from here: the fallen roof, the plank bridge).
var warren_at := 0

func setup(owner_session) -> void:
	session = owner_session
	street = Street.new()
	street.seed_value = int(session.run_seed)
	rng.seed = int(session.run_seed)*7919+11
	add_child(street)
	for p: Vector3 in GATE_WALK: route.append(p)
	warren_at = route.size()
	route.append_array([W.at(-14,W.FLOOR,8),W.at(-24,W.FLOOR,8),W.at(-31,W.FLOOR,8),W.pos(1.65,W.DECK,8)])
	for z in [5,2,-1,-4,-7,W.B1_Z]: route.append(W.pos(1.65,W.DECK,z))
	route.append(W.pos(-1.7,W.DECK,W.B1_Z))
	for z in [-7,-3,1,4,6.5,10,14,18.5,20.5]: route.append(W.pos(-1.7,W.DECK,z))
	route.append(W.pos(-4.9,W.DECK,20.4))
	guide = Figure.new()
	add_child(guide)
	guide.setup("res://assets/characters/zombies/z_tanod.glb",route[0],"Dodong Sikma")
	guide.rotation.y = PI*.5   # facing the gate, the house behind it
	guide.pose("idle_hurt")
	# 0.66: a tanod's flashlight, held low and pointed at the ground ahead of him: he is seen at the gate in the dark,
	# and the squad sees where he is leading. (No shadow: it moves with him.)
	var torch := SpotLight3D.new()
	torch.name = "Dodong's flashlight"
	torch.position = Vector3(.22,1.05,-.25)
	torch.rotation = Vector3(-.5,0,0)
	torch.spot_range = 9.0
	torch.spot_angle = 24.0
	torch.spot_attenuation = 1.2
	torch.light_energy = 2.2
	torch.light_color = Color(1.0,.93,.8)
	torch.shadow_enabled = false
	guide.add_child(torch)
	jonna = Figure.new()
	add_child(jonna)
	jonna.setup("res://assets/characters/survivors/jonna.glb",Street.ORIGIN+BackOffice.DOORWAY,"Jonna")
	jonna.pose("idle_hurt")
	jonna.visible = false
	rommel = Figure.new()
	add_child(rommel)
	rommel.setup("res://assets/characters/survivors/school_guard.glb",Street.ORIGIN+SCHOOL.GUARD_SEAT,"Rommel")
	rommel.rotation.y = .91
	rommel.pose("sit_hurt")
	rommel.visible = false
	music.stream = preload("res://assets/audio/coop_pursuit.wav")
	music.volume_db = -34
	add_child(music)
	# The bridge, far bank and warren are the same places as in the solo world.
	var marks: Array[Vector3] = [Vector3(3,-2.85,18),Vector3(-19,-2.85,18),Vector3(-36,-2.8,18),
		C.at(C.LANE_U,C.FLOOR,20),C.at(C.LANE_U,C.FLOOR,38),C.at(C.LANE_U,C.FLOOR,59),
		C.at(-12,C.FLOOR,60),C.at(-14,C.FLOOR,43),C.at(-14,C.FLOOR,23),route[warren_at]]
	for i in marks.size()-1:
		var mark := Node3D.new()
		add_child(mark)
		mark.position = marks[i]+Vector3.UP*.09
		mark.rotation.y = atan2(marks[i+1].x-marks[i].x,marks[i+1].z-marks[i].z)
		street.piece(mark,Vector3.ZERO,Vector3(.17,.025,1.1),"#8b3027")
		for side in [-1,1]:
			var tip = street.piece(mark,Vector3(side*.18,0,.37),Vector3(.14,.027,.61),"#8b3027")
			tip.rotation.y = -side*.69
	_victims()
	_put_ahead_away()
	# 0.66: Store Road and the mart, read into the nav's map in the background during chapter one.
	if multiplayer.is_server():
		map_ahead(-13.0, 13.0, -1.0, 84.0, 0.0)

## The street's dead, lying where they fell (local bodies on every peer: rounds still move and tear them).
func _victims() -> void:
	for i in VICTIMS.size():
		var spec: Array = VICTIMS[i]
		var v := Figure.new()
		add_child(v)
		v.key = -100-i
		v.session = session
		v.setup("res://assets/characters/zombies/z_%s.glb"%INFECTED[int(spec[1])],Street.ORIGIN+(spec[0] as Vector3),"",true)
		v.rotation.y = float(spec[2])
		v.clips.play("death_fwd")
		v.clips.seek(1.55,true)
		v.go_limp(Vector3.ZERO)
		victims.append(v)
	# 0.42: the dead of Olivar Family Mart, each left in the pose it fell from (a clip held part-way, then let go).
	# 0.44: and the squad and the tanod who held the ramp up to the gate (approach.gd).
	var dead: Array = Street.STORE_DEAD+Street.APPROACH.DEAD+Street.BACKSTREETS.DEAD
	for i in dead.size():
		var spec: Array = dead[i]
		var v := Figure.new()
		add_child(v)
		v.key = -120-i
		v.session = session
		v.setup("res://assets/characters/zombies/z_%s.glb"%INFECTED[int(spec[1])],Street.ORIGIN+(spec[0] as Vector3),"",true)
		v.rotation.y = float(spec[2])
		var clip: String = spec[3]
		v.clips.play(clip)
		v.clips.seek(v.clips.get_animation(clip).length*float(spec[4]),true)
		v.go_limp(spec[5] as Vector3)
		victims.append(v)

func nearest(at: Vector3, include_down := false) -> int:
	var best := INF
	var found := 0
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if p.hp<=0 and not include_down: continue
		var d := at.distance_squared_to(p.pos)
		if d<best:
			best = d
			found = id
	return found

func candidate(id: int) -> String:
	if not session.team.has(id): return ""
	var p: Dictionary = session.team[id]
	if p.hp<=0: return ""
	var at: Vector3 = p.pos
	var bot: bool = session.is_bot(id)
	if not bot and int(p.get("drag",-1))>=0: return "letgo"
	for other: int in session.team:
		if other!=id and session.team[other].hp==0 and at.distance_to(session.team[other].pos)<2.6: return "revive%d"%other
	# 0.46: a hurt teammate within reach, and a healthkit to patch them up with.
	if not bot and int(p.kits)>0:
		for other: int in session.team:
			if other!=id and int(session.team[other].hp)>0 and int(session.team[other].hp)<MAX_HP and at.distance_to(session.team[other].pos)<2.2: return "patch%d"%other
	if stage==0 and at.distance_to(guide.position)<3.3: return "talk"
	if stage==2 and at.distance_to(street.key.global_position)<2.6: return "keys"
	if stage==3 and at.distance_to(Street.ORIGIN+Street.GATE)<3.7: return "gate"
	if stage==6 and flags.get("office",false) and at.distance_to(jonna.position)<3.2: return "jonna"
	if stage==7 and not bot and at.distance_to(jonna.position)<5.0: return "listen"
	# 0.50: the school's story (anyone may turn the page), Rommel at the gate, room 501.
	if not bot and flags.has("story") and int(flags.story)<STORY.size(): return "story"
	if stage==9 and not bot and school!=null and at.distance_to(Street.ORIGIN+SCHOOL.GUARD_SEAT)<5.2:
		return "listen" if flags.get("guard_talk",false) else "guard"
	if stage==10 and not bot and school!=null and at.distance_to(Street.ORIGIN+SCHOOL.DOOR_501)<2.4: return "survivors"
	# 0.63: the fifth floor's mechanical room door (up the ladder), forced from inside: loud.
	if stage>=10 and stage<=13 and not bot and school!=null and not bool(flags.get("mechdoor",false)) and school.at_mech_door(at): return "mechdoor"
	# 0.52: Ma'am Teves's talk; the fifth floor's fire door, unchained with her key.
	if stage==11 and not bot and escape!=null and not escape.people.is_empty() and at.distance_to(escape.people[0].position)<6.0: return "listen"
	if stage==13 and not bot and escape!=null and escape.at_fire_door(at): return "unchain"
	# 0.53: Heavy-arm's key where he fell; the rear gate (shut until it is opened with it).
	if stage==15 and not bot and escape!=null and escape.fight!=null:
		if escape.fight.key_here(at): return "heavykey"
		if escape.fight.at_gate(at): return "reargate" if bool(flags.get("heavy_key_taken",false)) else "gatelocked"
	# 0.68: the hospital's people, its doors and the things for the laboratory.
	if stage==HOSPITAL and hospital!=null:
		var ha: String = hospital.candidate(at,flags,hospital.talking() and not bot)
		if ha!="" and not bot: return ha
	if stage in [16, 17] and not bot and outer_street!=null:
		var oa: String = outer_street.candidate(at,flags)
		if oa!="": return oa
	if stage==8 and not bot:
		if not flags.get("backdoor",false) and not flags.get("backdoor_open",false) and at.distance_to(Street.ORIGIN+Street.BACK_DOOR)<2.3: return "backdoor"
		if not flags.get("alley",false) and at.distance_to(Street.ORIGIN+Street.ALLEY_GATE)<2.8: return "alley"
	for k: int in drops:
		if bot and str(drops[k][1]).begins_with("weapon:"): continue
		if at.distance_to(drops[k][0])<1.9: return "drop%d"%k
	if not bot:
		for i in GRENADE_SPOTS.size():
			if not flags.get("nade%d"%i,false) and at.distance_to(Street.ORIGIN+(GRENADE_SPOTS[i] as Vector3))<1.9: return "nade%d"%i
	for i in street.doors.size():
		if at.distance_to(street.doors[i].global_position)<2.5: return "door%d"%i
	if stage in [4,5]:
		if not p.rifle:
			for i in street.rifles.size():
				if not flags.get("rifle%d"%i,false) and at.distance_to(street.rifles[i].global_position)<2.55: return "rifle%d"%i
		if not bot:
			for i in street.shotguns.size():
				if not flags.get("shotgun%d"%i,false) and at.distance_to(street.shotguns[i].global_position)<1.9: return "shotgun%d"%i
		if at.distance_to(Street.ORIGIN+Street.COUNTER+Vector3(1.6,0,2.8))<3: return "ammo"
	if not bot and stage>=3:
		var best := 2.1
		var found := ""
		for i in street.tables.size():
			var d := at.distance_to(street.tables[i].global_position)
			if d<best and not _dragged(i) and not street.tables[i].has_meta("locked"):
				best = d
				found = "table%d"%i
		if found!="": return found
	return ""

func _dragged(i: int) -> bool:
	for id: int in draggers:
		if int(draggers[id][0])==i: return true
	return false

func prompt_for(action: String) -> String:
	if action.begins_with("revive"): return "Hold E  •  Help %s up (healthkit)"%session.display_name(int(action.trim_prefix("revive")))
	if action.begins_with("patch"): return "Hold E  •  Patch up %s (healthkit)"%session.display_name(int(action.trim_prefix("patch")))
	if action.begins_with("nade"): return "E  •  Take frag grenade"
	if action.begins_with("drop"):
		var k := int(action.trim_prefix("drop"))
		if not drops.has(k): return ""
		var kind := str(drops[k][1])
		if kind.begins_with("weapon:"):
			var ammo: Array = drops[k][2] if (drops[k] as Array).size()>2 else [0,false,0]
			var rounds := int(ammo[0])+(1 if bool(ammo[1]) else 0)+int(ammo[2])
			return "E  •  Take %s (%d rounds)"%[InteriorArsenal.display_name(kind.trim_prefix("weapon:")),rounds]
		if kind.begins_with("healthkit"): return "E  •  Take "+str(InteriorArsenal.KIT_NAMES[drop_size(kind)]).to_lower()
		return "E  •  Take ammo (%s box)"%drop_size(kind)
	for pair in [["door","Open / close door"],["table","Hold E  •  drag table"],["rifle","Take rifle"],["shotgun","Take shotgun"]]:
		if action.begins_with(pair[0]): return ("" if pair[0]=="table" else "E  •  ")+pair[1]
	return {"story":"E  •  Go on","guard":"E  •  Speak to the guard","survivors":"E  •  Knock three times",
		"jonna":"E  •  Speak to Jonna","listen":"E  •  Go on","backdoor":"E  •  Open the back door","alley":"E  •  Unlock the service gate",
		"unchain":"E  •  Unlock the chain (Ma'am Teves's key)","mechdoor":"E  •  Force the door","heavykey":"E  •  Take the rear gate's key",
		"reargate":"E  •  Unlock the rear gate","gatelocked":"Chained and padlocked. The key is on the guard's lanyard.","talk":"E  •  Speak to Dodong","keys":"E  •  Take Gate Keys","gate":"E  •  Unlock gate","ammo":"E  •  Refill ammo",
		"letgo":"Let go of E  •  leave the table"}.get(action,OUTER_STREET.PROMPTS.get(action,"" if hospital==null else hospital.prompt(action)))

const WEAPON_NAMES := {"pistol":"Glock","rifle":"rifle","shotgun":"shotgun","sniper":"sniper rifle"}

## 0.53: the HUD's objective line: the stage's, unless the fight at the rear gate says otherwise.
func objective() -> String:
	if stage==HOSPITAL and hospital!=null: return hospital.objective(flags)
	if stage in [16, 17] and outer_street!=null: return outer_street.objective(flags,stage)
	if stage==15 and escape!=null and escape.fight!=null:
		var o: String = escape.fight.objective()
		if o!="": return o
	return OBJECTIVES[stage]

## 0.53 (host): a grenade went off at `at` (grenade.gd, on the host whoever threw it): fuel drums close to it go up.
func boom(at: Vector3) -> void:
	if escape!=null and escape.fight!=null: escape.fight.near_blast(at)

func say(line: String, seconds := 8.0) -> void:
	text_line = line
	say_time = seconds

func interact(id: int, action: String) -> void:
	if action=="letgo":
		release(id)
		return
	if action=="" or action!=candidate(id) or stage>=OVER: return
	var p: Dictionary = session.team[id]
	if action=="talk":
		_dodong_talks()
	elif action=="keys":
		_keys_taken()
	elif action=="gate":
		open_road(id)
	elif action=="jonna":
		stage = 7
		stage_time = 0.0
		talker = id
		talk_index = -1
		talk_wait = .4
		jonna_step = 0
	elif action=="listen":
		if stage==11 and escape!=null: escape.listen()
		else: talk_wait = minf(talk_wait,.05)
	elif action=="unchain":
		escape.unchain()
	elif action=="mechdoor":
		_force_mech_door()
	elif action=="heavykey":
		escape.fight.take_key(id)
	elif action=="reargate":
		escape.fight.unlock()
	elif action=="outer_cutters":
		outer_street.take_cutters(self)
	elif action=="outer_chain":
		outer_street.cut_chain(self)
	elif action=="outer_power":
		outer_street.power_on(self)
	elif action.begins_with("hosp_") and hospital!=null:
		hospital.interact(self,id,action)
	elif action=="story":
		story_wait = minf(story_wait,.05)
	elif action=="guard":
		flags.guard_talk = true
		talker = id
		talk_index = -1
		talk_wait = .3
	elif action=="survivors":
		knock(id)
	elif action=="backdoor":
		_open_back_door()
	elif action=="alley":
		_open_alley()
	elif action.begins_with("table"):
		grab(id,int(action.trim_prefix("table")))
	elif action.begins_with("door"):
		flags[action] = not flags.get(action,false)
		var door: Node3D = street.doors[int(action.trim_prefix("door"))]
		nav.forget_box(AABB(door.global_position-Vector3(1.8,0,1.8),Vector3(3.6,2.6,3.6)))
	elif action.begins_with("rifle"):
		flags[action] = true
		p.rifle = true
		session.reward(id,"rifle")
	elif action.begins_with("shotgun"):
		flags[action] = true
		session.reward(id,"shotgun")
	elif action=="ammo":
		session.reward(id,"refill")
	elif action.begins_with("revive") or action.begins_with("patch"):
		var other := int(action.trim_prefix("revive").trim_prefix("patch"))
		if int(p.kits)>0: start_heal(id,other)
		else: session.personal(id,"A healthkit is needed to help them up.")
	elif action.begins_with("nade"):
		flags[action] = true
		session.reward(id,"grenade")
	elif action.begins_with("drop"):
		var k := int(action.trim_prefix("drop"))
		var kind := str(drops[k][1])
		if kind.begins_with("healthkit"):
			if int(p.kits)>=MAX_KITS:
				session.personal(id,"You can't carry more than %d healthkits."%MAX_KITS)
				return
			var size := drop_size(kind)
			add_kit(p,size)
			session.personal(id,"%s (%d)  •  hold F to use it"%[InteriorArsenal.KIT_NAMES[size],int(p.kits)])
		elif kind.begins_with("weapon:"):
			if session.is_bot(id): return
			session.give_weapon(id,kind.trim_prefix("weapon:"),drops[k][2] if (drops[k] as Array).size()>2 else [0,false,0])
		else: session.reward(id,"ammo:"+drop_size(kind))
		session.picked(id,kind)
		drops.erase(k)

## Dodong, spoken to: the escort begins. (0.55: play and the debug jumps both come through here, and the rest below.)
func _dodong_talks() -> void:
	stage = 1
	say("Dodong Sikma\nI’m bitten. Please, I just want to go home. The soldiers went to the Olivar mart. None came back, but their equipment is still there. Stay with me.",14)

## Dodong home: at his door, the escort over.
func _dodong_home() -> void:
	waypoint = route.size()
	guide.position = route[route.size()-1]
	guide.scale.y = 1.0
	guide.pose("idle_hurt")
	if stage<2:
		stage = 2
		say("Dodong Sikma\nThis is my house. I used to keep watch for the neighbourhood. My keys are beside the candle.")

## 0.55: the warren's narrow leaves Dodong opens on his way home (`escort` opens each as he comes within 2.15 m),
## open as he would have left them.
func _open_his_doors() -> void:
	for d in get_tree().get_nodes_in_group("warren_doors"):
		if not d.has_method("is_open") or d.is_open(): continue
		var at: Vector3 = d.global_position
		var near := false
		for i in route.size()-1:
			var a := Vector2(route[i].x,route[i].z)
			var b := Vector2(route[i+1].x,route[i+1].z)
			var p := Vector2(at.x,at.z)
			var t := clampf((p-a).dot(b-a)/maxf((b-a).length_squared(),.0001),0.0,1.0)
			if p.distance_to(a+(b-a)*t)<2.15 and absf(at.y-route[i].y)<2.5: near = true
		if not near: continue
		var path := str(session.main.get_path_to(d))
		if session.doors.has(path): session.switch_door.rpc(path,true)

func _keys_taken() -> void:
	stage = 3
	flags.keys = true
	say("Dodong Sikma\nThose are my gate keys. Leave me here. Take the north walk to the bridge, then the ramp. Go quietly up there. Hurry!")

func _open_back_door() -> void:
	flags.backdoor_open = true
	nav.forget_box(AABB(Street.ORIGIN+Street.BACK_DOOR-Vector3(1.6,0,1.6),Vector3(3.2,2.6,3.2)))

## The service gate unlocked with Jonna's key.
func _open_alley() -> void:
	flags.alley = true
	nav.forget_box(AABB(Street.ORIGIN+Street.ALLEY_GATE-Vector3(4.5,0,1.6),Vector3(9.0,3.0,3.2)))

## The road gate is open: a pack follows from behind a little later, and Store Road has its own (asleep, eating,
## wandering) waiting along the way.
func open_road(id: int) -> void:
	stage = 4
	stage_time = 0.0
	pursuit_anchor = id
	flags.gate = true
	flags.unlocked = true
	wave_left = 10
	wave_total = 10
	next_spawn = 7.0
	var spots := ROAD_SPOTS.duplicate()
	for i in range(spots.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var count := clampi(4+session.team.size(),5,9)
	for i in count:
		var at := ground(Street.ORIGIN+(spots[i] as Vector3))
		var z = spawn(at,true)
		if z==null: continue
		z.idle_mode = "wander" if rng.randf()<.65 else "sleep"
		z.home = z.position
		z.rotation.y = rng.randf_range(-PI,PI)
		z.wander_wait = rng.randf_range(0,4)
	# One or two at the dead in the lane and by the jeepney, eating.
	for i in 2:
		if rng.randf()<.3: continue
		var v: Node3D = victims[i]
		var at := ground(v.where()+Vector3(.55,0,-.35))
		var z = spawn(at,true)
		if z==null: continue
		z.idle_mode = "feed"
		var d: Vector3 = v.where()-z.position
		z.rotation.y = atan2(-d.x,-d.z)

func grab(id: int, i: int) -> void:
	if session.is_bot(id) or _dragged(i) or draggers.has(id): return
	var t: RigidBody3D = street.tables[i]
	var p: Dictionary = session.team[id]
	var local := t.to_local(p.pos+Vector3.UP*.7)
	var half: Vector3 = t.get_meta("half",Vector3(.5,.4,.5))
	local = Vector3(clampf(local.x,-half.x,half.x),.7,clampf(local.z,-half.z,half.z))
	draggers[id] = [i,local]
	p.drag = i
	t.sleeping = false

func release(id: int) -> void:
	draggers.erase(id)
	if session.team.has(id): session.team[id].drag = -1

## Host: each dragged table follows the hands of whoever has it, by its grab point, along the ground.
func drag_tick() -> void:
	for id: int in draggers.keys():
		if not session.team.has(id) or session.team[id].hp<=0:
			release(id)
			continue
		var p: Dictionary = session.team[id]
		var t: RigidBody3D = street.tables[int(draggers[id][0])]
		var grip: Vector3 = t.to_global(draggers[id][1])
		var forward := Vector3(-sin(float(p.yaw)),0,-cos(float(p.yaw)))
		var hand: Vector3 = p.pos+forward*.85+Vector3.UP*.7
		if Vector2(grip.x-p.pos.x,grip.z-p.pos.z).length()>2.6:
			release(id)
			continue
		var error := hand-grip
		error.y = clampf(error.y,-.04,.04)
		var at := grip-t.global_position
		var point_velocity := t.linear_velocity+t.angular_velocity.cross(at)
		var pull := (error*55.0-point_velocity*16.0)*t.mass*.3
		t.sleeping = false
		t.apply_force(pull.limit_length(700.0),at)

## The squad AI's own healthkit (the same three-second patch-up as a player's).
func heal(id: int) -> void:
	start_heal(id,id)

## 0.46 (host): `by` starts patching up `target` (themselves, or a teammate in reach): three seconds, a healthkit.
func start_heal(by: int, target: int) -> bool:
	if stage>=OVER or not session.team.has(by) or not session.team.has(target): return false
	var p: Dictionary = session.team[by]
	var t: Dictionary = session.team[target]
	if int(p.hp)<=0 or int(p.kits)<=0 or healing.has(target): return false
	for other: int in healing:
		if int(healing[other][0])==by: return false
	if by==target:
		if int(t.hp)>=MAX_HP:
			session.personal(by,"You're not hurt.")
			return false
	elif int(t.hp)>=MAX_HP or p.pos.distance_to(t.pos)>2.8: return false
	healing[target] = [by,0.0]
	t.heal_t = 0.0
	p.heal_t = 0.0
	if by!=target:
		t.held = true
		session.personal(target,"%s is patching you up. Hold still."%session.display_name(by))
	return true

## 0.49 (host): whether `id` is in a patch-up right now, either end of it (patching, being patched, or both).
func in_heal(id: int) -> bool:
	if healing.has(id): return true
	for target: int in healing:
		if int(healing[target][0])==id: return true
	return false

## 0.46 (host): `by` let go of F / E (or moved off): whatever they were doing stops, the kit is kept.
func stop_heal(by: int) -> void:
	for target: int in healing.keys():
		if int(healing[target][0])==by: _end_heal(target)

func _end_heal(target: int) -> void:
	if not healing.has(target): return
	var by := int(healing[target][0])
	healing.erase(target)
	for id in [by,target]:
		if session.team.has(id):
			session.team[id].heal_t = -1.0
			session.team[id].held = false

func heal_tick(delta: float) -> void:
	for target: int in healing.keys():
		var by := int(healing[target][0])
		if not session.team.has(by) or not session.team.has(target) or int(session.team[by].hp)<=0:
			_end_heal(target)
			continue
		var p: Dictionary = session.team[by]
		var t: Dictionary = session.team[target]
		# (0.49: the squad AI stand still for it, so only a human healer walking away breaks it off.)
		if by!=target and p.pos.distance_to(t.pos)>3.4 and not session.is_bot(by):
			session.personal(by,"Too far away: stay close to patch them up.")
			_end_heal(target)
			continue
		var done := float(healing[target][1])+delta
		healing[target][1] = done
		t.heal_t = done/HEAL_TIME
		p.heal_t = done/HEAL_TIME
		if done<HEAL_TIME: continue
		_end_heal(target)
		if int(p.kits)<=0: continue
		var was := int(t.hp)
		var size := take_kit(p,MAX_HP-maxi(was,0))
		var span: Array = InteriorArsenal.KITS.get(size,[HEAL_MIN,HEAL_MAX])
		var amount := rng.randi_range(int(span[0]),int(span[1]))
		t.hp = mini(MAX_HP,maxi(was,0)+amount)
		if was<=0:
			p.revives = int(p.revives)+1
			session.revived(by,target)
		session.healed(target)
		var gained := int(t.hp)-was
		if by==target: session.personal(by,"+%d HP  •  %d healthkit%s left"%[gained,int(p.kits),"" if int(p.kits)==1 else "s"])
		else:
			session.personal(by,"%s +%d HP  •  %d healthkit%s left"%[session.display_name(target),gained,int(p.kits),"" if int(p.kits)==1 else "s"])
			session.personal(target,"%s patched you up  •  +%d HP"%[session.display_name(by),gained])

func escort(delta: float) -> void:
	if stage!=1: return
	var friend := nearest(guide.position)
	if not friend or guide.position.distance_to(session.team[friend].pos)>7.5:
		guide.pose("idle_hurt")
		return
	var dest := route[waypoint]
	var dir: Vector3 = dest-guide.position
	if dir.length()<.15:
		waypoint += 1
		if waypoint==route.size(): _dodong_home()
		elif waypoint==warren_at+5: say("Dodong Sikma\nThe roof fell in. Hold C and follow me under. The plank bridge is just ahead.")
		return
	# Open the narrow leaves before the guide reaches their threshold.
	for d in get_tree().get_nodes_in_group("warren_doors"):
		if d.global_position.distance_to(guide.position)<2.15 and not d.is_open(): session.switch_door.rpc(str(session.main.get_path_to(d)),true)
	guide.position = guide.position.move_toward(dest,delta*1.55)
	# 0.66: outdoors (the town, the banks) his feet keep to the ground between the points.
	if waypoint<warren_at:
		var g := ground(guide.position)
		if g.is_finite() and absf(g.y-.03-guide.position.y)<.6: guide.position.y = g.y-.03
	guide.rotation.y = atan2(-dir.x,-dir.z)
	# 0.43: under the fallen roof he crouches and walks bent double (the crouch_walk clip); he used to be squashed
	# to 61 % of his height.
	var low: bool = guide.position.z<.9 and guide.position.z>-3.4 and waypoint>=warren_at and waypoint<warren_at+8
	guide.pose("crouch_walk" if low else "walk_hurt")
	guide.scale.y = 1.0

func ground(at: Vector3) -> Vector3:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.3,at+Vector3.DOWN*3.0,2))
	if hit.is_empty() or hit.normal.y < .65: return Vector3.INF
	return hit.position+Vector3.UP*.03

func _next_variant() -> int:
	if _variant_bag.is_empty():
		for i in INFECTED.size():
			_variant_bag.append(i)
		for i in range(_variant_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := _variant_bag[i]
			_variant_bag[i] = _variant_bag[j]
			_variant_bag[j] = tmp
	return _variant_bag.pop_back()

## A new infected at `at` (null when there is no ground there). `sleeping`: not hunting anyone yet. `student`: one
## of the school's (0.51: mostly students; now and then a teacher, the maintenance staff, a parent). `kind` forces it.
func spawn(at: Vector3, sleeping := false, student := false, kind := -1):
	if not at.is_finite(): return null
	next_id += 1
	if kind<0: kind = _next_variant() if not student else _school_kind()
	var z = make_enemy(next_id,kind,at)
	z.asleep = sleeping
	# 0.50: the students are young and they do not tire: faster than the town's infected. 0.51: the teachers a little
	# slower, the maintenance men slow and heavy (they take more), the parents anything.
	if kind>=STUDENT_FIRST and kind<TEACHER_FIRST: z.speed = rng.randf_range(2.6,3.7)
	elif kind>=TEACHER_FIRST and kind<JANITOR_FIRST: z.speed = rng.randf_range(2.2,3.1)
	elif kind>=LAB_FIRST: z.speed = rng.randf_range(2.2,3.4)
	elif kind>=JANITOR_FIRST:
		z.speed = rng.randf_range(1.9,2.6)
		z.hp *= 1.45
	elif student: z.speed = rng.randf_range(2.0,3.3)
	return z

## 0.66 (host): bulk spawns (a school floor's sleepers, a class standing in its room, the backstreets' sleepers,
## Outer Street's zones) are made LATER_PER_TICK a tick instead of all in one: a figure is ~1-2 ms to set up (its
## model, its ragdoll), and a floor reached was 46 ms in one frame. They stand where they would have, a few ticks
## later; nobody sees the difference. A debug jump makes the queue's all at once before it clears behind.
var _later: Array[Callable] = []
const LATER_PER_TICK := 3
const LATER_BUDGET_MS := 3.0
func later(job: Callable) -> void: _later.append(job)
func _later_tick() -> void:
	var t0 := Time.get_ticks_usec()
	var n := 0
	while not _later.is_empty() and n<LATER_PER_TICK and (n==0 or Time.get_ticks_usec()-t0<LATER_BUDGET_MS*1000.0):
		var job: Callable = _later.pop_front()
		if job.is_valid(): job.call()
		n += 1
func flush_later() -> void:
	while not _later.is_empty():
		var job: Callable = _later.pop_front()
		if job.is_valid(): job.call()

## 0.66 (the NOW standard, host): the ground ahead read into the nav's map before the squad gets there. Every search
## (an infected's way round a corner, a link of the waypoint graph) reads each half cell it crosses once (a ray and a
## body-sized check, zombie_nav `_floor`, remembered): over ground nobody had walked, one search was 5-9 ms, and the
## college's floors were the game's longest frames. Spans (street-local [x0, x1, z0, z1, floor y]) are read in the
## background NAV_AHEAD_US a tick (Store Road during chapter one), or behind a chapter board (`premap_step`, the
## college). The map is the same as the searches would have made; it is only made earlier.
const NAV_AHEAD_US := 800
var _ahead_spans: Array = []
var _ahead_h := Vector2i(1 << 30, 0)
var nav_premapped := 0
func map_ahead(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	_ahead_spans.append([x0, x1, z0, z1, y])

## Reads spans for at most `budget_us`; true when none are left.
func premap_step(budget_us: int) -> bool:
	if nav.space==null: nav.space = get_world_3d().direct_space_state
	var t0 := Time.get_ticks_usec()
	while not _ahead_spans.is_empty():
		var sp: Array = _ahead_spans[0]
		var o := Street.ORIGIN
		var hx0 := floori((o.x+float(sp[0]))/(InteriorZombieNav.CELL*.5))
		var hx1 := floori((o.x+float(sp[1]))/(InteriorZombieNav.CELL*.5))
		var hz0 := floori((o.z+float(sp[2]))/(InteriorZombieNav.CELL*.5))
		var hz1 := floori((o.z+float(sp[3]))/(InteriorZombieNav.CELL*.5))
		var y: float = o.y+float(sp[4])
		if _ahead_h.x==1<<30: _ahead_h = Vector2i(hx0,hz0)
		while _ahead_h.x<=hx1:
			while _ahead_h.y<=hz1:
				nav._floor(_ahead_h.x,_ahead_h.y,y)
				nav_premapped += 1
				_ahead_h.y += 1
				if Time.get_ticks_usec()-t0>budget_us: return false
			_ahead_h.y = hz0
			_ahead_h.x += 1
		_ahead_spans.pop_front()
		_ahead_h = Vector2i(1 << 30, 0)
	return true

## 0.67 (host): Outer Street's ground, in the order the squad comes to it (street-local [x0, x1, z0, z1, floor y]):
## the lane, the avenue and the plaza behind PILCST's board (`premap_outer_board`), the rest in the background
## (NAV_AHEAD_US a tick) long before anyone gets there. Outer Street's crowd frames were searches over ground never read.
var _outer_board_left := 0
func premap_outer() -> void:
	if not multiplayer.is_server() or bool(flags.get("outer_premapped",false)): return
	flags.outer_premapped = true
	map_ahead(28.0, 64.0, 596.0, 650.0, 0.0)
	map_ahead(22.0, 80.0, 648.0, 704.0, 0.0)
	_outer_board_left = _ahead_spans.size()
	for sp: Array in [[-8.0, 22.0, 661.0, 706.0, 5.0], [17.0, 67.0, 683.0, 692.0, 5.6], [19.0, 57.0, 670.0, 712.0, -5.2],
			[24.0, 37.0, 687.0, 752.0, -10.2], [30.0, 37.0, 733.0, 796.0, -11.3], [-14.0, 106.0, 733.0, 812.0, 0.0],
			[39.0, 80.0, 734.0, 786.0, 4.15], [88.0, 100.0, 812.0, 1086.0, 2.0]]:
		map_ahead(float(sp[0]), float(sp[1]), float(sp[2]), float(sp[3]), float(sp[4]))
	_outer_board_left = _ahead_spans.size()-_outer_board_left

## (host, a loading step behind the city's board) The lane to the plaza read in; true once it is.
func premap_outer_board() -> bool:
	premap_outer()
	if _ahead_spans.size()>_outer_board_left: premap_step(10000)
	return _ahead_spans.size()<=_outer_board_left

## The college, its yard and its field (behind the mart's board: session.gd's loading steps).
func premap_school() -> void:
	if not multiplayer.is_server() or bool(flags.get("school_premapped",false)): return
	flags.school_premapped = true
	map_ahead(4.0, 52.0, 497.0, 513.0, 0.0)
	for f in SCHOOL.FLOORS: map_ahead(-1.0, 59.0, 513.0, 536.0, f*SCHOOL.H)
	map_ahead(0.0, 60.0, 536.0, 601.0, 0.0)

## 0.51: who the school sends: students mostly, a teacher one time in eight, the maintenance staff, a parent.
func _school_kind() -> int:
	var roll := rng.randf()
	if roll<.66: return STUDENT_FIRST+rng.randi_range(0,9)
	if roll<.8: return TEACHER_FIRST+rng.randi_range(0,5)
	if roll<.87: return JANITOR_FIRST+rng.randi_range(0,1)
	return PARENTS[rng.randi()%PARENTS.size()]

func make_enemy(id: int, kind: int, at: Vector3):
	if kind==LUCKY_KIND:
		var lb := LUCKY_BODY.new()
		add_child(lb)
		lb.key = id
		lb.session = session
		lb.setup_lucky(at)
		lb.set_meta("kind",kind)
		lb.set_meta("never_prune",true)
		if hospital!=null: lb.fight = hospital.lucky
		enemies[id] = lb
		return lb
	if kind==HEAVY_KIND:
		var h := HEAVY_BODY.new()
		add_child(h)
		h.key = id
		h.session = session
		h.setup_heavy(at)
		h.set_meta("kind",kind)
		if escape!=null: h.fight = escape.fight
		enemies[id] = h
		return h
	var z := Figure.new()
	add_child(z)
	z.key = id
	z.session = session
	z.setup("res://assets/characters/zombies/z_%s.glb"%INFECTED[kind],at,"",true)
	z.set_meta("kind",kind)
	if hospital!=null: z.set_meta("never_prune",true)
	enemies[id] = z
	return z

func spawn_near(p: Dictionary) -> bool:
	var best := Vector3.INF
	var score := -INF
	var forward := Vector3(-sin(float(p.yaw)),0,-cos(float(p.yaw)))
	for i in 12:
		var angle := rng.randf_range(-PI,PI)
		var dir := Vector3(sin(angle),0,cos(angle))
		if stage==4: dir = Vector3(rng.randf_range(-.4,.4),0,-1).normalized()
		var trial: Vector3 = p.pos+dir*rng.randf_range(7.5,15)
		if stage==5: trial = _in_rect(Street.FRONT_SPAWN)
		if stage==4 and trial.z<Street.ORIGIN.z+1:
			trial = Vector3(Street.ORIGIN.x+rng.randf_range(-1.6,1.6),-2.08,rng.randf_range(56,60))
			# 0.66: the gate shut behind the squad: the pack is already through it, at the road's near end.
			if bool(flags.get("road_shut",false)): trial = Street.ORIGIN+Vector3(rng.randf_range(-2.5,2.5),0,rng.randf_range(3.0,7.0))
		var at := ground(trial)
		if not at.is_finite(): continue
		var close := nearest(at,true)
		if close and at.distance_to(session.team[close].pos)<4: continue
		var cell := InteriorZombieNav.cell_of(at)
		if is_nan(nav.floor_at(cell,at.y)): continue
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP,p.pos+Vector3.UP,2)
		var rank := -dir.dot(forward)+(2 if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty() else 0)
		if rank>score:
			score = rank
			best = at
	return spawn(best)!=null

func _in_rect(rect: Array) -> Vector3:
	var a: Vector3 = rect[0]
	var b: Vector3 = rect[1]
	return Street.ORIGIN+Vector3(rng.randf_range(a.x,b.x),0,rng.randf_range(a.z,b.z))

## 0.40: a shot's count, from whoever fired it (its rounds land through `damage`). 0.41: and it is heard: everything
## not yet hunting within a few streets comes to it (less through walls).
func fired(id: int) -> void:
	if stage>=OVER or not session.team.has(id): return
	var p: Dictionary = session.team[id]
	if p.hp<=0 or p.shot_at>Time.get_ticks_msec(): return
	p.shot_at = Time.get_ticks_msec()+60
	p.shots += 1
	threat = 3.0
	var loud := 42.0 if p.rifle else 32.0
	var space := get_world_3d().direct_space_state
	for z in enemies.values():
		if not z.asleep or z.has_meta("boss"): continue
		var d: float = z.position.distance_to(p.pos)
		if d>loud: continue
		var open: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(z.position+Vector3.UP*1.5,p.pos+Vector3.UP*1.5,2)).is_empty()
		if open or d<loud*.6: _queue_wake(z,randf_range(.15,.4)+d*.02)

## A shot worked out here, without a gun of its own (tests, and the old path): the line from `origin` along `dir`
## against each figure's head, chest and legs, stopped by the world.
func shot(id: int, origin: Vector3, dir: Vector3, rifle: bool) -> void:
	if stage>=OVER or not session.team.has(id) or not origin.is_finite() or not dir.is_finite(): return
	var p: Dictionary = session.team[id]
	if p.hp<=0 or origin.distance_to(p.pos)>3: return
	if p.shot_at>Time.get_ticks_msec(): return
	p.shot_at = Time.get_ticks_msec()+(65 if rifle else 120)
	p.shots += 1
	dir = dir.normalized()
	var best := 95.0
	var wall := InteriorSurfaces.seen_ray(get_world_3d().direct_space_state,origin,origin+dir*best,2|4|InteriorModelKit.SHOT_LAYER)
	if not wall.is_empty(): best = origin.distance_to(wall.position)+.08
	var victim := -1
	var bone := ""
	for k: int in enemies:
		var z = enemies[k]
		if z.dead: continue
		for part in [[1.55,.25,"head"],[1.0,.38,"chest"],[.45,.33,"thigh.L"]]:
			var centre: Vector3 = z.position+Vector3.UP*float(part[0])
			var dist := (centre-origin).dot(dir)
			if dist>=0 and dist<best and centre.distance_to(origin+dir*dist)<float(part[1]):
				best = dist
				victim = k
				bone = part[2]
	if victim<0: return
	var base := 46.0 if rifle else 34.0
	damage(id,victim,bone,origin+dir*best,dir,base*float((InteriorZombie.BODIES[bone] as Array)[5]),95.0 if rifle else 60.0)

## 0.40: the host's word on a hit, from any peer's own gun or a squad AI's: health, the push, and on death a
## ragdoll everywhere. Rounds that arrived in the same instant before the killing one add to how hard it goes over.
## 0.41: `tear` is what the round has to break the part with: enough and the part comes off, everywhere.
func damage(id: int, victim: int, bone: String, point: Vector3, dir: Vector3, dealt: float, knock: float, tear := -1.0) -> void:
	if stage>=OVER or not enemies.has(victim) or not session.team.has(id): return
	var enemy = enemies[victim]
	var p: Dictionary = session.team[id]
	dir = dir.normalized() if dir.length()>.001 else Vector3.FORWARD
	# 0.53: Heavy-arm weighs his own hits (armour, blasts); everyone sees the blood.
	if enemy.has_meta("boss"):
		var bf = boss_fight()
		if bf!=null: bf.hurt(id,bone,dealt)
		session.struck.rpc(victim,bone,point,dir,dealt,knock*.1,id)
		return
	enemy.knock_back(dir,knock)
	if enemy.asleep: _wake(enemy)
	threat = 3.0
	if enemy.hp<=0: return
	enemy.hp -= dealt
	p.hits += 1
	session.struck.rpc(victim,bone,point,dir,dealt,knock,id)
	var torn := _tally(enemy,bone,tear if tear>=0.0 else dealt*.5)
	var off: String = torn.cut
	# Without a head, a chest, its belly or a leg under it, it is finished.
	if off=="head" or off=="chest" or off=="hips" or off=="spine" or off.begins_with("thigh") or off.begins_with("shin"):
		enemy.hp = 0
	if enemy.hp>0:
		_send_tear(enemy,torn,dir,knock)
		return
	p.kills += 1
	if rng.randf()<.48:
		drops[victim] = [enemy.position,("healthkit:" if rng.randf()<.34 else "ammo:")+_roll_size(.55,.33)]
	_finish(id,victim,bone,dir)
	_send_tear(enemy,torn,dir,knock)

## Host: what a part has taken so far; whether it comes off now, or a piece is torn out of it.
func _tally(fig, bone: String, amount: float) -> Dictionary:
	var out := {"cut":"","burst":false,"chunk":""}
	var key := bone.get_slice(".",0)
	if not InteriorZombie.SEVER.has(key) or fig.severed.has(bone) or not fig.bodies.has(bone) or amount<=0.0: return out
	if bone in InteriorZombie.TRUNK and (fig.severed.has("chest") or fig.severed.has("belly")): return out
	var need := float(InteriorZombie.SEVER[key])*.8
	var frame := Engine.get_physics_frames()
	if int(fig.get_meta("tear_frame",-1))!=frame:
		fig.set_meta("tear_frame",frame)
		fig.set_meta("tear_now",{})
	var now: Dictionary = fig.get_meta("tear_now")
	now[bone] = float(now.get(bone,0.0))+amount
	var load := float(fig.sever_load.get(bone,0.0))+amount
	fig.sever_load[bone] = load
	if load>=need:
		out.cut = bone
		out.burst = bone=="head" and float(now[bone])>=InteriorZombie.HEAD_BURST*.8
		return out
	var step := int(fig.chunked.get(bone,0))
	if (step==0 and load>=need*.4) or (step==1 and load>=need*.74):
		fig.chunked[bone] = step+1
		out.chunk = bone
	return out

func _send_tear(fig, torn: Dictionary, dir: Vector3, knock: float) -> void:
	if torn.chunk!="": session.cut_all.rpc(fig.key,torn.chunk,dir,knock,false,true)
	if torn.cut!="": session.cut_all.rpc(fig.key,torn.cut,dir,knock,torn.burst,false)

## A round into one of the dead (`fig`): the host keeps the count for those everyone has; the street's own dead
## (`victims`) are torn here only.
func tear(fig, bone: String, way: Vector3, knock: float, amount: float) -> void:
	if fig==null or not is_instance_valid(fig): return
	var torn := _tally(fig,bone,amount)
	if fig.key<=-100:
		if torn.chunk!="": fig.cut(torn.chunk,way,knock,false,true)
		if torn.cut!="": fig.cut(torn.cut,way,knock,torn.burst)
		return
	_send_tear(fig,torn,way,knock)

func figure_of(key: int):
	if enemies.has(key): return enemies[key]
	for c in corpses:
		if is_instance_valid(c) and c.key==key: return c
	return null

func _finish(id: int, victim: int, bone: String, dir: Vector3) -> void:
	var enemy = enemies.get(victim)
	if enemy==null: return
	var push: Vector3 = dir*maxf(float(enemy.hit_sum),60.0)*1.9
	session.fallen.rpc(victim,enemy.position,int(enemy.get_meta("kind")),enemy.rotation.y,push,bone)
	session.killed(id,victim)

# ---------------------------------------------------------------- 0.41: what they notice

func _queue_wake(z, after: float) -> void:
	if not z.asleep: return
	for w: Array in pending_wake:
		if w[1]==z: return
	pending_wake.append([after,z])

## Turned: a moment of noticing (it screams), then the hunt. The ones close by come too.
func _wake(z) -> void:
	if not z.asleep or z.has_meta("boss"): return
	if log_wakes: print("INTERIOR_COOP_WOKE %s at %s" % [z.idle_mode,str((z.position-Street.ORIGIN).snapped(Vector3.ONE*.1))])
	z.asleep = false
	z.idle_mode = ""
	z.vault_time = -1.0
	z.stun = .6
	z.stun_clip = "alert"
	threat = 3.0
	for other in enemies.values():
		if other!=z and other.asleep and other.position.distance_to(z.position)<7.5: _queue_wake(other,randf_range(.5,1.6))

## Host, five times a second: light, movement and the sight of a survivor up close wake the ones not yet hunting.
func sense(delta: float) -> void:
	for i in range(pending_wake.size()-1,-1,-1):
		pending_wake[i][0] -= delta
		if pending_wake[i][0]<=0.0:
			var z = pending_wake[i][1]
			pending_wake.remove_at(i)
			if is_instance_valid(z) and not z.dead: _wake(z)
	sense_wait -= delta
	if sense_wait>0.0: return
	var gap := .2-sense_wait
	sense_wait = .2
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		var m: Array = moving.get(id,[p.pos,0.0])
		var speed := Vector2(p.pos.x-m[0].x,p.pos.z-m[0].z).length()/maxf(gap,.05)
		moving[id] = [p.pos,lerpf(float(m[1]),minf(speed,9.0),.5)]
	var space := get_world_3d().direct_space_state
	for z in enemies.values():
		if not z.asleep or z.dead or z.has_meta("boss"): continue
		var eye: Vector3 = z.position+Vector3.UP*1.55
		var facing := Vector3(-sin(z.rotation.y),0,-cos(z.rotation.y))
		for id: int in session.team:
			var p: Dictionary = session.team[id]
			if p.hp<=0: continue
			var d: float = z.position.distance_to(p.pos)
			if d>26.0: continue
			var noticed := false
			var los: bool = space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,p.pos+Vector3.UP*1.4,2)).is_empty()
			var asleep: bool = z.idle_mode=="sleep"
			if p.light and los:
				# The beam on it, or the lamp itself in the dark.
				var pitch := float(p.pitch)
				var beam := Vector3(-sin(float(p.yaw))*cos(pitch),sin(pitch),-cos(float(p.yaw))*cos(pitch))
				var to: Vector3 = (eye-(p.pos+Vector3.UP*1.5)).normalized()
				if beam.dot(to)>.9 and d<(16.0 if asleep else 24.0): noticed = true
				elif d<(6.0 if asleep else 11.0) and facing.dot(-to)>-.2: noticed = true
			var flat: Vector3 = Vector3(p.pos.x-z.position.x,0,p.pos.z-z.position.z).normalized()
			# (0.52: in the fifth floor's dark, with no light on you, one has to be all but in front of you to see you.)
			var sight: float = 3.0 if stage==13 and not p.light else 5.5
			if los and not asleep and facing.dot(flat)>.35 and d<sight: noticed = true
			var pace := float(moving.get(id,[p.pos,0.0])[1])
			# 0.52: past the standing horde, crouched and slow, only all but touching one gives you away.
			var touch: float = (.8 if asleep else 1.3) if stage==13 and pace<1.6 else (1.4 if asleep else 2.2)
			if d<touch: noticed = true
			var heard := 11.0 if pace>4.0 else (4.5 if pace>1.9 else 1.6)
			if asleep: heard *= .6
			if d<heard*(1.0 if los else .55): noticed = true
			if noticed:
				if log_wakes: print("INTERIOR_COOP_WAKE by %d d %.2f pace %.2f light %s los %s mode %s at %s" % [id,d,pace,str(p.light),str(los),z.idle_mode,str((z.position-Street.ORIGIN).snapped(Vector3.ONE*.1))])
				_wake(z)
				break

# ---------------------------------------------------------------- the host's tick

func tick(delta: float) -> void:
	nav.space = get_world_3d().direct_space_state
	_waypoints_tick(delta)
	say_time = maxf(0,say_time-delta)
	if say_time<=0: text_line = ""
	if stage>=OVER: return
	_later_tick()
	if not _ahead_spans.is_empty(): premap_step(NAV_AHEAD_US)
	escort(delta)
	_road_seal_check()
	office(delta)
	drag_tick()
	heal_tick(delta)
	sense(delta)
	stage_time += delta
	var living: Array = session.team.keys().filter(func(id): return session.team[id].hp>0)
	if living.is_empty() or guide_hp<=0:
		print("INTERIOR_COOP_FAILED stage %d guide %d team %s" % [stage,guide_hp,session.team.keys().map(func(i): return [i,session.team[i].hp])])
		stage = FAILED
		say("Dodong didn’t make it home." if guide_hp<=0 else "The whole team is down.",30)
		return
	if stage==4 and wave_left==0:
		var gathered := true
		for id in living:
			if session.is_bot(id): continue
			var v: Vector3 = session.team[id].pos-Street.ORIGIN-Street.STORE
			if absf(v.x)>8.4 or absf(v.z)>8.15: gathered = false
		if gathered:
			# 0.66: the gate behind is shut by the siege (if someone hung back short of the seal's line until now).
			if not bool(flags.get("road_shut",false)):
				flags.road_shut = true
				flags.gate = false
			session.gather_bots(Street.ORIGIN+Street.STORE)
			# Recover pursuit stragglers caught in other districts before counting the store wave.
			for k in enemies.keys():
				var z = enemies[k]
				if z.asleep or z.position.distance_to(Street.ORIGIN+Street.STORE)>34:
					enemies.erase(k)
					z.queue_free()
			stage = 5
			stage_time = 0.0
			wave_left = maxi(16,4*session.team.size())
			back_left = 3+mini(session.team.size(),3)
			breach_at = rng.randf_range(24.0,42.0)
			wave_total = wave_left+back_left
			next_spawn = 0
	if stage==5: _mop_up(delta)
	if stage==5 and wave_left==0 and back_left==0 and enemies.is_empty():
		stage = 6
		stage_time = 0.0
		office_wait = 4.0
		flags.gate = false
		for id: int in draggers.keys(): release(id)
		for id: int in session.team:
			session.team[id].hp = MAX_HP
			session.reward(id,"refill")
		return
	if stage==8 and school!=null and not flags.has("story"):
		for id in living:
			if session.is_bot(id): continue
			var v: Vector3 = session.team[id].pos-Street.ORIGIN
			if v.z>466.0 and v.x>18.0 and v.x<38.0:
				flags.story = 0
				story_wait = _page_time(0)
				print("INTERIOR_COOP_SCHOOL story")
				break
	_story_tick(delta)
	_guard_tick(delta)
	if stage>=10 and stage<16: _school_tick(delta,living)
	elif stage>=16 and stage<HOSPITAL:
		if escape!=null and not bool(flags.get("bridge_out",false)): escape._move_people(delta)
		_outer_tick(delta,living)
		# 0.68: across the bridge, the board up: on into the hospital once everyone is ready.
		if bool(flags.get("bridge_out",false)) and board_all_ready(): start_hospital()
	elif stage==HOSPITAL and hospital!=null:
		hospital.host_tick(self,delta,living)
	var hunting := 0
	for z in enemies.values():
		if not z.asleep: hunting += 1
	var cap: int = maxi(8,session.team.size()*5)
	next_spawn -= delta
	threat = maxf(0,threat-delta)
	pressure = move_toward(pressure,0,delta*.06)
	if stage>=4:
		for i in street.doors.size():
			var at: Vector3 = street.doors[i].global_position+Vector3(-2 if i%2==0 else 2,0,0)
			var closest := nearest(at)
			if stage==4 and closest and not awake_houses.has(i) and at.distance_to(session.team[closest].pos)<13 and hunting<cap-1:
				awake_houses[i] = true
				spawn(at,true)
				if rng.randf()<.45: spawn(at+Vector3(0,0,1.2),true)
	# The last stand's second front: the service alley behind the store, and its door.
	if stage==5 and back_left>0 and stage_time>breach_at-14.0:
		back_wait -= delta
		if back_wait<=0.0:
			back_wait = 1.3
			var z = spawn(ground(_in_rect(Street.BACK_SPAWN)))
			if z!=null:
				z.back = true
				back_left -= 1
				_back_fails = 0
			else:
				_back_fails += 1
				if _back_fails>=8:
					_back_fails = 0
					back_left -= 1
	if next_spawn<=0 and hunting<cap:
		var p: Dictionary = session.team[living.pick_random()]
		if stage==4 and pursuit_anchor in living: p = session.team[pursuit_anchor]
		var outside: bool = Vector2(p.pos.x,p.pos.z).length()>12
		if (stage<4 and outside) or wave_left>0:
			if spawn_near(p):
				if stage>=4: wave_left -= 1
				_spawn_fails = 0
				next_spawn = (.45 if stage==5 else 1.1) if stage>=4 else lerpf(2.5,8.5,clampf(pressure,0,1))
			else:
				next_spawn = .55
				# (0.49: nowhere to put one for ~6 s: it is let go, or the wave never ends.)
				_spawn_fails += 1
				if stage>=4 and wave_left>0 and _spawn_fails>=11:
					_spawn_fails = 0
					wave_left -= 1
	underfoot.clear()
	var dead: Array = corpses+victims
	for c in dead:
		if is_instance_valid(c): underfoot.append(c.where())
	var keys := enemies.keys()
	var door_at := Street.ORIGIN+Street.BACK_DOOR
	for j in keys.size():
		var z = enemies[keys[j]]
		if z.hp<=0 or z.has_meta("boss"): continue
		if z.asleep:
			z.idle(delta)
			continue
		var id := nearest(z.position)
		if not id: continue
		var target: Vector3 = session.team[id].pos
		var attacks_guide: bool = stage==1 and z.position.distance_to(guide.position)<z.position.distance_to(target)
		if attacks_guide: target = guide.position
		var at_door := false
		if z.back and not flags.get("backdoor",false):
			# 0.47: everyone crowding the shut back door is at the door, not at a player. (Before 0.47 only those
			# within 1.15 m hammered; the ones just behind were within attack reach of the door spot, and each of
			# their "attacks" was charged to the player nearest the door, through the wall: the squad in the
			# stockroom doorway was torn apart by infected outside that nobody could see, and the door never gave.)
			target = door_at+Vector3(0,0,.75)
			at_door = true
			var off := Vector2(z.position.x-target.x,z.position.z-target.z).length()
			if off<1.6:
				_hammer(z,delta,off<1.15)
				continue
		if stage==5 and (z.stalled>6 or z.position.y<Street.ORIGIN.y-3):
			var recovered := ground(_in_rect(Street.BACK_SPAWN if z.back and not flags.get("backdoor",false) else Street.FRONT_SPAWN))
			if recovered.is_finite():
				z.position = recovered
				z.path.clear()
				z.stalled = 0
		if z.position.distance_to(target)>(140 if stage>=16 else (80 if stage>=10 else 50)) and stage!=5:
			enemies.erase(keys[j])
			z.queue_free()
			continue
		if z.position.distance_to(target)<7: threat = 3.0
		var aim: Vector3 = target
		var crawling := false
		if stage==HOSPITAL and hospital!=null:
			aim = hospital.steer(z.position,target,flags)
		elif stage>=16 and outer_street!=null:
			aim = outer_street.steer(z.position,target,flags)
		elif school!=null and stage>=8:
			aim = school.steer(z.position,target)
			# 0.51: the maintenance ladder (climbed by hand) and the duct (on hands and knees).
			if school.carry(z,aim,delta):
				z.pose("walk_hurt")
				continue
			crawling = school.squeeze(z)
		var struck: bool = z.chase(delta,aim,nav,j==Engine.get_physics_frames()%maxi(keys.size(),1),underfoot,aim==target)
		if crawling and z.stun<=0.0: z.pose("crawl")
		if struck:
			if at_door: pass
			elif harmless or session.harmless: blocked_hits += 1
			elif attacks_guide: guide_hp = maxi(0,guide_hp-6)
			elif z.position.distance_to(session.team[id].pos)>1.75: pass   # 0.47: only the one it is at
			else:
				var hurt := mini(maxi(3,9-3*int(z.arms_lost)),int(session.team[id].hp))
				if log_hits: hit_log.append([id,z.back,flags.get("backdoor",false),z.position.distance_to(session.team[id].pos)])
				if log_hits: print("INTERIOR_COOP_HIT id %d hp %d z %s back %s at %s d %.2f stage %d" % [id,int(session.team[id].hp),(z.position-Street.ORIGIN).snapped(Vector3.ONE*.01),z.back,(target-Street.ORIGIN).snapped(Vector3.ONE*.01),z.position.distance_to(target),stage])
				session.team[id].hp -= hurt
				session.team[id].hurt += hurt
				pressure += .35
				session.hurt(id,hurt)

## 0.49 (host): once the last of the waves is in, what is left must be reachable. Those still at the shut back door
## break it in (4 s after nobody is left inside to fight); any others that stay out of the mart for 15 s (stuck,
## asleep, wandered off) are let go. Logs the siege every 10 s (`INTERIOR_COOP_SIEGE`).
func _mop_up(delta: float) -> void:
	_stage_log -= delta
	var inside := 0
	var at_back := 0
	var away := 0
	for z in enemies.values():
		if not is_instance_valid(z) or z.hp<=0 or z.dead: continue
		var v: Vector3 = z.position-Street.ORIGIN
		if z.back and not flags.get("backdoor",false): at_back += 1
		elif not z.asleep and absf(v.x)<10.0 and v.z>54.0 and v.z<82.0 and absf(v.y)<3.0: inside += 1
		else: away += 1
	if _stage_log<=0.0:
		_stage_log = 10.0
		print("INTERIOR_COOP_SIEGE wave_left %d back_left %d enemies %d inside %d at_back %d away %d door %.0f" % [wave_left,back_left,enemies.size(),inside,at_back,away,street.back_door_hp])
	if wave_left>0 or back_left>0 or enemies.is_empty():
		_mop_wait = 0.0
		return
	if inside>0:
		_mop_wait = 0.0
		return
	_mop_wait += delta
	if at_back>0 and not flags.get("backdoor",false) and _mop_wait>4.0:
		street.back_door_hp = 0.0
		flags.backdoor = true
		street.sync(flags)
		nav.forget_box(AABB(Street.ORIGIN+Street.BACK_DOOR-Vector3(1.6,0,1.6),Vector3(3.2,2.6,3.2)))
		say("The back door gives way!",5)
		_mop_wait = 0.0
		return
	if at_back==0 and _mop_wait>15.0:
		for k in enemies.keys():
			var z = enemies[k]
			# (A dead one still listed is a body: it stays where it fell, it just stops counting.)
			if is_instance_valid(z) and z.hp>0 and not z.dead: z.queue_free()
			enemies.erase(k)
		print("INTERIOR_COOP_SIEGE stragglers let go")
		_mop_wait = 0.0

## At the back door: shoulder and fists until it gives. A table pushed up against it inside holds it much longer.
func _hammer(z, delta: float, front := true) -> void:
	z.rotation.y = lerp_angle(z.rotation.y,0.0,1.0-exp(-8*delta))
	z.velocity = Vector3.ZERO
	z.bash_wait -= delta
	z.pose("wall_impact" if z.bash_wait>.55 else "dual_heavy")
	if z.bash_wait>0.0: return
	z.bash_wait = randf_range(1.1,1.8)
	var braced := 1.0
	var inside := Street.ORIGIN+Street.BACK_DOOR+Vector3(0,0,-.9)
	for t in street.tables:
		if Vector2(t.global_position.x-inside.x,t.global_position.z-inside.z).length()<1.3: braced = .28
	# (The ones behind the front rank shove the crowd into it: they count for less.)
	street.back_door_hp -= randf_range(4.0,7.0)*braced*(1.0 if front else .3)
	flags.backhits = int(flags.get("backhits",0))+1
	threat = 3.0
	if street.back_door_hp<=0.0:
		flags.backdoor = true
		street.sync(flags)
		nav.forget_box(AABB(Street.ORIGIN+Street.BACK_DOOR-Vector3(1.6,0,1.6),Vector3(3.2,2.6,3.2)))

func render(delta: float) -> void:
	street.sync(flags)
	if bool(flags.get("heavy_clean",false)) and not _heavy_cleaned: clean_before_heavy()
	var volume := -9.0 if threat>0 and stage<OVER else -45.0
	music.volume_db = move_toward(music.volume_db,volume,delta*15)
	if volume>-40 and not music.playing: music.play()
	if music.volume_db<=-44 and music.playing: music.stop()
	for k in drop_nodes.keys():
		if not drops.has(k):
			drop_nodes[k].queue_free()
			drop_nodes.erase(k)
	for k in drops:
		if drop_nodes.has(k): continue
		if str(drops[k][1]).begins_with("weapon:"):
			drop_nodes[k] = _lay_weapon(str(drops[k][1]).trim_prefix("weapon:"),drops[k][0],float(k%17)*.37)
			Shine.apply(drop_nodes[k])
			continue
		var node := Node3D.new()
		node.position = drops[k][0]+Vector3.UP*.14
		add_child(node)
		var med: bool = str(drops[k][1]).begins_with("healthkit")
		# 0.48: small, medium and large: a pouch, the kit, a trauma case.
		var k_size := drop_size(str(drops[k][1]))
		var grow: float = {"small":.68,"medium":1.0,"large":1.4}[k_size]
		node.scale = Vector3.ONE*grow
		street.piece(node,Vector3.ZERO,Vector3(.31,.17,.22),("#ddd8b8" if k_size!="large" else "#c9c4a4") if med else ("#7a803c" if k_size!="large" else "#5d6331"))
		if med:
			street.piece(node,Vector3.UP*.09,Vector3(.15,.012,.046),"#b23529")
			street.piece(node,Vector3.UP*.091,Vector3(.05,.014,.14),"#b23529")
			if k_size=="large": street.piece(node,Vector3(0,.0,-.112),Vector3(.32,.03,.012),"#b23529")
		elif k_size!="small":
			street.piece(node,Vector3(0,.09,0),Vector3(.12,.012,.08),"#c9b25a")
		# 0.58: everything that can be picked up shines white (scripts/pickup_shine.gdshader).
		Shine.apply(node)
		drop_nodes[k] = node
	_kick_the_dead(delta)
	_grenades_lying()
	if not road_unloaded and bool(flags.get("road_shut",false)): _unload_road()
	_unload_tick()
	if not front_shut and flags.get("locked",false): shut_front()
	if flags.get("board",false) and not ahead_awake: wake_ahead()
	if stage>=8 and stage<OVER and not ahead_awake: wake_ahead()
	# (0.55: a debug teleport ahead of the run, into the backstreets or the college, wakes them early on every peer.)
	if flags.get("woken",false) and not ahead_awake: wake_ahead()
	if not cleaned and stage>=8 and stage<OVER and _all_out_back(): _leave_behind()
	if school!=null and stage<16 and not bool(flags.get("pilcst_out",false)):
		var viewer: Vector3 = session.main.player.global_position if session.main.get("player")!=null else Street.ORIGIN
		school.sync(flags,delta,viewer)
		_hide_far(delta)
		rommel.visible = true
		if flags.get("school_shut",false) and not school_unloaded:
			school_unloaded = true
			_soft_unload(Street.ORIGIN+Vector3(-16,-30,470),Street.ORIGIN+KEEP_HI,"backstreets",[],true)
	elif school!=null and bool(flags.get("outer_sealed_behind",false)):
		school._rear_gate_sync(flags,delta)
	if escape!=null: escape.render(delta)
	if bool(flags.get("outer_built",false)) and outer_street==null and not bool(flags.get("bridge_out",false)): build_outer_street()
	if outer_street!=null and not bool(flags.get("bridge_out",false)): outer_street.sync(flags,delta,session.main.player.global_position if session.main.get("player")!=null else Vector3.INF)
	# 0.68: across the bridge Ma'am Teves and her students are gone; the hospital once it is built.
	if bool(flags.get("bridge_out",false)) and escape!=null and not escape.people.is_empty():
		for f in escape.people:
			if is_instance_valid(f): f.queue_free()
		escape.people.clear()
	if bool(flags.get("hosp_built",false)) and hospital==null: build_hospital()
	if hospital!=null: hospital.sync(flags,delta,session.main.player.global_position if session.main.get("player")!=null else Vector3.INF)

## 0.51 (every peer): the infected and the dead on floors the school is not drawing (`school.shown`: the viewer's
## floor and the ones next to it) are not drawn either: there is a floor slab or two between. Nothing else about
## them changes (their bodies, their physics, the host's moving them).
var _hide_wait := 0.0
func _hide_far(delta: float) -> void:
	_hide_wait -= delta
	if _hide_wait>0.0: return
	_hide_wait = .15
	for list in [enemies.values(),corpses,victims]:
		for fig in list:
			if not is_instance_valid(fig): continue
			var at: Vector3 = fig.where() if fig.dead else fig.position
			# (Only those inside the school's walls: what was put away with the backstreets stays put away, and the
			# yard and the fire escape are seen from everywhere.)
			var zf: int = school.floor_of(at)
			if zf<0: continue
			var on: bool = school.draws_floor(zf)
			if fig.visible!=on: fig.visible = on

## 0.46: a dropped weapon on the ground: its own model, lying on its side.
const WEAPON_LENGTH := {"pistol":.2,"rifle":.92,"shotgun":1.0,"sniper":1.15}
func _lay_weapon(which: String, at: Vector3, yaw: float) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = at
	holder.rotation.y = yaw
	var cls := InteriorArsenal.class_of(which)
	var scene: PackedScene = {"pistol":InteriorGun.GLOCK,"rifle":InteriorGun.RIFLE,"shotgun":InteriorGun.SHOTGUN,"sniper":InteriorGun.SNIPER}.get(cls,InteriorGun.GLOCK)
	var own := InteriorArsenal.model_path(which)
	if own!="" and ResourceLoader.exists(own): scene = load(own) as PackedScene
	var real_length: float = {"pistol":.22,"rifle":.92,"shotgun":1.0,"sniper":1.2}.get(cls,.5)
	var gun := scene.instantiate() as Node3D
	holder.add_child(gun)
	var box := _bounds(gun,gun.global_transform.affine_inverse())
	if box.size.length()<.001: return holder
	var size := box.size
	# The thinnest side down.
	if size.x<=size.y and size.x<=size.z: gun.rotation = Vector3(0,0,PI*.5)
	elif size.z<=size.y and size.z<=size.x: gun.rotation = Vector3(PI*.5,0,0)
	var longest := maxf(size.x,maxf(size.y,size.z))
	gun.scale = Vector3.ONE*(real_length/longest if own=="" else 1.0)
	var placed := _bounds(gun,holder.global_transform.affine_inverse())
	gun.position -= Vector3(placed.get_center().x,placed.position.y-.01,placed.get_center().z)
	return holder

func _bounds(node: Node3D, to_local: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*","MeshInstance3D",true,false):
		var mesh := m as MeshInstance3D
		if mesh.mesh==null: continue
		var b: AABB = (to_local*mesh.global_transform)*mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

## 0.46: the grenades still lying where they were left (every peer, from the flags).
func _grenades_lying() -> void:
	for i in GRENADE_SPOTS.size():
		var taken: bool = flags.get("nade%d"%i,false)
		if taken:
			if nade_nodes.has(i):
				nade_nodes[i].queue_free()
				nade_nodes.erase(i)
			continue
		if nade_nodes.has(i): continue
		var at: Vector3 = Street.ORIGIN+(GRENADE_SPOTS[i] as Vector3)
		var floor_at := ground(at)
		if not floor_at.is_finite(): floor_at = at
		if _nade_scene==null: _nade_scene = load("res://assets/grenade/frag_grenade.glb")
		var node := Node3D.new()
		add_child(node)
		node.position = floor_at+Vector3.UP*.005
		node.rotation.y = float(i)*1.7
		# An olive ammo pouch under it, so it reads in the dark.
		street.piece(node,Vector3(0,.025,0),Vector3(.2,.05,.13),"#3d4428")
		for k in 2:
			var g := _nade_scene.instantiate() as Node3D
			node.add_child(g)
			g.position = Vector3(-.045+k*.09,.085,0)
			g.rotation = Vector3(0,k*1.2,PI*.5)
		Shine.apply(node)
		nade_nodes[i] = node

## 0.46: every survivor still up is through the service gate and into the backstreets.
func _all_out_back() -> bool:
	if not flags.get("alley",false): return false
	var any := false
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if session.is_bot(id) or int(p.hp)<=0: continue
		any = true
		if float(p.pos.z)-Street.ORIGIN.z<Street.ALLEY_GATE.z+5.0: return false
	return any

## 0.66 (owner: "make the game focus on the current mission and unload the old ones/finished ones ... close the paths
## to the old maps just to unload them"): chapter one ends at the Old Salmonan gate. Once every survivor (on their
## feet or down) is ROAD_SEAL_Z past it on Store Road, it slides shut behind them (host: `flags.road_shut`; the pack
## that follows is already on this side: `spawn_near`), and on every peer the home, the town, the canal and the warren
## are put away (`_unload_road`): hidden, silent, their dead freed, their meshes let go of. Only Store Road with the
## ramp's landing behind the gate, and what lies ahead, stay.
const ROAD_SEAL_Z := 11.0
const ROAD_KEEP_LO := Vector3(-45, -30, -30)
const ROAD_KEEP_HI := Vector3(48, 60, 140)
var road_unloaded := false
func _road_seal_check() -> void:
	if stage!=4 or bool(flags.get("road_shut",false)): return
	var any := false
	for id: int in session.team:
		if session.is_bot(id): continue
		any = true
		if float(session.team[id].pos.z)-Street.ORIGIN.z<ROAD_SEAL_Z: return
	if not any: return
	flags.road_shut = true
	flags.gate = false
	nav.forget_box(AABB(Street.ORIGIN+Street.GATE-Vector3(6,1,2),Vector3(12,5,4)))
	print("INTERIOR_COOP_ROAD shut behind the squad")

func _unload_road() -> void:
	if road_unloaded: return
	road_unloaded = true
	var t := Time.get_ticks_usec()
	_soft_unload(Street.ORIGIN+ROAD_KEEP_LO,Street.ORIGIN+ROAD_KEEP_HI,"chapter one",[AABB(Street.ORIGIN+KEEP_LO,KEEP_HI-KEEP_LO)],true)
	print("INTERIOR_COOP_ROAD putting chapter one away (%.1f ms to start)" % [(Time.get_ticks_usec()-t)/1000.0])

## 0.46 (every peer): the mart is done with and the team is in the backstreets: the solo world, the canal, Store
## Road and the ramp are put away (hidden, their bodies and processing switched off), the bodies left back there are
## freed, and the infected that were back there are dropped. Only the backstreets (KEEP_LO..KEEP_HI) stay.
func _leave_behind() -> void:
	cleaned = true
	_soft_unload(Street.ORIGIN+KEEP_LO,Street.ORIGIN+KEEP_HI,"behind",[],true)

## 0.55: the boxes `_soft_unload` kept (world): a place outside any of them has been put away behind the run.
## (0.66: each unload keeps a set of boxes; a place is put away when it is outside every box of some set.)
var kept: Array = []

## 0.49: what `_leave_behind` did, for any box: everything drawn wholly outside `lo..hi` is hidden and stops
## processing, the dead outside are freed and so are the infected (host).
## 0.66: `sliced` (during play): the walk over the world and the letting go of what it hid run as a job a little each
## frame (`_unload_tick`, UNLOAD_BUDGET_MS) instead of all at once (chapter one in one go was a 70 ms frame). The
## bodies, Dodong and the infected outside are dealt with at once (cheap). At a chapter's board (behind its screen)
## it still runs in one go.
const UNLOAD_BUDGET_MS := 2.0
var _unload_jobs: Array = []
func _soft_unload(lo: Vector3, hi: Vector3, label: String, also: Array = [], sliced := false) -> void:
	var keep := AABB(lo,hi-lo)
	var keeps: Array[AABB] = [keep]
	for b: AABB in also: keeps.append(b)
	kept.append(keeps)
	var hidden := [0]
	var roots: Array = []
	if session.main.get("room")!=null and session.main.room!=null: roots.append(session.main.room)
	# The world's own pieces under the game (not the player, the infected's blood, grenades, the air, the lens).
	var spared: Array = [session.main.player,session.main.get("room")]
	for key in ["zombies","grenades","atmosphere_particles","bodycam","menu_street"]:
		if session.main.get(key)!=null: spared.append(session.main.get(key))
	for child in session.main.get_children():
		if child is Node3D and not child in spared and not child.is_ancestor_of(session.main.player):
			roots.append(child)
	roots.append(street)
	if sliced:
		var stack: Array = []
		for r in roots: stack.append([r,0])
		_unload_jobs.append({"stack":stack,"keeps":keeps,"hidden":hidden,"label":label,"t":0.0,"frames":0})
	else:
		for r in roots: _prune(r,keeps,hidden,0)
	# The bodies back on Store Road, at the ramp and on the far bank.
	for list in [victims,corpses]:
		for i in range(list.size()-1,-1,-1):
			var v = list[i]
			if is_instance_valid(v) and not _in_keeps(keeps,v.where(),4.0):
				v.queue_free()
				list.remove_at(i)
	if not _in_keeps(keeps,guide.global_position,2.0):
		guide.visible = false
		guide.process_mode = Node.PROCESS_MODE_DISABLED
	if session.main.get("zombies")!=null and session.main.zombies!=null and session.main.zombies.has_method("kill_all"):
		for z in session.main.zombies.alive(): z.queue_free()
	if multiplayer.is_server():
		for k in enemies.keys():
			if not _in_keeps(keeps,enemies[k].global_position,6.0):
				enemies[k].queue_free()
				enemies.erase(k)
	if not sliced: print("INTERIOR_COOP_CLEANUP %s hidden %d nodes, bodies left %d" % [label,hidden[0],victims.size()+corpses.size()])

## 0.66 (every peer, each frame): the sliced unloads' walk, then their letting go (`free_unloaded`'s work), within
## UNLOAD_BUDGET_MS a frame. The same nodes hidden and the same meshes let go of as in one go, a few frames later.
var _free_stack: Array = []
var _free_count := 0
func _unload_tick() -> void:
	if _unload_jobs.is_empty() and _free_stack.is_empty(): return
	var t0 := Time.get_ticks_usec()
	var budget := UNLOAD_BUDGET_MS*1000.0
	while not _unload_jobs.is_empty() and Time.get_ticks_usec()-t0<budget:
		var job: Dictionary = _unload_jobs[0]
		var stack: Array = job.stack
		while not stack.is_empty() and Time.get_ticks_usec()-t0<budget:
			var item: Array = stack.pop_back()
			_prune_one(item[0],job.keeps,job.hidden,int(item[1]),stack)
		job.frames = int(job.frames)+1
		if stack.is_empty():
			_unload_jobs.pop_front()
			print("INTERIOR_COOP_CLEANUP %s hidden %d nodes over %d frames, bodies left %d" % [job.label,job.hidden[0],job.frames,victims.size()+corpses.size()])
			# What it hid is let go of next, a little each frame too.
			for n in unloaded: _free_stack.append(n)
			unloaded.clear()
	while _unload_jobs.is_empty() and not _free_stack.is_empty() and Time.get_ticks_usec()-t0<budget:
		var c = _free_stack.pop_back()
		if not is_instance_valid(c): continue
		_free_count += _let_go(c)
		if c is CharacterBody3D or c is Skeleton3D: continue
		for k in c.get_children(): _free_stack.append(k)
		if _free_stack.is_empty():
			print("INTERIOR_COOP_UNLOAD let go of %d meshes (sliced)" % _free_count)
			_free_count = 0

## Is a sliced unload still under way?
func unloading() -> bool: return not _unload_jobs.is_empty() or not _free_stack.is_empty()

## One node of `_prune`'s walk: hidden whole when its drawn things are clear of every kept box, otherwise its
## children are queued (to depth 6).
func _prune_one(node: Node, keeps: Array, hidden: Array, depth: int, stack: Array) -> void:
	if not is_instance_valid(node) or not node is Node3D or node is DirectionalLight3D or node is WorldEnvironment or node is Camera3D: return
	# 0.68: what a later chapter built (the hospital, its people) is never put away by an earlier chapter's unload still
	# walking the scene: it has its own seals.
	if node.has_meta("never_prune"): return
	var n := node as Node3D
	if not n.visible: return
	var box := _world_box(n)
	if box.size==Vector3.ZERO and depth>0: return
	var touches := false
	for k: AABB in keeps:
		if box.intersects(k): touches = true
	if box.size!=Vector3.ZERO and not touches:
		if _holds_moon(n): return
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
		hidden[0] += 1
		unloaded.append(n)
		return
	if depth>6: return
	for c in n.get_children(): stack.append([c,depth+1])

## What `free_unloaded` does to one node (not its children): its mesh and material dropped, its particles stopped.
func _let_go(c: Node) -> int:
	if c is MeshInstance3D:
		if (c as MeshInstance3D).mesh!=null:
			(c as MeshInstance3D).mesh = null
			(c as MeshInstance3D).material_override = null
			return 1
	elif c is MultiMeshInstance3D:
		if (c as MultiMeshInstance3D).multimesh!=null:
			(c as MultiMeshInstance3D).multimesh = null
			return 1
	elif c is GPUParticles3D: (c as GPUParticles3D).emitting = false
	return 0

static func _in_keeps(keeps: Array, at: Vector3, margin: float) -> bool:
	for b: AABB in keeps:
		if b.grow(margin).has_point(at): return true
	return false

func _prune(node: Node, keeps: Array, hidden: Array, depth: int) -> void:
	if not node is Node3D or node is DirectionalLight3D or node is WorldEnvironment or node is Camera3D: return
	if node.has_meta("never_prune"): return
	var n := node as Node3D
	if not n.visible: return
	var box := _world_box(n)
	if box.size==Vector3.ZERO and depth>0: return
	var touches := false
	for k: AABB in keeps:
		if box.intersects(k): touches = true
	if box.size!=Vector3.ZERO and not touches:
		if _holds_moon(n): return
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
		hidden[0] += 1
		unloaded.append(n)
		return
	if depth>6: return
	for c in n.get_children(): _prune(c,keeps,hidden,depth+1)

## 0.53: what `_soft_unload` hid, let go of for real at a chapter's board (session.gd): the meshes and their
## materials dropped (the GPU's copies go with them), the particles stopped. The nodes stay (code may hold them; their
## colliders keep the ground under the dead).
var unloaded: Array = []
func free_unloaded() -> int:
	var freed := 0
	# (0.66: a sliced unload still under way is finished first, here, in one go.)
	while not _unload_jobs.is_empty():
		var job: Dictionary = _unload_jobs.pop_front()
		var st: Array = job.stack
		while not st.is_empty():
			var item: Array = st.pop_back()
			_prune_one(item[0],job.keeps,job.hidden,int(item[1]),st)
	for n in _free_stack: unloaded.append(n)
	_free_stack.clear()
	for n in unloaded:
		if not is_instance_valid(n): continue
		var stack: Array = [n]
		while not stack.is_empty():
			var c = stack.pop_back()
			freed += _let_go(c)
			# (A figure keeps its own: the dead are freed whole elsewhere.)
			if c is CharacterBody3D or c is Skeleton3D: continue
			for k in c.get_children(): stack.append(k)
	unloaded.clear()
	print("INTERIOR_COOP_UNLOAD let go of %d meshes" % freed)
	return freed

## 0.53: what the next chapter brings (loaded at the mart's board): the college's students, staff and parents,
## Ma'am Teves and her students, Rommel, and Heavy-arm with his clips.
func chapter_assets() -> Array:
	var out: Array = []
	for i in range(STUDENT_FIRST,INFECTED.size()): out.append("res://assets/characters/zombies/z_%s.glb"%INFECTED[i])
	for i in PARENTS: out.append("res://assets/characters/zombies/z_%s.glb"%INFECTED[i])
	for who in ["teves","bea","paolo","jerome","trisha"]: out.append("res://assets/characters/survivors/pilcst_%s.glb"%who)
	out.append("res://assets/characters/survivors/school_guard.glb")
	out.append(HEAVY_BODY.ASSET)
	out.append(HEAVY_BODY.CLIPS_ASSET)
	return out

func _holds_moon(n: Node) -> bool:
	return not n.find_children("*","DirectionalLight3D",true,false).is_empty() or not n.find_children("*","WorldEnvironment",true,false).is_empty()

## Where a node's drawn things are (world): its visual instances merged.
func _world_box(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	var seen := 0
	while not stack.is_empty() and seen<4000:
		var c = stack.pop_back()
		seen += 1
		if c is VisualInstance3D and not c is DirectionalLight3D:
			var b: AABB = (c as VisualInstance3D).global_transform*(c as VisualInstance3D).get_aabb()
			if b.size!=Vector3.ZERO:
				out = b if first else out.merge(b)
				first = false
		for k in c.get_children(): stack.append(k)
	if seen>=4000:
		# Too big to measure piece by piece: never hidden whole (its children are looked at instead).
		return AABB(Vector3(-1e5,-1e5,-1e5),Vector3(2e5,2e5,2e5))
	return out

## 0.46 (host): a weapon put down (G held): it lies where it was dropped, with whatever was in and with it.
func put_down(id: int, which: String, ammo: Array) -> void:
	if not session.team.has(id) or InteriorArsenal.class_of(which)=="" or ammo.size()<3: return
	which = InteriorArsenal.resolve(which)
	var p: Dictionary = session.team[id]
	var forward := Vector3(-sin(float(p.yaw)),0,-cos(float(p.yaw)))
	var at := ground(p.pos+forward*.85)
	if not at.is_finite(): at = ground(p.pos)
	if not at.is_finite(): at = p.pos
	next_drop += 1
	drops[next_drop] = [at,"weapon:"+which,[clampi(int(ammo[0]),0,64),bool(ammo[1]),clampi(int(ammo[2]),0,999)]]

## 0.48: "healthkit:large" -> "large" (a plain "ammo" or "healthkit" is a medium one).
static func drop_size(kind: String) -> String:
	var size := kind.get_slice(":",1) if ":" in kind else "medium"
	return size if size in ["small","medium","large"] else "medium"

func _roll_size(small: float, medium: float) -> String:
	var r := rng.randf()
	return "small" if r<small else ("medium" if r<small+medium else "large")

## A healthkit of `size` into the survivor's pack (`kits` counts them, `kit_sizes` says which).
static func add_kit(p: Dictionary, size: String) -> void:
	var sizes: Array = p.get("kit_sizes",[])
	while sizes.size()<int(p.kits): sizes.append("medium")
	sizes.append(size)
	p.kit_sizes = sizes
	p.kits = int(p.kits)+1

## The kit used to make up `missing` HP: the smallest that covers it, else the largest. Returns its size.
static func take_kit(p: Dictionary, missing: int) -> String:
	var sizes: Array = p.get("kit_sizes",[])
	while sizes.size()<int(p.kits): sizes.append("medium")
	while sizes.size()>int(p.kits): sizes.pop_back()
	if sizes.is_empty():
		p.kits = 0
		return "medium"
	var pick := -1
	for i in sizes.size():
		var top := int((InteriorArsenal.KITS[sizes[i]] as Array)[1])
		if top>=missing and (pick<0 or top<int((InteriorArsenal.KITS[sizes[pick]] as Array)[1])): pick = i
	if pick<0:
		for i in sizes.size():
			if pick<0 or int((InteriorArsenal.KITS[sizes[i]] as Array)[1])>int((InteriorArsenal.KITS[sizes[pick]] as Array)[1]): pick = i
	var size: String = sizes[pick]
	sizes.remove_at(pick)
	p.kit_sizes = sizes
	p.kits = sizes.size()
	return size

## 0.48 (host): the waypoint graph grows round the living, and the map is scattered as it does.
func _waypoints_tick(delta: float) -> void:
	if nav.waypoints==null: nav.waypoints = InteriorWaypoints.new(nav)
	_way_wait -= delta
	if _way_wait<=0.0:
		_way_wait = .5
		var at: Array = []
		for id: int in session.team:
			if int(session.team[id].hp)>0: at.append(session.team[id].pos)
		nav.waypoints.seed_around(at)
	# (0.56: every other tick, 700 µs: one node costs ~.55 ms (rays, links), so the budget always ran over, and the
	# graph filling in round a player who had just arrived (8000 points in the college) was 2.5-4 ms of every tick for
	# twenty seconds. It fills in over about forty now.)
	if Engine.get_physics_frames()%2==0: nav.waypoints.grow(700)
	_seed_wait -= delta
	if _seed_wait<=0.0 and stage<OVER:
		_seed_wait = 2.5
		_scatter()

## Every 22 m square the graph has filled in, joined to the players, gets its roll once: a weapon (most squares),
## an ammunition box, a healthkit, each somewhere a body can walk to.
func _scatter() -> void:
	var anchor := Vector3.INF
	var living: Array[Vector3] = []
	for id: int in session.team:
		if int(session.team[id].hp)>0:
			living.append(session.team[id].pos)
			if not anchor.is_finite(): anchor = session.team[id].pos
	if not anchor.is_finite(): return
	var ids: PackedInt32Array = nav.waypoints.joined(anchor)
	var counts := {}
	for id: int in ids:
		var p: Vector3 = nav.waypoints.nodes[id][0]
		var key := Vector2i(floori(p.x/BUCKET),floori(p.z/BUCKET))
		counts[key] = int(counts.get(key,0))+1
	for key: Vector2i in counts:
		if _seeded.has(key) or int(counts[key])<14: continue
		var centre := Vector3((key.x+.5)*BUCKET,0,(key.y+.5)*BUCKET)
		# Only a square the graph has finished (well inside what is built round a player).
		var inside := false
		for at: Vector3 in living:
			if Vector2(at.x-centre.x,at.z-centre.z).length()<InteriorWaypoints.RADIUS-BUCKET: inside = true
		if not inside: continue
		_seeded[key] = true
		var spots: Array[Vector3] = nav.waypoints.reachable_in(ids,Vector2(key.x*BUCKET,key.y*BUCKET),Vector2((key.x+1)*BUCKET,(key.y+1)*BUCKET))
		if spots.size()<4: continue
		var rolls: Array = []
		if rng.randf()<.6: rolls.append("weapon")
		if rng.randf()<.45: rolls.append("ammo")
		if rng.randf()<.3: rolls.append("healthkit")
		for what: String in rolls:
			for attempt in 8:
				var at: Vector3 = spots[rng.randi_range(0,spots.size()-1)]
				if not _clear_spot(at,living): continue
				var floor_at := ground(at+Vector3.UP*.3)
				if not floor_at.is_finite(): continue
				next_drop += 1
				if what=="weapon":
					var wid := InteriorArsenal.pick(rng)
					var size := int(InteriorArsenal.stats(wid).get("mag",int(InteriorGun.PROFILES[InteriorArsenal.class_of(wid)].mag)))
					drops[next_drop] = [floor_at,"weapon:"+wid,[size,true,size*rng.randi_range(1,3)]]
				else:
					drops[next_drop] = [floor_at,what+":"+_roll_size(.5,.35)]
				break

## Not on top of another drop, and out of sight of where the players stand (it is there before they come).
func _clear_spot(at: Vector3, living: Array[Vector3]) -> bool:
	for k in drops:
		if (drops[k][0] as Vector3).distance_to(at)<2.6: return false
	for p: Vector3 in living:
		if p.distance_to(at)<10.0: return false
	return true

## 0.48 (host): T: both hands into whatever is close in front. The infected reel (or go down), the ones behind
## them catch the stumble, tables and loose things slide away.
func shove(id: int) -> void:
	if not session.team.has(id) or int(session.team[id].hp)<=0: return
	var now := Time.get_ticks_msec()*.001
	if now<float(_shove_ready.get(id,0.0)): return
	_shove_ready[id] = now+1.0
	var p: Dictionary = session.team[id]
	var forward := Vector3(-sin(float(p.yaw)),0,-cos(float(p.yaw)))
	var from: Vector3 = p.pos
	var struck: Array = []
	for k: int in enemies:
		var z = enemies[k]
		if z==null or not is_instance_valid(z) or not z.alive(): continue
		var to: Vector3 = z.position-from
		var rise := absf(to.y)
		to.y = 0.0
		if to.length()>SHOVE_REACH or rise>1.3: continue
		if to.length()>.35 and to.normalized().dot(forward)<.35: continue
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from+Vector3.UP*1.0,z.position+Vector3.UP*1.0,2)).is_empty(): continue
		struck.append(z)
	# 0.49: two hands push one body: the nearest in front.
	struck.sort_custom(func(a,b): return a.position.distance_squared_to(from)<b.position.distance_squared_to(from))
	if struck.size()>1: struck.resize(1)
	var hit := {}
	for z in struck:
		_stumble(z,forward,1.0,hit)
	# One stumbling back into another right behind it only jostles that one.
	for z in struck:
		for k: int in enemies:
			var other = enemies[k]
			if other==null or not is_instance_valid(other) or not other.alive() or hit.has(other): continue
			var gap: Vector3 = other.position-z.position
			gap.y = 0.0
			if gap.length()<.75 and (gap.length()<.3 or gap.normalized().dot(forward)>.2):
				_stumble(other,(forward+gap.normalized()*.4).normalized(),.3,hit)
	# Tables and loose things.
	var space := get_world_3d().direct_space_state
	var reach := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = .85
	reach.shape = ball
	reach.collision_mask = 4|32
	reach.transform = Transform3D(Basis.IDENTITY,from+forward*1.0+Vector3.UP*.8)
	var pushed := 0
	# (0.61: 24, was 8: a doorway jammed with school chairs is a dozen bodies, and T moved a few of them a little.)
	for found in space.intersect_shape(reach,24):
		var body := found.collider as RigidBody3D
		if body==null or body.freeze: continue
		body.sleeping = false
		var mass := maxf(body.mass,1.0)
		if body.collision_layer&32 and body.has_meta("coop_prop"):
			# 0.61: a school chair (6.5 kg) is flung clear, about 6 m/s along the shove and 2 m/s up, so a heap in a
			# doorway comes apart. (1.6 m/s, as for a table, only nudged it against the chairs behind.)
			body.apply_impulse(forward*mass*6.0+Vector3.UP*mass*2.0,body.to_global(body.center_of_mass)-body.global_position)
			if school!=null: school.props.woke(int(body.get_meta("coop_prop")))
			pushed += 1
			continue
		# 0.49: what two arms put into it (about 45 N s at most): a box skids, a table shifts, a rack barely moves.
		body.apply_impulse(forward*minf(mass*1.6,45.0)+Vector3.UP*clampf(mass*.08,0.0,3.0),Vector3(0,.35,0))
		pushed += 1
	if not struck.is_empty() or pushed>0: threat = maxf(threat,1.0)

func _stumble(z, way: Vector3, strength: float, hit: Dictionary) -> void:
	hit[z] = true
	if z.asleep: _wake(z)
	# 0.49: a real shove: one step back (about 0.3 m), a short stagger. It only goes over if it was already
	# reeling when the hands met it (and not always then).
	var reeling: bool = z.stun>.25
	z.knock_back(way,90.0*strength)
	z.shove = (z.shove+Vector3(way.x,0,way.z).normalized()*1.1*strength).limit_length(2.0)
	if reeling and strength>=.95 and randf()<.2:
		z.stun = 1.8
		z.stun_clip = "knockdown"
	else:
		z.stun = maxf(z.stun,.35+.3*strength)
		z.stun_clip = "stagger_heavy" if strength>=.95 and randf()<.25 else "stagger_small"
	z.vault_time = -1.0

## 0.44 (host): after the last wave Jonna opens the office door and calls them in; when someone speaks to her she
## goes back to her place against the wall and tells them what she knows; then the backstreets.
func office(delta: float) -> void:
	if stage==6:
		if not flags.get("office",false):
			office_wait -= delta
			if office_wait<=0.0:
				flags.office = true
				say("Jonna\nPssst! Hoy! Here, the office! Quick, before more of them come!",12)
		jonna.visible = flags.get("office",false)
		return
	if stage!=7: return
	if int(flags.get("lockup",0))>0:
		lockup(delta)
		return
	var path: Array[Vector3] = [Street.ORIGIN+BackOffice.DOORWAY+Vector3(0,0,.5),Street.ORIGIN+Vector3(3.3,0,71.9),Street.ORIGIN+BackOffice.SEAT]
	if jonna_step<path.size():
		var dest: Vector3 = path[jonna_step]
		var dir: Vector3 = dest-jonna.position
		dir.y = 0.0
		if dir.length()<.08:
			jonna_step += 1
			if jonna_step==path.size():
				jonna.position = Street.ORIGIN+BackOffice.SEAT
				jonna.rotation.y = 0.0
				jonna.pose("sit_hurt")
		else:
			jonna.position = jonna.position.move_toward(dest,delta*.75)
			jonna.rotation.y = atan2(-dir.x,-dir.z)
			jonna.pose("walk_hurt")
	talk_wait -= delta
	if talk_wait>0.0: return
	talk_index += 1
	if talk_index>=TALK.size():
		_start_lockup()
		return
	var line: Array = TALK[talk_index]
	var who: String = line[0]
	if who=="{P}":
		var slot: int = int(session.team[talker].slot) if session.team.has(talker) else 0
		who = session.NAMES[slot % session.NAMES.size()]
	var text: String = line[1]
	say(who+"\n"+text,60)
	talk_wait = clampf(2.6+text.length()*.062,4.5,13.0)

## 0.44 (host): out the back. Jonna hands over the service gate's key; the infected wait along the backstreets.
func backstreets() -> void:
	wake_ahead()
	flags.board = false
	if int(flags.get("lockup",0))>0: flags.lockup = 5
	stage = 8
	stage_time = 0.0
	flags.alley_key = true
	say("Jonna\nTake it. The service gate key. Lock my door behind you. Go.",10)
	var spots: Array = Street.BACKSTREETS.SPOTS.duplicate()
	for i in range(spots.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var count := clampi(9+session.team.size()*2,10,spots.size())
	for i in count:
		var spot: Vector3 = spots[i]
		later(func() -> void:
			var z = spawn(ground(Street.ORIGIN+spot+Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))),true)
			if z==null: return
			z.idle_mode = "wander" if rng.randf()<.55 else "sleep"
			z.home = z.position
			z.rotation.y = rng.randf_range(-PI,PI)
			z.wander_wait = rng.randf_range(0,4))
	wave_left = 6+2*session.team.size()
	next_spawn = 30.0

## 0.49 (host): Jonna gets up, walks out to the front and pulls the shutter down, then padlocks it.
func _start_lockup() -> void:
	flags.lockup = 1
	flags.shutter = 0.0
	say("Jonna\nWait. Let me shut the front first. The light draws them.",9)
	var out: Array[Vector3] = [Street.ORIGIN+Vector3(3.3,0,71.9),Street.ORIGIN+BackOffice.DOORWAY+Vector3(0,0,.5),Street.ORIGIN+BackOffice.DOORWAY+Vector3(0,0,-1.2)]
	var from: Vector3 = out[-1]
	var to: Vector3 = Street.ORIGIN+FRONT_SPOT
	var way := PackedVector3Array()
	if nav!=null:
		nav.space = get_world_3d().direct_space_state
		way = nav.path(from,to)
	_jonna_route = out
	for p in way: _jonna_route.append(Vector3(p.x,Street.ORIGIN.y,p.z))
	if way.is_empty():
		_jonna_route.append(Street.ORIGIN+Vector3(3.4,0,64.6))
		_jonna_route.append(Street.ORIGIN+Vector3(.35,0,59.0))
	_jonna_route.append(to)
	jonna_step = 0

## Jonna along `_jonna_route`; true once she is at its end.
func _jonna_walk(delta: float, speed: float) -> bool:
	while jonna_step<_jonna_route.size():
		var dest: Vector3 = _jonna_route[jonna_step]
		var dir: Vector3 = dest-jonna.position
		dir.y = 0.0
		if dir.length()<.08:
			jonna_step += 1
			continue
		jonna.position = jonna.position.move_toward(Vector3(dest.x,jonna.position.y,dest.z),delta*speed)
		jonna.rotation.y = atan2(-dir.x,-dir.z)
		jonna.pose("walk_hurt")
		return false
	return true

func lockup(delta: float) -> void:
	var phase := int(flags.get("lockup",0))
	if phase==1:
		if _jonna_walk(delta,1.05):
			jonna.rotation.y = 0.0
			jonna.pose("idle_hurt")
			flags.lockup = 2
	elif phase==2:
		flags.shutter = minf(1.0,float(flags.get("shutter",0.0))+delta/SHUTTER_TIME)
		jonna.pose("idle_hurt")
		if float(flags.shutter)>=1.0:
			flags.lockup = 3
			_lock_wait = 1.3
	elif phase==3:
		_lock_wait -= delta
		if _lock_wait<=0.0:
			flags.locked = true
			flags.lockup = 4
			say("Jonna\nThere. Nothing comes through that now.",7)
			# Back to her place against the office wall while they catch their breath.
			_jonna_route = []
			_jonna_route.append(Street.ORIGIN+Vector3(.35,0,59.0))
			_jonna_route.append(Street.ORIGIN+Vector3(3.4,0,64.6))
			_jonna_route.append(Street.ORIGIN+BackOffice.DOORWAY+Vector3(0,0,-1.2))
			_jonna_route.append(Street.ORIGIN+BackOffice.DOORWAY+Vector3(0,0,.5))
			_jonna_route.append(Street.ORIGIN+Vector3(3.3,0,71.9))
			_jonna_route.append(Street.ORIGIN+BackOffice.SEAT)
			jonna_step = 0
			for id: int in session.team: session.team[id].next_ready = session.is_bot(id)
			flags.board = true
	elif phase==4:
		if _jonna_walk(delta,.85): _jonna_seated()
		if board_all_ready(): _board_done()

func _jonna_seated() -> void:
	jonna.position = Street.ORIGIN+BackOffice.SEAT
	jonna.rotation.y = 0.0
	jonna.pose("sit_hurt")

## 0.49: every survivor (the squad AI are always ready) has pressed READY on the chapter's board.
func board_all_ready() -> bool:
	if not flags.get("board",false): return false
	for id: int in session.team:
		if not session.is_bot(id) and not bool(session.team[id].get("next_ready",false)): return false
	return true

func _board_done() -> void:
	_jonna_seated()
	backstreets()

## 0.49 (every peer): the shutter is down and locked: the street outside, the ramp, the far bank, the canal and
## the solo world are put away; only the mart and what lies ahead of it stay.
func shut_front() -> void:
	if front_shut: return
	front_shut = true
	_soft_unload(Street.ORIGIN+Vector3(-16,-30,STORE_FRONT_Z),Street.ORIGIN+KEEP_HI,"front")
const STORE_FRONT_Z := 55.6

## 0.49 (every peer): the backstreets as built, put away until the run gets there (they cost nothing to draw or to
## hear meanwhile). Their colliders stay: the dead lying there are ragdolls and keep their ground.
func _put_ahead_away() -> void:
	var bs: Node3D = street.backstreets
	if bs==null: return
	var first := Street.STORE_DEAD.size()+Street.APPROACH.DEAD.size()
	for i in range(victims.size()):
		var v = victims[i]
		# (The four VICTIMS come first, then the store's, the approach's and the backstreets' dead.)
		if i>=VICTIMS.size()+first and is_instance_valid(v):
			_ahead_dead.append(v)
			v.visible = false
	bs.visible = false
	# (A sound that does not process is held where it is: silent until woken.)
	for a in bs.find_children("*","AudioStreamPlayer3D",true,false): (a as Node).process_mode = Node.PROCESS_MODE_DISABLED

func wake_ahead() -> void:
	if ahead_awake: return
	ahead_awake = true
	var bs: Node3D = street.backstreets
	if bs==null: return
	bs.visible = true
	for a in bs.find_children("*","AudioStreamPlayer3D",true,false): (a as Node).process_mode = Node.PROCESS_MODE_INHERIT
	for v in _ahead_dead:
		if is_instance_valid(v): v.visible = true
	print("INTERIOR_COOP_AHEAD woke the backstreets")
	_build_school()

## 0.50 (every peer): the college at the end of the backstreets, its dead, Rommel at the gate.
func _build_school() -> void:
	if school!=null: return
	school = SCHOOL.new()
	street.add_child(school)
	school.build(street)
	school.props.session = session
	for i in SCHOOL.DEAD.size():
		var spec: Array = SCHOOL.DEAD[i]
		var v := Figure.new()
		add_child(v)
		v.key = -300-i
		v.session = session
		v.setup("res://assets/characters/zombies/z_%s.glb"%INFECTED[STUDENT_FIRST+int(spec[1])],Street.ORIGIN+(spec[0] as Vector3),"",true)
		v.rotation.y = float(spec[2])
		var clip: String = spec[3]
		v.clips.play(clip)
		v.clips.seek(v.clips.get_animation(clip).length*float(spec[4]),true)
		v.go_limp(spec[5] as Vector3)
		victims.append(v)
	rommel.visible = true
	rommel.position = Street.ORIGIN+SCHOOL.GUARD_SEAT
	rommel.pose("sit_hurt")
	escape = ESCAPE.new()
	add_child(escape)
	escape.setup(self)

func _page_time(page: int) -> float:
	return clampf(4.0+str(STORY[page]).length()/30.0,8.0,15.0)

## 0.50 (host): the story's pages turn by themselves (or on E); after the last, Rommel calls out.
func _story_tick(delta: float) -> void:
	if not flags.has("story") or int(flags.story)>=STORY.size(): return
	story_wait -= delta
	if story_wait>0.0: return
	flags.story = int(flags.story)+1
	if int(flags.story)<STORY.size():
		story_wait = _page_time(int(flags.story))
		return
	if stage==8:
		stage = 9
		stage_time = 0.0
		say("Rommel\nHoy... hoy! Over here, by the gate! Don't shoot... I'm not one of them!",12)

## 0.50 (host): Rommel's account, line by line; then he opens the gate.
func _guard_tick(delta: float) -> void:
	if stage!=9 or not flags.get("guard_talk",false): return
	talk_wait -= delta
	if talk_wait>0.0: return
	talk_index += 1
	if talk_index>=GUARD_TALK.size():
		open_school()
		return
	var line: Array = GUARD_TALK[talk_index]
	var who: String = line[0]
	if who=="{P}":
		var slot: int = int(session.team[talker].slot) if session.team.has(talker) else 0
		who = session.NAMES[slot % session.NAMES.size()]
	var text: String = line[1]
	say(who+"\n"+text,60)
	talk_wait = clampf(2.6+text.length()*.062,4.5,13.0)

## 0.50 (host): the gate slides open; the yard has a few of them in it; the school begins.
func open_school() -> void:
	flags.school_gate = true
	flags.guard_talk = false
	stage = 10
	stage_time = 0.0
	school_wait = 14.0
	nav.forget_box(AABB(Street.ORIGIN+SCHOOL.GATE-Vector3(5.5,0,1.6),Vector3(9.0,3.0,3.2)))
	say("Rommel\nIt's open. The main doors are at the end of the covered walk. Fifth floor, west side. Go!",10)
	print("INTERIOR_COOP_SCHOOL gate open")
	for i in 3+mini(session.team.size(),3):
		var at := ground(Street.ORIGIN+Vector3(rng.randf_range(6,50),0,rng.randf_range(505,512)))
		var z = spawn(at,true,true)
		if z==null: continue
		z.idle_mode = "wander"
		z.home = z.position
		z.rotation.y = rng.randf_range(-PI,PI)
		z.wander_wait = rng.randf_range(0,4)

## 0.50 (host): inside the school. A floor reached for the first time has its own lying about, and (above the
## ground) a rush down the corridor from the far end; all the while more come out of the rooms near whoever is
## inside, and they keep coming. Once every survivor is through the gate Rommel shuts it behind them.
func _school_tick(delta: float, living: Array) -> void:
	if school==null: return
	var humans := 0
	var in_yard := 0
	# (Every survivor, down or not: the gate is not shut on someone crawling in.)
	for id: int in session.team:
		if session.is_bot(id): continue
		humans += 1
		var pos: Vector3 = session.team[id].pos
		if (pos-Street.ORIGIN).z>503.0 and school.in_grounds(pos): in_yard += 1
		if int(session.team[id].hp)<=0: continue
		var f: int = school.floor_of(pos)
		if f>=0 and not flags.get("floor%d"%f,false):
			flags["floor%d"%f] = true
			_populate(f)
			if f>0: _rush(f)
			print("INTERIOR_COOP_SCHOOL floor %d reached" % (f+1))
			if f==1: say("Both stairs up are piled with desks. Someone wrote on the wall: FIRE EXIT, EAST END.",8)
			if f==3:
				say("Both stairs are blocked again. A note says the janitor's ladder goes up.",8)
				_kuya_boy()
			if f==4: say("Somewhere down this corridor someone is knocking. Three times, then nothing.",8)
	if not flags.get("school_shut",false) and humans>0 and in_yard==humans and stage_time>2.0:
		flags.school_shut = true
		session.gather_bots(Street.ORIGIN+SCHOOL.ENTRANCE+Vector3(0,0,-4))
		say("Rommel\nI've got the gate. Go! Don't wait for me!",7)
	_doors_tick(delta)
	_school_cleanup(delta)
	# 0.52: from 501 on the way out runs things (the horde, the field); the rooms only send more on the second
	# floor after the blast.
	if stage>=11 and escape!=null: escape.tick(delta,living)
	if stage!=10 and stage!=14: return
	school_wait -= delta
	if school_wait>0.0: return
	var hunting := 0
	for z in enemies.values():
		if is_instance_valid(z) and not z.asleep and not z.dead: hunting += 1
	var cap: int = 10+4*session.team.size()
	if _alive_count()>=SCHOOL_CEILING: return
	school_wait = rng.randf_range(2.4,4.6)*(1.0 if session.team.size()>1 else 1.35)
	if hunting>=cap or living.is_empty(): return
	var p: Dictionary = session.team[living.pick_random()]
	var f: int = maxi(school.floor_of(p.pos),0)
	var spots: Array = school.spawn_points[f]
	var space := get_world_3d().direct_space_state
	for attempt in 8:
		var pick := rng.randi()%spots.size()
		# (0.51: not out of a room whose door is still shut.)
		if school.door_shut(int(school.spawn_doors[f][pick])): continue
		var at: Vector3 = Street.ORIGIN+(spots[pick] as Vector3)
		var d: float = at.distance_to(p.pos)
		if d<9.0 or d>34.0: continue
		var close := nearest(at,true)
		if close and at.distance_to(session.team[close].pos)<7.0: continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.4,p.pos+Vector3.UP*1.4,2)).is_empty(): continue
		var z = spawn(ground(at),false,true)
		if z!=null:
			threat = 3.0
			break

## Kuya Boy went up his own ladder and did not come down: he is in the mechanical room, feeding (once: the fourth floor
## first reached, or a debug jump to the ladder or the duct).
func _kuya_boy() -> void:
	if flags.get("kuya",false): return
	flags.kuya = true
	var boy = spawn(ground(Street.ORIGIN+Vector3(33.4,SCHOOL.H*4,529.6)),true,true,JANITOR_FIRST)
	if boy!=null:
		boy.idle_mode = "feed"
		boy.home = boy.position

func _populate(f: int) -> void:
	if f>0: _class_in_session(f)
	var spots: Array = school.sleep_spots[f].duplicate()
	for i in range(spots.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var n := clampi(7+2*session.team.size(),8,spots.size())
	n = mini(n,maxi(SCHOOL_CEILING-_alive_count(),0))
	for i in n:
		var spot: Vector3 = spots[i]
		later(func() -> void:
			var at := ground(Street.ORIGIN+spot+Vector3(rng.randf_range(-.6,.6),0,rng.randf_range(-.6,.6)))
			var z = spawn(at,true,true)
			if z==null: return
			var roll := rng.randf()
			z.idle_mode = "wander" if roll<.5 else ("sleep" if roll<.85 else "feed")
			z.home = z.position
			z.rotation.y = rng.randf_range(-PI,PI)
			z.wander_wait = rng.randf_range(0,4))

## 0.63 (every peer, once; the owner, for frame rate): the moment the squad faces Heavy-arm (heavyarm.gd sets
## `flags.heavy_clean` when he spots them), the night's old mess is put away: the dead and the posed dead, the blood,
## the torn-off parts, everywhere but within CLEAN_KEEP of someone on their feet (what they are fighting now stays).
## The host also lets go of the infected still inside the school building, away from everyone.
const CLEAN_KEEP := 20.0
var _heavy_cleaned := false
func clean_before_heavy() -> void:
	if _heavy_cleaned: return
	_heavy_cleaned = true
	var keep: Array = []
	for id: int in session.team:
		if int(session.team[id].hp)>0: keep.append(session.team[id].pos)
	var bodies := 0
	for list in [corpses,victims]:
		for i in range(list.size()-1,-1,-1):
			var v = list[i]
			if is_instance_valid(v):
				var at: Vector3 = v.where()
				var near := false
				for k: Vector3 in keep:
					if at.distance_to(k)<CLEAN_KEEP: near = true
				if near: continue
				v.queue_free()
				bodies += 1
			list.remove_at(i)
	var blood = session.blood()
	var spilled: int = blood.clear_away(keep,CLEAN_KEEP) if blood!=null and blood.has_method("clear_away") else 0
	var inside := 0
	if multiplayer.is_server():
		for k in enemies.keys():
			var z = enemies[k]
			if not is_instance_valid(z) or z.has_meta("boss"): continue
			var l: Vector3 = z.position-Street.ORIGIN
			if l.z>534.5 and l.y<2.0: continue
			var near := false
			for p: Vector3 in keep:
				if z.position.distance_to(p)<25.0: near = true
			if near: continue
			z.queue_free()
			enemies.erase(k)
			inside += 1
	print("INTERIOR_COOP_HEAVY clean: %d bodies, %d blood and parts, %d infected inside the school" % [bodies,spilled,inside])

## 0.63 (host): the fifth floor's mechanical room door forced open from inside. It bursts out into the corridor (school.gd
## `_mech_sync` on every peer); the bang wakes the sleepers on the fifth floor near it.
func _force_mech_door() -> void:
	if school==null or bool(flags.get("mechdoor",false)): return
	flags.mechdoor = true
	var at: Vector3 = Street.ORIGIN+Vector3(school.mech_door_x,SCHOOL.H*4,524.4)
	nav.forget_box(AABB(at-Vector3(2.0,.5,2.2),Vector3(4.0,3.0,4.4)))
	threat = 3.0
	for z in enemies.values():
		if not z.asleep or z.has_meta("boss"): continue
		if absf(z.position.y-at.y)>1.6: continue
		var d: float = z.position.distance_to(at)
		if d<20.0: _queue_wake(z,randf_range(.3,.9)+d*.05)
	print("INTERIOR_COOP_SCHOOL mech door forced")

## 0.63 (host + every peer, idempotent): builds Outer Street (only from the chapter board's loading, or a debug jump),
## drops PILCST's temporary street stub so no duplicate street meshes overlap at z=600..616.
func build_outer_street() -> void:
	if outer_street!=null: return
	outer_street = OUTER_STREET.new()
	street.add_child(outer_street)
	outer_street.build(street)
	outer_street.after_build(self)
	if school!=null and school.has_method("drop_rear_stub"): school.drop_rear_stub()
	# 0.67 (host): what the nav read here before the chapter stood (PILCST's stub street) is forgotten now, when the
	# world changes (it was at the chapter's start, which also threw away the ground read behind the board), and the
	# chapter's ground is read in (`premap_outer`).
	if multiplayer.is_server():
		nav.forget_box(AABB(outer_street.world(Vector3(-20,-14,595)),Vector3(130,40,290)))
		premap_outer()

## 0.63 (host): leaves PILCST board into District 01 Outer Street (stage 16).
func start_outer_street() -> void:
	build_outer_street()
	flags.outer_built = true
	flags.board = false
	flags.pilcst_out = false
	flags.outer_sealed_behind = true
	if school!=null and school.has_method("seal_rear_gate"): school.seal_rear_gate()
	for id: int in session.team: session.team[id].next_ready = false
	var min_w: Vector3 = outer_street.world(Vector3(44.0,0.0,603.5))
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if (p.pos-Street.ORIGIN).z<601.5:
			var spot := ground(min_w+Vector3(float(absi(id)%3-1)*1.1,0,rng.randf_range(0.5,2.2)))
			if spot.is_finite():
				if session.is_bot(id) and session.bots!=null and session.bots.bots.has(id):
					session.bots.bots[id].body.global_position = spot
				else:
					session.debug_move_one(id,spot,PI)
	if escape!=null:
		for f in escape.people:
			if is_instance_valid(f) and (f.position-Street.ORIGIN).z<600.8:
				var gp := ground(min_w+Vector3(rng.randf_range(-1.2,1.2),0,rng.randf_range(0.8,2.6)))
				if gp.is_finite(): f.position = gp
	stage = 16
	stage_time = 0.0
	print("INTERIOR_COOP_OUTER start")

## 0.68 (host): across the bridge: Ma'am Teves and her students stay behind, the chapter's board comes up and the
## hospital loads behind it (session.gd's loading steps); everyone READY: `start_hospital`.
func _win_outer_street() -> void:
	if stage>=OVER or bool(flags.get("bridge_out",false)): return
	flags.bridge_out = true
	flags.board = true
	for id: int in session.team: session.team[id].next_ready = session.is_bot(id)
	print("INTERIOR_COOP_OUTER across the bridge, board up")

## (host + every peer, idempotent) Builds the hospital (only from the bridge board's loading, or a debug jump).
func build_hospital() -> void:
	if hospital!=null: return
	hospital = HOSPITAL_SCRIPT.new()
	hospital.set_meta("never_prune", true)
	street.add_child(hospital)
	hospital.build(street)
	hospital.after_build(self)
	if multiplayer.is_server():
		nav.forget_box(AABB(hospital.world(hospital.HO+Vector3(-40,-4,-36)),Vector3(80,24,76)))

## (every peer, behind the bridge's board) Outer Street put away: everything but the hospital's ground hidden, then let
## go of (`free_unloaded`, the next loading step).
func leave_outer_street() -> void:
	if bool(flags.get("outer_left_here",false)): return
	flags.outer_left_here = true
	var lo: Vector3 = Street.ORIGIN+HOSPITAL_SCRIPT.HO+Vector3(-260,-30,-240)
	_soft_unload(lo,lo+Vector3(520,120,520),"outer street")
	if outer_street!=null:
		outer_street.visible = false
		outer_street.process_mode = Node.PROCESS_MODE_DISABLED
		for c in outer_street.get_children(): _free_stack.append(c)

## (host, a loading step behind the bridge's board) The hospital's floors read into the nav's map.
func premap_hospital() -> bool:
	if not multiplayer.is_server(): return true
	if not bool(flags.get("hosp_premapped",false)):
		flags.hosp_premapped = true
		var o: Vector3 = HOSPITAL_SCRIPT.HO
		map_ahead(o.x-30.0,o.x+30.0,o.z-30.0,o.z+1.0,0.0)
		for y in [0.0,HOSPITAL_SCRIPT.F2,HOSPITAL_SCRIPT.F3]: map_ahead(o.x-24.0,o.x+24.0,o.z,o.z+36.0,y)
	if not _ahead_spans.is_empty(): premap_step(10000)
	return _ahead_spans.is_empty()

## 0.68: what the hospital brings (loaded behind the bridge's board): its staff and patients, the living at the
## ambulances, Doctor Berido, Doctor Lucky and his clips.
func hospital_assets() -> Array:
	var out: Array = []
	for i in range(LAB_FIRST,INFECTED.size()): out.append("res://assets/characters/zombies/z_%s.glb" % INFECTED[i])
	for k in ["berido","doctor_m","doctor_f","nurse_f","nurse_m","police_1","police_2"]: out.append("res://assets/characters/survivors/hosp_%s.glb" % k)
	out.append(LUCKY_BODY.ASSET)
	out.append(LUCKY_BODY.CLIPS_ASSET)
	return out

## 0.68 (host): everyone READY on the bridge's board: the squad outside the hospital (stage 18).
func start_hospital() -> void:
	build_hospital()
	flags.hosp_built = true
	flags.board = false
	for id: int in session.team: session.team[id].next_ready = false
	for k in enemies.keys():
		if is_instance_valid(enemies[k]) and not enemies[k].has_meta("boss"): enemies[k].queue_free()
		enemies.erase(k)
	var base: Vector3 = hospital.world(hospital.HO+hospital.SPAWN)
	var i := 0
	for id: int in session.team:
		var spot := ground(base+Vector3(float(i%4)*1.2-1.8,.5,-float(i/4)*1.4))
		if not spot.is_finite(): spot = base
		if session.is_bot(id) and session.bots!=null and session.bots.bots.has(id):
			session.bots.bots[id].body.global_position = spot
		else:
			session.debug_move_one(id,spot,PI)
		i += 1
	stage = HOSPITAL
	stage_time = 0.0
	threat = 0.0
	say("",0.0)
	print("INTERIOR_COOP_HOSPITAL start")

func _win_hospital() -> void:
	if stage>=OVER: return
	stage = WON
	say("The flare is up over the hospital.",12)
	print("INTERIOR_COOP_HOSPITAL won")

## 0.68: the boss fight under way (Heavy-arm's at PILCST's rear gate, or Doctor Lucky's in the laboratory).
func boss_fight():
	if hospital!=null and hospital.lucky!=null: return hospital.lucky
	if escape!=null and escape.fight!=null: return escape.fight
	return null

func _outer_tick(delta: float, living: Array) -> void:
	if outer_street==null or stage<16 or stage>=HOSPITAL or bool(flags.get("bridge_out",false)): return
	outer_street.host_tick(self,delta,living)

## 0.51 (host): a class still standing in one of the floor's rooms: in rows at their armchairs, facing the board,
## not moving; their teacher at the front, facing them. They turn when they notice anyone.
func _class_in_session(f: int) -> void:
	var rooms: Array = school.class_rooms[f]
	if rooms.is_empty() or _alive_count()>SCHOOL_CEILING-8: return
	var room: Array = rooms[rng.randi()%rooms.size()]
	var x0: float = room[0]
	var x1: float = room[1]
	var z0: float = room[2]
	var z1: float = room[3]
	var y: float = f*SCHOOL.H
	var n := clampi(4+session.team.size(),5,8)
	var made := 0
	var x := x0+2.9
	while x<x1-.8 and made<n:
		var z := z0+1.3
		while z<z1-1.0 and made<n:
			if rng.randf()<.7:
				var at := ground(Street.ORIGIN+Vector3(x+rng.randf_range(-.15,.15),y,z+rng.randf_range(-.15,.15)))
				var kind := STUDENT_FIRST+rng.randi_range(0,9)
				var turn := PI*.5+rng.randf_range(-.12,.12)
				later(func() -> void:
					var st = spawn(at,true,false,kind)
					if st!=null:
						st.idle_mode = "sleep"
						st.home = st.position
						st.rotation.y = turn)
				made += 1
			z += 1.76
		x += 2.0
	var t_at := ground(Street.ORIGIN+Vector3(x0+1.0,y,(z0+z1)*.5))
	var t_kind := TEACHER_FIRST+rng.randi_range(0,5)
	later(func() -> void:
		var teacher = spawn(t_at,true,false,t_kind)
		if teacher!=null:
			teacher.idle_mode = "sleep"
			teacher.home = teacher.position
			teacher.rotation.y = -PI*.5)
	print("INTERIOR_COOP_SCHOOL class of %d standing on floor %d" % [made,f+1])

func _alive_count() -> int:
	var n := 0
	for z in enemies.values():
		if is_instance_valid(z) and not z.dead and z.hp>0: n += 1
	return n

## 0.51 (host): the shut doors. A group of classrooms pounds from inside when a survivor comes near (`flags.pound`, a
## bit a door), then the doors give one after another (`flags.broke`) and the classes inside pour out. The scare doors
## only pound, for a few seconds, once.
var _door_wait := 0.0
var _bursts: Array = []
var _pound_end := {}
func _doors_tick(delta: float) -> void:
	if school==null or school.doors.is_empty(): return
	var now := stage_time
	for i in range(_bursts.size()-1,-1,-1):
		if now>=float(_bursts[i][0]):
			var d: int = _bursts[i][1]
			_bursts.remove_at(i)
			_burst(d)
	for d: int in _pound_end.keys():
		if now>=float(_pound_end[d]):
			_pound_end.erase(d)
			flags.pound = int(flags.get("pound",0)) & ~(1<<d)
	_door_wait -= delta
	if _door_wait>0.0: return
	_door_wait = .25
	var fired: int = int(flags.get("fired",0))
	for i in school.doors.size():
		if fired & (1<<i): continue
		var d: Dictionary = school.doors[i]
		var spot: Vector3 = Street.ORIGIN+Vector3(float(d.x),int(d.k)*SCHOOL.H,523.5)
		var reach := 9.5 if d.kind=="ambush" else 4.5
		var near := false
		for id: int in session.team:
			var p: Dictionary = session.team[id]
			if int(p.hp)<=0 or session.is_bot(id): continue
			if absf(p.pos.y-spot.y)<1.4 and Vector2(p.pos.x-spot.x,p.pos.z-spot.z).length()<reach: near = true
		if not near: continue
		if d.kind=="scare":
			fired |= 1<<i
			flags.pound = int(flags.get("pound",0)) | (1<<i)
			_pound_end[i] = now+rng.randf_range(2.2,3.4)
			continue
		# The whole group goes: pounding, then one door after another.
		var at := now+rng.randf_range(1.4,2.2)
		for j: int in school.groups[int(d.group)]:
			if fired & (1<<j): continue
			fired |= 1<<j
			flags.pound = int(flags.get("pound",0)) | (1<<j)
			_bursts.append([at,j])
			at += rng.randf_range(.7,1.5)
		threat = 3.0
		print("INTERIOR_COOP_SCHOOL doors pounding group %d" % int(d.group))
	flags.fired = fired

func _burst(i: int) -> void:
	flags.pound = int(flags.get("pound",0)) & ~(1<<i)
	flags.broke = int(flags.get("broke",0)) | (1<<i)
	nav.forget_box(school.door_box(i))
	var room_left := SCHOOL_CEILING+6-_alive_count()
	var n := clampi(2+(session.team.size()+1)/2,2,4)
	n = mini(n,maxi(room_left,1))
	var made := 0
	for at: Vector3 in school.behind(i,n):
		var z = spawn(ground(at),false,true)
		if z==null: continue
		z.stun = rng.randf_range(.1,.5)
		z.stun_clip = "alert"
		made += 1
	threat = 3.0
	print("INTERIOR_COOP_SCHOOL door %s broke, %d out" % [school.doors[i].room,made])

## 0.51 (host): every 3 s, those that cannot matter any more are let go: hunting or not, two floors or more from every
## survivor (and the asleep a floor below everyone, the squad gone on past them), or stuck far from anyone for long.
## The dead stay (their bodies are the solo game's MAX_CORPSES ragdolls and are never cut); the doors and the
## blood stay. Logs `INTERIOR_COOP_SCHOOL cleanup`.
var _clean_wait := 3.0
func _school_cleanup(delta: float) -> void:
	_clean_wait -= delta
	if _clean_wait>0.0: return
	_clean_wait = 3.0
	var floors: Array = []
	var where: Array = []
	for id: int in session.team:
		var p: Dictionary = session.team[id]
		if int(p.hp)<=0: continue
		floors.append(maxi(school.floor_of(p.pos),0) if school.in_grounds(p.pos) else -1)
		where.append(p.pos)
	if floors.is_empty(): return
	var lowest: int = floors.min()
	var let_go := 0
	for k in enemies.keys():
		var z = enemies[k]
		if not is_instance_valid(z) or z.dead or z.hp<=0 or z.has_meta("boss"): continue
		var zf: int = maxi(int(roundf((z.position.y-Street.ORIGIN.y)/SCHOOL.H)),0)
		var gap := 99
		var close := 999.0
		for i in floors.size():
			gap = mini(gap,absi(zf-int(floors[i])) if int(floors[i])>=0 else zf)
			close = minf(close,z.position.distance_to(where[i]))
		var drop := gap>=2 and close>14.0
		if z.asleep and zf<lowest and close>16.0: drop = true
		if not z.asleep and z.stalled>8.0 and close>24.0: drop = true
		if drop:
			enemies.erase(k)
			z.queue_free()
			let_go += 1
	if let_go>0: print("INTERIOR_COOP_SCHOOL cleanup let go %d, %d left" % [let_go,enemies.size()])

func _rush(f: int) -> void:
	var n := clampi(5+2*session.team.size(),6,14)
	n = mini(n,maxi(SCHOOL_CEILING-_alive_count(),2))
	var made := 0
	for at: Vector3 in school.rush_points(f):
		if made>=n: break
		var z = spawn(ground(Street.ORIGIN+at),false,true)
		if z!=null: made += 1
	threat = 3.0
	print("INTERIOR_COOP_SCHOOL rush %d on floor %d" % [made,f+1])

## 0.50 (host): three knocks on 501. They open only when nothing is hunting close by.
func knock(id: int) -> void:
	var door := Street.ORIGIN+SCHOOL.DOOR_501
	for z in enemies.values():
		if is_instance_valid(z) and not z.asleep and not z.dead and z.position.distance_to(door)<14.0:
			session.personal(id,"Nobody opens. Not with them this close: clear the corridor first.")
			return
	# (0.52: nor while a door down the hall is still being beaten from inside.)
	if int(flags.get("pound",0))!=0 or not _bursts.is_empty():
		session.personal(id,"Nobody opens. Something is still beating on a door down the hall.")
		return
	# 0.52: the door opens on Ma'am Teves and four students, and the night goes on (escape.gd).
	print("INTERIOR_COOP_SCHOOL survivors found")
	escape.knocked(id)

## Every peer: feet that walk into the dead move them (a shin knocked aside, an arm dragged a little).
func _kick_the_dead(delta: float) -> void:
	kick_wait -= delta
	if kick_wait>0.0: return
	kick_wait = .1
	var dead: Array = corpses+victims
	if dead.is_empty(): return
	for z in enemies.values():
		if z.dead: continue
		var moving_by: Vector3 = z._seen_velocity
		if Vector2(moving_by.x,moving_by.z).length()<.6: continue
		var feet: Vector3 = z.global_position+Vector3.UP*.15
		for c in dead:
			if not is_instance_valid(c) or c.where().distance_squared_to(feet)>2.2: continue
			for body: PhysicalBone3D in c.bodies.values():
				if not is_instance_valid(body) or body.global_position.distance_to(feet)>.42: continue
				var push := Vector3(moving_by.x,0,moving_by.z).limit_length(3.0)*body.mass*.25+Vector3.UP*body.mass*.35
				body.apply_central_impulse(push)
				break

# ---------------------------------------------------------------- 0.49: debug missions (0.55: every checkpoint settled)

## Where `debug_jump` can put the squad: [stage it runs at, street-local spot or "" for one worked out, yaw (0 faces
## -Z, PI faces +Z), what it is, how it is left]. Jumps go forward only (what is behind is put away as the run moves on).
## 0.55: every objective before the place's stage is done the way play does it (`debug_complete`), and the rest of
## what a run that got there has behind it is settled (`_settle`). How it is left:
##   fresh    the stage as it begins in play: its own sleepers, waves and opening line. Otherwise the place is partway
##            through: what is behind the spot is done with (its infected gone, its line said).
##   outback  out of the mart's back door and through the service gate (Jonna's key).
##   floors   how many of PILCST's floors were crossed on the way up: reached (their bells rung long ago), their
##            sleepers and rushes behind, their shut classes met. A floor not among them is reached on arrival, as in
##            play (its sleepers, a class, a rush down the corridor).
##   kuya     Kuya Boy feeding in the mechanical room (he goes up there when the fourth floor is first reached).
##   heavy    how far the rear gate's fight went: "down" Heavy-arm dead, his key where he fell; "open" the key taken
##            and the gate unlocked; "out" through it, the chapter's board up.
##   line     what was last said stays up (it says where things stand).
const JUMPS := {
	"dodong": [0, "", 0.0, "Dodong outside the courtyard gate, before he speaks", {"fresh": true}],
	"escort": [1, "", 0.0, "walking Dodong home", {"fresh": true}],
	"keys": [2, "", 0.0, "Dodong's house, the gate keys beside the candle", {"fresh": true}],
	"ramp": [3, Vector3(11.6, Street.APPROACH.G, -5.2), PI * .5, "the floodwall ramp, keys in hand", {}],
	"gate": [3, Vector3(1.8, 0, -2.3), PI, "at the Old Salmonan gate, keys in hand", {}],
	"storeroad": [4, Vector3(0, 0, 3.5), PI, "through the gate, at the foot of Store Road (a pack following)", {"fresh": true}],
	"mart": [4, Vector3(0, 0, 51.5), PI, "in front of Olivar Family Mart", {}],
	"siege": [5, Vector3(0, 0, 61.0), 0.0, "inside the mart, the siege starting", {"fresh": true}],
	"office": [6, Vector3(4.1, 0, 66.4), PI, "the siege over, Jonna calling from the office", {"fresh": true}],
	"jonna": [7, Vector3(3.6, 0, 71.0), PI, "in the office, Jonna talking", {"fresh": true}],
	"board": [7, Vector3(.6, 0, 61.0), 0.0, "the front locked, the chapter board up", {}],
	"backdoor": [8, Vector3(-6.0, 0, 72.3), PI, "the service gate's key in hand, at the mart's back door", {"fresh": true}],
	"backstreets": [8, Vector3(-2.0, 0, 84.0), PI, "through the service gate, the backstreets", {"outback": true}],
	"arcade": [8, Vector3(43.0, 0, 190.0), PI, "the Avenida arcade, halfway along the backstreets", {"outback": true}],
	"brickalley": [8, Vector3(28.0, 0, 452.0), PI, "the brick alley, before the college", {"outback": true}],
	"school": [9, Vector3(28.0, 0, 497.6), PI, "the college's back gate, Rommel behind it", {"fresh": true}],
	"lobby": [10, Vector3(28.0, 0, 516.5), PI, "inside PILCST, the lobby (Rommel's gate shut behind)", {"fresh": true, "floors": 0}],
	"floor2": [10, Vector3(28.0, SCHOOL.H, 523.5), PI * .5, "PILCST, the second floor (the fire exit at the east end goes on up)", {"floors": 1}],
	"fireescape": [10, Vector3(57.3, SCHOOL.H, 523.5), PI, "PILCST, on the fire escape's second-floor landing", {"floors": 2}],
	"floor3": [10, Vector3(52.0, SCHOOL.H * 2, 523.5), PI * .5, "PILCST, the third floor (west stairs go on up)", {"floors": 2}],
	"floor4": [10, Vector3(4.0, SCHOOL.H * 3, 523.5), -PI * .5, "PILCST, the fourth floor (the maintenance room's ladder goes on up)", {"floors": 3}],
	"ladder": [10, Vector3(36.0, SCHOOL.H * 3, 532.6), PI, "PILCST, the maintenance room, at the foot of the ladder", {"floors": 4, "kuya": true}],
	"duct": [10, Vector3(36.0, SCHOOL.H * 4, 531.6), PI * .5, "PILCST, the fifth floor's mechanical room, by the duct", {"floors": 4, "kuya": true}],
	"floor5": [10, Vector3(52.0, SCHOOL.H * 4, 523.5), PI * .5, "PILCST, the fifth floor; room 501 is at the west end", {"floors": 4}],
	# 0.52: the way out.
	"teves": [11, Vector3(6.9, SCHOOL.H * 4, 523.6), 0.0, "room 501 open, Ma'am Teves at the door", {"fresh": true}],
	"horde": [12, Vector3(3.6, SCHOOL.H * 4, 517.4), PI, "inside 501, lights off, the horde coming", {"fresh": true}],
	"sneak": [13, Vector3(7.2, SCHOOL.H * 4, 520.0), PI, "inside 501 at its door, the horde standing in the dark corridor; the fire exit at the far end", {"fresh": true}],
	"firedoor": [13, Vector3(53.4, SCHOOL.H * 4, 523.5), -PI * .5, "the fifth floor's fire door, still chained", {}],
	"blast": [14, Vector3(57.3, SCHOOL.H, 523.5), PI * .5, "the fire escape's second-floor landing, after the blast", {"fresh": true}],
	"room208": [14, Vector3(14.8, SCHOOL.H, 523.5), PI, "the second floor, at room 208 (its wall blown out onto the lean-to)", {}],
	"field": [15, Vector3(11.0, 0, 543.5), PI, "the school field, under the lean-to's eave", {"fresh": true}],
	# 0.53: Heavy-arm.
	"heavyarm": [15, Vector3(40.0, 0, 572.0), PI, "the field, Heavy-arm sitting against the shut rear gate", {}],
	"heavykey": [15, Vector3(42.0, 0, 590.0), PI, "Heavy-arm down, the rear gate's key where he fell", {"heavy": "down", "line": true}],
	"reargate": [15, Vector3(44.0, 0, 594.5), PI, "Heavy-arm down, the key taken, the rear gate open", {"heavy": "open", "line": true}],
	"pilcstout": [15, Vector3(44.0, 0, 603.5), PI, "out through the rear gate, the chapter board up", {"heavy": "out"}],
	# 0.63: Outer Street ("outer": the objectives done before it).
	"outerstreet": [16, Vector3(44.0, 0, 603.5), PI, "Outer Street: the lane from PILCST's rear gate", {"fresh": true}],
	"outerbus": [16, Vector3(40.3, 0, 646.5), PI, "Outer Street: the pile-up, at the bus's back door", {"outer": ["outer_avenue"]}],
	"outerplaza": [16, Vector3(40.3, 0, 664.0), PI, "Outer Street: through the bus, the plaza", {"outer": ["outer_avenue", "outer_pileup"]}],
	"outerterrace": [16, Vector3(13.0, 5.0, 672.0), -PI * .5, "Outer Street: the hillside terrace, the hardware store", {"outer": ["outer_avenue", "outer_pileup", "outer_shutter_seen"]}],
	"outerstation": [16, Vector3(33.0, -5.2, 685.0), PI, "Outer Street: the subway concourse, the power off", {"outer": ["outer_avenue", "outer_pileup", "outer_shutter_seen", "outer_cutters", "outer_shutter"]}],
	"outerplatform": [16, Vector3(29.5, -10.2, 714.0), PI, "Outer Street: the platform, the power back", {"outer": ["outer_avenue", "outer_pileup", "outer_shutter_seen", "outer_cutters", "outer_shutter", "outer_power"]}],
	"outertunnel": [16, Vector3(34.6, -11.3, 755.0), PI, "Outer Street: through the train, the tunnel", {"outer": ["outer_avenue", "outer_pileup", "outer_shutter_seen", "outer_cutters", "outer_shutter", "outer_power", "outer_platform", "outer_train"]}],
	"outerriver": [16, Vector3(8.0, 0, 789.0), PI * .5, "Outer Street: up the long stair, the river road", {"outer": ["outer_avenue", "outer_pileup", "outer_shutter_seen", "outer_cutters", "outer_shutter", "outer_power", "outer_platform", "outer_train", "outer_exit", "outer_up"]}],
	# 0.65: Market Row (outer_row.gd) and the long bridge.
	"outermart": [16, Vector3(58.25, .15, 757.6), PI, "Outer Street: the mart's loading door", {"outer": ["outer_avenue", "outer_pileup", "outer_shutter_seen", "outer_cutters", "outer_shutter", "outer_power", "outer_platform", "outer_train", "outer_exit", "outer_up", "outer_pizza", "outer_court", "outer_alley"]}],
	"outerbridge": [17, Vector3(94.0, 0, 797.0), PI, "Outer Street: the long bridge, the row behind", {"fresh": true}],
	# 0.68: the hospital ("hosp": its objectives' flags done before it; spots hospital-local + HOSPITAL_SCRIPT.HO).
	"hospital": [18, HOSPITAL_SCRIPT.HO + Vector3(0, 0, -15.0), PI, "The hospital: outside, the ambulances", {"fresh": true, "hosp": []}],
	"hosplobby": [18, HOSPITAL_SCRIPT.HO + Vector3(0, 0, 5.0), PI, "The hospital: the lobby, the shutters down behind", {"hosp": ["hosp_talked", "hosp_inside"]}],
	"hospstairs": [18, HOSPITAL_SCRIPT.HO + Vector3(-18.5, 0, 33.0), PI, "The hospital: the stairwell at the end of the back corridor", {"hosp": ["hosp_talked", "hosp_inside"], "zones": ["lobby", "hall", "er", "back"]}],
	"hosp2f": [18, HOSPITAL_SCRIPT.HO + Vector3(-12.0, 4.2, 23.3), -PI * .5, "The hospital: the second floor's corridor", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs"]}],
	"berido": [18, HOSPITAL_SCRIPT.HO + Vector3(12.6, 4.2, 32.7), -PI * .5, "The hospital: the theatre, by the hole into the supply room", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs"]}],
	"kitchen": [18, HOSPITAL_SCRIPT.HO + Vector3(-21.0, 4.2, 17.5), PI, "The hospital: the cafeteria's kitchen, at the ladder", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk"]}],
	"records": [18, HOSPITAL_SCRIPT.HO + Vector3(-6.0, 4.2, 28.6), PI, "The hospital: the records room, out of the duct", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk", "hosp_ladder", "hosp_records"]}],
	"hosp3f": [18, HOSPITAL_SCRIPT.HO + Vector3(-7.0, 8.4, 30.0), PI, "The hospital: the third floor, the records annex", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk", "hosp_ladder", "hosp_records", "hosp_bookcase", "hosp_third"]}],
	"labdoor": [18, HOSPITAL_SCRIPT.HO + Vector3(-2.0, 8.4, 24.0), -PI * .5, "The hospital: the laboratory's door, everything found", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk", "hosp_ladder", "hosp_records", "hosp_bookcase", "hosp_third", "hosp_items"]}],
	"lab": [18, HOSPITAL_SCRIPT.HO + Vector3(2.0, 8.4, 24.0), -PI * .5, "The hospital: the laboratory open, its people coming", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk", "hosp_ladder", "hosp_records", "hosp_bookcase", "hosp_third", "hosp_items", "lab_open"]}],
	"lucky": [18, HOSPITAL_SCRIPT.HO + Vector3(8.0, 8.4, 20.0), 0.0, "The hospital: the laboratory, Doctor Lucky coming out of his pod", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk", "hosp_ladder", "hosp_records", "hosp_bookcase", "hosp_third", "hosp_items", "lab_open", "hosp_lab_clear", "hosp_story"]}],
	"hosproof": [18, HOSPITAL_SCRIPT.HO + Vector3(14.0, 16.2, 30.0), PI, "The hospital: the roof, the flare", {"hosp": ["hosp_talked", "hosp_inside", "hosp_upstairs", "hosp_berido", "hosp_berido_talk", "hosp_ladder", "hosp_records", "hosp_bookcase", "hosp_third", "hosp_items", "lab_open", "hosp_lab_clear", "hosp_story", "hosp_lucky_dead", "hosp_roof"]}],
}
## 0.55: the rear gate's fight, in order (JUMPS "heavy"; `_heavy_now`).
const HEAVY_STEPS := ["", "down", "open", "out"]

## The one objective in hand, done the way play would do it (the flags, the people, the doors as they would be). One
## stage forward, at once (the lockup and the board included). Returns a spot that suits the new stage.
func debug_complete() -> Vector3:
	var from := stage
	match stage:
		0:
			_dodong_talks()
		1:
			_dodong_home()
			_open_his_doors()
		2:
			_keys_taken()
		3:
			open_road(1)
		4:
			wave_left = 0
			for k in enemies.keys():
				enemies[k].queue_free()
				enemies.erase(k)
			session.gather_bots(Street.ORIGIN+Street.STORE)
			stage = 5
			stage_time = 0.0
			wave_left = maxi(16,4*session.team.size())
			back_left = 3+mini(session.team.size(),3)
			breach_at = rng.randf_range(24.0,42.0)
			wave_total = wave_left+back_left
			next_spawn = 0
		5:
			wave_left = 0
			back_left = 0
			for k in enemies.keys(): damage(1,k,"head",enemies[k].global_position,Vector3.FORWARD,999.0,60.0)
			for k in enemies.keys():
				enemies[k].queue_free()
				enemies.erase(k)
			stage = 6
			stage_time = 0.0
			office_wait = 0.0
			flags.gate = false
			for id: int in draggers.keys(): release(id)
			for id: int in session.team:
				session.team[id].hp = MAX_HP
				session.reward(id,"refill")
		6:
			office_wait = 0.0
			flags.office = true
			jonna.visible = true
			stage = 7
			stage_time = 0.0
			talker = 1
			talk_index = -1
			talk_wait = .4
			jonna_step = 0
		7:
			# The talk, her walk to the front and the padlock, then the board as if everyone pressed READY.
			talk_index = TALK.size()
			flags.shutter = 1.0
			flags.locked = true
			flags.lockup = 4
			flags.board = true
			_board_done()
		8:
			# (0.55: out of the back door and through the service gate first: play cannot get to the college without.)
			_out_back()
			wake_ahead()
			# The story told, Rommel calling from behind the gate.
			flags.story = STORY.size()
			stage = 9
			stage_time = 0.0
			say("Rommel\nHoy... hoy! Over here, by the gate! Don't shoot... I'm not one of them!",12)
		9:
			talk_index = GUARD_TALK.size()
			open_school()
		10:
			knock_done()
		11, 12, 13, 14:
			escape.debug_step()
		15:
			if not bool(flags.get("pilcst_out",false)): escape.debug_step()
			else: start_outer_street()
		16:
			outer_street.debug_finish(self)
		17:
			_win_outer_street()
			start_hospital()
		18:
			hospital.debug_finish(self)
			_win_hospital()
	print("INTERIOR_COOP_DEBUG complete %d -> %d" % [from,stage])
	return _stage_spot(stage)

## A sensible place to stand for `which` stage (world position).
func _stage_spot(which: int) -> Vector3:
	match which:
		0, 1: return guide.position+Vector3(1.2,0,0)
		2: return guide.position+Vector3(0,0,1.2)
		3: return Street.ORIGIN+Vector3(1.8,0,-2.3)
		4: return Street.ORIGIN+Vector3(0,0,51.5)
		5: return Street.ORIGIN+Vector3(0,0,61.0)
		6: return Street.ORIGIN+Vector3(4.1,0,66.4)
		7: return Street.ORIGIN+Vector3(3.6,0,71.0)
		8: return Street.ORIGIN+Vector3(-2.0,0,84.0)
		9: return Street.ORIGIN+Vector3(28.0,0,497.6)
		10: return Street.ORIGIN+Vector3(28.0,0,516.5)
		11: return Street.ORIGIN+Vector3(6.9,SCHOOL.H*4,523.6)
		12: return Street.ORIGIN+Vector3(3.6,SCHOOL.H*4,517.4)
		13: return Street.ORIGIN+Vector3(7.4,SCHOOL.H*4,523.5)
		14: return Street.ORIGIN+Vector3(57.3,SCHOOL.H,523.5)
		15: return Street.ORIGIN+Vector3(11.0,0,543.5)
		16: return Street.ORIGIN+Vector3(44.0,0,605.0)
		17: return Street.ORIGIN+Vector3(52.0,0,730.0)
		18: return Street.ORIGIN+HOSPITAL_SCRIPT.HO+Vector3(0,0,-15.0)
	return Vector3.INF

## Forward to `place` (a JUMPS key, or a stage number 0-15: the place it begins at): every objective on the way
## completed in turn, what is behind the spot cleared (`_clear_behind`) and settled as play would leave it (`_settle`),
## then the squad stood there. Returns [world spot, yaw] or [] with the reason in `debug_note`.
var debug_note := ""
func debug_jump(place: String) -> Array:
	place = place.strip_edges().to_lower()
	if place.is_valid_int(): place = stage_place(int(place))
	if not JUMPS.has(place):
		debug_note = "Unknown place '%s'. Places: %s, or a stage 0-15." % [place,", ".join(JUMPS.keys())]
		return []
	var why := jump_blocked(place)
	if why!="":
		debug_note = why
		return []
	var spec: Array = JUMPS[place]
	var how: Dictionary = spec[4]
	var guard := 0
	while stage<int(spec[0]) and guard<24:
		debug_complete()
		guard += 1
	flush_later()
	var spot: Vector3 = (Street.ORIGIN+(spec[1] as Vector3)) if spec[1] is Vector3 else Vector3.INF
	_clear_behind(spot-Street.ORIGIN if spot.is_finite() else Vector3.ZERO,bool(how.get("fresh",false)))
	_settle(place,how)
	if not spot.is_finite(): spot = _stage_spot(stage)
	var yaw := float(spec[2])
	var g := ground(spot)
	if g.is_finite(): spot = g
	if escape!=null and stage>=13 and stage<OVER: escape.debug_place(spot,yaw)
	debug_note = "Stage %d: %s" % [stage,str(spec[3])]
	print("INTERIOR_COOP_DEBUG jump %s -> stage %d" % [place,stage])
	return [spot,yaw]

## 0.55: why the squad cannot jump to `place` now ("" when it can). The run goes forward only: a place at an earlier
## stage is behind it, and so is one earlier in this stage's own order where that order is kept (the board up, the
## rear gate's fight further on).
func jump_blocked(place: String) -> String:
	if not JUMPS.has(place): return "Unknown place '%s'." % place
	if stage>=OVER: return "The run is over (stage %d). Leave and host again to start over." % stage
	var target := int(JUMPS[place][0])
	var how: Dictionary = JUMPS[place][4]
	var back := "Jumps only go forward (now at stage %d). Leave and host again to start over." % stage
	if target<stage: return back
	if target>stage: return ""
	if place=="board" and int(flags.get("lockup",0))>=4: return back
	if stage==15:
		var now := _heavy_now()
		if now>=3 or HEAVY_STEPS.find(str(how.get("heavy","")))<now: return back
	return ""

## 0.55: how far the rear gate's fight has gone (HEAVY_STEPS): him up, him down, the gate open, out through it.
func _heavy_now() -> int:
	if flags.get("pilcst_out",false): return 3
	if flags.get("reargate",false) or flags.get("heavy_key_taken",false): return 2
	if escape!=null and escape.fight!=null and escape.fight.state=="dead": return 1
	return 0

## The place stage `s` begins at (its "fresh" place, else its first one).
func stage_place(s: int) -> String:
	var first := ""
	for k: String in JUMPS:
		if int(JUMPS[k][0])!=s: continue
		if bool((JUMPS[k][4] as Dictionary).get("fresh",false)): return k
		if first=="": first = k
	return first if first!="" else str(s)

## 0.55 (host): the infected behind `spot` (street-local) let go. What play has waiting ahead of it stays: the sleepers
## further up Store Road and along the backstreets, the horde standing on the fifth floor, the field's (all of them
## where the field begins, those further on partway across), Heavy-arm. A stage's waves stand only where it begins (the
## mart's siege and the backstreets' trickle always). Store Road's houses already passed have been forced.
func _clear_behind(spot: Vector3, fresh: bool) -> void:
	for k in enemies.keys():
		var z = enemies[k]
		if is_instance_valid(z) and _waits_ahead(z,spot,fresh): continue
		if is_instance_valid(z): z.queue_free()
		enemies.erase(k)
	if stage==4:
		for i in street.doors.size():
			if (street.doors[i].global_position-Street.ORIGIN).z<spot.z+2.0: awake_houses[i] = true
	if not (stage==5 or stage==8 or (stage==4 and fresh)): wave_left = 0
	next_spawn = maxf(next_spawn,4.0)
	# (0.52: arriving by a jump is not running in: what is asleep there does not hear it.)
	moving.clear()

func _waits_ahead(z, spot: Vector3, fresh: bool) -> bool:
	if z.dead or z.hp<=0: return false
	if z.has_meta("boss"): return true
	var l: Vector3 = z.position-Street.ORIGIN
	match stage:
		4, 8: return z.asleep and l.y<3.0 and l.z>spot.z+4.0
		13: return z.asleep and l.y>SCHOOL.H*4-1.0
		14: return l.z>535.0
		15: return l.z>535.0 and (fresh or l.z>spot.z+4.0)
		16, 17: return l.z>602.0
	return false

## 0.55 (host): what a run that got to `place` has behind it beyond what the objectives' own steps leave (each does
## one objective; play does more on the way): everyone on their feet; Dodong's doors open behind him; the soldiers'
## rifles taken from the mart's rack; Jonna seated and the front locked; out of the back door and through the service
## gate; Rommel's gate shut behind the squad; PILCST's floors crossed; Kuya Boy; Paolo's look at the buried stair;
## Heavy-arm as far as the place says. What was said last goes, unless the place begins its stage. `flags.settled`
## keeps every peer from hearing again what is behind it (the floors' bells, the horde on the stairs, the chain, the
## blast).
func _settle(place: String, how: Dictionary) -> void:
	var fresh := bool(how.get("fresh",false))
	for id: int in draggers.keys(): release(id)
	for target: int in healing.keys(): _end_heal(target)
	for id: int in session.team:
		session.team[id].hp = MAX_HP
		session.team[id].held = false
	if stage>=2: _open_his_doors()
	# 0.66: past the siege's start the Old Salmonan gate is shut behind and chapter one put away (stage 4 shuts it
	# itself once the squad is up the road: `_road_seal_check`).
	if stage>=5:
		flags.road_shut = true
		flags.gate = false
	if stage>=6: _rifles_taken()
	if place=="board":
		# The talk done and the shutter down: the board waits for READY.
		talk_index = TALK.size()
		jonna.visible = true
		jonna.position = Street.ORIGIN+BackOffice.SEAT
		flags.office = true
		flags.shutter = 1.0
		flags.locked = true
		flags.lockup = 4
		_jonna_route = [Street.ORIGIN+BackOffice.SEAT]
		jonna_step = 0
		for id: int in session.team: session.team[id].next_ready = session.is_bot(id)
		flags.board = true
	if stage>=8:
		jonna.visible = true
		flags.office = true
		flags.shutter = 1.0
		flags.locked = true
		flags.lockup = 5
		_jonna_route = []
		_jonna_seated()
	if stage>=9 or bool(how.get("outback",false)): _out_back()
	if stage>=10:
		flags.school_gate = true
		flags.guard_talk = false
		flags.school_shut = true
		if school!=null: _floors_crossed(int(how.get("floors",SCHOOL.FLOORS)))
	if bool(how.get("kuya",false)): _kuya_boy()
	if escape!=null and (stage>=15 or place=="room208"): escape._entered_two = true
	# (The fifth floor's dark: every light put out for the horde, as Ma'am Teves asked.)
	if stage==12 or stage==13:
		for id: int in session.team:
			session.team[id].light = false
			session.reward(id,"dark")
	match str(how.get("heavy","")):
		"down": escape.fight.debug_down()
		"open": escape.fight.debug_finish()
		"out":
			escape.fight.debug_finish()
			escape.out()
	if stage>=16 and stage<HOSPITAL:
		flags.outer_built = true
		flags.board = false
		flags.pilcst_out = false
		flags.outer_sealed_behind = true
		if escape!=null and not escape._cleaned: escape.clean()
		build_outer_street()
		if school!=null and school.has_method("seal_rear_gate"): school.seal_rear_gate()
	if stage>=16 and stage<HOSPITAL and outer_street!=null:
		outer_street.debug_settle(self,how.get("outer",[]))
	if stage==HOSPITAL:
		flags.bridge_out = true
		flags.board = false
		flags.hosp_built = true
		build_hospital()
		hospital.debug_settle(self,how.get("hosp",[]))
		for zid: String in how.get("zones",[]): hospital._zones_done[zid] = true
	if stage==17 and outer_street!=null:
		for st: Array in OUTER_STREET.STEPS: flags[st[0]] = true
		outer_street.debug_finish(self)
	threat = 0.0
	pressure = 0.0
	if not fresh and not bool(how.get("line",false)): say("",0.0)
	flags.settled = stage-(1 if fresh else 0)

## 0.55: out of the mart's back door and through the service gate with Jonna's key, as the squad goes.
func _out_back() -> void:
	flags.alley_key = true
	if not flags.get("backdoor",false) and not flags.get("backdoor_open",false): _open_back_door()
	if not flags.get("alley",false): _open_alley()

## 0.55: past the mart, the squad carries the soldiers' rifles from its rack, one each as far as they go (people
## first), as they would have taken them: the rack is only offered while the mart is fought for (stages 4 and 5).
func _rifles_taken() -> void:
	var racks: Array = []
	for i in street.rifles.size():
		if not flags.get("rifle%d"%i,false): racks.append(i)
	var ids: Array = session.team.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(session.is_bot(a))<int(session.is_bot(b)))
	for id: int in ids:
		if racks.is_empty(): return
		var p: Dictionary = session.team[id]
		if bool(p.get("rifle",false)): continue
		flags["rifle%d"%int(racks.pop_front())] = true
		p.rifle = true
		session.reward(id,"rifle")

## 0.55: PILCST's first `n` floors crossed on the way up: each reached (its bell rang long ago: kept quiet now, on
## every peer), its sleepers, class and rush behind the squad, its shut doors met (nothing pounds or bursts there).
func _floors_crossed(n: int) -> void:
	var quiet := int(flags.get("quiet_floors",0))
	for f in mini(n,SCHOOL.FLOORS):
		if flags.get("floor%d"%f,false): continue
		flags["floor%d"%f] = true
		quiet |= 1<<f
	flags.quiet_floors = quiet
	var behind := 0
	for i in school.doors.size():
		if int(school.doors[i].k)<n: behind |= 1<<i
	flags.fired = int(flags.get("fired",0)) | behind
	flags.pound = int(flags.get("pound",0)) & ~behind
	_bursts = _bursts.filter(func(b: Array) -> bool: return (behind & (1<<int(b[1])))==0)
	for d: int in _pound_end.keys():
		if behind & (1<<d): _pound_end.erase(d)

## Debug: room 501 opened as if knocked on with the corridor clear.
func knock_done() -> void:
	for k in enemies.keys():
		if is_instance_valid(enemies[k]): enemies[k].queue_free()
		enemies.erase(k)
	# (0.52: and the classes behind the shut doors met already: nothing beating on a door down the hall.)
	_bursts.clear()
	_pound_end.clear()
	flags.pound = 0
	if school!=null: flags.fired = (1<<school.doors.size())-1
	knock(1 if session.team.has(1) else session.team.keys()[0])

# ---------------------------------------------------------------- 0.55: debug teleports

## (`places`, built once.)
static var _place_list: Array = []

## Every known place, for the debug menu's teleports (`debug_go`: the squad moved there, the run left where it is):
## [key, name, group, world spot, yaw]. In the order the run goes, then the town it starts in (the solo game's world).
## Vector3.INF: the house's own spawn. The school's spots are ones its review captures stood on.
static func places() -> Array:
	if not _place_list.is_empty(): return _place_list
	var o := Street.ORIGIN
	var h := SCHOOL.H
	var canal := "The canal and Dodong's warren"
	var road := "Old Salmonan and Store Road"
	var mart := "Olivar Family Mart"
	var back := "The backstreets"
	var low := "PILCST: grounds to the third floor"
	var high := "PILCST: fourth and fifth floors"
	var field := "PILCST: the field and the rear gate"
	var outer := "Outer Street"
	var town := "The town (where the run starts)"
	_place_list = [
		["bridge", "Canal bridge", canal, C.at(-.5, C.FLOOR, C.BRIDGE_Z - 1.6), 0.0],
		["farbank", "Far bank lane", canal, C.at(C.LANE_U, C.FLOOR, 38.0), 0.0],
		["warrengate", "Warren gate", canal, W.at(-22.0, W.FLOOR, 9.5), 0.0],
		["dodongwaits", "Where Dodong waits", canal, GATE_SPOT + Vector3(-1.2, 0, 0), -PI * .5],
		["plankbridge", "Plank bridge", canal, W.pos(0.0, W.DECK, W.B1_Z), 0.0],
		["dodonghouse", "Dodong's house", canal, W.pos(-4.9, W.DECK, 20.4) + Vector3(0, 0, 1.2), 0.0],
		["ramp", "Floodwall ramp", road, o + Vector3(11.6, Street.APPROACH.G, -5.2), PI * .5],
		["gate", "Old Salmonan gate", road, o + Vector3(1.8, 0, -2.3), PI],
		["storeroad", "Foot of Store Road", road, o + Vector3(0, 0, 3.5), PI],
		["storeroad2", "Mid Store Road", road, o + Vector3(0, 0, 28.0), PI],
		["martfront", "Mart front", road, o + Vector3(0, 0, 51.5), PI],
		["martin", "Inside the mart", mart, o + Vector3(0, 0, 61.0), 0.0],
		["supplies", "Soldiers' supplies", mart, o + Vector3(3.4, 0, 65.0), -PI * .5],
		["officedoor", "Office door", mart, o + Vector3(4.1, 0, 66.4), PI],
		["office", "Back office", mart, o + Vector3(3.6, 0, 71.0), PI],
		["backdoor", "Back door", mart, o + Vector3(-6.0, 0, 72.3), PI],
		["servicealley", "Service alley", mart, o + Vector3(0.0, 0, 77.2), PI],
		["servicegate", "Service gate", back, o + Vector3(-2.0, 0, 84.0), PI],
		["servicelane", "Service lane", back, o + Vector3(-2.0, 0, 115.0), PI],
		["tilestreet", "Tile street", back, o + Vector3(20.0, 0, 145.5), -PI * .5],
		["arcade", "Avenida arcade", back, o + Vector3(43.0, 0, 190.0), PI],
		["parol", "Parol lane", back, o + Vector3(43.5, 0, 250.0), PI],
		["polestreet", "Pole street", back, o + Vector3(27.5, 0, 340.0), PI],
		["brickalley", "Brick alley", back, o + Vector3(28.0, 0, 452.0), PI],
		["collegegate", "College back gate", back, o + Vector3(28.0, 0, 491.0), PI],
		["yard", "Yard (Rommel)", low, o + Vector3(28.6, 0, 504.4), PI],
		["lobby", "Lobby", low, o + Vector3(28.0, 0, 515.0), PI],
		["grandstair", "Grand stair", low, o + Vector3(28.0, 0, 521.5), PI],
		["corridor1", "Corridor 1F", low, o + Vector3(26.0, 0, 523.5), PI * .5],
		["corridor2", "Corridor 2F", low, o + Vector3(27.0, h, 523.5), -PI * .5],
		["room208", "Room 208's door", low, o + Vector3(14.6, h, 523.4), PI],
		["breach208", "208's blown wall", low, o + Vector3(12.0, h, 528.6), PI],
		["fire2", "Fire escape 2F", low, o + Vector3(57.0, h, 522.0), PI],
		["chemlab", "Chemistry lab", low, o + Vector3(14.5, h * 2, 520.8), PI * .5],
		["floor3", "3F, east end", low, o + Vector3(52.0, h * 2, 523.5), PI * .5],
		["corridor4", "Corridor 4F", high, o + Vector3(24.0, h * 3, 523.5), -PI * .5],
		["maintenance", "Maintenance room", high, o + Vector3(37.8, h * 3, 527.6), PI],
		["mech", "Mechanical room", high, o + Vector3(36.0, h * 4, 531.6), PI * .5],
		["floor5", "5F, east end", high, o + Vector3(50.0, h * 4, 523.5), PI * .5],
		["door501", "Room 501's door", high, o + Vector3(7.5, h * 4, 524.2), 0.0],
		["in501", "Inside room 501", high, o + Vector3(3.6, h * 4, 517.4), PI],
		["firedoor5", "5F fire door", high, o + Vector3(52.0, h * 4, 523.5), -PI * .5],
		["fire5", "Fire escape 5F", high, o + Vector3(57.9, h * 4, 522.2), PI],
		["leanto", "Lean-to roof", field, o + Vector3(12.6, 2.9, 534.6), PI],
		["field", "School field", field, o + Vector3(11.6, 0, 540.8), PI],
		["court", "Covered court", field, o + Vector3(49.0, 0, 567.0), PI],
		["drums", "Fuel drums", field, o + Vector3(28.0, 0, 588.0), PI],
		["reargate", "Rear gate", field, o + Vector3(44.0, 0, 594.5), PI],
		["city", "Past the rear gate", field, o + Vector3(44.0, 0, 603.5), PI],
		["outerlane", "The lane", outer, o + Vector3(44.0, 0, 604.0), PI],
		["outeravenue", "The avenue", outer, o + Vector3(46.0, 0, 630.0), PI],
		["outerbus", "The bus's back door", outer, o + Vector3(40.3, 0, 646.5), PI],
		["outerplaza", "The plaza", outer, o + Vector3(40.3, 0, 664.0), PI],
		["outershutter", "The subway's shutter", outer, o + Vector3(33.0, .15, 668.5), PI],
		["outerterrace", "The terrace", outer, o + Vector3(13.0, 5.0, 672.0), -PI * .5],
		["outerhardware", "The hardware store", outer, o + Vector3(3.0, 5.0, 686.0), -PI * .5],
		["outeroverpass", "The overpass", outer, o + Vector3(42.0, 5.6, 690.0), PI * .5],
		["outerconcourse", "The concourse", outer, o + Vector3(33.0, -5.2, 685.0), PI],
		["outerpower", "The power room", outer, o + Vector3(52.0, -5.2, 687.0), PI * .5],
		["outerplatform", "The platform", outer, o + Vector3(29.5, -10.2, 714.0), PI],
		["outertrain", "Inside the train", outer, o + Vector3(34.6, -10.15, 730.0), PI],
		["outertunnel", "The tunnel", outer, o + Vector3(34.6, -11.3, 755.0), PI],
		["outerstair", "The long stair", outer, o + Vector3(28.0, -10.0, 782.0), -PI * .5],
		["outerriver", "The river road", outer, o + Vector3(8.0, 0, 789.0), PI * .5],
		["outerpizza", "Airah's Pizzahan", outer, o + Vector3(23.0, .15, 783.0), PI],
		["outercourt", "The neon court", outer, o + Vector3(24.0, .15, 766.0), PI],
		["outerflats", "The flats", outer, o + Vector3(34.0, .15, 760.0), -PI * .5],
		["outeralley", "The red-stair alley", outer, o + Vector3(42.0, .15, 755.4), -PI * .5],
		["outereatery", "The eatery up the red stair", outer, o + Vector3(55.6, 4.15, 746.4), 0.0],
		["outermart", "Nichols Davao Mart", outer, o + Vector3(53.2, .15, 767.0), PI],
		["outermartup", "The mart's top floor", outer, o + Vector3(50.0, 4.55, 781.0), -PI * .5],
		["outerboutique", "Azrin & Azrael", outer, o + Vector3(70.0, 4.55, 774.5), -PI * .5],
		["outerfuneral", "The funeral parlor", outer, o + Vector3(91.3, .15, 783.0), 0.0],
		["outerbridge", "The bridge", outer, o + Vector3(94.0, 2.0, 820.0), PI],
		["outerbridgefar", "The bridge's far end", outer, o + Vector3(94.0, 2.0, 1050.0), PI],
		["home", "Living room", town, Vector3.INF, 0.0],
		["courtyard", "Courtyard", town, Vector3(10.0, -2.75, 4.0), 0.0],
		["street", "Street", town, Vector3(18.9, -2.75, 6.0), 0.0],
		["fieldroad", "Field road", town, Vector3(21.0, -2.75, 58.0), 0.0],
		["nicholsgate", "Nichols gate", town, Vector3(-12.0, -2.75, -55.0), 0.0],
		["nicholsfoyer", "Nichols foyer", town, NICHOLS.local(0.0, 2.0, .2), 0.0],
		["nicholsup", "Nichols upstairs", town, NICHOLS.local(-6.5, 1.3, 4.6), 0.0],
		["parlour", "Nichols parlour", town, NICHOLS.local(-8.0, 3.0, .2), 0.0],
		["cellar", "Nichols cellar", town, NICHOLS.local(-6.0, 14.0, -2.5), 0.0],
		["tunnel", "Wartime tunnel", town, NICHOLS.local(2.6, 16.8, -3.4), 0.0],
		["wallhole", "Wall hole", town, Vector3(InteriorTownSiege.HOLE_X, -2.75, InteriorTownSiege.NORTH_Z - 2.0), 0.0],
		["slum", "Slum passage", town, Vector3(-20.5, -2.75, 18.1), 0.0],
		["crawl", "Secret crawl", town, Vector3(InteriorTownSiege.SECRET_X + 1.9, -2.75, InteriorTownSiege.SOUTH_Z + 2.6), 0.0],
	]
	return _place_list

func _place(key: String) -> Array:
	for pl: Array in places():
		if str(pl[0])==key: return pl
	return []

func _place_at(pl: Array) -> Vector3:
	var at: Vector3 = pl[3]
	if at.is_finite(): return at
	var home = session.main.player.get("_spawn_position")
	return home if home is Vector3 else session.main.player.global_position

## Why nobody can be put at place `key` now ("" when they can): it has been put away behind the run (hidden, its
## bodies off: `_soft_unload`), every peer alike.
func place_closed(key: String) -> String:
	var pl := _place(key)
	if pl.is_empty(): return "Unknown place '%s'." % key
	var at := _place_at(pl)
	for keeps: Array in kept:
		if not _in_keeps(keeps,at,2.0): return "put away behind the run"
	return ""

## 0.55 (host): debug: the squad (or only `id`, `alone`) to the known place `key`; the run stays where it is. A place
## in the backstreets or the college ahead of the run wakes them early (on every peer: `flags.woken`).
func debug_go(id: int, key: String, alone: bool) -> String:
	var pl := _place(key)
	if pl.is_empty(): return "Unknown place '%s' (places lists them)." % key
	var why := place_closed(key)
	if why!="": return "%s: %s." % [pl[1],why]
	var at := _place_at(pl)
	var l := at-Street.ORIGIN
	if l.z>=600.0 and outer_street==null: build_outer_street()
	if l.z>79.5 and l.x>-20.0 and l.x<120.0 and absf(l.y)<40.0 and not ahead_awake:
		flags.woken = true
		wake_ahead()
	var g := ground(at)
	if g.is_finite(): at = g
	var yaw := float(pl[4])
	if alone: session.debug_move_one(id,at,yaw)
	else: session.debug_move_squad(at,yaw,true,id)
	moving.clear()
	return "%s %s (the run stays at stage %d)." % ["You:" if alone else "The squad:",pl[1],stage]

## 0.55: where `n` of the squad (and those with them) stand round `at` (world) facing `yaw`: side by side, then rows
## behind, then a row ahead; each on solid ground at the same level, in plain sight of the first (not through a wall)
## and apart. Not enough room: the rest share the first spot.
func squad_spots(at: Vector3, yaw: float, n: int) -> Array:
	var first := ground(at)
	if not first.is_finite(): first = at
	var across := Vector3(cos(yaw),0,-sin(yaw))*.95
	var back := Vector3(sin(yaw),0,cos(yaw))*.95
	var space := get_world_3d().direct_space_state
	var out: Array = [first]
	for row in [0,1,2,3,-1]:
		for a in [0,1,-1,2,-2,3,-3,4,-4]:
			if out.size()>=n: return out
			if row==0 and a==0: continue
			var g := ground(first+across*float(a)+back*float(row))
			if not g.is_finite() or absf(g.y-first.y)>.6: continue
			var close := false
			for s: Vector3 in out:
				if s.distance_to(g)<.7: close = true
			if close: continue
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(first+Vector3.UP,g+Vector3.UP,2)).is_empty(): continue
			out.append(g)
	while out.size()<n: out.append(first)
	return out

## The debug command line (scripts/debug_menu.gd, Co-op), run on the host for squad member `id`. Returns the reply.
func debug_command(id: int, line: String) -> String:
	var words := line.strip_edges().split(" ",false)
	if words.is_empty(): return ""
	var cmd := words[0].to_lower()
	var arg := words[1].to_lower() if words.size()>1 else ""
	var p: Dictionary = session.team[id]
	match cmd:
		"help","?":
			return "complete | jump <place|0-17> | go <place> [me] | squad | places | stage | spawn [n] | kill | heal | kits [n] [squad] | god on/off | give <weapon> | ammo | bots [n] | tp <x> <y> <z> | where | boss <charge|throw|roar|hp n|kill>"
		"places":
			var jumps: Array = []
			for k: String in JUMPS: jumps.append("%s (%d)" % [k,int(JUMPS[k][0])])
			var spots: Array = []
			for pl: Array in places(): spots.append(str(pl[0]))
			return "jump (the run moves on): %s\ngo (only the squad moves): %s" % [", ".join(jumps),", ".join(spots)]
		"complete","done","next":
			# (0.55: the next stage from where it begins, everything behind settled: the same as a jump there.)
			var from := stage
			if stage<15:
				var r := debug_jump(stage_place(stage+1))
				if r.is_empty(): return debug_note
				session.debug_move_squad(r[0],float(r[1]),true,id)
			elif stage<OVER:
				var r_at := debug_complete()
				if stage!=from and r_at.is_finite():
					var g := ground(r_at)
					session.debug_move_squad(g if g.is_finite() else r_at,PI,true,id)
			return "Objective %d done -> %d: %s" % [from,stage,OBJECTIVES[mini(stage,OBJECTIVES.size()-1)]]
		"jump","goto":
			var r := debug_jump(arg)
			if r.is_empty(): return debug_note
			session.debug_move_squad(r[0],float(r[1]),true,id)
			return debug_note
		"go","teleport":
			if arg=="": return "go <place> [me]  (places lists them; 'me' moves only you)"
			return debug_go(id,arg,words.size()>2 and words[2].to_lower() in ["me","alone","solo"])
		"squad","bring":
			session.debug_move_squad(p.pos,float(p.yaw),true,id)
			return "The squad is with you"
		"stage":
			return "Stage %d: %s" % [stage,objective()]
		"boss":
			# 0.53: Heavy-arm, at the rear gate (stage 15, or from the blast on).
			if escape==null or escape.fight==null or stage<14: return "Heavy-arm is at PILCST's rear gate (jump heavyarm)."
			var f = escape.fight
			if arg=="kill":
				f.debug_finish()
				return "Heavy-arm down; the key taken, the rear gate open."
			if arg=="hp" and words.size()>2 and words[2].is_valid_float():
				f.hp = clampf(float(words[2]),1.0,f.max_hp)
				return "Heavy-arm at %.0f of %.0f." % [f.hp,f.max_hp]
			if arg in ["charge","throw","roar"]: return f.debug_force(arg)
			return "Heavy-arm: %s, %.0f of %.0f." % [f.state,f.hp,f.max_hp]
		"spawn":
			var n := clampi(int(arg) if arg.is_valid_int() else 1,1,30)
			var made := 0
			for i in n:
				if spawn_near(p): made += 1
			return "%d infected" % made
		"kill":
			var n := enemies.size()
			for k in enemies.keys(): damage(id,k,"head",enemies[k].global_position+Vector3.UP*1.5,Vector3.FORWARD,999.0,60.0)
			return "%d infected put down" % n
		"heal":
			# (0.55: up again if down, any patch-up on them ended.)
			for who: int in session.team:
				_end_heal(who)
				session.team[who].hp = MAX_HP
				session.team[who].held = false
				session.reward(who,"refill")
			return "Squad at full health and ammunition"
		"kits":
			# (0.55: `kits [n] squad` fills everyone's.)
			var n := clampi(int(arg) if arg.is_valid_int() else MAX_KITS,0,MAX_KITS)
			var all: bool = "squad" in words or "all" in words
			for who: int in (session.team.keys() if all else [id]):
				var q: Dictionary = session.team[who]
				q.kits = 0
				q.kit_sizes = []
				for i in n: add_kit(q,"medium")
			return "%d healthkits%s" % [n," each, the whole squad" if all else ""]
		"god":
			var on := arg!="off"
			harmless = on
			session.harmless = on
			# (0.55: the menu's Invulnerable box follows, or it would put it back on: debug_menu.gd `_keep_god`.)
			var menu: Node = session.main.get_node_or_null("DebugMenu")
			if menu!=null: menu.god = on
			if session.main.get("zombies")!=null and session.main.zombies!=null: session.main.zombies.invulnerable = on
			return "Squad invulnerable: no damage of any kind" if on else "Squad can be hurt again"
		"give":
			var which := InteriorArsenal.resolve(arg)
			if which=="":
				return "No such weapon. Try: "+", ".join(InteriorArsenal.WEAPONS.keys())
			put_down(id,which,[30,true,120])
			return "%s at your feet (E to take it)" % InteriorArsenal.display_name(which)
		"ammo":
			session.reward(id,"refill")
			return "Ammunition topped up"
		"bots":
			var n := clampi(int(arg) if arg.is_valid_int() else 4,0,4)
			while session.team.size()-session.humans()<n and session.add_bot(): pass
			while session.team.size()-session.humans()>n and session.team.size()>session.humans(): session.remove_bot()
			return "%d squad AI" % (session.team.size()-session.humans())
		"tp":
			if words.size()<4: return "tp <x> <y> <z> (street-local; 'where' prints yours; go <place> for a named one)"
			var to := Street.ORIGIN+Vector3(float(words[1]),float(words[2]),float(words[3]))
			session.debug_move_one(id,to,float(p.yaw))
			return "Moved to %s" % str(to-Street.ORIGIN)
		"where":
			return "Stage %d, street-local %s" % [stage,str((p.pos-Street.ORIGIN).snapped(Vector3.ONE*.1))]
	return "Unknown command '%s' (help lists them)" % cmd

func debug_skip() -> Vector3:
	match stage:
		0:
			stage = 1
			return guide.position+Vector3(1.2,0,0)
		1:
			guide.position = route[route.size()-1]
			waypoint = route.size()
			stage = 2
			say("Dodong Sikma
This is my house. My keys are beside the candle.")
			return guide.position+Vector3(0,0,1.2)
		2:
			stage = 3
			flags.keys = true
			return street.key.global_position+Vector3(0,0,1.0)
		3:
			open_road(1)
			return Street.ORIGIN+Street.GATE+Vector3(0,0,2.0)
		4:
			wave_left = 0
			return Street.ORIGIN+Street.STORE
		5:
			wave_left = 0
			back_left = 0
			for k in enemies.keys(): damage(1,k,"head",enemies[k].global_position,Vector3.FORWARD,999.0,60.0)
		6:
			office_wait = 0.0
			flags.office = true
			return jonna.position+Vector3(0,0,-1.6)
		7:
			# 0.49: the talk, then Jonna's lockup (straight to the padlock), then the board (everyone ready).
			if int(flags.get("lockup",0))==0:
				talk_index = TALK.size()
				talk_wait = 0.0
				_start_lockup()
			if int(flags.get("lockup",0))<4:
				jonna.position = Street.ORIGIN+FRONT_SPOT
				flags.shutter = 1.0
				flags.lockup = 3
				_lock_wait = 0.0
			else:
				_board_done()
			return Street.ORIGIN+Street.BACK_DOOR+Vector3(0,0,-1.2)
		8:
			flags.backdoor_open = true
			flags.alley = true
			return Street.ORIGIN+Vector3(28.0,0,486.0)
		9:
			talk_index = GUARD_TALK.size()
			open_school()
			return Street.ORIGIN+SCHOOL.ENTRANCE+Vector3(0,0,-3)
		10:
			knock_done()
			return Street.ORIGIN+SCHOOL.DOOR_501+Vector3(0,0,1)
		11, 12, 13, 14, 15:
			escape.debug_step()
			return _stage_spot(stage)
	return Vector3.INF

## 0.52: the squad keeps it down (no lights, crouched, nobody shoots the ones standing asleep): while the horde
## goes past 501 and while they get past it to the fire exit.
func quiet() -> bool:
	return stage==12 or stage==13
