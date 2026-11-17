extends "res://scripts/world/scenery.gd"

const WIDTHS = [24,27,30,45,38]
const DEPTHS = [19,19,19,19,30]
var bat_bounds: Rect2i
var bat_delay = 4.0
const UndeadModel = preload("res://scripts/gameplay/undead.gd")
var graves: Array[Node3D] = []
var perches: Array[Vector3] = []
var grave_actor: Dictionary
var grave_delay = 9.0
var last_grave = -1
var crow: Node3D
var crow_wings: Array[Node3D] = []
var perch_index = 0
var crow_delay = 5.0
var sentinel_head: Node3D
var gaze_delay = 11.0
const ROUTES = [
	[Vector2i(-11,4),Vector2i(-7,4),Vector2i(-7,-4),Vector2i(-2,-4),Vector2i(-2,5),Vector2i(4,5),Vector2i(4,-3),Vector2i(10,-3)],
	[Vector2i(-13,-6),Vector2i(-8,-6),Vector2i(-8,3),Vector2i(-4,3),Vector2i(-4,-2),Vector2i(2,-2),Vector2i(2,6),Vector2i(7,6),Vector2i(7,-5),Vector2i(12,-5)],
	[Vector2i(-14,5),Vector2i(-10,5),Vector2i(-10,-5),Vector2i(-5,-5),Vector2i(-5,2),Vector2i(0,2),Vector2i(0,-6),Vector2i(5,-6),Vector2i(5,5),Vector2i(13,5)],
	[Vector2i(-22,4),Vector2i(-15,4),Vector2i(-15,-5),Vector2i(-6,-5),Vector2i(-6,4),Vector2i(-2,4),Vector2i(-2,-1),Vector2i(5,-1),Vector2i(5,-6),Vector2i(12,-6),Vector2i(12,3),Vector2i(20,3)],
	[Vector2i(-18,-9),Vector2i(-10,-9),Vector2i(-10,-12),Vector2i(3,-12),
		Vector2i(3,-5),Vector2i(6,-5),Vector2i(6,-1),Vector2i(14,-1),Vector2i(14,6),
		Vector2i(10,6),Vector2i(10,11),Vector2i(-8,11),Vector2i(-8,6),Vector2i(-12,6),
		Vector2i(-12,-5),Vector2i(-6,-5),Vector2i(-6,2),Vector2i(2,2)]
]

