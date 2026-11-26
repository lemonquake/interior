extends Node3D
const Mission := preload("res://scripts/coop/mission.gd")
## 0.40: the squad AI the host can bring in to fill the team (lobby, or the debug menu during play). They live on
## the host only: each is a team member like any player (scripts/coop/session.gd `team`, negative ids), drawn on every
## peer by the same survivor figures, and moved here by a body of its own.
##
## How one thinks, every eighth of a second (staggered between them):
## - who it looks after: its leader, the nearest player on their feet (and Dodong while he is being walked home).
## - what it can see: the infected in line of sight (the world blocks it), ranked by how close they are to the leader,
##   to Dodong and to itself; the one going for the leader comes first. It calls them out as they appear.
## - when to give ground: one at arm's length, two close, or hurt with them coming: it backs away along the open
##   direction that gains the most room from all of them while staying near the team, shooting as it goes; with
##   the team in trouble it calls for backup or a fall back.
## - protecting: a figure on the leader puts it at the leader's side, square to the threat so its line of fire is
##   clear of them; one coming up behind the leader is called out. It never fires with a friend in the line.
## - ammunition: counted round by round; it reloads when empty, or tops up when nothing is near, and says so with
##   them close; low and empty are called out, and empty means staying behind the leader until ammunition turns up.
## - the rest: helps the downed up (with a healthkit), heals itself when it is safe, picks up rifles, ammunition and
##   healthkits it passes, calls out what it finds, and keeps a place in a loose formation round the leader, the last
##   one watching behind. It follows orders from the voice menu: follow, hold here, fall back, backup, let's go,
##   check this out.
const Street := preload("res://scripts/coop/street.gd")
const EYE := 1.45
const THINK := .125
const LINES_GAP := 1300           # ms between two lines from the whole squad
## Formation places round the leader (right, back), in the leader's frame.
const SLOTS: Array[Vector2] = [Vector2(-1.4,1.5), Vector2(1.4,1.5), Vector2(0,2.7), Vector2(-2.2,2.9)]
const PISTOL := {"mag": 17, "interval": .3, "damage": 34.0, "knock": 60.0, "reload": 1.7, "rifle": false}
const RIFLE := {"mag": 30, "interval": .11, "damage": 46.0, "knock": 95.0, "reload": 2.3, "rifle": true}
var session
var mission
var bots := {}
var _said_at := 0
var _searches := 0
var _frame := 0
## 0.52: where each survivor has walked lately (id -> points ~.35 m apart): past the standing horde the squad AI
## steps where the leader stepped instead of fanning out beside them.
var trails := {}

class Bot:
	var id := 0
	var index := 0
	var body: CharacterBody3D
	var skill := .8
	var leader := 1
	var mode := "follow"
	var target := -1
	var target_seen := 0.0
	var think := 0.0
	var gun: Dictionary
	var mag := 17
	var reserve := 85
	var reload_left := 0.0
	var next_shot := 0.0
	var burst := 0
	var path := PackedVector3Array()
	var path_wait := 0.0
	var path_goal := Vector3.INF
	var dest := Vector3.ZERO
	var run := false
	var face := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var seen := {}
	var said := {}
	var order := ""
	var order_at := Vector3.ZERO
	var order_until := 0
	var stuck := 0.0
	var last_at := Vector3.ZERO
	var fought_at := -100.0
	var quiet := 0.0
	var low_said := false
	var out_said := false
	var down_said := false
	var errand := ""
	var errand_at := Vector3.ZERO
	var scan := 0.0
	var straight := true
	var straight_wait := 0.0
	var straight_to := Vector3.INF

func setup(owner_session) -> void:
	session = owner_session
	mission = session.mission
	name = "SquadAI"

func is_bot(id: int) -> bool: return bots.has(id)

