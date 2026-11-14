extends Node3D

@onready var map = get_parent()
var random = RandomNumberGenerator.new()
var bird_delay = 3.0
var squirrel_delay = 8.0
var snake_delay = 5.0
var mole_delay = 7.0
var last_burrow = -1
const BURROWS = [Vector2(3.3,3.6),Vector2(-6.3,-2.1),Vector2(0.2,-7.2),Vector2(2.8,7.5)]
var last_trail = {}

const HILLSIDE_TRAILS = [
	[Vector2(-8.3,-4.55), Vector2(5.2,-4.55)],
	[Vector2(-8.3,4.55), Vector2(5.2,4.55)],
	[Vector2(-8.95,-4.45), Vector2(-8.95,0.75)],
]
const VALLEY_TRAILS = [
	[Vector2(-8.95,-7.5), Vector2(-8.95,6.1)],
	[Vector2(8.95,-4.8), Vector2(8.95,-0.7)],
	[Vector2(-3.9,6.0), Vector2(6.8,6.0)],
]
const THREE_FIELDS_TRAILS = [
	[Vector2(-7.8,-9.55), Vector2(-2.6,-9.55)],
	[Vector2(-8.0,9.4), Vector2(-2.0,9.4)],
	[Vector2(-9.55,-4.6), Vector2(-9.55,1.2)],
]

func _ready():
	var sheep = pivot(self, Vector3(6.65,0.02,2.85))
	var legs = []
	for x in [-0.12, 0.12]:
		for z in [-0.17, 0.17]:
			var hip = pivot(sheep, Vector3(x,0.21,z))
			map.box(hip,Vector3(0,-0.10,0),Vector3(0.085,0.22,0.085),"50473d")
			legs.append(hip)
	var fleece = SphereMesh.new()
	fleece.radius = 0.26
	fleece.height = 0.43
	fleece.radial_segments = 8
	fleece.rings = 4
	map.mesh_part(sheep,fleece,Vector3.UP*0.31,"eee3c9").scale.z = 1.5
	map.mesh_part(sheep,fleece,Vector3(0,0.32,-0.35),"d8ccb4").scale = Vector3.ONE*0.38
	var neck = pivot(sheep, Vector3(0,0.34,0.25))
	map.box(neck,Vector3(0,0.03,0.11),Vector3(0.20,0.22,0.25),"615648")
	for side in [-1,1]:
		map.box(neck,Vector3(side*0.13,0.09,0.10),Vector3(0.11,0.06,0.08),"716256")
		map.box(neck,Vector3(side*0.102,0.055,0.17),Vector3(0.015,0.032,0.03),"302e2b")
	var pasture = [sheep.position, Vector3(6.32,0.02,3.58), Vector3(7.62,0.02,3.65),
		Vector3(8.46,0.02,3.36)]
	var routine = sheep.create_tween().set_loops()
	for i in pasture.size():
		for bite in 2:
			routine.tween_property(neck,"rotation:x",1.0,0.85)
			routine.tween_interval(1.3 + 0.25 * i)
			routine.tween_property(neck,"rotation:x",0.36 if bite == 0 else -0.10,0.65)
		var start: Vector3 = pasture[i]
		var end: Vector3 = pasture[(i+1) % pasture.size()]
		var heading = atan2(end.x-start.x, end.z-start.z)
		var previous: Vector3 = pasture[posmod(i-1, pasture.size())]
		var from_angle = atan2(start.x-previous.x, start.z-previous.z)
		if i == 0:
			sheep.rotation.y = from_angle
		routine.tween_method(func(weight: float):
			sheep.rotation.y = lerp_angle(from_angle, heading, weight)
		,0.0,1.0,0.75)
		var steps = maxi(2, roundi(start.distance_to(end)/0.23))
		routine.tween_method(func(weight: float):
			var stride = sin(weight * steps * TAU)
			sheep.position = start.lerp(end, weight) + Vector3.UP * absf(stride) * 0.013
			for leg in legs.size():
				legs[leg].rotation.x = stride * (0.33 if leg in [0,3] else -0.33)
		,0.0,1.0,start.distance_to(end)/0.29)

func _process(delta):
	if map.quarry:
		mole_delay -= delta
		if mole_delay <= 0:
			send_mole()
			mole_delay = random.randf_range(18,32)
	if map.mill_valley:
		snake_delay -= delta
		if snake_delay <= 0:
			send_snake()
			snake_delay = random.randf_range(20,34)
	bird_delay -= delta
	squirrel_delay -= delta
	if bird_delay <= 0:
		send_birds()
		bird_delay = random.randf_range(22, 37)
	if squirrel_delay <= 0:
		send_squirrel()
		squirrel_delay = random.randf_range(19, 33)