func build(map, chapter: int):
	rng.seed = 8764 + chapter
	var width: int = WIDTHS[chapter]
	var depth: int = DEPTHS[chapter]
	var bounds = Rect2i(-floori(width/2.0),-floori(depth/2.0),width,depth)
	var center = Vector3(bounds.position.x+(width-1)*0.5,0,bounds.position.y+(depth-1)*0.5)
	box(self,center+Vector3.DOWN*0.55,Vector3(width,0.88,depth),"4d474e","earth")
	box(self,center+Vector3.DOWN*0.055,Vector3(width,0.11,depth),["697063","60696b","686273","596969","615d68"][chapter],"earth")
	var environment = WorldEnvironment.new()
	var night = Environment.new()
	night.background_mode = Environment.BG_COLOR
	night.background_color = Color(["252d43","1e303c","30283e","222f3b","27263a"][chapter])
	night.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	night.ambient_light_color = Color("bdcdef")
	night.ambient_light_energy = 0.39
	environment.environment = night
	add_child(environment)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42,-50,0)
	moon.light_color = Color("b7cafa")
	moon.light_energy = 0.54
	moon.shadow_enabled = true
	add_child(moon)
	var occupied = {}
	var gate: Vector2i = map.route.back()
	for cell in map.route:
		occupied[cell] = true
	for dx in range(-2,2):
		for dz in range(-1,2):
			occupied[gate+Vector2i(dx,dz)] = true
	for cell in map.route:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var site: Vector2i = cell+direction
			if occupied.has(site) or not bounds.has_point(site) or map.near_spawn_gate(site):
				continue
			occupied[site] = true
			map.pads[site] = box(self,map.ground(site)+Vector3.UP*0.025,Vector3(0.89,0.05,0.89),map.pad_color,"grass")
	var corners: Array = ROUTES[chapter]
	for i in corners.size():
		var corner: Vector2i = corners[i]
		for offset in [Vector2i(-1,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1)]:
			var site = corner+Vector2i(offset)
			if bounds.has_point(site) and not occupied.has(site):
				lamp(map.ground(site),i%2 == 0)
				occupied[site] = true
				break
	if chapter <= 1:
		var grove = Rect2i(-12,-9,7,4) if chapter == 0 else Rect2i(-4,-9,10,5)
		forest(grove,occupied)
	if chapter == 1:
		var fountain_site = Rect2i(-3,5,5,4)
		reserve(fountain_site,occupied)
		fountain(Vector3(-1.6,0,6.7))
		for side in [-1,1]:
			var angel = group(Vector3(-1.6+side*1.55,0,6.56))
			angel.rotation.y = -side*0.45
			statue(angel)
		build_crow()
	elif chapter == 2:
		reserve(Rect2i(-15,-9,3,4),occupied)
		reserve(Rect2i(-12,-9,3,2),occupied)
		build_chapel(group(Vector3(-13.8,0,-7.85)))
		reserve(Rect2i(8,-8,7,10),occupied)
		memorial(map)
		for site in [Vector2i(-13,-5),Vector2i(-3,6),Vector2i(2,7)]:
			occupied[site] = true
			statue(group(map.ground(site)))
	elif chapter >= 3:
		bat_bounds = bounds
		reserve(Rect2i(map.route.front()-Vector2i(2,2),Vector2i(5,5)),occupied)
		if chapter == 3:
			forest(Rect2i(-21,-8,5,4),occupied)
			build_night_alley(occupied,map)
			reserve(Rect2i(7,2,4,5),occupied)
			fountain(Vector3(8.5,0,4))
			for x in [7.1,9.9]:
				statue(group(Vector3(x,0,3.6)))
		else:
			reserve(Rect2i(8,-14,8,11),occupied)
			memorial(map,Vector3(11.5,0,-8.8))
			reserve(Rect2i(-18,9,4,4),occupied)
			build_chapel(group(Vector3(-16.3,0,10.5)))
			forest(Rect2i(-18,-3,5,6),occupied)
	var spacing = 3 if chapter >= 3 else 2
	for z in range(bounds.position.y+1,bounds.end.y,spacing):
		for x in range(bounds.position.x+1,bounds.end.x-1,spacing):
			var site = Vector2i(x,z)
			if occupied.has(site) or rng.randf() < 0.22:
				continue
			if chapter == 2 and map.near_spawn_gate(site):
				site += Vector2i(1,2*signi(site.y-map.route.front().y))
			var plot = group(map.ground(site)+Vector3(rng.randf_range(-0.12,0.12),0,rng.randf_range(-0.12,0.12)))
			plot.rotation.y = rng.randf_range(-0.32,0.32)
			plot.scale = Vector3.ONE*rng.randf_range(0.83,1.11)
			var roll = rng.randf()
			if roll < [0.16,0.32,0.14,0.23,0.18][chapter]:
				dead_tree(plot)
			elif chapter == 0 and roll < 0.27:
				statue(plot)
			elif roll < [0.39,0.59,0.56,0.42,0.40][chapter]:
				open_grave(plot)
			else:
				gravestone(plot)
	crypt(map.ground(gate),chapter)
	if chapter == 2:
		var tree_sites = [Vector3(-14.8,0,-5.68),Vector3(-11.8,0,-8.75),Vector3(-10.15,0,-8.5)]
		for i in tree_sites.size():
			var trunk = group(tree_sites[i])
			var fork = dead_tree(trunk)
			if i == 0:
				build_owl(limb(trunk,fork))
	if graves.is_empty():
		for z in range(bounds.position.y+1,bounds.end.y-1):
			for x in range(bounds.position.x+1,bounds.end.x-1):
				if not occupied.has(Vector2i(x,z)) and x%2 == bounds.position.x%2 and z%2 != 0:
					open_grave(group(Vector3(x,0,z)))
					break
			if not graves.is_empty():
				break
	var sleeper = limb(self,Vector3.ZERO)
	grave_actor = UndeadModel.build_model(map,sleeper,"skeleton")
	sleeper.hide()

func lamp(at: Vector3, torch: bool):
	var post = group(at)
	cone(post,Vector3.UP*0.12,0.24,0.19,0.24,6,"696676","stone")
	cone(post,Vector3.UP*0.76,0.09,0.065,1.22,6,"494452")
	cone(post,Vector3.UP*1.39,0.13,0.23,0.18,6,"5e5360")
	var glow: MeshInstance3D
	if torch:
		glow = cone(post,Vector3.UP*1.61,0.15,0.013,0.42,5,"ffb95a")
	else:
		glow = box(post,Vector3.UP*1.63,Vector3(0.26,0.35,0.26),"ffd989")
		cone(post,Vector3.UP*1.88,0.27,0.035,0.18,4,"494452")
		for x in [-0.14,0.14]:
			for z in [-0.14,0.14]:
				box(post,Vector3(x,1.63,z),Vector3(0.03,0.36,0.03),"443b42")
	var ember = glow.material_override.duplicate()
	ember.emission_enabled = true
	ember.emission = Color("ffac50" if torch else "ffdc92")
	ember.emission_energy_multiplier = 2.1
	glow.material_override = ember
	var light = OmniLight3D.new()
	post.add_child(light)
	light.position.y = 1.65
	light.light_color = ember.emission
	light.omni_range = 4.5
	light.light_energy = 2.4
	if torch:
		var flicker = post.create_tween().set_loops()
		var beat = rng.randf_range(0.18,0.32)
		flicker.tween_property(glow,"scale",Vector3(0.84,1.18,0.84),beat)
		flicker.parallel().tween_property(light,"light_energy",1.9,beat)
		flicker.tween_property(glow,"scale",Vector3.ONE,beat*1.4)
		flicker.parallel().tween_property(light,"light_energy",2.4,beat*1.4)

func gravestone(plot):
	box(plot,Vector3.UP*0.07,Vector3(0.68,0.14,0.80),"686675","stone")
	var stone = limb(plot,Vector3(0,0.13,-0.17))
	stone.rotation.z = rng.randf_range(-0.13,0.13)
	if rng.randf() < 0.32:
		box(stone,Vector3.UP*0.35,Vector3(0.14,0.70,0.14),"928d99","stone")
		box(stone,Vector3.UP*0.48,Vector3(0.49,0.12,0.15),"928d99","stone")
		return
	box(stone,Vector3.UP*0.30,Vector3(0.52,0.60,0.18),"a6a3a9","stone")
	oval(stone,Vector3.UP*0.58,Vector3(0.52,0.35,0.18),"a6a3a9","stone")
	for y in [0.31,0.40]:
		box(stone,Vector3(0,y,0.093),Vector3(0.24,0.025,0.014),"585366")

