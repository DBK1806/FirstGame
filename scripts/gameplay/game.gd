extends "res://scripts/world/scenery.gd"

const Campaign = preload("res://scripts/gameplay/campaign.gd")
const Cemetery = preload("res://scripts/world/cemetery.gd")
const Undead = preload("res://scripts/gameplay/undead.gd")
const Ballista = preload("res://scripts/gameplay/ballista.gd")
const QUARRY_HEALTH = [7,9,11,15,20,25,30,37,45,54,64,74]

const COST = 30
const RANGE = 4
const KILL_REWARD = 3
const BRUTE_REWARD = 6
const UNDEAD_REWARDS = {"skeleton":3,"zombie":7,"gargoyle":30,"death":30}
const Reaper = preload("res://scripts/gameplay/reaper.gd")
const WAVE_REWARD = 8
const PASS_HEALTH = [4, 5, 7, 11, 17, 20]
const VALLEY_HEALTH = [6, 8, 11, 15, 20, 26, 33, 41]
const THREE_FIELDS_HEALTH = [7, 8, 10, 14, 20, 24, 28, 36, 44, 54]
const COIN_ICON = preload("res://assets/icons/coin.svg")
const MORTAR_COST = 60
const MORTAR_RANGE = 4
const ARROW_DAMAGE = 1
const SHELL_DAMAGE = 5
const ARCHER_INTERVAL = 0.5
const VETERAN_DAMAGE = 2.5
const VETERAN_INTERVAL = 0.5
const ARCHER_UPGRADE_COST = 50
const MORTAR_INTERVAL = 3.0
const BLAST_RADIUS = 1.5
const FLIGHT_TIME = 0.90
const GRAVITY = Vector3.DOWN * 19.0
const GATE_OFFSET = 2.12
enum Tower { ARCHER, MORTAR, MILL, BALLISTA }
const TOWER_NAMES = ["Лучники","Мортира","Ветряная мельница","Баллиста"]
const TOWER_ROLES = ["Стрела в одну цель","Ядро по площади","Замедление по области","Болт пробивает врагов в ряд"]
const TOWER_COSTS = [COST,MORTAR_COST,40,65]
const TOWER_RANGES = [RANGE,MORTAR_RANGE,3,5]
const TOWER_ICONS = [preload("res://assets/icons/archer_icon.svg"),preload("res://assets/icons/mortar_icon.svg"),preload("res://assets/icons/windmill_icon.svg"),preload("res://assets/icons/ballista_icon.svg")]
const MILL_SLOW_PERCENT = 25
const UPGRADE_COSTS = [ARCHER_UPGRADE_COST,85,45,75]
const ELITE_RANGES = [4.5,4.5,3.5,6]
const HEAVY_SHELL_DAMAGE = 7
const HEAVY_BLAST_RADIUS = 1.65
const STRONG_WIND_PERCENT = 40
const CAMERA_OFFSET = Vector3(10,22,29)
@export var mill_valley = false
@export var three_fields = false
@export var quarry = false
@export var dusk_ridge = false
@export_range(0,5) var cemetery_stage: int = 0
@onready var pad_color = "858c80" if cemetery_stage else "9da35c"
@onready var level_number = 5+cemetery_stage if cemetery_stage else (5 if dusk_ridge else (4 if quarry else (3 if three_fields else (2 if mill_valley else 1))))
@onready var health_table = Undead.HEALTH[cemetery_stage-1] if cemetery_stage else [PASS_HEALTH,VALLEY_HEALTH,THREE_FIELDS_HEALTH,QUARRY_HEALTH,QUARRY_HEALTH][level_number-1]
@onready var wave_count = health_table.size()
var damage_dealt = 0.0
var gold_earned = 0
var monsters_defeated = 0
var hud_root: Control
var speed_panel = PanelContainer.new()

var route: Array[Vector2i] = []
var pads = {}
var towers: Array = []
var enemies: Array = []
var camera = Camera3D.new()
var camera_zoom = 1.0
var dragging_map = false
var coins = 60
var lives = 12
var wave = 0
var remaining = 0
var spawn_clock = 0.0
var fighting = false
var finished = false
var ui = CanvasLayer.new()
var health_bars = Node2D.new()
var rewards = Node2D.new()
var gate_attackers = 0
var reaper_pending = false
var boss_warning: Label
var gate_boards = []
var gate_strap: MeshInstance3D
var shells_in_flight = 0
var selected_tower = Tower.ARCHER
var stats = Label.new()
var action = Button.new()
var hint = Label.new()
var info_panel = PanelContainer.new()
var upgrade_panel = PanelContainer.new()
var upgrade_title = Label.new()
var upgrade_action = Button.new()
var upgrade_stats = Label.new()
var upgrade_kind = Tower.ARCHER
var upgrade_hover_tile: Control
var world_info_visible = false
var upgraded = [false,false,false,false]
var tower_details = RichTextLabel.new()
var hovered = Vector2i(999,999)
var ring = Node3D.new()
var message_time = 0.0

func ground(cell):
	return Vector3(cell.x,0,cell.y)

func _ready():
	rng.seed = 1823 if mill_valley else 471
	if not cemetery_stage:
		light_world(quarry,dusk_ridge)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	camera.current = true
	fit_camera()
	get_viewport().size_changed.connect(fit_camera)
	var corners = [Vector2i(-9,2),Vector2i(-5,2),Vector2i(-5,-2),Vector2i(-1,-2),Vector2i(-1,3),Vector2i(3,3),Vector2i(3,-2),Vector2i(8,-2)]
	if mill_valley:
		corners = [Vector2i(-9,8),Vector2i(-5,8),Vector2i(-5,4),Vector2i(1,4),
			Vector2i(1,0),Vector2i(-6,0),Vector2i(-6,-5),Vector2i(-2,-5),
			Vector2i(-2,-2),Vector2i(3,-2),Vector2i(3,-7),Vector2i(8,-7)]
	if three_fields:
		corners = [Vector2i(-8,-8),Vector2i(-3,-8),Vector2i(-3,-5),Vector2i(-8,-5),
			Vector2i(-8,-1),Vector2i(-4,-1),Vector2i(-4,2),Vector2i(-8,2),
			Vector2i(-8,6),Vector2i(-2,6),Vector2i(-2,2),Vector2i(2,2),
			Vector2i(2,7),Vector2i(8,7)]
	if quarry:
		corners = [Vector2i(-7,-8),Vector2i(-3,-8),Vector2i(-3,-5),Vector2i(-8,-5),
			Vector2i(-8,1),Vector2i(-4,1),Vector2i(-4,6),Vector2i(1,6),Vector2i(1,3),
			Vector2i(-1,3),Vector2i(-1,-2),Vector2i(2,-2),Vector2i(2,-6),Vector2i(7,-6)]
	if dusk_ridge:
		corners = [Vector2i(-9,5),Vector2i(-5,5),Vector2i(-5,1),Vector2i(-8,1),
			Vector2i(-8,-5),Vector2i(-3,-5),Vector2i(-3,-1),Vector2i(1,-1),
			Vector2i(1,5),Vector2i(4,5),Vector2i(4,-5),Vector2i(9,-5)]
	if cemetery_stage:
		coins = 140 if cemetery_stage in [1,5] else 125
		$GoblinFall.stream = preload("res://assets/audio/sfx/bone_scatter.wav")
		$BruteFall.stream = preload("res://assets/audio/sfx/zombie_groan.wav")
		corners = Cemetery.ROUTES[cemetery_stage-1]
	route.append(corners[0])
	for corner in corners.slice(1):
		while route.back() != corner:
			route.append(route.back() + (corner - route.back()).sign())
	if cemetery_stage:
		var cemetery = Cemetery.new()
		add_child(cemetery)
		cemetery.build(self,cemetery_stage-1)
	elif dusk_ridge:
		build_dusk_ridge()
	elif quarry:
		build_quarry()
	elif three_fields:
		build_three_fields()
	else:
		var depth = 19 if mill_valley else 12
		box(self,Vector3(0,-0.47,0),Vector3(19.08,0.8,depth+0.08),"796d50","earth")
		box(self,Vector3(0,-0.105,0),Vector3(19,0.21,depth),MOSS,"grass")
	for cell in route:
		box(self,ground(cell)+Vector3.UP*0.025,Vector3(1.01,0.05,1.01),"a8a0a4" if cemetery_stage else "bea574","stone" if cemetery_stage else "earth")
		for i in 3:
			var pebble = Vector3(rng.randf_range(-0.43,0.43),0.057,rng.randf_range(-0.43,0.43))
			box(self,ground(cell)+pebble,Vector3(0.17,0.014,0.08),"d3bd93").rotation.y = rng.randf()*PI
	if level_number <= 2:
		build_meadow()
	fort()
	if mill_valley:
		build_windmill()
	if not cemetery_stage:
		add_child(preload("res://scripts/world/wildlife.gd").new())
	add_child(ring)
	var outline = TorusMesh.new()
	outline.inner_radius = RANGE-0.025
	outline.outer_radius = RANGE+0.025
	mesh_part(ring,outline,Vector3.UP*0.09,GOLD)
	ring.hide()
	build_ui()
	refresh()

func near_spawn_gate(cell: Vector2i) -> bool:
	var offset = (cell - route[0]).abs()
	return maxi(offset.x, offset.y) <= 1