func pivot(parent: Node3D, offset: Vector3) -> Node3D:
	var part = Node3D.new()
	parent.add_child(part)
	part.position = offset
	return part

func send_mole():
	last_burrow = (last_burrow + random.randi_range(1,BURROWS.size()-1)) % BURROWS.size() if last_burrow >= 0 else random.randi_range(0,BURROWS.size()-1)
	var spot: Vector2 = BURROWS[last_burrow]
	var mound = pivot(self,Vector3(spot.x,0,spot.y))
	map.cone(mound,Vector3.UP*0.047,0.32,0.17,0.094,9,"846447","earth")
	map.cone(mound,Vector3.UP*0.095,0.16,0.16,0.01,9,"43372e")
	var mole = pivot(mound,Vector3.DOWN*0.27)
	var head = SphereMesh.new()
	head.radius = 0.145
	head.height = 0.39
	head.radial_segments = 9
	head.rings = 5
	map.mesh_part(mole,head,Vector3.ZERO,"57473d")
	map.box(mole,Vector3(0,0.035,0.14),Vector3(0.10,0.075,0.11),"c68a7d")
	for side in [-1,1]:
		map.box(mole,Vector3(side*0.086,0.083,0.10),Vector3.ONE*0.036,"292821")
		map.box(mole,Vector3(side*0.13,-0.055,0.065),Vector3(0.095,0.054,0.12),"b68d77")
	var visit = mound.create_tween()
	visit.tween_property(mole,"position:y",0.20,0.55).set_trans(Tween.TRANS_SINE)
	visit.tween_property(mole,"rotation:y",0.85,0.7)
	visit.tween_interval(0.55)
	visit.tween_property(mole,"rotation:y",-0.4,0.8)
	visit.tween_property(mole,"position:y",-0.27,0.36)
	visit.tween_property(mound,"scale",Vector3.ONE*0.01,0.45)
	visit.tween_callback(mound.queue_free)

func send_birds():
	var bearing = random.randf_range(0.0, TAU)
	var heading = Vector3(cos(bearing), 0, sin(bearing))
	var spread = 6.5 if map.mill_valley else 4.0
	var center = heading.cross(Vector3.UP) * random.randf_range(-spread, spread)
	center.y = random.randf_range(3.2, 4.2)
	var flock = pivot(self, center - heading * 17.0)
	flock.rotation.y = atan2(heading.x, heading.z)
	for i in random.randi_range(2, 4):
		var bird = pivot(flock, Vector3(i * 0.42 * (-1 if i % 2 else 1), i * 0.06, -i * 0.52))
		var body = map.cone(bird, Vector3.ZERO, 0.085, 0.05, 0.27, 5, "494e49")
		body.rotation.x = PI/2
		var wings = []
		for side in [-1, 1]:
			var joint = pivot(bird, Vector3(side * 0.04, 0, 0))
			var feather = map.cone(joint, Vector3(side * 0.16, 0, -0.025), 0.11, 0.012, 0.32, 3, "394742")
			feather.rotation.z = -side * PI/2
			feather.scale.x = 0.32
			wings.append(joint)
		var flap = bird.create_tween().set_loops()
		flap.tween_method(func(phase: float):
			var angle = sin(phase + i) * 0.64
			wings[0].rotation.z = -angle
			wings[1].rotation.z = angle
			bird.position.y = i * 0.06 + 0.05 * cos(phase + i)
		, 0.0, TAU, 0.54 + i * 0.035)
	var crossing = flock.create_tween()
	crossing.tween_property(flock, "position", center + heading * 17.0 + Vector3.UP * 0.5, 12.0)
	crossing.tween_callback(flock.queue_free)