func limb(parent,at):
	var n = Node3D.new()
	parent.add_child(n)
	n.position = at
	return n

func dead_tree(plot,perch: bool = false) -> Vector3:
	var first_fork = Vector3.ZERO
	var bark = ["51464a","433a42","635251"][rng.randi_range(0,2)]
	var bend = Vector3(rng.randf_range(-0.24,0.24),rng.randf_range(0.74,1.26),0)
	segment(plot,Vector3.ZERO,bend,0.16,0.094,bark,"wood")
	var crown = bend+Vector3(rng.randf_range(-0.30,0.30),rng.randf_range(0.62,1.02),0.12)
	segment(plot,bend,crown,0.10,0.019,bark,"wood")
	for i in rng.randi_range(3,5):
		var angle = i*2.4+rng.randf_range(-0.32,0.32)
		var direction = Vector3(cos(angle),0,sin(angle))
		var start = bend.lerp(crown,rng.randf_range(-0.35,0.68))
		var fork = start+direction*rng.randf_range(0.27,0.51)+Vector3.UP*rng.randf_range(0.13,0.32)
		segment(plot,start,fork,0.073,0.048,bark,"wood")
		segment(plot,fork,fork+direction*0.26+Vector3.UP*rng.randf_range(0.24,0.57),0.052,0.006,bark,"wood")
		segment(plot,fork,fork-direction*0.05+Vector3.UP*0.33,0.038,0.005,bark,"wood")
		if i == 0:
			first_fork = fork
			if perch:
				perches.append(plot.to_global(fork))
	return first_fork

func segment(parent,a: Vector3,b: Vector3,r1: float,r2: float,color: String,surface: String):
	var piece = cone(parent,(a+b)*0.5,r1,r2,a.distance_to(b),7,color,surface)
	piece.quaternion = Quaternion(Vector3.UP,a.direction_to(b))
	return piece

func reserve(area: Rect2i,occupied):
	for z in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			occupied[Vector2i(x,z)] = true

func forest(area: Rect2i,occupied):
	for z in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var site = Vector2i(x,z)
			if occupied.has(site):
				continue
			occupied[site] = true
			if rng.randf() < 0.38:
				continue
			var trunk = group(Vector3(x+rng.randf_range(-0.15,0.15),0,z+rng.randf_range(-0.15,0.15)))
			trunk.rotation.y = rng.randf()*TAU
			trunk.scale = Vector3.ONE*rng.randf_range(0.72,1.31)
			dead_tree(trunk,true)

func open_grave(plot):
	graves.append(plot)
	box(plot,Vector3.UP*0.008,Vector3(0.71,0.016,0.93),"292530")
	for x in [-0.39,0.39]:
		box(plot,Vector3(x,0.055,0),Vector3(0.10,0.11,0.98),"625651","earth")
	box(plot,Vector3(0,0.15,-0.49),Vector3(0.65,0.30,0.10),"7d7581","stone")
	oval(plot,Vector3(0.42,0.035,0.05),Vector3(0.21,0.21,0.85),"756459","earth")

func statue(plot):
	plot.add_to_group("cemetery_statues")
	var marble = "bbb7b0"
	box(plot,Vector3.UP*0.10,Vector3(0.90,0.20,0.84),"85828a","concrete")
	box(plot,Vector3.UP*0.24,Vector3(0.72,0.10,0.67),"a3a0a3","concrete")
	cone(plot,Vector3.UP*0.63,0.29,0.145,0.69,10,marble,"concrete")
	oval(plot,Vector3.UP*0.98,Vector3(0.37,0.42,0.24),marble,"concrete")
	var face = limb(plot,Vector3(0,1.28,0.045))
	face.rotation.x = 0.17
	oval(face,Vector3(0,0.015,-0.025),Vector3(0.31,0.37,0.28),"98949b","concrete")
	oval(face,Vector3(0,-0.008,0.055),Vector3(0.24,0.30,0.23),marble,"concrete")
	for side in [-1,1]:
		var eye = box(face,Vector3(side*0.055,0.022,0.155),Vector3(0.066,0.034,0.025),"ffdf56")
		var gold = eye.material_override
		gold.emission_enabled = true
		gold.emission = Color("ffcf33")
		gold.emission_energy_multiplier = 2.6
		var shoulder = Vector3(side*0.16,1.075,0.035)
		var elbow = Vector3(side*0.185,0.89,0.105)
		var wrist = Vector3(side*0.034,1.025,0.20)
		segment(plot,shoulder,elbow,0.081,0.062,marble,"concrete")
		segment(plot,elbow,wrist,0.063,0.045,marble,"concrete")
		oval(plot,wrist+Vector3.UP*0.055,Vector3(0.060,0.14,0.08),marble,"concrete")
		angel_wing(plot,side,marble)