func build_quarry():
	# Stone shelves narrow at each end of the quarry.
	for shelf in [Rect2(-8.5,-9.5,17,5),Rect2(-10.5,-4.5,21,9),Rect2(-7.5,4.5,15,4)]:
		var c: Vector2 = shelf.get_center()
		box(self,Vector3(c.x,-0.65,c.y),Vector3(shelf.size.x,0.7,shelf.size.y),"846951","earth")
		box(self,Vector3(c.x,-0.22,c.y),Vector3(shelf.size.x,0.24,shelf.size.y),"be915e","stone")
		box(self,Vector3(c.x,-0.05,c.y),Vector3(shelf.size.x,0.1,shelf.size.y),MOSS,"grass")
	for cell in route:
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var site = cell + step
			var limit = 10 if absi(site.y)<=4 else (8 if site.y<0 else 7)
			if absi(site.x)>limit or site in route or site in pads or near_spawn_gate(site):
				continue
			if (site.x>=5 and site.y<=-5) or site in [Vector2i(-9,-2),Vector2i(-7,-2)]:
				continue
			pads[site] = box(self,ground(site)+Vector3.UP*0.024,Vector3(0.90,0.048,0.90),"9da35c","grass")
	build_mine(Vector3(4.65,0,-0.85),-0.32)
	build_mine(Vector3(-6.15,0,3.7),0.32)
	for peak in [Vector3(1.2,2.25,-8.45),Vector3(2.55,3.1,-8.6),Vector3(3.88,1.95,-8.4)]:
		var mountain = group(Vector3(peak.x,0,peak.z))
		mountain.rotation.y = peak.x
		mountain.scale = Vector3(1.25,peak.y,0.85)
		quarry_rock(mountain,Vector3.ZERO,[Vector2(1.06,0),Vector2(0.92,0.23),
			Vector2(0.79,0.38),Vector2(0.63,0.43),Vector2(0.57,0.70),
			Vector2(0.41,0.84),Vector2(0.30,0.95),Vector2(0.19,0.98),Vector2(0,1)],0.16)
		var spur = quarry_rock(mountain,Vector3(0.60,0,0.22),[Vector2(0.62,0),
			Vector2(0.54,0.19),Vector2(0.36,0.39),Vector2(0.25,0.49),Vector2(0,0.53)],0.14)
		spur.rotation.y = 0.8
	var arch = group(Vector3(-8,0,-2))
	for side in [-1,1]:
		for row in 3:
			box(arch,Vector3(side*0.94,0.20+row*0.39,0),Vector3(0.40,0.38,0.51),"989886","stone")
	for i in 9:
		var angle = (i+0.5)*PI/9
		var stone = box(arch,Vector3(cos(angle)*0.94,1.17+sin(angle)*0.94,0),
			Vector3(0.39,0.35,0.52),"c1baa2" if i==4 else "a5a38e","stone")
		stone.rotation.z = angle-PI/2
	box(arch,Vector3(0,2.10,0.34),Vector3(0.065,0.08,0.35),"51483b")
	box(arch,Vector3(0,1.94,0.49),Vector3(0.028,0.27,0.028),"51483b")
	var lamp = limb_joint(arch,Vector3(0,1.69,0.49))
	var glass = box(lamp,Vector3.ZERO,Vector3(0.18,0.25,0.16),"ffca76")
	var glow = glass.material_override.duplicate()
	glow.emission_enabled = true
	glow.emission = Color("ffbe68")
	glow.emission_energy_multiplier = 2.2
	glass.material_override = glow
	for side in [-1,1]:
		box(lamp,Vector3(side*0.096,0,0.075),Vector3(0.023,0.26,0.023),"51483b")
		box(lamp,Vector3(0,side*0.14,0),Vector3(0.24,0.04,0.22),"51483b")
	var pool = OmniLight3D.new()
	pool.light_color = Color("ffb563")
	pool.light_energy = 1.8
	pool.omni_range = 3.4
	lamp.add_child(pool)
	pool.position.y = -0.2
	var hoist = group(Vector3(5.25,0,-2.4))
	for x in [-0.42,0.42]:
		box(hoist,Vector3(x,0.74,0),Vector3(0.15,1.48,0.19),WOOD,"wood")
	box(hoist,Vector3(0,1.44,0),Vector3(1.30,0.17,0.19),WOOD,"wood")
	box(hoist,Vector3(0,0.92,0),Vector3(0.035,0.96,0.035),"554632")
	cone(hoist,Vector3.UP*0.39,0.22,0.26,0.28,8,"685746","wood")
	for p in [Vector2(-9.6,2.8),Vector2(-9.1,3.6),Vector2(-6.8,7.5),Vector2(-5.9,7.7),
			Vector2(4.2,6.6),Vector2(4.8,7.2),Vector2(5.6,6.8),Vector2(0,-8.6),
			Vector2(-7.2,6.4),Vector2(-6.6,6.7),Vector2(-6.9,5.8),Vector2(-9.85,1.7),
			Vector2(6.1,7.7),Vector2(4.9,6.1),Vector2(3.7,7.4),Vector2(5.3,-8.6),Vector2(6.1,-8.85)]:
		tree(Vector3(p.x,0,p.y),rng.randf_range(0.74,1.12))
	for p in [Vector2(-3.25,-2.9),Vector2(-4.35,-2.5)]:
		tree(Vector3(p.x,0,p.y),0.83)
	for p in [Vector2(-3.8,-1.7),Vector2(-4.9,-2.1),Vector2(1.35,0.35)]:
		bush(Vector3(p.x,0,p.y))

func build_dusk_ridge():
	box(self,Vector3(0,-0.54,-1),Vector3(23,0.92,21),"655a54","earth")
	box(self,Vector3(0,-0.05,-1),Vector3(23,0.1,21),"798349","grass")
	for cell in route:
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var site = cell + step
			if site in route or site in pads or near_spawn_gate(site):
				continue
			if site.x >= 7 and site.y <= -4:
				continue
			pads[site] = box(self,ground(site)+Vector3.UP*0.024,Vector3(0.90,0.048,0.90),"9da35c","grass")
	var profiles = [
		[Vector2(1,0),Vector2(0.83,0.25),Vector2(0.55,0.55),Vector2(0.31,0.81),Vector2(0.13,0.98),Vector2(0,1)],
		[Vector2(1,0),Vector2(0.84,0.27),Vector2(0.72,0.66),Vector2(0.56,0.94),Vector2(0.39,1),Vector2(0,1.01)],
		[Vector2(1,0),Vector2(0.87,0.32),Vector2(0.63,0.38),Vector2(0.47,0.73),Vector2(0.23,0.94),Vector2(0,1)]]
	var peaks = [Vector3(-9.1,1.7,-8.15),Vector3(-7.35,3.35,-9.4),Vector3(-5.4,1.85,-8.2),
		Vector3(-1.9,2.15,-9.25),Vector3(0.15,3.75,-8.35),Vector3(1.65,2.05,-6.15),Vector3(3.7,1.35,-9.8),
		Vector3(-0.8,1.35,-4.3),Vector3(0.9,0.85,-4.5)]
	var rock_footprints: Array[Rect2] = []
	for i in peaks.size():
		var peak: Vector3 = peaks[i]
		var base = group(Vector3(peak.x,0,peak.z))
		base.rotation.y = rng.randf_range(-0.65,0.65) + (PI if i%2 else 0.0)
		base.scale = Vector3(rng.randf_range(1.6,2.2),peak.y,rng.randf_range(0.85,1.15))
		if i < 7:
			base.scale *= Vector3(1.35,1,1.95)
		var rock = quarry_rock(base,Vector3.ZERO,profiles[i%3],0.12,rng.randf_range(-0.40,0.40))
		# Measure the rotated stone itself so empty corners do not squeeze the foothills.
		var footprint = Rect2(Vector2(peak.x,peak.z),Vector2.ZERO)
		for vertex in rock.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = rock.to_global(vertex)
			footprint = footprint.expand(Vector2(point.x,point.z))
		var local_offset = footprint.position - Vector2(peak.x,peak.z)
		while true:
			if i in [1,3,6]:
				base.position.z = -11.5 - local_offset.y + 0.0001
			footprint.position = Vector2(base.position.x,base.position.z) + local_offset
			if ridge_clear(footprint):
				break
			base.scale *= Vector3(0.9,1,0.9)
			footprint.size *= 0.9
			local_offset *= 0.9
		rock_footprints.append(footprint)
		if i == 5:
			var summit = Vector3.ZERO
			for vertex in rock.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if vertex.y > summit.y:
					summit = vertex
			build_stork_nest(rock.to_global(summit)-Vector3.UP*0.055)
	for hill in [Vector3(-7.6,0.65,7.7),Vector3(-5.1,0.42,8.35),Vector3(-5.6,0.60,-2.4),
			Vector3(-10.3,0.83,-2.4),Vector3(7,0.72,6.1),Vector3(8.2,0.37,7.35)]:
		var size = Vector3(rng.randf_range(1.9,3.1),hill.y*2,rng.randf_range(1.4,2.2))
		var span = Vector2(size.x,size.z)
		if ridge_clear(Rect2(Vector2(hill.x,hill.z)-span/2,span)):
			oval(self,Vector3(hill.x,-0.12,hill.z),size,"74844c","grass")
	for stand in [Vector2(-10.3,-6.1),Vector2(-4.1,-7.6),Vector2(2.6,-7.3),Vector2(5.7,-8),
			Vector2(-10.1,0.3),Vector2(-9.8,7.7),Vector2(-2.8,7.5),Vector2(5.5,7.5),
			Vector2(-1,-3.9),Vector2(7.4,-2.3),Vector2(-2,2.6)]:
		for i in 6:
			var a = i*TAU/6 + rng.randf_range(-0.22,0.22)
			var p = Vector3(stand.x+0.88*cos(a),0,stand.y+0.62*sin(a))
			if not ridge_clear(Rect2(p.x-0.60,p.z-0.60,1.20,1.20),rock_footprints):
				continue
			if i % 3 == 0:
				bush(p)
			else:
				tree(p,rng.randf_range(0.65,1.12))
	var spring = group(Vector3(10,0,-1.65))
	var cliff = quarry_rock(spring,Vector3(0,0,-0.47),profiles[2],0.12)
	cliff.scale = Vector3(1.28,1.75,0.91)
	for side in [-1,1]:
		var jamb = quarry_rock(spring,Vector3(side*0.51,0,0.50),profiles[1],0.10)
		jamb.scale = Vector3(0.31,0.81,0.56)
	var lintel = quarry_rock(spring,Vector3(0,0.63,0.44),profiles[1],0.09)
	lintel.scale = Vector3(0.88,0.42,0.57)
	oval(spring,Vector3(0,0.43,0.38),Vector3(0.92,0.59,0.21),"28282c")
	create_stream(PackedVector3Array([Vector3(10,0.30,-1.28),Vector3(10,0.29,-0.96),
		Vector3(10.02,0.26,-0.69),Vector3(10.06,0.12,-0.59),Vector3(10.1,0.04,-0.39),
		Vector3(9.7,0.036,1.4),Vector3(10,0.036,3.1),Vector3(9.35,0.036,5.4),
		Vector3(9.8,0.036,7.1),Vector3(10.2,0.036,9.5)]),4)

