extends Node3D

const WEST = -16.9
const EAST = 4.45
const JUNCTION = -10.5
const SOUTH = 7.2
const NORTH = -2.65
const SHOT_INTERVAL = 8.0
const REACH = 5.3
const DAMAGE = 2
const EAST_PATH = [Vector2(JUNCTION,SOUTH),Vector2(4.45,7.2),Vector2(4.45,1.65),Vector2(8.5,1.65),Vector2(8.5,-3.6)]
var map
var legs: Array[Node3D] = []
var shoulders: Node3D
var muzzle: Node3D
var report = AudioStreamPlayer.new()
var stride = 0.0
var cooldown = 0.0
var destination = Vector2(JUNCTION,2.0)
var rethink = 0.0
var target = {}
var aim_time = 0.0
var flash_time = 0.0

func setup(scenery,game):
	name = "NightWatchman"
	map = game
	position = Vector3(WEST,0.025,7.2)
	rotation.y = PI/2
	for side in [-1,1]:
		var leg = scenery.limb(self,Vector3(side*0.086,0.41,0))
		legs.append(leg)
		scenery.box(leg,Vector3.DOWN*0.16,Vector3(0.115,0.34,0.13),"494453")
		scenery.box(leg,Vector3(0,-0.345,0.035),Vector3(0.135,0.13,0.22),"373337")
	scenery.cone(self,Vector3.UP*0.57,0.23,0.155,0.48,8,"474452")
	for h in [0.49,0.58,0.67]:
		scenery.oval(self,Vector3(0.035,h,0.20-(h-0.49)*0.14),Vector3.ONE*0.032,"b49b79")
	shoulders = scenery.limb(self,Vector3.UP*0.73)
	scenery.oval(shoulders,Vector3.UP*0.045,Vector3(0.41,0.32,0.29),"514b58")
	scenery.oval(shoulders,Vector3(0,0.285,0.015),Vector3(0.237,0.285,0.22),"ba9983")
	scenery.oval(shoulders,Vector3(0,0.239,0.09),Vector3(0.189,0.105,0.091),"746762")
	scenery.oval(shoulders,Vector3(0,0.291,0.128),Vector3(0.048,0.063,0.054),"b2937c")
	for side in [-1,1]:
		scenery.box(shoulders,Vector3(side*0.051,0.315,0.112),Vector3(0.032,0.022,0.022),"39343b")
	scenery.cone(shoulders,Vector3.UP*0.385,0.209,0.193,0.034,12,"3a3540")
	scenery.cone(shoulders,Vector3.UP*0.447,0.151,0.116,0.12,10,"504956")
	scenery.cone(shoulders,Vector3.UP*0.18,0.145,0.126,0.095,8,"795e56")
	var stock = scenery.limb(shoulders,Vector3(0.096,0.004,0.12))
	scenery.box(stock,Vector3(0,0,-0.06),Vector3(0.093,0.093,0.25),"8b694d","wood")
	for side in [-1,1]:
		scenery.box(stock,Vector3(side*0.032,0.031,0.22),Vector3(0.055,0.055,0.41),"787780")
		var hand = Vector3(0.091,0.01,0.23 if side < 0 else 0.08)
		var elbow = Vector3(side*0.206,-0.085,0.035)
		scenery.segment(shoulders,Vector3(side*0.157,0.085,0),elbow,0.076,0.060,"504b58","")
		scenery.segment(shoulders,elbow,hand,0.059,0.042,"504b58","")
		scenery.oval(shoulders,hand,Vector3.ONE*0.093,"b69b86")
	muzzle = scenery.limb(stock,Vector3(0,0.03,0.48))
	var flare = scenery.oval(muzzle,Vector3.ZERO,Vector3(0.17,0.17,0.27),"ffd991")
	var ember = flare.material_override.duplicate()
	ember.emission_enabled = true
	ember.emission = Color("ffc472")
	flare.material_override = ember
	muzzle.hide()
	add_child(report)
	report.stream = preload("res://assets/audio/sfx/mortar_launch.wav")
	report.bus = &"Effects"
	report.pitch_scale = 1.45
	report.volume_db = -12
	scale = Vector3.ONE*1.15