func angel_wing(plot,side: int,tone: String):
	# A continuous feather fan, with its thick base embedded in the shoulder blade.
	var outline = PackedVector3Array([
		Vector3(0,-0.13,0),Vector3(-0.02,0.10,0),Vector3(0.23,0.34,-0.09),
		Vector3(0.66,0.55,-0.20),Vector3(0.51,0.31,-0.17),Vector3(0.57,0.32,-0.19),
		Vector3(0.44,0.12,-0.17),Vector3(0.48,0.13,-0.18),Vector3(0.33,-0.025,-0.14),
		Vector3(0.36,-0.03,-0.15),Vector3(0.19,-0.16,-0.09)])
	var front = Vector3(0.19,0.12,0.04)
	var back = Vector3(0.19,0.12,-0.17)
	var sculpt = SurfaceTool.new()
	sculpt.begin(Mesh.PRIMITIVE_TRIANGLES)
	sculpt.set_smooth_group(-1)
	for i in outline.size():
		var a = outline[i]
		var b = outline[(i+1)%outline.size()]
		if side < 0:
			var swap = a
			a = b
			b = swap
		for point in [front,a,b,back,b,a]:
			sculpt.add_vertex(point*Vector3(side,1,1))
	sculpt.generate_normals()
	mesh_part(plot,sculpt.commit(),Vector3(side*0.075,1.025,-0.055),tone,"concrete")

func fountain(at: Vector3):
	var basin = group(at)
	cone(basin,Vector3.UP*0.10,0.97,0.89,0.20,12,"898792","concrete")
	cone(basin,Vector3.UP*0.27,0.82,0.99,0.23,12,"b4b0ad","concrete")
	cone(basin,Vector3.UP*0.39,0.90,0.90,0.025,12,"5e96ab")
	cone(basin,Vector3.UP*0.64,0.18,0.10,0.52,8,"aaa5a6","concrete")
	cone(basin,Vector3.UP*0.92,0.15,0.45,0.16,10,"c1bcb9","concrete")
	cone(basin,Vector3.UP*1.0,0.40,0.40,0.02,10,"79aaba")
	for i in 6:
		var dir = Vector3(cos(i*TAU/6),0,sin(i*TAU/6))
		var lip = dir*0.38+Vector3.UP*1.01
		var bend = dir*0.48+Vector3.UP*0.91
		var splash = dir*0.55+Vector3.UP*0.41
		segment(basin,lip,bend,0.025,0.021,"99c9cf","")
		segment(basin,bend,splash,0.021,0.017,"99c9cf","")
		var ripple = oval(basin,splash,Vector3(0.16,0.027,0.16),"9ac6ce")
		var pulse = ripple.create_tween().set_loops()
		pulse.tween_property(ripple,"scale",Vector3(0.26,0.015,0.26),0.65+i*0.03)
		pulse.tween_property(ripple,"scale",Vector3(0.12,0.02,0.12),0.32)

func build_night_alley(occupied,map):
	var watch = preload("res://scripts/world/night_watchman.gd")
	reserve(Rect2i(-21,6,27,4),occupied)
	var lodge = group(Vector3(-19.1,0,7.3))
	box(lodge,Vector3.UP*0.11,Vector3(2.35,0.22,1.67),"82777a","stone")
	box(lodge,Vector3.UP*0.83,Vector3(2.12,1.32,1.49),"a09588","stone")
	var gable = PrismMesh.new()
	gable.size = Vector3(1.65,0.47,2.12)
	mesh_part(lodge,gable,Vector3.UP*1.72,"897c78","stone").rotation.y = PI/2
	for side in [-1,1]:
		var roof = box(lodge,Vector3(0,1.72,side*0.42),Vector3(2.42,0.13,1.09),"56525e","roof")
		roof.rotation.x = side*0.48
	box(lodge,Vector3(-0.7,1.98,-0.23),Vector3(0.27,0.8,0.31),"77686a","stone")
	box(lodge,Vector3(0.45,0.62,0.76),Vector3(0.48,0.93,0.06),"53423b","wood")
	var window = box(lodge,Vector3(-0.47,0.92,0.76),Vector3(0.54,0.49,0.05),"dbad68")
	var glass = window.material_override.duplicate()
	glass.emission_enabled = true
	glass.emission = Color("e9aa60")
	window.material_override = glass
	box(lodge,Vector3(-0.47,0.92,0.80),Vector3(0.045,0.5,0.035),"5c4e48")
	for x in [-21.25,-17.25]:
		box(self,Vector3(x,0.49,5.95),Vector3(0.32,0.98,0.32),"847c81","stone")
		cone(self,Vector3(x,1.04,5.95),0.25,0.09,0.18,4,"a49a96")
		fence(self,Vector3(x,0,5.95),Vector3(x+(-0.95 if x < -20 else 0.95),0,5.95))
	reserve(Rect2i(-13,-3,6,7),occupied)
	reserve(Rect2i(-11,4,2,3),occupied)
	box(self,Vector3(watch.JUNCTION,0.016,2.225),Vector3(0.78,0.032,9.95),"8b837e","earth")
	for z in [-2.1,0,2.1]:
		for x in [-12.0,-9.0]:
			alley_yew(Vector3(x,0,z))
	reserve(Rect2i(7,-4,4,5),occupied)
	for z in [-3.5,-1.5]:
		for x in [7.0,10.0]:
			alley_yew(Vector3(x,0,z))
	alley_bench(Vector3(10,0,0.35),-PI/2)
	# A strip of gravel belongs to the keeper, clear of the road and the tower plots.
	box(self,Vector3((-17.2+watch.EAST)*0.5,0.018,watch.SOUTH),Vector3(watch.EAST+17.2+0.70,0.036,0.70),"807877","earth")
	for i in range(1,watch.EAST_PATH.size()-1):
		var a: Vector2 = watch.EAST_PATH[i]
		var b: Vector2 = watch.EAST_PATH[i+1]
		var center = (a+b)*0.5
		var gravel = box(self,Vector3(center.x,0.018,center.y),Vector3(0.70,0.036,a.distance_to(b)+0.70),"807877","earth")
		gravel.rotation.y = atan2(b.x-a.x,b.y-a.y)
		for step in range(ceili(a.distance_to(b)*4)+1):
			var point = a.lerp(b,float(step)/maxf(1,ceili(a.distance_to(b)*4)))
			reserve(Rect2i(Vector2i(floori(point.x-0.6),floori(point.y-0.6)),Vector2i(2,2)),occupied)
	for x in [-12.0,-4.0,3.0]:
		alley_bench(Vector3(x,0,6.45))
	reserve(Rect2i(15,-8,7,6),occupied)
	var plot = group(Vector3(18,0,-5.3))
	fence(plot,Vector3(-2.4,0,-1.65),Vector3(2.4,0,-1.65))
	for side in [-1,1]:
		fence(plot,Vector3(side*2.4,0,-1.65),Vector3(side*2.4,0,1.65))
		fence(plot,Vector3(side*2.4,0,1.65),Vector3(side*0.57,0,1.65))
		for z in [-0.85,0.58]:
			var grave = limb(plot,Vector3(side*1.32,0,z))
			gravestone(grave)
			grave_flowers(grave,"c4a0b0" if side < 0 else "d4c8ae")
	box(plot,Vector3.UP*0.13,Vector3(0.78,0.26,0.75),"8f858c","concrete")
	cone(plot,Vector3.UP*0.9,0.30,0.15,1.30,4,"a39ca4","concrete")
	cone(plot,Vector3.UP*1.70,0.15,0,0.30,4,"b1a9ac","concrete")
	var keeper = watch.new()
	add_child(keeper)
	keeper.setup(self,map)