func build_stork_nest(at: Vector3):
	var nest = group(at)
	nest.name = "StorkNest"
	cone(nest,Vector3.ZERO,0.25,0.41,0.16,11,"705038","wood")
	oval(nest,Vector3.UP*0.075,Vector3(0.66,0.1,0.6),"a88854")
	for i in 26:
		var angle = TAU*i/13 + 0.19*floori(i/13.0)
		var stick = box(nest,Vector3(cos(angle)*0.36,0.10+0.041*floori(i/13.0),sin(angle)*0.36),
			Vector3(0.048,0.042,0.31+0.05*sin(i)),"906d49" if i%3 else "684d38","wood")
		stick.rotation = Vector3(0.13*sin(i*2),-angle,0)
	var bird = limb_joint(nest,Vector3.UP*0.10)
	bird.rotation.y = 1.22
	for side in [-1,1]:
		cone(bird,Vector3(side*0.065,0.19,0),0.019,0.025,0.37,7,"bf5745")
	oval(bird,Vector3(0,0.45,-0.035),Vector3(0.29,0.32,0.52),"f1ecdb")
	for side in [-1,1]:
		oval(bird,Vector3(side*0.09,0.44,-0.15),Vector3(0.14,0.22,0.43),"353b42")
		oval(bird,Vector3(side*0.10,0.48,-0.065),Vector3(0.14,0.19,0.28),"dddcd0")
	var neck = limb_joint(bird,Vector3(0,0.50,0.135))
	oval(neck,Vector3(0,0.16,0.035),Vector3(0.135,0.44,0.14),"f1ecdb")
	oval(neck,Vector3(0,0.36,0.065),Vector3(0.17,0.17,0.23),"f1ecdb")
	for side in [-1,1]:
		oval(neck,Vector3(side*0.077,0.38,0.10),Vector3.ONE*0.035,"27282b")
	cone(neck,Vector3(0,0.35,0.29),0.046,0.003,0.28,7,"d96a45").rotation.x = PI*0.53
	var glance = neck.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	glance.tween_interval(3.3)
	glance.tween_property(neck,"rotation:y",-0.52,0.85)
	glance.tween_property(neck,"rotation:x",0.28,0.65)
	glance.tween_interval(1.2)
	glance.tween_property(neck,"rotation",Vector3.ZERO,1.15)

func ridge_clear(footprint: Rect2, rocks: Array[Rect2] = []) -> bool:
	if not Rect2(-11.5,-11.5,23,21).encloses(footprint):
		return false
	for rock in rocks:
		if footprint.intersects(rock):
			return false
	for cells in [pads.keys(),route]:
		for cell in cells:
			if footprint.intersects(Rect2(Vector2(cell)-Vector2.ONE*0.5,Vector2.ONE)):
				return false
	return true

func quarry_rock(parent: Node3D, origin: Vector3, profile: Array, irregularity: float, lean: float = 0.0) -> MeshInstance3D:
	# Short bevels between broad faces catch the low evening light.
	var sides = 9
	var phase = parent.position.x + origin.z
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in profile.size():
		var ring_point: Vector2 = profile[level]
		var count = sides if ring_point.x > 0 else 1
		for i in count:
			var a = TAU*i/sides + 0.07*sin(i*3.7+phase)
			var h = ring_point.y / profile.back().y
			var r = ring_point.x*(1.0+irregularity*(sin(3*a+phase)+0.54*cos(4*a+h*2.8)))
			var tilt = r * sin(a+phase) * 0.12 * minf(h*8.0,1)
			mesh.add_vertex(Vector3(r*cos(a)+h*(lean+0.14*sin(phase)),ring_point.y+tilt,r*sin(a)))
		if level > 0:
			for i in sides:
				var low = (level-1)*sides
				var j = (i+1)%sides
				for index in [low+i,low+j,low+sides+(i if count>1 else 0)]:
					mesh.add_index(index)
				if count>1:
					for index in [low+j,low+sides+j,low+sides+i]:
						mesh.add_index(index)
	mesh.generate_normals()
	# Blend smooth vertex normals toward each actual fracture plane.
	mesh.deindex()
	var facets = SurfaceTool.new()
	facets.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrays = mesh.commit_to_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0,points.size(),3):
		var face = (points[i+2]-points[i]).cross(points[i+1]-points[i]).normalized()
		for j in range(i,i+3):
			facets.set_normal(normals[j].lerp(face,0.52).normalized())
			facets.add_vertex(points[j])
	var rock = MeshInstance3D.new()
	rock.mesh = facets.commit()
	rock.material_override = preload("res://shaders/quarry_rock.tres")
	parent.add_child(rock)
	rock.position = origin
	return rock

func build_mine(at: Vector3, facing: float):
	var mine = group(at)
	mine.rotation.y = facing
	quarry_rock(mine,Vector3(0,0,-0.24),[Vector2(1.0,0),Vector2(1.02,0.42),
		Vector2(0.88,0.76),Vector2(0.76,0.82),Vector2(0.70,1.13),
		Vector2(0.48,1.38),Vector2(0.31,1.45),Vector2(0,1.47)],0.12)
	for side in [-1,1]:
		var shoulder = quarry_rock(mine,Vector3(side*0.74,0,0.25),[Vector2(0.43,0),
			Vector2(0.39,0.32),Vector2(0.31,0.49),Vector2(0.18,0.69),Vector2(0,0.72)],0.13)
		shoulder.scale.y = 1.0 if side == 1 else 0.78
	box(mine,Vector3(0,0.49,0.71),Vector3(0.90,0.98,0.20),"332d29")
	for side in [-1,1]:
		box(mine,Vector3(side*0.48,0.52,0.85),Vector3(0.17,1.04,0.20),WOOD,"wood").rotation.z = -side*0.07
		box(mine,Vector3(side*0.46,0.82,0.97),Vector3(0.20,0.10,0.055),"605d50")
		box(mine,Vector3(side*0.20,0.068,1.14),Vector3(0.05,0.05,0.83),"68685b")
	box(mine,Vector3(0,1.04,0.86),Vector3(1.25,0.21,0.25),"ac8051","wood")
	for z in [0.90,1.15,1.4]:
		box(mine,Vector3(0,0.028,z),Vector3(0.60,0.055,0.11),WOOD,"wood")
	box(mine,Vector3(0.51,0.70,1.01),Vector3(0.14,0.19,0.12),"ffd38a")
	box(mine,Vector3(0.51,0.81,1.01),Vector3(0.18,0.05,0.16),"504c43")

func build_meadow():
	var extent = 8 if mill_valley else 4
	for x in range(-8,8):
		for z in range(-extent,extent+1):
			var cell = Vector2i(x,z)
			var near_castle = x >= 7 and (z <= -6 if mill_valley else z <= 0)
			if cell in route or near_castle or near_spawn_gate(cell):
				continue
			var near_road = false
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if (cell + step) in route:
					near_road = true
			if near_road:
				pads[cell] = box(self,ground(cell)+Vector3.UP*0.024,Vector3(0.90,0.048,0.90),"9da35c","grass")
			elif not (x >= 6 and z >= 0) and not (mill_valley and ((x >= 3 and z in [2,3,4]) or z == 6)) and rng.randf() < 0.42:
				tree(ground(cell),rng.randf_range(0.64,1.02))
	for i in 54:
		var p = Vector3(rng.randf_range(-9.2,9.2),0, rng.randf_range(4.85,5.62) * (-1 if i%2 else 1))
		if mill_valley:
			p.z = signf(p.z)*rng.randf_range(8.7,9.1)
			if Vector2(p.x,p.z).distance_to(Vector2(-7,8)) < 3.2 or Vector2(p.x,p.z).distance_to(Vector2(8,-7)) < 2.5:
				continue
		if i % 5 == 0:
			cone(self,p+Vector3.UP*0.17,0.38,0.23,0.35,5,"a5a489")
		else:
			tree(p,rng.randf_range(0.58,1.28))

func build_three_fields():
	# Three adjoining ten-cell squares, with the northeast quadrant open.
	for center in [Vector2(-5,-5), Vector2(-5,5), Vector2(5,5)]:
		box(self,Vector3(center.x,-0.51,center.y),Vector3(10,0.82,10),"796d50","earth")
		box(self,Vector3(center.x,-0.05,center.y),Vector3(10,0.10,10),MOSS,"grass")
	for cell in route:
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var site = cell + step
			if site in route or pads.has(site) or near_spawn_gate(site) or (site.x >= 0 and site.y <= 0):
				continue
			if (site.x >= 6 and site.y >= 6) or (site.x in [4,5] and site.y >= 5) or (site.x == 3 and site.y <= 4):
				continue
			pads[site] = box(self,ground(site)+Vector3.UP*0.024,Vector3(0.9,0.048,0.9),"9da35c","grass")
	var wheat = planted_field(Vector2(-5.05,8.4),Vector2(4.9,1.95),"ad884c","dbb85f")
	var scarecrow = Node3D.new()
	wheat.add_child(scarecrow)
	scarecrow.position = Vector3(1.3,0,-0.12)
	scarecrow.rotation.y = 0.25
	box(scarecrow,Vector3.UP*0.48,Vector3(0.075,0.96,0.075),WOOD,"wood")
	box(scarecrow,Vector3.UP*0.72,Vector3(0.75,0.055,0.06),"ad8a50","wood")
	cone(scarecrow,Vector3.UP*0.63,0.18,0.13,0.37,5,"a05439")
	for side in [-1,1]:
		box(scarecrow,Vector3(side*0.22,0.71,0),Vector3(0.22,0.12,0.13),"a05439").rotation.z = -side*0.12
	cone(scarecrow,Vector3.UP*0.92,0.12,0.14,0.22,7,"d4b779")
	cone(scarecrow,Vector3.UP*1.04,0.23,0.22,0.045,8,"b48c46")
	cone(scarecrow,Vector3.UP*1.12,0.15,0.055,0.16,7,"c89e52")
	planted_field(Vector2(-1.14,-0.55),Vector2(2,2),"8c8249","b4b562")
	build_farm_supplies()
	for p in [Vector2(-6.65,-3.1),Vector2(-5.85,-2.95),Vector2(-4.85,-3.1),
			Vector2(-6.35,4.05),Vector2(-5.28,4.15),Vector2(-4.38,3.98)]:
		tree(Vector3(p.x,0,p.y),rng.randf_range(0.64,0.90))
	for p in [Vector2(-9.55,-7.4),Vector2(-9.55,-6.4),Vector2(-1.1,-9),Vector2(-1.2,-7.8),
			Vector2(-1.1,-6.6),Vector2(-8.8,8.3),Vector2(-9.2,9.2),Vector2(0.6,9.1)]:
		tree(Vector3(p.x,0,p.y),rng.randf_range(0.65,0.95))
	build_stream()
	for i in 9:
		box(self,Vector3(3.83+i*0.16,0.08,7),Vector3(0.15,0.10,1.05),"95734f","wood")
	for z in [6.45,7.55]:
		box(self,Vector3(4.47,0.32,z),Vector3(1.52,0.075,0.065),WOOD,"wood")
		for x in [3.77,5.17]:
			box(self,Vector3(x,0.20,z),Vector3(0.09,0.4,0.09),WOOD,"wood")