## A new squad member in the team's slot `slot`, standing at `at`.
func add(id: int, at: Vector3) -> void:
	var b := Bot.new()
	b.id = id
	b.index = bots.size()
	b.skill = randf_range(.72,.92)
	b.gun = PISTOL
	b.mag = 17
	b.reserve = 85
	b.think = randf()*THINK
	b.body = CharacterBody3D.new()
	b.body.name = "Bot %d"%-id
	b.body.collision_layer = 0
	b.body.collision_mask = 2
	b.body.floor_snap_length = .4
	b.body.floor_max_angle = deg_to_rad(48.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .26
	capsule.height = 1.0
	shape.shape = capsule
	shape.position.y = .52
	b.body.add_child(shape)
	add_child(b.body)
	b.body.global_position = at
	b.dest = at
	b.last_at = at
	b.yaw = float(session.team[id].yaw)
	bots[id] = b

func remove(id: int) -> void:
	var b: Bot = bots.get(id)
	if b==null: return
	b.body.queue_free()
	bots.erase(id)

func tick(delta: float) -> void:
	_frame += 1
	_searches = 0
	mission.nav.space = get_world_3d().direct_space_state
	for id: int in bots.keys():
		if not session.team.has(id):
			remove(id)
			continue
		_tick(bots[id],delta)
	for id: int in session.team:
		var at: Vector3 = session.team[id].pos
		var trail: PackedVector3Array = trails.get(id,PackedVector3Array())
		if trail.is_empty() or trail[trail.size()-1].distance_to(at)>.35:
			trail.append(at)
			if trail.size()>48: trail.remove_at(0)
			trails[id] = trail

# ---------------------------------------------------------------- one squad member

func _tick(b: Bot, delta: float) -> void:
	var p: Dictionary = session.team[b.id]
	var now := Time.get_ticks_msec()/1000.0
	if p.hp<=0:
		if not b.down_said:
			b.down_said = true
			say(b,"down",true)
		b.body.velocity = Vector3.ZERO
		p.clip = "down_idle"
		p.light = false
		return
	if b.down_said:
		b.down_said = false
		b.target = -1
	b.reload_left = maxf(0.0,b.reload_left-delta)
	if b.reload_left<=0.0 and p.has("reloading") and p.reloading:
		var take := mini(int(b.gun.mag)-b.mag,b.reserve)
		b.mag += take
		b.reserve -= take
		p.reloading = false
	b.think -= delta
	if b.think<=0.0:
		b.think = THINK
		_decide(b,p,now)
	_move(b,p,delta)
	_aim_and_fire(b,p,delta,now)
	p.pos = b.body.global_position
	p.yaw = b.yaw
	p.pitch = b.pitch
	# 0.52: lights off while the horde is up on the fifth floor (mission `quiet`).
	p.light = not mission.quiet()
	p.rifle = b.gun.rifle
	p.ammo = b.mag
	p.reserve = b.reserve

func _leader(b: Bot) -> int:
	var team: Dictionary = session.team
	if b.order!="" and Time.get_ticks_msec()<b.order_until and team.has(b.leader) and team[b.leader].hp>0: return b.leader
	var best := 0
	var near := INF
	for id: int in team:
		if session.is_bot(id) or team[id].hp<=0: continue
		var d: float = b.body.global_position.distance_squared_to(team[id].pos)
		if d<near:
			near = d
			best = id
	if best==0:
		for id: int in team:
			if id!=b.id and team[id].hp>0:
				var d: float = b.body.global_position.distance_squared_to(team[id].pos)
				if d<near:
					near = d
					best = id
	return best if best!=0 else b.id

func _eye(b: Bot) -> Vector3: return b.body.global_position+Vector3.UP*EYE

func _clear(from: Vector3, to: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,2)).is_empty()

## 0.49: what a squad member sees (and so shoots at): what a round would get to, not the walking boxes.
func _sight(from: Vector3, to: Vector3) -> bool:
	return InteriorSurfaces.seen_ray(get_world_3d().direct_space_state,from,to,2|InteriorModelKit.SHOT_LAYER).is_empty()