func alley_yew(at: Vector3):
	var yew = group(at)
	cone(yew,Vector3.UP*0.23,0.095,0.073,0.46,7,"625044","wood")
	oval(yew,Vector3.UP*0.78,Vector3(0.67,1.15,0.69),"42554a","needles")
	oval(yew,Vector3.UP*1.26,Vector3(0.45,0.67,0.47),"4b6051","needles")

func alley_bench(at: Vector3,heading: float = 0.0):
	var bench = group(at)
	bench.rotation.y = heading
	for side in [-1,1]:
		box(bench,Vector3(side*0.42,0.16,0),Vector3(0.10,0.32,0.30),"56505a")
	box(bench,Vector3.UP*0.31,Vector3(1.15,0.085,0.34),"8c7564","wood")
	box(bench,Vector3(0,0.49,-0.14),Vector3(1.15,0.25,0.07),"816e61","wood")

func memorial(map,origin: Vector3 = Vector3(10.8,0,-3.4)):
	var yard = group(origin)
	box(yard,Vector3.UP*0.021,Vector3(0.95,0.04,8.65),"929093","stone")
	for side in [-1,1]:
		for row in 5:
			for column in 2:
				var grave = limb(yard,Vector3(side*(1.10+column*1.06),0,3.35-row*1.48))
				gravestone(grave)
				if (row*2+column+(3 if side > 0 else 0))%5 == 1:
					grave_flowers(grave,"c38a9e" if column else "dad4c0")
		var x = side*2.96
		fence(yard,Vector3(x,0,-4.55),Vector3(x,0,4.55))
		fence(yard,Vector3(x,0,4.55),Vector3(side*0.60,0,4.55))
	fence(yard,Vector3(-2.96,0,-4.55),Vector3(2.96,0,-4.55))
	var pedestal = limb(yard,Vector3(0,0,-3.68))
	pedestal.add_to_group("cemetery_statues")
	box(pedestal,Vector3.UP*0.13,Vector3(1.22,0.26,1.02),"87838c","concrete")
	box(pedestal,Vector3.UP*0.37,Vector3(0.95,0.22,0.82),"aaa4aa","concrete")
	var figure = limb(pedestal,Vector3.UP*0.49)
	var sentinel = UndeadModel.build_model(map,figure,"gargoyle")
	sentinel_head = sentinel.head
	sentinel.chest.rotation.x = 0.16
	for arm in sentinel.arms:
		arm.rotation.x = -0.55

func grave_flowers(grave: Node3D,tone: String):
	var bunch = limb(grave,Vector3(0.06,0.145,0.19))
	bunch.name = "Flowers"
	for i in 3:
		var angle = i*TAU/3
		var stem = Vector3(0.11*cos(angle),0.13+i*0.023,0.075*sin(angle))
		segment(bunch,Vector3.ZERO,stem,0.012,0.009,"657853","")
		for j in 5:
			var petal = Vector3(cos(j*TAU/5),0,sin(j*TAU/5))*0.036
			oval(bunch,stem+petal,Vector3(0.069,0.04,0.069),tone)
		oval(bunch,stem+Vector3.UP*0.016,Vector3(0.036,0.03,0.036),"e3be74")