func planted_field(center: Vector2, size: Vector2, soil: String, crop: String) -> Node3D:
	var plot = group(Vector3(center.x,0.018,center.y))
	box(plot,Vector3.ZERO,Vector3(size.x,0.035,size.y),soil,"field")
	var rows = maxi(1,roundi(size.x/0.3))
	for row in rows:
		var x = size.x * ((row+0.5)/rows - 0.5)
		box(plot,Vector3(x,0.056,0),Vector3(0.11,0.09,size.y-0.16),crop,"field")
	return plot

func build_farm_supplies():
	var yard = group(Vector3(-1.22,0,-1.92))
	for offset in [Vector2(-0.52,0.02),Vector2(-0.11,-0.10)]:
		var barrel = Node3D.new()
		yard.add_child(barrel)
		barrel.position = Vector3(offset.x,0,offset.y)
		cone(barrel,Vector3.UP*0.09,0.16,0.195,0.18,10,"956944","wood")
		cone(barrel,Vector3.UP*0.29,0.195,0.16,0.22,10,"956944","wood")
		for h in [0.085,0.305]:
			cone(barrel,Vector3.UP*h,0.19,0.19,0.034,10,"514b43")
		cone(barrel,Vector3.UP*0.402,0.142,0.142,0.012,10,"bc925f","wood")
	var crate = group(Vector3(-0.64,0,-1.91))
	crate.rotation.y = -0.16
	box(crate,Vector3.UP*0.055,Vector3(0.45,0.09,0.32),WOOD,"wood")
	for h in [0.12,0.21]:
		for side in [-1,1]:
			box(crate,Vector3(0,h,side*0.16),Vector3(0.47,0.072,0.035),"ad8052","wood")
			box(crate,Vector3(side*0.21,h,0),Vector3(0.035,0.072,0.30),"ad8052","wood")
	for x in [-0.12,0,0.12]:
		for z in [-0.07,0.07]:
			cone(crate,Vector3(x,0.21,z),0.065,0.042,0.10,6,"ce783a")
	var fork = group(Vector3(-1.82,0,-1.64))
	fork.rotation.z = -0.19
	box(fork,Vector3.UP*0.51,Vector3(0.037,0.63,0.037),WOOD,"wood")
	box(fork,Vector3.UP*0.20,Vector3(0.19,0.036,0.032),"565954")
	for x in [-0.078,0,0.078]:
		box(fork,Vector3(x,0.11,0),Vector3(0.02,0.18,0.025),"565954")

func build_stream():
	var centers = PackedVector3Array([
		Vector3(3.2,0.032,0),Vector3(3.65,0.032,1.8),Vector3(3.35,0.032,3.5),
		Vector3(4.55,0.032,5.3),Vector3(4.45,0.032,7.9),Vector3(5.25,0.032,9.65),
		Vector3(5.3,0.032,10)])
	create_stream(centers)

func create_stream(centers: PackedVector3Array, bank_start: int = 0):
	var bed_count = centers.size()
	var lip = centers[-1]
	for i in range(1,11):
		var t = i * 0.048
		centers.append(lip + Vector3(0.14*t,-4.9*t*t,1.12*t))
	var water = ShaderMaterial.new()
	water.shader = preload("res://shaders/stream.gdshader")
	for is_water in [false,true]:
		var strip = SurfaceTool.new()
		strip.begin(Mesh.PRIMITIVE_TRIANGLES)
		strip.set_material(water if is_water else mat("bba878","earth"))
		var distance = 0.0
		var count = centers.size() if is_water else bed_count
		var first = 0 if is_water else bank_start
		for i in range(first,count):
			if i > first:
				distance += centers[i].distance_to(centers[i-1])
			var tangent = centers[mini(i+1,centers.size()-1)] - centers[maxi(i-1,0)]
			var across = Vector3(tangent.z,0,-tangent.x).normalized()
			# Square both ends of the riverbed against the straight map edge.
			if i == 0 or i >= bed_count-1:
				across = Vector3.RIGHT
			for side in [-1,1]:
				var width = 0.32 if is_water else 0.425
				width *= 1.0 - 0.18 * clampf(lip.y-centers[i].y,0,1)
				var point = centers[i] + across * side * width
				if not is_water:
					point.y -= 0.018
				strip.set_uv(Vector2((side+1)*0.5,distance))
				strip.add_vertex(point)
			if i > first:
				var start = (i-first-1)*2
				for offset in [0,1,2,1,3,2]:
					strip.add_index(start+offset)
		strip.generate_normals()
		var surface = MeshInstance3D.new()
		surface.mesh = strip.commit()
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(surface)
	var spray = CPUParticles3D.new()
	spray.amount = 64
	spray.lifetime = 0.62
	spray.preprocess = 0.7
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(0.31,0.018,0.035)
	spray.direction = Vector3(0.08,0.09,1)
	spray.spread = 24
	spray.initial_velocity_min = 0.92
	spray.initial_velocity_max = 1.55
	spray.gravity = Vector3.DOWN * 9.8
	spray.scale_amount_min = 0.65
	spray.scale_amount_max = 1.25
	var taper = Curve.new()
	taper.add_point(Vector2(0,0.45))
	taper.add_point(Vector2(0.55,1))
	taper.add_point(Vector2(1,0))
	spray.scale_amount_curve = taper
	var drop = SphereMesh.new()
	drop.radius = 0.027
	drop.height = 0.077
	drop.radial_segments = 5
	drop.rings = 2
	drop.material = mat("c5e3da")
	spray.mesh = drop
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)
	spray.position = lip + Vector3.UP * 0.025

func fit_camera():
	var size = get_viewport().get_visible_rect().size
	camera.size = maxf(17.5,24.0*size.y/maxf(size.x,1)) * camera_zoom
	if cemetery_stage:
		camera.size = maxf(20.5,(Cemetery.WIDTHS[cemetery_stage-1]+8)*size.y/maxf(size.x,1))*camera_zoom
		if cemetery_stage >= 4:
			camera.size = maxf(camera.size,(Cemetery.DEPTHS[cemetery_stage-1]*0.63+Cemetery.WIDTHS[cemetery_stage-1]*0.2+7)*camera_zoom)

func pan_camera(offset: Vector3):
	var focus = camera.position - CAMERA_OFFSET + offset
	var depth = 9.0 if level_number >= 2 else 5.0
	if cemetery_stage >= 4:
		depth = Cemetery.DEPTHS[cemetery_stage-1]*0.5
	var width = Cemetery.WIDTHS[cemetery_stage-1]*0.5 if cemetery_stage else 9.0
	camera.position = CAMERA_OFFSET + Vector3(clampf(focus.x,-width,width),0,clampf(focus.z,-depth,depth))

func ground_at_screen(point: Vector2) -> Vector3:
	var origin = camera.project_ray_origin(point)
	var direction = camera.project_ray_normal(point)
	return origin - direction * (origin.y / direction.y)

func _input(event):
	if not dragging_map:
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			pan_camera(ground_at_screen(event.position-event.relative)-ground_at_screen(event.position))
			get_viewport().set_input_as_handled()
		else:
			dragging_map = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		dragging_map = false
		get_viewport().set_input_as_handled()

func build_windmill():
	var mill = group(Vector3(4.2,0,3))
	cone(mill,Vector3.UP*0.82,0.57,0.39,1.64,8,"caba97","stone")
	cone(mill,Vector3.UP*1.91,0.57,0.06,0.56,8,"804c34","roof")
	box(mill,Vector3(0,0.31,0.50),Vector3(0.28,0.6,0.06),WOOD,"wood")
	var hub = limb_joint(mill,Vector3(0,1.56,0.62))
	for i in 4:
		var spoke = limb_joint(hub,Vector3.ZERO)
		spoke.rotation.z = i * PI/2
		box(spoke,Vector3(0,0.55,0),Vector3(0.065,1.1,0.065),WOOD,"wood")
		box(spoke,Vector3(0.11,0.75,0.01),Vector3(0.19,0.62,0.035),"e1cda4")
	var turn = hub.create_tween().set_loops()
	turn.tween_property(hub,"rotation:z",TAU,12.0).from(0.0)

func fort():
	if three_fields:
		village([Vector2(6.1,1.1),Vector2(7.6,2.4),Vector2(8.25,0.8),Vector2(-1.25,-4.4),Vector2(-1.35,-2.7)])
	elif not cemetery_stage:
		village()
	if not cemetery_stage:
		castle(ground(route.back()),1.0)
	# A timber outwork brings the point of impact in front of the corner tower.
	var outer_gate = group(ground(route.back()) + Vector3.LEFT * (GATE_OFFSET - 0.34))
	for z in [-0.49, 0.49]:
		box(outer_gate, Vector3(0,0.48,z), Vector3(0.14,0.96,0.14), WOOD, "wood")
		box(outer_gate, Vector3(0.38,0.53,z), Vector3(0.75,0.12,0.10), WOOD, "wood")
	for z in [-0.32, -0.16, 0.0, 0.16, 0.32]:
		gate_boards.append(box(outer_gate, Vector3(0,0.36,z), Vector3(0.12,0.72,0.15), "856747", "wood"))
	gate_strap = box(outer_gate, Vector3(-0.07,0.46,0), Vector3(0.05,0.075,0.88), "535651")
	var gate = group(ground(route.front()))
	for z in [-0.52,0.52]:
		box(gate,Vector3(0,0.68,z),Vector3(0.16,1.36,0.16),WOOD,"wood")
	box(gate,Vector3.UP*1.32,Vector3(0.19,0.22,1.24),WOOD,"wood")
	box(gate,Vector3(0.11,1.12,0),Vector3(0.05,0.38,0.36),"985542")

func hud_panel(root,at_bottom):
	var panel = PanelContainer.new()
	root.add_child(panel)
	if at_bottom:
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_top = -106
		panel.offset_bottom = -18
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		panel.offset_top = 18
		panel.offset_bottom = 76
	panel.offset_left = 22
	panel.offset_right = -22
	panel.add_theme_stylebox_override("panel",panel_color("273831","6b765a"))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	panel.add_child(row)
	return row

func label_style(label, size, tone):
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color(tone))