func _decide(b: Bot, p: Dictionary, now: float) -> void:
	var team: Dictionary = session.team
	b.leader = _leader(b)
	var lead: Dictionary = team[b.leader]
	var lead_at: Vector3 = lead.pos
	var lead_forward := Vector3(-sin(float(lead.yaw)),0,-cos(float(lead.yaw)))
	var me := b.body.global_position
	var eye := _eye(b)
	# What it can see, and how much each matters.
	var threats: Array = []
	var close_count := 0
	var nearest := INF
	var nearest_key := -1
	var visible := 0
	var on_leader := -1
	for k: int in mission.enemies:
		var z = mission.enemies[k]
		if z.dead or z.hp<=0: continue
		var zat: Vector3 = z.global_position
		var d := me.distance_to(zat)
		if d>48.0: continue
		if d<nearest:
			nearest = d
			nearest_key = k
		if d<4.2: close_count += 1
		var sees := d<2.0 or (d<40.0 and _sight(eye,zat+Vector3.UP*1.2))
		if not sees: continue
		visible += 1
		var to_lead := zat.distance_to(lead_at)
		var score := 9.0/(d+.6)+15.0/(to_lead+.6)
		if mission.stage==1: score += 12.0/(zat.distance_to(mission.guide.global_position)+.6)
		# 0.41: one that has not noticed anyone is left alone unless it is close: a shot wakes the street.
		# (0.52: and none at all of those while the squad keeps quiet past the horde.)
		if z.asleep and (d>7.0 or mission.quiet()): continue
		if z.asleep: score *= .25
		if k==b.target: score *= 1.35
		threats.append([score,k])
		if to_lead<5.0 and not z.asleep: on_leader = k
		if not b.seen.has(k):
			b.seen[k] = true
			if not z.asleep and d<32.0: _spotted(b,visible)
		# One coming up behind the leader.
		if to_lead<7.0 and lead_forward.dot((zat-lead_at).normalized())<-.25 and b.leader!=b.id and not session.is_bot(b.leader):
			say(b,"behind",false,9.0)
	threats.sort_custom(func(x,y): return x[0]>y[0])
	var previous := b.target
	b.target = threats[0][1] if not threats.is_empty() else -1
	if b.target!=previous: b.target_seen = now
	if b.target>=0: b.fought_at = now
	elif now-b.fought_at>4.0 and now-b.fought_at<5.0: say(b,"clear",false,25.0)
	# Ammunition.
	var total := b.mag+b.reserve
	if b.mag==0 and b.reserve>0 and b.reload_left<=0.0: _reload(b,p,visible>0 or nearest<14.0)
	elif b.mag<int(b.gun.mag)*.35 and b.reserve>0 and nearest>16.0 and b.reload_left<=0.0 and b.target<0: _reload(b,p,false)
	if total<=0 and not b.out_said:
		b.out_said = true
		say(b,"no_ammo",false,20.0)
	elif total>0 and total<(40 if b.gun.rifle else 20) and not b.low_said:
		b.low_said = true
		say(b,"low_ammo",false)
	if total>=(60 if b.gun.rifle else 34):
		b.low_said = false
		b.out_said = false
	# 0.49: in a patch-up (being patched by a teammate, patching itself, or patching someone): it stays where it is
	# until it is done, still turning to shoot at what comes; nothing else it would do moves it off.
	if mission.in_heal(b.id):
		b.mode = "patch"
		b.dest = me
		b.path.clear()
		b.run = false
		return
	# Hurt and safe: a healthkit (not while a human teammate is already coming over with one).
	if p.hp<=Mission.MAX_HP*.45 and p.kits>0 and nearest>6.0 and not _medic_near(b):
		mission.heal(b.id)
		if mission.in_heal(b.id):
			b.mode = "patch"
			b.dest = me
			b.path.clear()
			return
	b.run = false
	b.face = Vector3.ZERO
	# 0.52: while the horde goes past 501: down along the back wall of the room, still (unless they come in).
	if mission.stage==12 and (b.target<0 or nearest>6.0):
		var spot: Vector3 = mission.ground(Street.ORIGIN+Vector3(1.3+(b.index%4)*1.6,3.6*4,515.2))
		b.mode = "hold"
		b.dest = spot if spot.is_finite() else me
		b.face = Vector3(0,0,1)
		return
	# Give ground: too close, too many, or too hurt to trade blows.
	var retreat: bool = nearest<2.3 or (close_count>=2 and nearest<3.4) or (p.hp<=Mission.MAX_HP*.35 and nearest<7.0) or (total<=0 and nearest<6.0)
	if retreat:
		b.mode = "retreat"
		b.dest = _escape(b,lead_at)
		b.run = true
		if close_count>=3: say(b,"fall_back",false,10.0)
		elif p.hp<=Mission.MAX_HP*.35: say(b,"backup",false,12.0)
		return
	# Someone down: help them up.
	var downed := _downed(b)
	if downed!=0 and p.kits>0:
		var at: Vector3 = team[downed].pos
		var danger := _nearest_to(at)
		if danger>3.0 or nearest>5.0:
			b.mode = "revive"
			b.dest = at
			b.run = me.distance_to(at)>3.0
			if me.distance_to(at)<2.2:
				var action: String = mission.candidate(b.id)
				if action.begins_with("revive"):
					mission.interact(b.id,action)
					say(b,"reviving",true)
			return
	# Orders from the voice menu.
	if b.order!="" and Time.get_ticks_msec()<b.order_until:
		match b.order:
			"hold":
				b.mode = "hold"
				b.dest = b.order_at
				return
			"backup","fall_back":
				if me.distance_to(b.order_at)>2.5:
					b.mode = "regroup"
					b.dest = b.order_at
					b.run = true
					return
			"check":
				if me.distance_to(b.order_at)>1.6 and b.target<0:
					b.mode = "check"
					b.dest = b.order_at
					return
	elif b.order!="":
		b.order = ""
	# Covering the leader: at their side, square to the threat.
	if on_leader>=0 and b.leader!=b.id:
		var threat_at: Vector3 = mission.enemies[on_leader].global_position
		var across := (threat_at-lead_at)
		across.y = 0
		across = across.normalized().cross(Vector3.UP)
		var side := 1.0 if (me-lead_at).dot(across)>=0.0 else -1.0
		b.mode = "cover"
		b.dest = lead_at+across*side*1.9
		b.run = me.distance_to(b.dest)>2.5
		b.target = on_leader
		say(b,"covering",false,14.0)
		return
	# Too close to what it shoots at: back off a step while shooting.
	if b.target>=0 and nearest<4.5:
		var away: Vector3 = me-mission.enemies[nearest_key].global_position
		away.y = 0
		b.mode = "kite"
		b.dest = me+away.normalized()*2.0
		return
	# Out of ammunition: behind the leader, where the others can cover it, and to ammunition if any is near.
	if total<=0:
		var supply := _supply(b,true)
		b.mode = "resupply"
		b.dest = supply if supply.is_finite() else lead_at-lead_forward*2.0
		b.run = true
		_pick_up(b)
		return
	# Nothing close: things worth having.
	if b.target<0 or nearest>14.0:
		var want := _supply(b,false)
		if want.is_finite() and want.distance_to(lead_at)<16.0:
			b.mode = "loot"
			b.dest = want
			b.run = me.distance_to(want)>5.0
			_pick_up(b)
			return
	# Its place round the leader. The last one keeps an eye behind.
	var basis := Basis(Vector3.UP,float(lead.yaw))
	var slot: Vector2 = SLOTS[b.index%SLOTS.size()]
	var place := lead_at+basis*Vector3(slot.x,0,slot.y)
	if b.leader==b.id: place = me
	if b.order=="follow": place = lead_at.lerp(place,.6)
	if mission.quiet() and b.leader!=b.id:
		var trail: PackedVector3Array = trails.get(b.leader,PackedVector3Array())
		var back: int = 4+4*(b.index%SLOTS.size())
		place = trail[maxi(trail.size()-1-back,0)] if not trail.is_empty() else lead_at
	# 0.50: in the school a place beside the leader can be over the grand stair's well or behind a wall: then
	# the leader's own spot (the floor probe there finds the stair below, and it would walk back down to it).
	if mission.school!=null and b.leader!=b.id:
		var fy: float = mission.nav.floor_at(InteriorZombieNav.cell_of(place),place.y+.2)
		if is_nan(fy) or absf(fy-lead_at.y)>.35 or not _clear(lead_at+Vector3.UP*.6,place+Vector3.UP*.6): place = lead_at
	b.mode = "follow"
	b.dest = place
	b.run = me.distance_to(place)>5.5 and not mission.quiet()
	if b.target<0:
		b.scan += THINK
		if b.index%SLOTS.size()==2 or b.index%SLOTS.size()==3: b.face = -Vector3(-sin(float(lead.yaw)),0,-cos(float(lead.yaw)))
		elif me.distance_to(place)<1.2: b.face = Basis(Vector3.UP,float(lead.yaw)+sin(b.scan*.6+b.index)*.9)*Vector3.FORWARD
	# Lost: well behind or stuck for a while, it catches up.
	if (me.distance_to(lead_at)>32.0 or b.stuck>5.0) and b.target<0 and b.leader!=b.id:
		var spot := _behind(lead_at,lead_forward)
		if spot.is_finite():
			b.body.global_position = spot
			b.body.reset_physics_interpolation()
			b.path.clear()
			b.stuck = 0.0