func build_chapel(chapel: Node3D):
	chapel.name = "Chapel"
	chapel.look_at(Vector3(14.5,0,9.5),Vector3.UP,true)
	box(chapel,Vector3.UP*0.10,Vector3(1.55,0.20,1.55),"55555f","stone")
	box(chapel,Vector3(0,0.055,0.88),Vector3(0.83,0.11,0.32),"64616a","stone")
	box(chapel,Vector3.UP*0.88,Vector3(1.38,1.38,1.34),"777479")
	box(chapel,Vector3.UP*1.58,Vector3(1.49,0.13,1.45),"50515b")
	cone(chapel,Vector3.UP*1.77,0.53,0.53,0.32,10,"716d72")
	cone(chapel,Vector3.UP*2.03,0.57,0.47,0.24,10,"454752")
	cone(chapel,Vector3.UP*2.31,0.47,0.045,0.32,10,"454752")
	var window = limb(chapel,Vector3(-0.70,0.99,0))
	box(window,Vector3.ZERO,Vector3(0.055,0.54,0.45),"4a4548","wood")
	var pane = box(window,Vector3.LEFT*0.033,Vector3(0.018,0.44,0.35),"ceac78")
	var glass = pane.material_override.duplicate()
	glass.emission_enabled = true
	glass.emission = Color("9a673a")
	pane.material_override = glass
	box(window,Vector3.LEFT*0.052,Vector3(0.025,0.46,0.031),"514942")
	box(window,Vector3(-0.04,-0.27,0),Vector3(0.14,0.055,0.52),"5f5960")
	var rake = limb(chapel,Vector3(-0.91,0.10,-0.41))
	rake.rotation.z = -0.19
	cone(rake,Vector3.UP*0.43,0.023,0.020,0.86,6,"9e835d","wood")
	box(rake,Vector3.ZERO,Vector3(0.06,0.047,0.29),"86888b")
	for tooth in 5:
		box(rake,Vector3(-0.018,-0.042,(tooth-2)*0.058),Vector3(0.03,0.085,0.022),"939397")
	var shovel = limb(chapel,Vector3(-0.92,0.05,0.40))
	shovel.rotation.z = -0.20
	cone(shovel,Vector3.UP*0.56,0.025,0.022,0.80,6,"987951","wood")
	oval(shovel,Vector3.UP*0.13,Vector3(0.065,0.27,0.19),"8c9299")
	box(shovel,Vector3.UP*0.96,Vector3(0.055,0.045,0.13),"a48662","wood")
	box(chapel,Vector3(0,0.63,0.68),Vector3(0.53,0.84,0.045),"423831","wood")
	var bulb = box(chapel,Vector3(0,1.21,0.71),Vector3(0.095,0.14,0.07),"f2cb89")
	var glow = bulb.material_override.duplicate()
	glow.emission_enabled = true
	glow.emission = Color("ffcb82")
	bulb.material_override = glow
	var light = OmniLight3D.new()
	chapel.add_child(light)
	light.position = Vector3(0,1.22,0.98)
	light.light_color = Color("ffcd8c")
	light.light_energy = 0.68
	light.omni_range = 1.55

func build_owl(owl: Node3D):
	owl.name = "ChapelOwl"
	owl.rotation.y = 0.30
	oval(owl,Vector3.UP*0.23,Vector3(0.29,0.39,0.24),"847162")
	oval(owl,Vector3(0,0.24,0.075),Vector3(0.22,0.29,0.15),"b29b7d")
	var head = limb(owl,Vector3.UP*0.435)
	oval(head,Vector3.ZERO,Vector3(0.34,0.26,0.26),"887666")
	var eyes: Array[Node3D] = []
	for side in [-1,1]:
		oval(owl,Vector3(side*0.13,0.22,-0.028),Vector3(0.11,0.32,0.16),"61534b")
		cone(head,Vector3(side*0.102,0.125,0),0.054,0,0.14,4,"6f6257").rotation.z = -side*0.24
		oval(head,Vector3(side*0.071,0.015,0.094),Vector3(0.155,0.14,0.10),"c5b395")
		var socket = limb(head,Vector3(side*0.070,0.021,0.143))
		eyes.append(socket)
		var eye = oval(socket,Vector3.ZERO,Vector3(0.073,0.072,0.035),"ffda65")
		eye.material_override.emission_enabled = true
		eye.material_override.emission = Color("ffcc48")
		eye.material_override.emission_energy_multiplier = 2.4
		oval(socket,Vector3(0,0,0.018),Vector3(0.025,0.043,0.012),"28252a")
		box(owl,Vector3(side*0.058,0.034,0.035),Vector3(0.052,0.058,0.11),"97794e")
	cone(head,Vector3(0,-0.027,0.15),0.008,0.037,0.08,5,"927448")
	owl_blink(head,eyes)
	owl_glance(head)