func build_ui():
	add_child(ui)
	ui.add_child(health_bars)
	health_bars.draw.connect(draw_health_bars)
	ui.add_child(rewards)
	var root = Control.new()
	hud_root = root
	ui.add_child(root)
	fit_interface(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = hud_panel(root,false)
	var title = Label.new()
	title.text = Campaign.level_title(level_number).to_upper()
	label_style(title,24,"f3dfb7")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var coin = TextureRect.new()
	coin.texture = COIN_ICON
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	top.add_child(coin)
	label_style(stats,20,"f7e9c8")
	top.add_child(stats)
	build_speed_controls(root)
	if cemetery_stage == 5:
		boss_warning = Label.new()
		root.add_child(boss_warning)
		boss_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		boss_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
		boss_warning.offset_top = 92
		boss_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_style(boss_warning,24,"ffdab0")
		boss_warning.add_theme_stylebox_override("normal",panel_color("422b39f0","af815d"))
		boss_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_warning.hide()
	var bottom = hud_panel(root,true)
	build_tower_row(bottom,false)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_style(hint,18,"f2e7c9")
	bottom.add_child(hint)
	action.custom_minimum_size.x = 226
	action.add_theme_stylebox_override("normal",panel_color("78582d","c4a365"))
	action.add_theme_stylebox_override("hover",panel_color("92703d","dfb766"))
	action.add_theme_stylebox_override("disabled",panel_color("35463f","626e60"))
	action.add_theme_font_size_override("font_size",19)
	bottom.add_child(action)
	action.pressed.connect(advance)
	build_tower_row(bottom,true)
	root.add_child(preload("res://scripts/ui/pause_menu.gd").new())
	default_hint()

func build_speed_controls(root: Control):
	root.add_child(speed_panel)
	speed_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speed_panel.offset_right = -22
	speed_panel.offset_left = -222
	speed_panel.offset_top = 82
	speed_panel.add_theme_stylebox_override("panel",panel_color("273831","6b765a"))
	var row = HBoxContainer.new()
	speed_panel.add_child(row)
	var caption = Label.new()
	caption.text = "Скорость"
	label_style(caption,16,"edcf94")
	row.add_child(caption)
	var choices = ButtonGroup.new()
	for rate in [1,2,3]:
		var button = Button.new()
		button.text = "%d×" % rate
		button.custom_minimum_size = Vector2(38,28)
		button.toggle_mode = true
		button.button_group = choices
		button.button_pressed = rate == 1
		var active = panel_color("78582d","edc572")
		active.content_margin_left = 4
		active.content_margin_right = 4
		active.content_margin_top = 2
		active.content_margin_bottom = 2
		button.add_theme_stylebox_override("pressed",active)
		button.add_theme_stylebox_override("hover_pressed",active)
		row.add_child(button)
		button.pressed.connect(func():
			if Engine.time_scale != rate:
				Engine.time_scale = rate
				$SpeedCue.play()
		)

func _exit_tree():
	Engine.time_scale = 1.0

func build_tower_row(bottom, upgrades: bool):
	var stack = VBoxContainer.new()
	bottom.add_child(stack)
	var caption = Label.new()
	caption.text = "Улучшение" if upgrades else "Постройка"
	label_style(caption,15,"edcf94")
	stack.add_child(caption)
	var tiles = HBoxContainer.new()
	stack.add_child(tiles)
	var panel = upgrade_panel if upgrades else info_panel
	# A plain Control anchors the floating panel without taking up row space.
	var anchor = Control.new()
	caption.add_child(anchor)
	panel.add_theme_stylebox_override("panel",panel_color("263a32","bc9b60"))
	anchor.add_child(panel)
	panel.hide()
	var choices = ButtonGroup.new()
	for kind in Tower.values():
		if not tower_available(kind):
			continue
		var tile = Button.new()
		tile.name = ["ArcherTile","MortarTile","MillTile","BallistaTile"][kind]
		if not upgrades:
			tile.toggle_mode = true
			tile.button_group = choices
			tile.button_pressed = kind == selected_tower
		tile.icon = TOWER_ICONS[kind]
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.expand_icon = true
		tile.custom_minimum_size = Vector2(46,46)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for state in ["normal","hover","pressed","hover_pressed"]:
			var selected = state in ["pressed","hover_pressed"]
			var style = panel_color("695638" if selected else "344a40","edc572" if selected else "84947a")
			style.set_border_width_all(3 if selected else 1)
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			if state in ["hover","hover_pressed"]:
				style.bg_color = style.bg_color.lightened(0.12)
			tile.add_theme_stylebox_override(state,style)
		tiles.add_child(tile)
		tile.pressed.connect($MenuClick.play.bind(0.0))
		if upgrades:
			var show_upgrade = func():
				upgrade_hover_tile = tile
				info_panel.hide()
				upgrade_title.text = TOWER_NAMES[kind]
				upgrade_kind = kind
				refresh_upgrade()
				panel.show()
				panel.reset_size()
				panel.position = Vector2(stack.size.x-panel.size.x,tiles.position.y-panel.size.y)
			tile.mouse_entered.connect(show_upgrade)
			tile.pressed.connect(show_upgrade)
		else:
			tile.mouse_entered.connect(func():
				world_info_visible = false
				upgrade_panel.hide()
				show_tower_details(kind)
			)
			tile.mouse_exited.connect(info_panel.hide)
			tile.pressed.connect(func():
				selected_tower = kind
				if not finished:
					default_hint()
			)
	if upgrades:
		var options = VBoxContainer.new()
		panel.add_child(options)
		var header = HBoxContainer.new()
		options.add_child(header)
		upgrade_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_style(upgrade_title,22,"ffe4ad")
		header.add_child(upgrade_title)
		var close = Button.new()
		close.text = "×"
		header.add_child(close)
		close.pressed.connect(panel.hide)
		close.pressed.connect($MenuClick.play.bind(0.0))
		options.add_child(upgrade_stats)
		options.add_child(upgrade_action)
		upgrade_action.pressed.connect($MenuClick.play.bind(0.0))
		upgrade_action.pressed.connect(buy_upgrade)
		return
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower_details.bbcode_enabled = true
	tower_details.custom_minimum_size = Vector2(320,180)
	tower_details.fit_content = true
	tower_details.scroll_active = false
	tower_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower_details.add_theme_font_size_override("bold_font_size",18)
	panel.add_child(tower_details)

func _hide_upgrade_outside(tile):
	var point = upgrade_panel.get_global_mouse_position()
	if upgrade_panel.get_global_rect().has_point(point):
		return
	if is_instance_valid(tile) and tile.get_global_rect().has_point(point):
		return
	upgrade_panel.hide()

func stat_text(value: float) -> String:
	if is_equal_approx(value,roundf(value)):
		return str(roundi(value))
	return String.num(value,2).replace(".",",")

func archer_damage() -> float:
	return VETERAN_DAMAGE if upgraded[Tower.ARCHER] else ARROW_DAMAGE

func archer_interval() -> float:
	return VETERAN_INTERVAL if upgraded[Tower.ARCHER] else ARCHER_INTERVAL

func tower_range(kind: int) -> float:
	return ELITE_RANGES[kind] if upgraded[kind] else TOWER_RANGES[kind]

func tower_available(kind: int) -> bool:
	return (kind != Tower.MILL or level_number >= 3) and (kind != Tower.BALLISTA or level_number >= 7)

func refresh_upgrade():
	match upgrade_kind:
		Tower.BALLISTA:
			upgrade_stats.text = "Урон по каждой цели  %d\nДальность  %d кл." % [Ballista.DAMAGE[1],ELITE_RANGES[Tower.BALLISTA]]
		Tower.ARCHER:
			upgrade_stats.text = "Урон  %s\nВыстрел каждые %s с" % [stat_text(VETERAN_DAMAGE),stat_text(VETERAN_INTERVAL)]
		Tower.MORTAR:
			upgrade_stats.text = "Урон  %d\nРадиус взрыва  %s кл.\nДальность  %s кл." % [HEAVY_SHELL_DAMAGE,stat_text(HEAVY_BLAST_RADIUS),stat_text(ELITE_RANGES[Tower.MORTAR])]
		Tower.MILL:
			upgrade_stats.text = "Замедление  %d%%\nРадиус  %s кл." % [STRONG_WIND_PERCENT,stat_text(ELITE_RANGES[Tower.MILL])]
	var price = UPGRADE_COSTS[upgrade_kind]
	upgrade_action.disabled = finished or upgraded[upgrade_kind] or coins < price
	upgrade_action.text = "Уровень 2 получен" if upgraded[upgrade_kind] else "Улучшить за %d монет" % price

func buy_upgrade():
	var price = UPGRADE_COSTS[upgrade_kind]
	if finished or upgraded[upgrade_kind] or coins < price or not tower_available(upgrade_kind):
		return
	coins -= price
	upgraded[upgrade_kind] = true
	for tower in towers:
		if tower.kind == upgrade_kind:
			tower.range = tower_range(tower.kind)
			reinforce_tower(tower,true)
	$BrickLay.play()
	refresh()

func reinforce_tower(tower, animate: bool):
	var base: Node3D = tower.node
	if tower.kind == Tower.ARCHER:
		reinforce_archer(base,animate)
		return
	if tower.kind == Tower.BALLISTA:
		Ballista.reinforce(self,tower.barrel)
	elif tower.kind == Tower.MORTAR:
		var tube = tower.barrel.get_node("Tube")
		tube.scale = Vector3(1.2,1.12,1.2)
		for h in [0.18,0.42]:
			cone(tube,Vector3.UP*h,0.226,0.226,0.07,10,"cda153")
		for side in [-1,1]:
			box(tower.barrel,Vector3(side*0.27,0.12,0),Vector3(0.09,0.28,0.49),"565d61")
	else:
		cone(base,Vector3.UP*0.34,0.45,0.40,0.22,8,"b6aa91","stone")
		var rotor = base.get_node("Rotor")
		rotor.scale = Vector3.ONE*1.15
		for i in 3:
			var sail = limb_joint(rotor,Vector3.ZERO)
			sail.rotation.z = (i+0.5)*TAU/3
			box(sail,Vector3.UP*0.30,Vector3(0.045,0.60,0.05),WOOD,"wood")
			box(sail,Vector3(0.07,0.40,0),Vector3(0.13,0.35,0.03),"83aeaa")
	if animate:
		tower_dust(base.position,false)
		base.scale = Vector3(1,0.88,1)
		base.create_tween().tween_property(base,"scale",Vector3.ONE,0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func reinforce_archer(base: Node3D, animate: bool):
	var stonework = limb_joint(base,Vector3.ZERO)
	cone(stonework,Vector3.UP*0.18,0.47,0.40,0.36,8,"998a79","stone")
	cone(stonework,Vector3.UP*1.05,0.47,0.49,0.17,8,"a99b84","stone")
	for i in 8:
		var angle = i * TAU/8
		var block = box(stonework,Vector3(0.43*sin(angle),1.21,0.43*cos(angle)),Vector3(0.17,0.22,0.15),"d2c5aa","stone")
		block.rotation.y = angle
	box(stonework,Vector3(0,0.84,0.33),Vector3(0.19,0.38,0.045),"92432d")
	box(stonework,Vector3(0,0.85,0.36),Vector3(0.045,0.29,0.016),GOLD)
	if animate:
		tower_dust(base.position,false)
		stonework.scale.y = 0.05
		stonework.create_tween().tween_property(stonework,"scale:y",1.0,0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_tower_details(kind: int):
	var description: String
	if kind == Tower.MILL:
		description = "Замедление   [color=#ffd079]%d%%[/color]\nДействует, пока враг в радиусе" % (STRONG_WIND_PERCENT if upgraded[kind] else MILL_SLOW_PERCENT)
	elif kind == Tower.BALLISTA:
		description = "Урон по каждой цели   [color=#ffd079]%d[/color]\nВыстрел каждые   [color=#ffd079]%s с[/color]" % [Ballista.DAMAGE[int(upgraded[kind])],stat_text(Ballista.INTERVAL)]
	else:
		var mortar = kind == Tower.MORTAR
		description = "Урон   [color=#ffd079]%s[/color]\nВыстрел каждые   [color=#ffd079]%s с[/color]" % [
			stat_text((HEAVY_SHELL_DAMAGE if upgraded[kind] else SHELL_DAMAGE) if mortar else archer_damage()),stat_text(MORTAR_INTERVAL if mortar else archer_interval())]
		if mortar:
			description += "\nРадиус взрыва   [color=#ffd079]%s кл.[/color]" % stat_text(HEAVY_BLAST_RADIUS if upgraded[kind] else BLAST_RADIUS)
	tower_details.text = ("[b][font_size=23][color=#ffe4ad]%s[/color][/font_size]\n%s\n%s\n" +
		"Дальность   [color=#ffd079]%s кл.[/color]\nЦена   [color=#ffd079]%d монет[/color][/b]") % [
		TOWER_NAMES[kind]+(" · II" if upgraded[kind] else ""),TOWER_ROLES[kind],description,stat_text(tower_range(kind)),TOWER_COSTS[kind]]
	info_panel.show()
	info_panel.reset_size()
	info_panel.position = Vector2(0,-info_panel.size.y-4)

func draw_health_bars():
	var normal_width = clampf(get_viewport().get_visible_rect().size.y * 0.028, 16, 32)
	var height = maxf(3, roundf(normal_width * 0.14))
	for mob in enemies:
		var reaper = mob.get("kind","") == "death"
		var width = normal_width*2.8 if reaper else normal_width
		var anchor = mob.body.global_position + Vector3.UP * (mob.body.scale.y * (1.31 if reaper else 0.94))
		var pos = (camera.unproject_position(anchor) - Vector2(width * 0.5, height + 3)).round()
		var ratio = float(mob.hp) / mob.max_hp
		var fill = Color("#91c45c") if ratio > 0.5 else Color("#e6b553") if ratio > 0.25 else Color("#e36e50")
		if reaper:
			var label = "Мир духов" if mob.in_spirit else "Смерть"
			health_bars.draw_string(ThemeDB.fallback_font,pos-Vector2(0,3),label,HORIZONTAL_ALIGNMENT_CENTER,width,13)
			if mob.in_spirit:
				fill = Color("#97d6ed")
		health_bars.draw_rect(Rect2(pos - Vector2.ONE, Vector2(width + 2, height + 2)), Color("#29241e"))
		health_bars.draw_rect(Rect2(pos, Vector2(width, height)), Color("#634c42"))
		health_bars.draw_rect(Rect2(pos, Vector2(maxf(1, roundf(width * ratio)), height)), fill)

func default_hint():
	hint.text = TOWER_NAMES[selected_tower]

func refresh():
	refresh_upgrade()
	stats.text = "Золото   %d      •      Ворота   %d / 12      •      Волна   %d / %d" % [coins,lives,wave,wave_count]
	action.disabled = fighting and not finished
	if finished:
		action.text = "Сыграть снова"
	elif fighting:
		action.text = "Идёт волна %d" % wave
	else:
		action.text = "Начать волну %d   ›" % (wave+1)

func advance():
	if finished:
		if lives > 0:
			return
		get_tree().reload_current_scene()
		return
	if fighting:
		return
	wave += 1
	fighting = true
	remaining = 5 + wave*2
	if cemetery_stage:
		remaining = 8+cemetery_stage+(wave-1)*2
	elif level_number >= 4:
		remaining = 10 + (wave-1)*2
	elif three_fields:
		remaining = 9 + (wave-1)*2
	elif mill_valley:
		remaining = roundi(remaining * 1.2)
	spawn_clock = 0
	reaper_pending = cemetery_stage == 5 and wave == wave_count
	refresh()

func mouse_cell(point = get_viewport().get_mouse_position()):
	var origin = camera.project_ray_origin(point)
	var hit = Plane(Vector3.UP,0.05).intersects_ray(origin,camera.project_ray_normal(point))
	if hit == null:
		return Vector2i(999,999)
	return Vector2i(roundi(hit.x),roundi(hit.z))

func _unhandled_input(event):
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging_map = true
		get_viewport().set_input_as_handled()
		return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var anchor = ground_at_screen(event.position)
		var step = 0.86 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/0.86
		camera_zoom = clampf(camera_zoom * pow(step,event.factor),0.55,1.55)
		fit_camera()
		pan_camera(anchor-ground_at_screen(event.position))
		get_viewport().set_input_as_handled()
		return
	if finished:
		return
	var cell = mouse_cell(event.position)
	if event.button_index == MOUSE_BUTTON_RIGHT:
		sell_tower(cell, event.position)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not pads.has(cell) or not tower_available(selected_tower):
		return
	var price = TOWER_COSTS[selected_tower]
	if coins < price:
		hint.text = "Для башни нужно ещё %d монет" % (price-coins)
		message_time = 2.4
		return
	var n = group(ground(cell))
	var tower = {"node":n,"cool":0.0,"cell":cell,"pad":pads[cell],"price":price,
		"range": tower_range(selected_tower), "kind":selected_tower, "barrel":null}
	if selected_tower == Tower.MILL:
		build_slow_mill(n)
	elif selected_tower == Tower.MORTAR:
		tower.barrel = build_mortar(n)
	elif selected_tower == Tower.BALLISTA:
		tower.barrel = Ballista.build(self,n)
	else:
		turret(n,Vector3.ZERO,0.85)
	if upgraded[selected_tower]:
		reinforce_tower(tower,false)
	towers.append(tower)
	tower_dust(n.position, false)
	$BrickLay.play()
	pads[cell].material_override = mat("89835c","grass")
	pads.erase(cell)
	ring.hide()
	coins -= price
	default_hint()
	message_time = 0
	refresh()

func tower_at(cell, point):
	# Test the projected silhouette first so a click on the roof also works.
	var selected = null
	var best = INF
	for tower in towers:
		var base = camera.unproject_position(tower.node.position)
		var top = camera.unproject_position(tower.node.position + Vector3.UP * (1.2 if tower.barrel else 1.9))
		var width = 0.62 if tower.kind == Tower.MILL else 0.40
		var radius = base.distance_to(camera.unproject_position(tower.node.position + camera.global_basis.x * width))
		var distance = point.distance_to(Geometry2D.get_closest_point_to_segment(point, base, top))
		if distance <= radius and distance < best:
			selected = tower
			best = distance
	if selected == null:
		for tower in towers:
			if tower.cell == cell:
				selected = tower
				break
	return selected

func sell_tower(cell, point):
	var selected = tower_at(cell, point)
	if selected == null:
		return
	towers.erase(selected)
	tower_dust(selected.node.position, true)
	$BrickRubble.play()
	selected.node.queue_free()
	pads[selected.cell] = selected.pad
	selected.pad.material_override = mat(pad_color,"grass")
	hovered = Vector2i(999,999)
	var refund = int(selected.price * 0.5)
	coins += refund
	show_reward(selected.node.position + Vector3.UP*1.2,refund)
	hint.text = "Башня продана за %d монет" % refund
	message_time = 2
	refresh()

func tower_dust(at: Vector3, demolition: bool):
	var cloud = group(at)
	var shape = SphereMesh.new()
	shape.radius = 0.16
	shape.height = 0.24
	shape.radial_segments = 6
	shape.rings = 2
	var spread = cloud.create_tween().set_parallel()
	var count = 10 if demolition else 7
	for i in count:
		var angle = TAU * (i + randf_range(-0.2,0.2)) / count
		var outward = Vector3(cos(angle),0,sin(angle))
		var start = outward * 0.36 + Vector3.UP * randf_range(0.10,0.18)
		var puff = mesh_part(cloud,shape,start,"bbab90" if i%2 else "cbbda4")
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lifetime = randf_range(0.40,0.58)
		var end = start + outward * (0.45 if demolition else 0.26) + Vector3.UP * randf_range(0.16,0.38)
		spread.tween_property(puff,"position",end,lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spread.tween_property(puff,"scale",Vector3.ZERO,lifetime-0.12).set_delay(0.12)
	spread.chain().tween_callback(cloud.queue_free)

func show_reward(at: Vector3, gold: int):
	var popup = HBoxContainer.new()
	rewards.add_child(popup)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon = TextureRect.new()
	icon.texture = COIN_ICON
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(icon)
	var amount = Label.new()
	amount.text = "+%d" % gold
	label_style(amount, 18, "ffe59d")
	amount.add_theme_constant_override("outline_size", 4)
	popup.add_child(amount)
	var factor = clampf(get_viewport().get_visible_rect().size.y / 800, 0.75, 1.35)
	popup.scale = Vector2.ONE * factor
	popup.position = camera.unproject_position(at) - Vector2(popup.get_combined_minimum_size().x * 0.5, 26) * factor
	var fade = popup.create_tween().set_parallel()
	fade.tween_property(popup, "position:y", popup.position.y - 32 * factor, 0.85)
	fade.tween_property(popup, "modulate:a", 0.0, 0.4).set_delay(0.45)
	fade.chain().tween_callback(popup.queue_free)

func limb_joint(parent: Node3D, at: Vector3) -> Node3D:
	var joint = Node3D.new()
	parent.add_child(joint)
	joint.position = at
	return joint

func build_goblin_head(parent: Node3D, skin: String):
	box(parent,Vector3.UP*0.38,Vector3(0.31,0.25,0.26),skin)
	cone(parent,Vector3.UP*0.54,0.23,0.08,0.19,5,"484b46")

func spawn_enemy():
	if cemetery_stage:
		enemies.append(Undead.spawn(self))
		return
	var n = group(ground(route.front()))
	var ogre = dusk_ridge and ((wave in [6,12] and remaining == 1) or (wave == 12 and remaining == 17))
	var brute = ogre or (wave >= 3 and remaining%4 == 0)
	var body = Node3D.new()
	n.add_child(body)
	var skin = "788349" if not brute else "8d7057"
	if ogre:
		skin = "9a9b68"
	var chest = limb_joint(body, Vector3.UP * 0.29)
	var legs = []
	var arms = []
	var guard_elbow: Node3D
	for side in [-1,1]:
		var hip = limb_joint(body, Vector3(side*0.10,0.30,0))
		box(hip,Vector3(0,-0.13,0),Vector3(0.14,0.26,0.14),WOOD,"wood")
		box(hip,Vector3(0,-0.25,0.038),Vector3(0.15,0.10,0.21),"514036")
		legs.append(hip)
		var shoulder = limb_joint(chest, Vector3(side*0.22,0.25,0))
		if side == -1:
			box(shoulder,Vector3.DOWN*0.095,Vector3(0.12,0.19,0.14),skin)
			guard_elbow = limb_joint(shoulder,Vector3.DOWN*0.19)
			box(guard_elbow,Vector3.DOWN*0.105,Vector3(0.11,0.21,0.12),skin)
			box(guard_elbow,Vector3.DOWN*0.22,Vector3(0.13,0.10,0.13),skin)
		else:
			box(shoulder,Vector3(0,-0.12,0),Vector3(0.12,0.24,0.14),skin)
			box(shoulder,Vector3(0,-0.21,0.065),Vector3(0.13,0.13,0.18),skin)
		arms.append(shoulder)
	box(chest,Vector3.UP*0.10,Vector3(0.33,0.34,0.24),"924938")
	build_goblin_head(chest,skin)
	if ogre:
		body.scale = Vector3(2.55,1.85,2.15)
		oval(chest,Vector3(0,0.08,0.035),Vector3(0.53,0.45,0.38),skin)
		box(chest,Vector3(0,-0.025,0.035),Vector3(0.44,0.085,0.33),"694831","wood")
		box(chest,Vector3(0,-0.025,0.21),Vector3(0.09,0.07,0.025),"c89a61")
		oval(arms[0],Vector3.ZERO,Vector3(0.27,0.19,0.29),"626876")
		for side in [-1,1]:
			cone(chest,Vector3(side*0.105,0.37,0.15),0.038,0.006,0.11,6,"efe2b8")
		var club = limb_joint(arms[1],Vector3(0,-0.22,0.12))
		club.rotation.x = 1.14
		cone(club,Vector3.UP*0.12,0.035,0.052,0.34,7,WOOD,"wood")
		cone(club,Vector3.UP*0.34,0.085,0.12,0.24,7,"84634a","wood")
	elif brute:
		body.scale = Vector3.ONE*1.38
	var hp = health_table[wave-1] * (7 if ogre else (2 if brute else 1))
	var mob = {"node":n,"body":body,"chest":chest,"legs":legs,"arms":arms,"guard_elbow":guard_elbow,
		"phase_offset":rng.randf_range(0,TAU),"progress":0.0,"hp":hp,"max_hp":hp,
		"brute":brute,"ogre":ogre,"speed":0.75 if ogre else (1.0 if brute or wave <= 3 else 1.5)}
	animate_gait(mob)
	enemies.append(mob)

func animate_gait(mob, shielding: bool = false):
	if cemetery_stage:
		Undead.animate(mob,shielding)
		return
	var stride = 1.1 if mob.brute else 0.70
	if mob.ogre:
		stride = 1.5
	var phase = mob.phase_offset + TAU * mob.progress / stride
	var swing = sin(phase)
	var transfer = cos(phase)
	var scale_y = mob.body.scale.y
	for i in 2:
		var side = 1.0 if i == 0 else -1.0
		var lift = maxf(0, -side * transfer)
		mob.legs[i].position.y = 0.30 + lift * (0.085 if mob.brute else 0.10)
		mob.legs[i].rotation.x = side * swing * (0.55 if mob.brute else 0.79)
		mob.arms[i].rotation = Vector3(-side * swing * (0.32 if mob.brute else 0.84),0,0)
	mob.guard_elbow.rotation = Vector3(-1.0,0,0)
	mob.chest.rotation.x = 0.07 if mob.brute else 0.20
	mob.chest.rotation.y = swing * (0.12 if mob.brute else 0.18)
	if mob.brute:
		mob.body.position.x = -0.055 * transfer
		mob.chest.rotation.z = 0.09 * transfer
		# Sink onto the planted boot at each change of support.
		mob.body.position.y = 0.05 - scale_y * 0.038 * pow(absf(swing), 4)
	else:
		mob.body.position.y = 0.05 + 0.045 * swing * swing
		mob.chest.rotation.z = 0.0
	if mob.ogre:
		# Shift weight before lifting the opposite foot. The club lags behind the torso.
		mob.body.position.x = -0.13*transfer
		mob.body.position.y = 0.07 - 0.09*pow(absf(swing),6)
		mob.chest.rotation = Vector3(0.17+0.06*absf(swing),0.22*swing,0.18*transfer)
		mob.arms[1].rotation.x = -0.3 + 0.48*sin(phase-0.45)
		for i in 2:
			mob.legs[i].position.y += maxf(0,transfer*(1 if i == 1 else -1))*0.09
	if shielding:
		# Fold the forearm across the eyes in chest space so it follows the head.
		var upper = Vector3(0.045,0.055,0.18).normalized()
		var forearm = Vector3(0.21,0.09+0.012*swing,0.01).normalized()
		var shoulder_pose = Quaternion(Vector3.DOWN,upper)
		mob.arms[0].quaternion = shoulder_pose
		mob.guard_elbow.quaternion = Quaternion(Vector3.DOWN,shoulder_pose.inverse()*forearm)
		mob.arms[1].rotation.x = 0.42 + 0.17*swing
		mob.chest.rotation.x = 0.43 + 0.06*absf(swing)
		mob.chest.rotation.z = 0.08*transfer
		mob.body.position.y = 0.025 - 0.024*absf(transfer)
		for i in 2:
			mob.legs[i].rotation.x *= 0.6
			mob.legs[i].position.y = 0.30 + (mob.legs[i].position.y-0.30)*0.55

func shoot(tower,enemy):
	$BowRelease.play()
	var start = tower.node.position + Vector3.UP*1.44
	var end = enemy.body.global_position + Vector3.UP*enemy.body.scale.y*0.44
	var arrow = box(self,start,Vector3(0.045,0.045,0.39),"efc36b")
	arrow.look_at(end)
	var tween = create_tween()
	tween.tween_property(arrow,"position",end,0.12)
	tween.tween_callback(arrow.queue_free)
	damage_enemy(enemy, archer_damage())

func damage_enemy(enemy, amount: float):
	if finished or enemy.hp <= 0 or enemy.get("in_spirit",false):
		return
	damage_dealt += minf(amount,enemy.hp)
	enemy.hp -= amount
	if enemy.hp <= 0:
		var death_sound = $BruteFall if enemy.brute else $GoblinFall
		if enemy.ogre and dusk_ridge:
			death_sound = $OgreFall
		elif cemetery_stage and enemy.kind == "gargoyle":
			death_sound = $GargoyleFall
		elif cemetery_stage and enemy.kind == "death":
			death_sound = $ReaperFall
		death_sound.play()
		var gold = 12 if enemy.ogre else (BRUTE_REWARD if enemy.brute else KILL_REWARD)
		if cemetery_stage:
			gold = UNDEAD_REWARDS[enemy.kind]
		show_reward(enemy.body.global_position + Vector3.UP * enemy.body.scale.y, gold)
		enemy.node.queue_free()
		enemies.erase(enemy)
		coins += gold
		gold_earned += gold
		monsters_defeated += 1
		refresh()

func build_slow_mill(base: Node3D):
	cone(base,Vector3.UP*0.18,0.44,0.36,0.36,8,"928874","stone")
	box(base,Vector3.UP*0.71,Vector3(0.54,0.78,0.52),"aa8052","wood")
	for side in [-1,1]:
		box(base,Vector3(side*0.23,0.72,0.265),Vector3(0.056,0.81,0.045),WOOD,"wood")
	cone(base,Vector3.UP*1.19,0.49,0.05,0.41,4,"477570","roof").rotation.y = PI/4
	var rotor = limb_joint(base,Vector3(0,1.07,0.37))
	rotor.name = "Rotor"
	for i in 3:
		var sail = limb_joint(rotor,Vector3.ZERO)
		sail.rotation.z = i*TAU/3
		box(sail,Vector3.UP*0.30,Vector3(0.05,0.60,0.05),WOOD,"wood")
		box(sail,Vector3(0.07,0.40,0),Vector3(0.13,0.35,0.03),"e4cb8c")
	box(rotor,Vector3.ZERO,Vector3(0.11,0.11,0.11),WOOD)
	rotor.create_tween().set_loops().tween_property(rotor,"rotation:z",TAU,0.96).from(0.0)

func build_mortar(base: Node3D) -> Node3D:
	cone(base, Vector3.UP*0.25, 0.49,0.46,0.50,8,STONE,"stone")
	cone(base, Vector3.UP*0.51, 0.48,0.45,0.12,8,WOOD,"wood")
	var swivel = limb_joint(base, Vector3.UP*0.58)
	for side in [-1,1]:
		box(swivel,Vector3(side*0.23,0.12,0),Vector3(0.11,0.29,0.43),WOOD,"wood")
	var barrel = limb_joint(swivel, Vector3.UP*0.12)
	barrel.name = "Tube"
	barrel.rotation.x = 0.55
	cone(barrel,Vector3.UP*0.28,0.18,0.22,0.64,10,"625542")
	cone(barrel,Vector3.UP*0.56,0.245,0.245,0.12,10,"aa8249")
	cone(barrel,Vector3.UP*0.623,0.17,0.17,0.012,10,"302f2b")
	return swivel

func launch_shell(tower, enemy):
	var damage = HEAVY_SHELL_DAMAGE if upgraded[Tower.MORTAR] else SHELL_DAMAGE
	var blast_radius = HEAVY_BLAST_RADIUS if upgraded[Tower.MORTAR] else BLAST_RADIUS
	var progress = minf(enemy.progress + movement_speed(enemy) * FLIGHT_TIME, route.size()-1-GATE_OFFSET)
	var i = floori(progress)
	var target = ground(route[i]).lerp(ground(route[i+1]), progress-i) + Vector3.UP*0.12
	var direction = target - tower.node.position
	tower.barrel.rotation.y = atan2(direction.x, direction.z)
	var start = tower.barrel.to_global(Vector3(0,0.65,0.33))
	var velocity = (target - start - 0.5 * GRAVITY * FLIGHT_TIME**2) / FLIGHT_TIME
	var ball = SphereMesh.new()
	ball.radius = 0.145
	ball.height = 0.29
	var shell = mesh_part(self,ball,start,"383b38")
	shells_in_flight += 1
	$MortarLaunch.play()
	var flight = shell.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	flight.tween_method(func(t: float):
		shell.position = start + velocity*t + 0.5*GRAVITY*t*t
	, 0.0, FLIGHT_TIME, FLIGHT_TIME)
	flight.parallel().tween_callback($ShellFall.play).set_delay(FLIGHT_TIME-0.30)
	flight.tween_callback(func():
		shell.queue_free()
		shells_in_flight -= 1
		$ShellBlast.play()
		var flash = cone(self,target,0.68,0.20,0.40,9,"f4b44f")
		var burst = flash.create_tween()
		flash.scale = Vector3.ONE * 0.15
		burst.tween_property(flash,"scale",Vector3(1.8,1.4,1.8),0.08)
		burst.tween_property(flash,"scale",Vector3(2,0.02,2),0.18)
		burst.tween_callback(flash.queue_free)
		if not finished:
			for mob in enemies.duplicate():
				if mob.node.position.distance_squared_to(target) <= blast_radius**2:
					damage_enemy(mob, damage)
	)

func update_gate_damage():
	if lives <= 9:
		gate_boards[0].rotation.x = -0.30
		gate_boards[0].material_override = mat("5c4434","wood")
	if lives <= 6:
		gate_boards[2].scale.y = 0.42
		gate_boards[2].position.y = 0.16
		gate_strap.rotation.x = 0.26
	if lives <= 3:
		gate_boards[3].rotation.z = 1.20
		gate_boards[3].position = Vector3(-0.24,0.17,0.16)
		gate_strap.rotation.x = 0.75
	if lives == 0:
		gate_strap.hide()
		for board in gate_boards:
			board.rotation.z = 1.52
			board.position.x = -0.27
			board.position.y = 0.10

func attack_gate(mob):
	if cemetery_stage:
		mob.flight = 0.0
	animate_gait(mob)
	gate_attackers += 1
	var body: Node3D = mob.body
	var strike = mob.node.create_tween()
	strike.tween_property(mob.arms[0], "rotation:x", -2.4, 0.20)
	strike.parallel().tween_property(mob.chest, "rotation:x", -0.20, 0.20)
	strike.tween_property(body, "position:z", 0.18, 0.12)
	strike.parallel().tween_property(mob.arms[0], "rotation:x", -1.3, 0.12)
	strike.parallel().tween_property(mob.chest, "rotation:x", 0.48, 0.12)
	strike.tween_callback(func():
		if not finished:
			lives = maxi(0, lives - (4 if mob.ogre else (2 if mob.brute else 1)))
			$GateStrike.play()
			update_gate_damage()
			if lives == 0:
				end_game(false)
			else:
				refresh()
	)
	strike.tween_property(body, "position:z", -0.03, 0.16)
	var faded_materials = {}
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var original = mesh.material_override
		if not faded_materials.has(original):
			var copy = original.duplicate()
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			faded_materials[original] = copy
		mesh.material_override = faded_materials[original]
	for material in faded_materials.values():
		strike.parallel().tween_property(material, "albedo_color:a", 0.0, 1.1)
	strike.tween_callback(func():
		mob.node.queue_free()
		gate_attackers -= 1
	)

func end_game(won):
	if finished:
		return
	finished = true
	if boss_warning:
		boss_warning.hide()
	Engine.time_scale = 1.0
	speed_panel.hide()
	fighting = false
	ring.hide()
	hint.text = "Ворота пали. Попробуйте другую расстановку башен."
	refresh()
	if won:
		Campaign.record_win(level_number)
		$BackgroundMusic.stop()
		$Victory.play()
		show_victory()

func show_victory():
	dragging_map = false
	for control in hud_root.get_children():
		control.hide()
		control.set_process_input(false)
	var veil = ColorRect.new()
	hud_root.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color("162521c8")
	var center = CenterContainer.new()
	veil.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	center.add_child(panel)
	panel.add_theme_stylebox_override("panel",panel_color("293c33","c8a764"))
	var stack = VBoxContainer.new()
	panel.add_child(stack)
	stack.custom_minimum_size.x = 350
	stack.add_theme_constant_override("separation",10)
	var title = Label.new()
	title.text = "Победа!" if level_number < Campaign.SCENES.size() else "Кампания пройдена!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_style(title,36,"ffe2a5")
	stack.add_child(title)
	var summary = Label.new()
	summary.text = "%s · отбито волн: %d\n\nУрон по монстрам: %s\nПобеждено гоблинов: %d\nЗаработано золота: %d\nПрочность ворот: %d / 12" % [
		Campaign.level_title(level_number),wave,stat_text(damage_dealt),monsters_defeated,gold_earned,lives]
	label_style(summary,20,"f0e3c7")
	stack.add_child(summary)
	if level_number < Campaign.SCENES.size():
		var next = Button.new()
		next.text = "Следующий уровень"
		stack.add_child(next)
		next.pressed.connect(leave_victory.bind(Campaign.SCENES[level_number]))
	var home = Button.new()
	home.text = "Главное меню"
	stack.add_child(home)
	home.pressed.connect(leave_victory.bind("res://scenes/ui/menu.tscn"))
	stack.get_child(2).grab_focus()

func leave_victory(path: String):
	if not hud_root.visible:
		return
	hud_root.hide()
	var curtain = preload("res://scripts/ui/transition.gd").new()
	get_tree().root.add_child(curtain)
	curtain.start(load(path))

func _process(delta):
	if finished:
		if not enemies.is_empty():
			health_bars.queue_redraw()
		return
	if message_time > 0:
		message_time -= delta
		if message_time <= 0:
			default_hint()
	if upgrade_panel.visible:
		_hide_upgrade_outside(upgrade_hover_tile)
	update_range_preview(get_viewport().get_mouse_position(), get_viewport().gui_get_hovered_control() != null)
	if not fighting:
		return
	step_wave(delta)

func update_range_preview(point: Vector2, over_ui: bool):
	var empty = Vector2i(999,999)
	var cell = empty if over_ui else mouse_cell(point)
	var tower = null if over_ui or pads.has(cell) else tower_at(cell, point)
	if tower != null:
		show_tower_details(tower.kind)
		world_info_visible = true
		cell = empty
	elif world_info_visible:
		info_panel.hide()
		world_info_visible = false
	if cell != hovered:
		if pads.has(hovered):
			pads[hovered].material_override = mat(pad_color,"grass")
		hovered = cell
	ring.visible = tower != null or pads.has(cell)
	if ring.visible:
		var radius = tower_range(selected_tower)
		if tower != null:
			radius = tower.range
			ring.position = tower.node.position
		else:
			var price = TOWER_COSTS[selected_tower]
			pads[cell].material_override = mat("d9bc76" if coins >= price else "aa7560","grass")
			ring.position = ground(cell)
		var factor = float(radius) / RANGE
		ring.scale = Vector3(factor, 1, factor)

func movement_speed(mob) -> float:
	if mob.get("in_spirit",false):
		return mob.speed
	var flying = cemetery_stage > 0 and mob.flight > 0
	var speed: float = Undead.FLIGHT_SPEED if flying else mob.speed
	for tower in towers:
		if tower.kind == Tower.MILL and tower.node.position.distance_squared_to(mob.node.position) <= tower.range**2:
			var percent = STRONG_WIND_PERCENT if upgraded[Tower.MILL] else MILL_SLOW_PERCENT
			var slow = percent / 100.0
			if flying:
				slow *= 0.5
			var slowed = speed * (1.0-slow)
			if cemetery_stage and mob.kind == "zombie":
				return maxf(0.60,slowed)
			return slowed
	return speed

func step_wave(delta):
	health_bars.queue_redraw()
	spawn_clock -= delta
	if remaining > 0 and spawn_clock <= 0:
		spawn_enemy()
		remaining -= 1
		spawn_clock = 0.64 if level_number >= 3 else 0.94
		if reaper_pending and remaining == 0:
			spawn_clock = 5.0
			hint.text = "Последний отряд вышел. Приближается Смерть…"
			message_time = 5.0
	elif reaper_pending and remaining == 0 and spawn_clock <= 0:
		reaper_pending = false
		boss_warning.hide()
		enemies.append(Reaper.spawn(self,2.5*Undead.gargoyle_hp(self)))
		hint.text = "Смерть у ворот кладбища. В мире духов она неуязвима."
		message_time = 5.0
	if reaper_pending and remaining == 0:
		boss_warning.text = "Идёт босс: Смерть  ·  %d с" % ceili(spawn_clock)
		boss_warning.show()
	for i in range(enemies.size()-1,-1,-1):
		var mob = enemies[i]
		if cemetery_stage and mob.kind == "gargoyle":
			Undead.tick_flight(mob,delta)
		elif cemetery_stage and mob.kind == "death":
			Reaper.tick(mob,delta)
		var speed = movement_speed(mob)
		mob.progress += delta*speed
		var index = floori(mob.progress)
		# The west gate is on the outer wall, before the castle's centre.
		if mob.progress >= route.size() - 1 - GATE_OFFSET:
			mob.node.position = ground(route.back()) + Vector3.LEFT * GATE_OFFSET
			mob.node.rotation.y = PI/2
			enemies.remove_at(i)
			if mob.get("kind","") == "death":
				lives = 0
				$GateStrike.play()
				update_gate_damage()
				end_game(false)
				hint.text = "Смерть достигла замка. Оборона пала."
				return
			attack_gate(mob)
		else:
			var a = ground(route[index])
			var b = ground(route[index+1])
			mob.node.position = a.lerp(b,mob.progress-index)
			mob.node.rotation.y = atan2(b.x-a.x,b.z-a.z)
			animate_gait(mob,speed < mob.speed)
	for tower in towers:
		if tower.kind == Tower.MILL:
			continue
		tower.cool -= delta
		if tower.cool > 0:
			continue
		var target = null
		for mob in enemies:
			if mob.get("in_spirit",false):
				continue
			if tower.node.position.distance_squared_to(mob.node.position) <= tower.range**2:
				if target == null or mob.progress > target.progress:
					target = mob
		if target != null:
			if tower.kind == Tower.BALLISTA:
				Ballista.fire(self,tower,target,Ballista.DAMAGE[int(upgraded[Tower.BALLISTA])])
				tower.cool = Ballista.INTERVAL
			elif tower.barrel:
				launch_shell(tower,target)
				tower.cool = MORTAR_INTERVAL
			else:
				shoot(tower,target)
				tower.cool = archer_interval()
	if remaining == 0 and not reaper_pending and enemies.is_empty() and gate_attackers == 0 and shells_in_flight == 0:
		fighting = false
		if wave == wave_count:
			end_game(true)
		else:
			coins += WAVE_REWARD
			gold_earned += WAVE_REWARD
			hint.text = "Волна отбита! Награда — %d монет. Подготовьте оборону." % WAVE_REWARD
			message_time = 5
			refresh()