func _spotted(b: Bot, count: int) -> void:
	if count>=5: say(b,"horde",false,12.0)
	else: say(b,"spotted",false,8.0)

func _reload(b: Bot, p: Dictionary, loud: bool) -> void:
	if b.reserve<=0 or b.mag>=int(b.gun.mag): return
	b.reload_left = float(b.gun.reload)
	p.reloading = true
	if loud: say(b,"reloading",false,5.0)

func _nearest_to(at: Vector3) -> float:
	var best := INF
	for k: int in mission.enemies:
		var z = mission.enemies[k]
		if not z.dead and z.hp>0: best = minf(best,at.distance_to(z.global_position))
	return best

func _downed(b: Bot) -> int:
	var best := 0
	var near := 30.0
	for id: int in session.team:
		if id==b.id or session.team[id].hp>0: continue
		var d: float = b.body.global_position.distance_to(session.team[id].pos)
		if d<near:
			near = d
			best = id
	return best

## Somewhere a step or three away with more room from all of them, and not away from the team.
func _escape(b: Bot, lead_at: Vector3) -> Vector3:
	var me := b.body.global_position
	var best := me
	var score := -INF
	for i in 12:
		var a := TAU*i/12.0
		var way := Vector3(sin(a),0,cos(a))
		var to := me+way*3.2
		if not _clear(me+Vector3.UP*.6,to+Vector3.UP*.6): continue
		var cell := InteriorZombieNav.cell_of(to)
		if is_nan(mission.nav.floor_at(cell,to.y+.2)): continue
		var s := 0.0
		for k: int in mission.enemies:
			var z = mission.enemies[k]
			if z.dead or z.hp<=0: continue
			var d: float = to.distance_to(z.global_position)
			if d<12.0: s += minf(d,8.0)-8.0
		s -= maxf(0.0,to.distance_to(lead_at)-4.0)*.7
		if s>score:
			score = s
			best = to
	return best