func owl_blink(head: Node3D,eyes: Array[Node3D]):
	var blink = head.create_tween().set_trans(Tween.TRANS_SINE)
	blink.tween_interval(rng.randf_range(2.6,5.8))
	var open_eyes = func(amount: float):
		for socket in eyes:
			socket.scale.y = maxf(0.025,amount)
			socket.visible = amount > 0.035
	blink.tween_method(open_eyes,1.0,0.0,0.09)
	blink.tween_interval(0.07)
	blink.tween_method(open_eyes,0.0,1.0,0.14)
	blink.finished.connect(owl_blink.bind(head,eyes),CONNECT_ONE_SHOT)

func owl_glance(head: Node3D):
	var turn = head.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_interval(rng.randf_range(4.0,8.0))
	var side = -1 if rng.randf() < 0.5 else 1
	turn.tween_property(head,"rotation",Vector3(-0.06,side*rng.randf_range(0.42,0.78),side*0.10),0.48)
	turn.tween_interval(rng.randf_range(0.8,1.7))
	turn.tween_property(head,"rotation",Vector3.ZERO,0.65)
	turn.finished.connect(owl_glance.bind(head),CONNECT_ONE_SHOT)

func fence(parent,a: Vector3,b: Vector3):
	var dir = a.direction_to(b)
	var count = ceili(a.distance_to(b)/0.38)
	for i in count+1:
		var p = a.lerp(b,float(i)/count)
		var thick = 0.079 if i%5 == 0 else 0.046
		box(parent,p+Vector3.UP*0.29,Vector3(thick,0.58,thick),"27252d")
		cone(parent,p+Vector3.UP*0.64,0.062,0,0.16,4,"37333d")
	for y in [0.20,0.45]:
		box(parent,(a+b)*0.5+Vector3.UP*y,dir.abs()*a.distance_to(b)+Vector3(0.036,0.04,0.036),"302d35")

func build_crow():
	crow = group(perches[0])
	crow.name = "Raven"
	oval(crow,Vector3.UP*0.13,Vector3(0.21,0.23,0.42),"302e39")
	oval(crow,Vector3(0,0.255,0.145),Vector3(0.19,0.20,0.20),"272631")
	cone(crow,Vector3(0,0.24,0.27),0.064,0.006,0.15,5,"4c4651").rotation.x = PI/2
	oval(crow,Vector3(0,0.13,-0.22),Vector3(0.15,0.06,0.27),"262632")
	for side in [-1,1]:
		box(crow,Vector3(side*0.056,0.028,0.015),Vector3(0.027,0.055,0.09),"564d50")
		oval(crow,Vector3(side*0.081,0.27,0.183),Vector3.ONE*0.033,"c6ac86")
		var wing = limb(crow,Vector3(side*0.08,0.19,0))
		crow_wings.append(wing)
		oval(wing,Vector3(side*0.17,0,-0.04),Vector3(0.39,0.061,0.18),"373644")
		oval(wing,Vector3(side*0.35,0,-0.115),Vector3(0.27,0.045,0.13),"292936")
		wing.rotation.y = side*1.25

func send_bats():
	var side = -1 if rng.randf() < 0.5 else 1
	var half_width = bat_bounds.size.x*0.5+3
	var depth = bat_bounds.size.y*0.38
	var start = Vector3(side*half_width,rng.randf_range(2.9,3.8),rng.randf_range(-depth,depth))
	var end = Vector3(-side*half_width,start.y+0.3,rng.randf_range(-depth,depth))
	var flock = group(start)
	flock.name = "Bats"
	flock.look_at(end,Vector3.UP,true)
	for i in rng.randi_range(3,5):
		var bat = limb(flock,Vector3((1 if i%2 else -1)*i*0.36,0.12*sin(i),-i*0.64))
		oval(bat,Vector3.ZERO,Vector3(0.15,0.14,0.32),"524653")
		oval(bat,Vector3(0,0.04,0.12),Vector3(0.15,0.14,0.15),"625563")
		var wings = []
		for sign_x in [-1,1]:
			cone(bat,Vector3(sign_x*0.05,0.14,0.12),0.04,0,0.12,3,"685a66")
			var wing = limb(bat,Vector3(sign_x*0.05,0.025,0))
			var points = [Vector3(0,0,-0.10),Vector3(0,0,0.09),Vector3(0.20,0.055,0.19),
				Vector3(0.47,0.01,0.11),Vector3(0.35,-0.02,0.025),Vector3(0.31,-0.03,-0.10),
				Vector3(0.23,-0.015,-0.05),Vector3(0.14,-0.02,-0.16),Vector3(0.08,0,-0.09)]
			var skin = SurfaceTool.new()
			skin.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in points.size():
				var a: Vector3 = points[j]
				var b: Vector3 = points[(j+1)%points.size()]
				var ridge = Vector3(0.16,0.065,0.035)
				for vertex in [ridge,a,b,ridge,b,a]:
					skin.add_vertex(vertex*Vector3(sign_x,1,1))
			skin.generate_normals()
			mesh_part(wing,skin.commit(),Vector3.ZERO,"675469")
			wings.append(wing)
		var height: float = bat.position.y
		var flap = bat.create_tween().set_loops()
		flap.tween_method(func(phase: float):
			var angle = sin(phase+i)*0.83
			wings[0].rotation.z = -angle
			wings[1].rotation.z = angle
			bat.position.y = height+0.075*cos(phase+i)
		,0.0,TAU,rng.randf_range(0.28,0.38))
	var flight = flock.create_tween()
	flight.tween_property(flock,"position",end,start.distance_to(end)/3.7)
	flight.tween_callback(flock.queue_free)