func ground_trail(species: String, length: float) -> PackedVector2Array:
	var trails = VALLEY_TRAILS if map.mill_valley else HILLSIDE_TRAILS
	if map.three_fields:
		trails = THREE_FIELDS_TRAILS
	if map.quarry:
		trails = [[Vector2(-7.2,-9.05),Vector2(-2.2,-9.05)],
			[Vector2(-4.9,7.95),Vector2(1.8,7.95)],
			[Vector2(9.65,-3.5),Vector2(9.65,2.7)]]
	var index = random.randi_range(0, trails.size() - 1)
	if last_trail.has(species):
		index = (last_trail[species] + random.randi_range(1, trails.size() - 1)) % trails.size()
	last_trail[species] = index
	var a: Vector2 = trails[index][0]
	var b: Vector2 = trails[index][1]
	if random.randf() < 0.5:
		var swap = a
		a = b
		b = swap
	var heading = a.direction_to(b)
	var start = a + heading * random.randf_range(0.0, a.distance_to(b) - length)
	return PackedVector2Array([start, start + heading * length])

func send_squirrel():
	var trail = ground_trail("squirrel", 3.5)
	var heading = trail[0].direction_to(trail[1])
	var direction = Vector3(heading.x, 0, heading.y)
	var squirrel = pivot(self, Vector3(trail[0].x, 0.05, trail[0].y))
	squirrel.rotation.y = atan2(direction.x, direction.z)
	var fur = "af6034"
	map.box(squirrel, Vector3(0,0.16,0), Vector3(0.17,0.19,0.33), fur)
	map.box(squirrel, Vector3(0,0.27,0.16), Vector3(0.16,0.15,0.16), fur)
	for side in [-1,1]:
		map.cone(squirrel, Vector3(side*0.055,0.37,0.14), 0.048, 0, 0.10, 3, fur)
		map.box(squirrel, Vector3(side*0.077,0.29,0.20), Vector3(0.023,0.031,0.031), "332920")
	var tail = pivot(squirrel, Vector3(0,0.16,-0.13))
	map.cone(tail, Vector3(0,0.16,-0.09), 0.055,0.105,0.37,5, "99512e").rotation.x = -0.5
	map.cone(tail, Vector3(0,0.36,-0.14), 0.10,0.035,0.20,5, "cf8850").rotation.x = 0.38
	var origin = squirrel.position
	var bound = func(distance: float):
		var hop = absf(sin(distance * PI / 0.38))
		squirrel.position = origin + direction * distance + Vector3.UP * (0.105 * hop)
		squirrel.position += direction.cross(Vector3.UP) * (0.12 * sin(distance * PI / 3.5))
		squirrel.rotation.x = 0.13 * sin(distance * TAU / 0.38)
		tail.rotation.x = 0.22 * hop
	var run = squirrel.create_tween()
	squirrel.scale = Vector3.ONE * 0.01
	run.tween_property(squirrel, "scale", Vector3.ONE, 0.22)
	run.parallel().tween_method(bound, 0.0, 1.52, 1.3)
	run.tween_interval(0.65)
	run.tween_method(bound, 1.52, 3.5, 1.7)
	run.parallel().tween_property(squirrel, "scale", Vector3.ONE * 0.01, 0.22).set_delay(1.48)
	run.tween_callback(squirrel.queue_free)

func send_snake():
	var trail = ground_trail("snake", 3.8)
	var heading = trail[0].direction_to(trail[1])
	var snake = pivot(self, Vector3(trail[0].x, 0.065, trail[0].y))
	snake.rotation.y = atan2(-heading.y, heading.x)
	var segments = []
	var shape = SphereMesh.new()
	shape.radius = 0.09
	shape.height = 0.13
	shape.radial_segments = 6
	shape.rings = 3
	for i in 9:
		var section = map.mesh_part(snake,shape,Vector3.ZERO,"8b8742" if i%3 == 0 else "586733")
		var width = 1.15 if i == 0 else 1.0 - i * 0.075
		section.scale = Vector3(1.15,width,width)
		segments.append(section)
	for side in [-1,1]:
		map.box(segments[0],Vector3(0.04,0.035,side*0.069),Vector3(0.025,0.023,0.018),"302e25")
	var slither = snake.create_tween()
	var origin = snake.position
	snake.scale = Vector3.ONE * 0.02
	slither.tween_property(snake,"scale",Vector3.ONE,0.35)
	slither.parallel().tween_method(func(distance: float):
		snake.position = origin + snake.basis.x.normalized() * distance
		for i in segments.size():
			var x = distance - i*0.115
			segments[i].position = Vector3(-i*0.115,0,0.14*sin(5*x))
			segments[i].rotation.y = -atan(0.7*cos(5*x))
	,0.0,3.8,7.0)
	slither.parallel().tween_property(snake,"scale",Vector3.ONE*0.02,0.35).set_delay(6.65)
	slither.tween_callback(snake.queue_free)