## Ammunition (always, when `needed`), a rifle, or a healthkit within reach.
func _supply(b: Bot, needed: bool) -> Vector3:
	var me := b.body.global_position
	var p: Dictionary = session.team[b.id]
	var best := Vector3.INF
	var near := 18.0
	for k: int in mission.drops:
		var kind: String = mission.drops[k][1]
		var at: Vector3 = mission.drops[k][0]
		var d := me.distance_to(at)
		var wanted: bool = (kind.begins_with("ammo") and (needed or b.mag+b.reserve<int(b.gun.mag)*3)) or (kind.begins_with("healthkit") and p.kits<2 and not needed)
		if not wanted: continue
		if d<12.0 and not b.said.has("drop%d"%k):
			b.said["drop%d"%k] = 0
			say(b,"ammo" if kind.begins_with("ammo") else "medkit",false,6.0)
		if d<near:
			near = d
			best = at
	if mission.stage in [4,5]:
		if not b.gun.rifle:
			for i in mission.street.rifles.size():
				if mission.flags.get("rifle%d"%i,false): continue
				var at: Vector3 = mission.street.rifles[i].global_position
				var d := me.distance_to(at)
				if d<14.0 and not b.said.has("guns"):
					b.said["guns"] = 0
					say(b,"guns",false)
				if d<near:
					near = d
					best = at
		if needed or b.mag+b.reserve<int(b.gun.mag)*2:
			var counter: Vector3 = Street.ORIGIN+Street.COUNTER+Vector3(1.6,0,2.8)
			if me.distance_to(counter)<near: best = counter
	return best

func _pick_up(b: Bot) -> void:
	var action: String = mission.candidate(b.id)
	if action.begins_with("drop") or action.begins_with("rifle") or action=="ammo":
		mission.interact(b.id,action)