func _process(delta):
	if map.finished:
		muzzle.hide()
		return
	flash_time = maxf(0,flash_time-delta)
	muzzle.visible = flash_time > 0
	cooldown = maxf(0,cooldown-delta)
	if map.fighting:
		if cooldown <= 0.45 and target.is_empty():
			var nearest = REACH*REACH
			for mob in map.enemies:
				var distance = position.distance_squared_to(mob.node.position)
				if distance < nearest:
					nearest = distance
					target = mob
			aim_time = 0.0
	if not target.is_empty():
		if not map.enemies.has(target) or position.distance_to(target.node.position)>REACH:
			target = {}
		else:
			var offset: Vector3 = target.node.position-position
			rotate_towards_heading(atan2(offset.x,offset.z),delta)
			shoulders.rotation.x = move_toward(shoulders.rotation.x,0.06,delta*1.6)
			aim_time += delta
			if cooldown <= 0 and aim_time >= 0.45 and absf(angle_difference(rotation.y,atan2(offset.x,offset.z))) < 0.12:
				report.play()
				flash_time = 0.13
				muzzle.show()
				shoulders.rotation.x = -0.17
				cooldown = SHOT_INTERVAL
				show_hit(target)
				map.damage_enemy(target,DAMAGE)
				target = {}
			return
	shoulders.rotation.x = move_toward(shoulders.rotation.x,0.26,delta*1.5)
	rethink -= delta
	if rethink <= 0:
		rethink = 0.75
		destination = wave_lookout()
	var here = Vector2(position.x,position.z)
	var waypoint = patrol_waypoint(here,destination)
	var next = here.move_toward(waypoint,delta*0.95)
	if next != here:
		var step = next-here
		rotate_towards_heading(atan2(step.x,step.y),delta)
		position.x = next.x
		position.z = next.y
		stride += step.length()*7.0
	for i in 2:
		legs[i].rotation.x = sin(stride)*(0.37 if i==0 else -0.37) if next != here else 0.0

func wave_lookout() -> Vector2:
	if map.enemies.is_empty():
		return Vector2(JUNCTION,2.0)
	# Follow the middle of the pack and look ahead along the actual bends.
	var progress: Array[float] = []
	for mob in map.enemies:
		progress.append(mob.progress)
	progress.sort()
	var cell: Vector2i = map.route[mini(roundi(progress[progress.size() >> 1]+2.5),map.route.size()-1)]
	var wave = Vector2(cell)
	var avenue = Vector2(JUNCTION,clampf(wave.y,NORTH,SOUTH))
	var path = Vector2(clampf(wave.x,WEST,EAST),SOUTH)
	var best = avenue if avenue.distance_squared_to(wave)<path.distance_squared_to(wave) else path
	for i in EAST_PATH.size()-1:
		var candidate = Geometry2D.get_closest_point_to_segment(wave,EAST_PATH[i],EAST_PATH[i+1])
		if candidate.distance_squared_to(wave) < best.distance_squared_to(wave):
			best = candidate
	return best

func show_hit(mob):
	var point: Vector3 = mob.body.global_position+Vector3.UP*mob.body.scale.y*0.46
	var start = muzzle.global_position
	var effects = map.group(point)
	var trace = map.box(effects,(start-point)*0.5,Vector3(0.026,0.026,maxf(start.distance_to(point),0.01)),"ffe5a4")
	if not trace.global_position.is_equal_approx(point):
		trace.look_at(point)
	var spark = map.oval(effects,Vector3.ZERO,Vector3.ONE*0.22,"ffe5a4")
	var light = muzzle.get_child(0).material_override
	spark.material_override = light
	trace.material_override = light
	var fade = effects.create_tween()
	fade.tween_interval(0.065)
	fade.tween_callback(trace.hide)
	fade.tween_property(spark,"scale",Vector3.ONE*0.025,0.14)
	fade.tween_callback(effects.queue_free)

func rotate_towards_heading(yaw: float,delta: float):
	rotation.y = rotate_toward(rotation.y,yaw,3.4*delta)

func east_distance(point: Vector2) -> float:
	var best_distance = INF
	var result = 0.0
	var walked = 0.0
	for i in EAST_PATH.size()-1:
		var closest = Geometry2D.get_closest_point_to_segment(point,EAST_PATH[i],EAST_PATH[i+1])
		if point.distance_squared_to(closest) < best_distance:
			best_distance = point.distance_squared_to(closest)
			result = walked + EAST_PATH[i].distance_to(closest)
		walked += EAST_PATH[i].distance_to(EAST_PATH[i+1])
	return result

func patrol_waypoint(here: Vector2, goal: Vector2) -> Vector2:
	var junction = Vector2(JUNCTION,SOUTH)
	if here.x > JUNCTION+0.01 or goal.x > JUNCTION+0.01:
		if here.x <= JUNCTION+0.01 and here.distance_to(junction)>0.01:
			return junction
		var from = east_distance(here)
		var to = east_distance(goal)
		var walked = 0.0
		var previous = junction
		for i in EAST_PATH.size():
			if i > 0:
				walked += EAST_PATH[i-1].distance_to(EAST_PATH[i])
			if to > from and walked > from+0.01 and walked < to:
				return EAST_PATH[i]
			if to < from and walked >= from-0.01:
				return previous if east_distance(previous) > to else (junction if goal.x <= JUNCTION else goal)
			previous = EAST_PATH[i]
		if here.x <= JUNCTION and here.distance_to(junction)>0.01:
			return junction
		return goal
	if not is_equal_approx(here.x,goal.x) and not is_equal_approx(here.y,goal.y):
		return junction
	return goal
