extends RefCounted

const HEALTH = [
	[7,9,11,13,16,19,22,26,30,35,40,46],
	[8,10,13,16,20,24,28,33,38,44,51,58],
	[9,12,15,18,22,27,32,38,44,51,58,66],
	[9,12,16,21,26,32,38,45,53,62,72,84,98,114],
	[10,13,17,21,27,33,40,48,57,67,78,90,104,120,138]]
const WEAPON_HEALTH = [1.04,1.09,1.0,0.95]
const FLIGHT_TIME = 0.95
const FLIGHT_SPEED = 3.1

static func base_gargoyle_hp(map) -> int:
	var factor = 4.6 if map.cemetery_stage == 5 else 5.4
	return roundi(map.health_table[map.wave-1]*factor)

static func gargoyle_hp(map) -> int:
	if map.cemetery_stage == 2:
		return 110 if map.wave < 9 else (190 if map.wave < 12 else 280)
	if map.cemetery_stage == 3:
		return 190 if map.wave < 9 else (280 if map.wave < 12 else 430)
	if map.cemetery_stage == 4:
		return base_gargoyle_hp(map) - 10
	if map.cemetery_stage == 5 and map.wave in [5,9]:
		return base_gargoyle_hp(map)
	return base_gargoyle_hp(map) + (50 if map.cemetery_stage == 1 else 100)

static func reaper_hp(map) -> float:
	return 2.5*base_gargoyle_hp(map) + 100

static func spawn(map):
	var chapter: int = map.cemetery_stage-1
	var kind = "skeleton"
	var first_boss_wave = 7 if map.cemetery_stage == 1 else 5
	var boss_wave = map.wave in [first_boss_wave,9,12] or map.wave == map.wave_count
	var final_pair = chapter >= 3 and map.wave == map.wave_count and map.remaining == 14
	if (boss_wave and map.remaining == 1) or final_pair:
		kind = "gargoyle"
	elif map.wave >= 2 and (map.remaining+map.wave)%4 == 0:
		kind = "zombie"
	var weapon = (map.remaining+map.wave+chapter)%4
	var factor: float = WEAPON_HEALTH[weapon]
	var speed = 1.40
	if kind == "zombie":
		factor = 2.45
		speed = 0.86
	elif kind == "gargoyle":
		speed = 1.13
	var hp = gargoyle_hp(map) if kind == "gargoyle" else maxi(1,roundi(map.health_table[map.wave-1]*factor)) + map.enemy_health_bonus()
	var root = map.group(map.ground(map.route.front()))
	var mob = build_model(map,root,kind,weapon)
	mob.merge({"kind":kind,"brute":kind != "skeleton","ogre":kind == "gargoyle","hp":hp,"max_hp":hp,
		"speed":speed,"progress":0.0,"phase":map.rng.randf()*TAU,"flight":0.0,"rest":4.8})
	return mob