func _behind(lead_at: Vector3, forward: Vector3) -> Vector3:
	for back in [2.2,3.0,1.6]:
		var at: Vector3 = mission.ground(lead_at-forward*back)
		if at.is_finite() and _clear(lead_at+Vector3.UP,at+Vector3.UP): return at
	return Vector3.INF

## What a reward does for a squad member (session.gd `reward`).
func reward(id: int, what: String) -> void:
	var b: Bot = bots.get(id)
	if b==null: return
	match what:
		"rifle":
			b.gun = RIFLE
			b.mag = 30
			b.reserve = 150
		"ammo", "ammo:small", "ammo:medium", "ammo:large": b.reserve += {"ammo:small":12,"ammo:large":60}.get(what,24)
		"refill":
			b.reserve = 300 if b.gun.rifle else 180
			b.mag = int(b.gun.mag)

## An order from the voice menu: `key` said by `speaker`.
func heard(speaker: int, key: String) -> void:
	if not session.team.has(speaker): return
	var at: Vector3 = session.team[speaker].pos
	var replied := false
	for b: Bot in bots.values():
		if b.id==speaker or session.team[b.id].hp<=0: continue
		var d: float = b.body.global_position.distance_to(at)
		if d>45.0: continue
		var order := ""
		match key:
			"hold": order = "hold"
			"follow","lets_go": order = "follow"
			"backup","fall_back": order = key
			"check":
				order = "check"
				var look := Vector3(-sin(float(session.team[speaker].yaw)),0,-cos(float(session.team[speaker].yaw)))
				var to: Vector3 = mission.ground(at+look*5.0)
				at = to if to.is_finite() else at
			"spotted","behind":
				# Turn and look where the speaker is looking.
				b.face = Vector3(-sin(float(session.team[speaker].yaw)),0,-cos(float(session.team[speaker].yaw)))
			"no_ammo","low_ammo":
				b.leader = speaker
		if order=="": continue
		b.order = order
		b.leader = speaker
		b.order_at = b.body.global_position if order=="hold" else at
		b.order_until = Time.get_ticks_msec()+(30000 if order=="hold" else 15000)
		b.think = 0.0
		if not replied:
			replied = true
			say(b,"copy",false,2.0)

# ---------------------------------------------------------------- moving

## 0.49: a human teammate close by with a healthkit, looking at this one: it waits for them rather than spend its own.
func _medic_near(b: Bot) -> bool:
	for id: int in session.team:
		if id==b.id or session.is_bot(id): continue
		var t: Dictionary = session.team[id]
		if int(t.hp)>0 and int(t.kits)>0 and t.pos.distance_to(b.body.global_position)<2.6: return true
	return false