func _process(delta):
	if bat_bounds.has_area():
		bat_delay -= delta
		if bat_delay <= 0:
			send_bats()
			bat_delay = rng.randf_range(21,34)
	if sentinel_head:
		gaze_delay -= delta
		if gaze_delay <= 0:
			var gaze = sentinel_head.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			gaze.tween_method(turn_sentinel,0.0,1.0,0.85)
			gaze.tween_method(turn_sentinel,1.0,1.0,2.4)
			gaze.tween_method(turn_sentinel,1.0,0.0,1.1)
			gaze_delay = rng.randf_range(22,39)
	if not grave_actor.is_empty():
		grave_delay -= delta
		if grave_delay <= 0:
			grave_visit()
			grave_delay = rng.randf_range(24,43)
	if is_instance_valid(crow):
		crow_delay -= delta
		if crow_delay <= 0:
			fly_crow()
			crow_delay = rng.randf_range(10,20)

func turn_sentinel(weight: float):
	var camera = get_viewport().get_camera_3d()
	if camera:
		var direction = sentinel_head.get_parent().to_local(camera.global_position)-sentinel_head.position
		var facing = Basis.looking_at(direction,Vector3.UP,true).get_rotation_quaternion()
		sentinel_head.quaternion = Quaternion.IDENTITY.slerp(facing,weight)

func grave_visit():
	last_grave = (last_grave+rng.randi_range(1,maxi(1,graves.size()-1)))%graves.size()
	var plot = graves[last_grave]
	var actor: Node3D = grave_actor.node
	actor.reparent(plot,false)
	actor.position = Vector3(0,-0.41,0.24)
	actor.rotation.x = -PI/2
	grave_actor.head.rotation.y = 0
	actor.show()
	var visit = actor.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visit.tween_property(actor,"rotation:x",-0.15,1.28)
	visit.tween_property(grave_actor.head,"rotation:y",0.88,0.62)
	visit.tween_interval(0.58)
	visit.tween_property(grave_actor.head,"rotation:y",-0.75,0.83)
	visit.tween_interval(0.57)
	visit.tween_property(grave_actor.head,"rotation:y",0,0.32)
	var shoulder: Node3D = grave_actor.arms[1]
	var elbow: Node3D = grave_actor.right_elbow
	visit.tween_property(shoulder,"rotation:z",2.50,0.55)
	visit.parallel().tween_property(elbow,"rotation:z",2.12,0.55)
	for stroke in 3:
		visit.tween_property(elbow,"rotation:z",1.93,0.15)
		visit.tween_property(elbow,"rotation:z",2.12,0.17)
	visit.tween_property(shoulder,"rotation:z",0.0,0.46)
	visit.parallel().tween_property(elbow,"rotation:z",0.0,0.46)
	visit.tween_property(actor,"rotation:x",-PI/2,0.91)
	visit.tween_callback(actor.hide)

func fly_crow():
	var start = crow.position
	perch_index = (perch_index+rng.randi_range(1,perches.size()-1))%perches.size()
	var target = to_local(perches[perch_index])
	var duration = maxf(1.4,start.distance_to(target)/2.65)
	crow.rotation.y = atan2(target.x-start.x,target.z-start.z)
	var flight = crow.create_tween()
	flight.tween_method(func(t: float):
		crow.position = start.lerp(target,t)+Vector3.UP*sin(t*PI)*1.20
		var spread = clampf(minf(t,1-t)*8.0,0,1)
		for i in 2:
			var side = 2*i-1
			crow_wings[i].rotation.y = side*1.25*(1-spread)
			crow_wings[i].rotation.z = side*sin(t*duration*TAU*3.7)*0.63*spread
	,0.0,1.0,duration)

func crypt(at: Vector3,chapter: int):
	var hall = group(at)
	box(hall,Vector3.UP*0.11,Vector3(2.6,0.22,2.36),"777485","stone")
	box(hall,Vector3.UP*0.86,Vector3(2.22,1.48,1.96),"95909a","stone")
	box(hall,Vector3(-1.12,0.55,0),Vector3(0.05,1.06,0.74),"302b37")
	box(hall,Vector3.UP*1.63,Vector3(2.52,0.18,2.18),"6e6979","stone")
	var dome = cone(hall,Vector3.UP*1.98,1.4,0.27,0.62,4,"565263","roof")
	dome.rotation.y = PI/4
	if chapter == 0:
		for x in [-0.29,0.29]:
			for z in [-0.25,0.25]:
				box(hall,Vector3(x,2.42,z),Vector3(0.09,0.58,0.10),"76717e","stone")
		cone(hall,Vector3.UP*2.41,0.18,0.08,0.26,8,"b09865")
		cone(hall,Vector3.UP*2.83,0.56,0,0.40,4,"565263","roof").rotation.y = PI/4
	elif chapter == 2:
		cone(hall,Vector3.UP*2.68,0.27,0.035,0.94,6,"797181","stone")
	for x in [-0.62,0.62]:
		box(hall,Vector3(x,1.03,0.985),Vector3(0.28,0.52,0.045),"3f384a")
		box(hall,Vector3(x,1.03,1.013),Vector3(0.045,0.52,0.025),"88818e")
	for side in [-1,1]:
		lamp(at+Vector3(-1.3,0,side*0.95),false)