static func build_model(map,root,kind: String,weapon: int = -1):
	var body = map.limb_joint(root,Vector3.ZERO)
	var chest = map.limb_joint(body,Vector3.UP*0.37)
	var mob = {"node":root,"body":body,"chest":chest,"arms":[],"legs":[],"wings":[]}
	var skin = {"skeleton":"dfd9be","zombie":"82937c","gargoyle":"797887"}[kind]
	var bone = kind == "skeleton"
	for side in [-1,1]:
		var leg = map.limb_joint(body,Vector3(side*0.10,0.37,0))
		var arm = map.limb_joint(chest,Vector3(side*0.20,0.22,0))
		mob.legs.append(leg)
		mob.arms.append(arm)
		var thick = 0.067 if bone else 0.15
		for joint in [leg,arm]:
			map.box(joint,Vector3.DOWN*0.085,Vector3(thick,0.17,thick),skin)
			map.oval(joint,Vector3.DOWN*0.18,Vector3.ONE*(thick+0.034),skin)
			if kind != "gargoyle" and joint == arm and side == 1:
				var elbow = map.limb_joint(arm,Vector3.DOWN*0.18)
				mob["right_elbow"] = elbow
				map.box(elbow,Vector3(0,-0.075,0.02),Vector3(thick,0.16,thick),skin)
				map.box(elbow,Vector3(0,-0.168,0.025),Vector3(0.063,0.066,0.042),skin)
			else:
				map.box(joint,Vector3(0,-0.255,0.02),Vector3(thick,0.16,thick),skin)
		map.box(leg,Vector3(0,-0.34,0.037),Vector3(thick+0.04,0.08,0.17),skin)
	if bone:
		map.box(chest,Vector3.UP*0.11,Vector3(0.075,0.34,0.08),skin)
		for row in 3:
			map.box(chest,Vector3.UP*(0.08+row*0.075),Vector3(0.27+0.028*row,0.043,0.15),skin)
		map.box(chest,Vector3.DOWN*0.018,Vector3(0.24,0.095,0.14),skin)
		if weapon >= 0:
			add_weapon(map,mob.arms[0],weapon)
	else:
		map.box(chest,Vector3.UP*0.11,Vector3(0.40,0.37,0.25),"685461" if kind == "zombie" else skin)
		map.box(chest,Vector3(0,0.02,0.13),Vector3(0.36,0.055,0.025),"514650")
	var head = map.limb_joint(chest,Vector3.UP*0.37)
	mob["head"] = head
	map.box(head,Vector3.ZERO,Vector3(0.29,0.23,0.24),skin)
	map.box(head,Vector3(0,-0.12,0.034),Vector3(0.20,0.075,0.18),skin)
	for side in [-1,1]:
		map.box(head,Vector3(side*0.077,0.018,0.12),Vector3(0.074,0.057,0.022),"382f3d" if bone else "d8ad69")
	if kind == "zombie":
		body.scale = Vector3(1.22,1.13,1.18)
		map.box(head,Vector3(0.01,0.101,-0.008),Vector3(0.30,0.067,0.25),"51484b")
	elif kind == "gargoyle":
		body.scale = Vector3.ONE*1.55
		map.oval(head,Vector3(0,-0.055,0.12),Vector3(0.20,0.11,0.17),skin)
		for side in [-1,1]:
			map.box(head,Vector3(side*0.078,0.061,0.116),Vector3(0.14,0.044,0.065),skin).rotation.z = side*0.28
			map.cone(head,Vector3(side*0.11,0.17,-0.03),0.065,0,0.20,5,skin).rotation.z = -side*0.4
			var wing = map.limb_joint(chest,Vector3(side*0.16,0.20,-0.12))
			mob.wings.append(wing)
			add_wing(map,wing,side)
		var plain = map.mat(skin)
		for piece in body.find_children("*","MeshInstance3D",true,false):
			if piece.material_override == plain:
				piece.material_override = map.mat(skin,"concrete")
	return mob

static func add_weapon(map,arm,index):
	var grip = map.limb_joint(arm,Vector3(0,-0.33,0.07))
	grip.rotation.x = 0.95
	map.box(grip,Vector3.UP*0.19,Vector3(0.041,0.62,0.045),"745740","wood")
	var steel = "b0b6bd"
	match index:
		0:
			map.box(grip,Vector3.UP*0.09,Vector3(0.20,0.05,0.055),steel)
			map.cone(grip,Vector3.UP*0.34,0.074,0.017,0.49,4,steel)
		1:
			for side in [-1,1]:
				map.cone(grip,Vector3(0,0.48,side*0.10),0.055,0.008,0.23,4,steel).rotation.x = side*1.90
		2:
			map.box(grip,Vector3.UP*0.51,Vector3(0.18,0.17,0.044),steel)
			map.cone(grip,Vector3.UP*0.625,0.105,0.035,0.08,4,steel)
		3:
			map.box(grip,Vector3.UP*0.48,Vector3(0.29,0.045,0.04),steel)
			for x in [-0.12,-0.04,0.04,0.12]:
				map.box(grip,Vector3(x,0.55,0.018),Vector3(0.025,0.15,0.034),steel)