func _move(b: Bot, p: Dictionary, delta: float) -> void:
	var me := b.body.global_position
	# 0.50: in the school, the next point on the open stair when what it heads for is on another floor; 0.63: multi-tier Outer Street steering.
	var dest: Vector3 = b.dest
	# 0.68: the hospital's floors.
	if mission.stage==mission.HOSPITAL and mission.hospital!=null: dest = mission.hospital.steer(me,b.dest,mission.flags)
	elif mission.stage>=16 and mission.outer_street!=null: dest = mission.outer_street.steer(me,b.dest,mission.flags)
	elif mission.school!=null: dest = mission.school.steer(me,b.dest)
	# 0.51: the maintenance ladder is climbed by hand; in the duct it goes on hands and knees.
	if mission.stage<16 and mission.school!=null and mission.school.carry(b.body,dest,delta):
		p.clip = "walk"
		b.last_at = b.body.global_position
		b.stuck = 0.0
		return
	var crawl: bool = mission.stage<16 and mission.school!=null and mission.school.in_duct(me)
	var to := dest-me
	to.y = 0
	var wish := Vector3.ZERO
	var close := .55 if b.mode=="follow" else .3
	if to.length()>close:
		var step := dest
		# The straight way, looked at a few times a second.
		b.straight_wait -= delta
		if b.straight_wait<=0.0 or b.straight_to.distance_to(dest)>.8:
			b.straight_wait = .2
			b.straight_to = dest
			b.straight = _clear(me+Vector3.UP*.45,dest+Vector3.UP*.45) and _clear(me+Vector3.UP*1.1,dest+Vector3.UP*1.1)
		var straight := b.straight
		if straight or dest.distance_to(me)<1.2:
			b.path.clear()
		else:
			b.path_wait -= delta
			if (b.path.is_empty() or b.path_goal.distance_to(dest)>2.0 or b.stuck>.8) and b.path_wait<=0.0 and _searches<1:
				_searches += 1
				# (0.67: at most 4 ms of a tick: over ground never read (just after a jump or a teleport) one search ran
				# 20-50 ms. Out of time, it keeps its way and tries again next tick; what it read is remembered.)
				var nav = mission.nav
				nav.search_aborted = false
				nav.search_deadline = Time.get_ticks_usec()+4000
				var found: PackedVector3Array = nav.path(me,dest)
				nav.search_deadline = 0
				if nav.search_aborted:
					nav.search_aborted = false
					b.path_wait = .05
				else:
					b.path = found
					b.path_goal = dest
					b.path_wait = .7
			while not b.path.is_empty() and Vector2(b.path[0].x-me.x,b.path[0].z-me.z).length()<.5: b.path.remove_at(0)
			if not b.path.is_empty(): step = b.path[0]
		wish = Vector3(step.x-me.x,0,step.z-me.z).normalized()
	# Room for the others: never stand in a teammate.
	for id: int in session.team:
		if id==b.id: continue
		var off: Vector3 = me-session.team[id].pos
		off.y = 0
		if off.length()<.9 and off.length()>.001: wish += off.normalized()*(.9-off.length())*1.6
	var speed := InteriorPlayer.RUN_SPEED if b.run else InteriorPlayer.WALK_SPEED
	if b.mode=="kite" or (b.mode=="retreat" and b.target>=0): speed = InteriorPlayer.WALK_SPEED*1.15
	if p.hp<=Mission.CRITICAL_HP: speed *= .64
	if crawl: speed = InteriorPlayer.CROUCH_SPEED
	# 0.52: crouched past the horde (walking is heard).
	var low: bool = mission.quiet() and b.target<0
	if low: speed = InteriorPlayer.CROUCH_SPEED
	# 0.46: being patched up by a teammate: stands still for it. 0.49: any patch-up, either end, and at once (no
	# slide from the pace it had), and no stepping aside for the teammate leaning in to do it.
	var patching: bool = bool(p.get("held",false)) or mission.in_heal(b.id)
	if patching:
		speed = 0.0
		wish = Vector3.ZERO
	if wish.length()>1.0: wish = wish.normalized()
	var v := b.body.velocity
	if patching:
		v.x = 0.0
		v.z = 0.0
	var target_v := wish*speed
	v.x = move_toward(v.x,target_v.x,22.0*delta)
	v.z = move_toward(v.z,target_v.z,22.0*delta)
	v.y = 0.0 if b.body.is_on_floor() else v.y-16.0*delta
	b.body.velocity = v
	b.body.move_and_slide()
	if b.body.is_on_wall() and wish.length()>.1:
		# A kerb or a stair: up onto it.
		var ahead := b.body.global_position+wish*.38
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*.5,ahead+Vector3.DOWN*.1,2))
		if not hit.is_empty() and hit.position.y-b.body.global_position.y>.03 and hit.position.y-b.body.global_position.y<.45:
			b.body.global_position.y = hit.position.y+.02
	var moved := Vector2(b.body.global_position.x-b.last_at.x,b.body.global_position.z-b.last_at.z).length()
	b.stuck = b.stuck+delta if wish.length()>.3 and moved<speed*delta*.2 else maxf(0.0,b.stuck-delta*2.0)
	b.last_at = b.body.global_position
	var planar := Vector2(v.x,v.z).length()
	p.clip = "walk_hurt" if planar>.2 and p.hp<=Mission.CRITICAL_HP else ("run" if planar>3.0 else ("walk" if planar>.2 else "idle"))
	if low and planar>.12: p.clip = "crouch_walk"
	if crawl: p.clip = "crawl" if planar>.12 else "down_idle"
	if b.target<0:
		var look := b.face if b.face.length()>.1 else (Vector3(v.x,0,v.z) if planar>.6 else Vector3.ZERO)
		if look.length()>.1: b.yaw = lerp_angle(b.yaw,atan2(-look.x,-look.z),1.0-exp(-6.0*delta))
		b.pitch = lerpf(b.pitch,-.08,1.0-exp(-4.0*delta))