static func add_wing(map,wing,side):
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim = [Vector3(0,0.03,0),Vector3(0.16,0.31,-0.06),Vector3(0.35,0.49,-0.11),
		Vector3(0.52,0.46,-0.21),Vector3(0.67,0.34,-0.32),Vector3(0.76,0.15,-0.45)]
	var hem = [Vector3(0,-0.10,0),Vector3(0.16,-0.035,-0.19),Vector3(0.30,-0.15,-0.32),
		Vector3(0.46,0.065,-0.34),Vector3(0.60,-0.01,-0.44),rim.back()]
	for i in rim.size()-1:
		var triangles = [rim[i],hem[i],rim[i+1]]
		if i < rim.size()-2:
			triangles.append_array([rim[i+1],hem[i],hem[i+1]])
		for j in range(0,triangles.size(),3):
			for index in [0,1,2,2,1,0]:
				mesh.add_vertex(triangles[j+index]*Vector3(side,1,1))
		var a: Vector3 = rim[i]*Vector3(side,1,1)
		var b: Vector3 = rim[i+1]*Vector3(side,1,1)
		var rib = map.box(wing,(a+b)*0.5,Vector3(0.044,0.046,a.distance_to(b)),"96909d","concrete")
		rib.look_at(wing.to_global(b))
	mesh.generate_normals()
	map.mesh_part(wing,mesh.commit(),Vector3.ZERO,"737281","concrete")

static func tick_flight(mob,delta):
	if mob.flight > 0:
		mob.flight = maxf(0,mob.flight-delta)
	else:
		mob.rest -= delta
		if mob.rest <= 0:
			mob.flight = FLIGHT_TIME
			mob.rest = 5.4

static func animate(mob,shielding: bool):
	if mob.kind == "death":
		var sway = sin(mob.progress*4.0)
		mob.body.position.y = 0.07+0.055*sway+(0.14 if mob.in_spirit else 0.0)
		mob.chest.rotation.z = 0.04*sway
		mob.arms[0].rotation.x = -0.19+0.10*sway
		return
	var phase: float = mob.phase + mob.progress*TAU/(1.05 if mob.brute else 0.78)
	var step = sin(phase)
	var lift = 0.0
	if mob.flight > 0:
		lift = sin(PI*mob.flight/FLIGHT_TIME)
	mob.body.position.y = absf(step)*0.025 + lift*0.85
	for i in 2:
		var swing = step*(1 if i == 0 else -1)
		mob.legs[i].rotation.x = swing*0.52*(1-lift)+lift*0.70
		if mob.kind == "zombie":
			mob.arms[i].rotation.x = -1.35+swing*0.16
		else:
			mob.arms[i].rotation.x = -0.25-swing*0.41
	mob.chest.rotation.z = step*(0.10 if mob.kind == "zombie" else 0.04)
	mob.chest.rotation.x = 0.18 if mob.brute else 0.06
	if mob.kind != "gargoyle":
		mob.arms[1].rotation = Vector3(mob.arms[1].rotation.x,0,0)
		mob.right_elbow.rotation = Vector3.ZERO
		if shielding:
			var upper = Quaternion(Vector3.DOWN,Vector3(-0.045,0.055,0.18).normalized())
			mob.arms[1].quaternion = upper
			mob.right_elbow.quaternion = Quaternion(Vector3.DOWN,upper.inverse()*Vector3(-0.21,0.09+0.012*step,0.01).normalized())
			mob.chest.rotation.x = 0.43+0.06*absf(step)
			for leg in mob.legs:
				leg.rotation.x *= 0.6
	for i in mob.wings.size():
		var flap = 0.25 if mob.flight <= 0 else -0.29+0.46*cos(3*TAU*mob.flight/FLIGHT_TIME)
		mob.wings[i].rotation.y = (1 if i == 0 else -1)*flap