# ---------------------------------------------------------------- shooting

func _aim_and_fire(b: Bot, p: Dictionary, delta: float, now: float) -> void:
	if b.target<0 or not mission.enemies.has(b.target): return
	var z = mission.enemies[b.target]
	if z.dead or z.hp<=0:
		b.target = -1
		return
	var eye := _eye(b)
	var close := eye.distance_to(z.global_position)
	var aim_point: Vector3 = z.global_position+Vector3.UP*(1.5 if close<9.0 and b.skill>.82 else 1.12)
	var to := aim_point-eye
	var want_yaw := atan2(-to.x,-to.z)
	var want_pitch := atan2(to.y,Vector2(to.x,to.z).length())
	b.yaw = lerp_angle(b.yaw,want_yaw,1.0-exp(-(9.0+b.skill*5.0)*delta))
	b.pitch = lerpf(b.pitch,want_pitch,1.0-exp(-10.0*delta))
	if b.reload_left>0.0 or b.mag<=0 or now<b.next_shot: return
	# A moment to settle on someone new.
	if now-b.target_seen<lerpf(.45,.2,b.skill): return
	if absf(angle_difference(b.yaw,want_yaw))>.22: return
	# Never with a friend in the way.
	var line := to.normalized()
	for id: int in session.team:
		if id==b.id or session.team[id].hp<=0: continue
		var mate: Vector3 = session.team[id].pos+Vector3.UP*1.1
		var along := (mate-eye).dot(line)
		if along>0.0 and along<close and mate.distance_to(eye+line*along)<.65:
			b.next_shot = now+.2
			return
	if not _sight(eye,aim_point): return
	# The spread: steadier standing, worse running, at range and in a hurry.
	var moving := Vector2(b.body.velocity.x,b.body.velocity.z).length()/InteriorPlayer.RUN_SPEED
	var cone := lerpf(.05,.014,b.skill)*(1.0+moving*1.4)*(1.0+close/30.0)
	var basis := Basis.looking_at(line,Vector3.UP if absf(line.y)<.98 else Vector3.BACK)
	var around := randf()*TAU
	var out := cone*sqrt(randf())
	var dir := -(basis*Basis(Vector3.UP,cos(around)*out)*Basis(Vector3.RIGHT,sin(around)*out)).z
	b.mag -= 1
	b.next_shot = now+float(b.gun.interval)*randf_range(.9,1.25)
	if b.gun.rifle:
		b.burst += 1
		if b.burst>=randi_range(3,5):
			b.burst = 0
			b.next_shot += randf_range(.25,.45)
	mission.fired(b.id)
	# (0.49: the same world a player's round meets: through walking boxes, onto what is drawn.)
	var hit := InteriorSurfaces.seen_ray(get_world_3d().direct_space_state,eye,eye+dir*80.0,2|InteriorZombie.HITBOX|InteriorModelKit.SHOT_LAYER)
	if hit.is_empty() or not (hit.collider as Node).has_meta("zombie"): return
	var who: Object = hit.collider.get_meta("zombie")
	if not is_instance_valid(who) or who.get("key")==null: return
	var bone := str(hit.collider.get_meta("bone","chest"))
	var dealt := float(b.gun.damage)*float((InteriorZombie.BODIES.get(bone,[0,0,0,0,0,1.0]) as Array)[5])
	mission.damage(b.id,int(who.get("key")),bone,hit.position,dir,dealt,float(b.gun.knock))

## Someone in the squad says `key`. Squad lines are spaced out so they never talk over each other.
func say(b: Bot, key: String, urgent := false, gap := 7.0) -> void:
	var now := Time.get_ticks_msec()
	if float(b.said.get(key,-100000))+gap*1000.0>now and not urgent: return
	if now<_said_at and not urgent: return
	b.said[key] = now
	_said_at = now+LINES_GAP
	session.speak_all(b.id,key)
