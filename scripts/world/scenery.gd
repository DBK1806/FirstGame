extends Node3D

const MOSS = "809644"
const STONE = "c0b397"
const SLATE = "40555a"
const WOOD = "67452e"
const GOLD = "e7b75c"
# Repeats per world unit keep terrain detail continuous across neighboring cells.
const SURFACES = {
	"needles": [preload("res://assets/textures/needles.png"), 0.7],
	"grass": [preload("res://assets/textures/meadow.png"), 0.43],
	"earth": [preload("res://assets/textures/earth.png"), 0.65],
	"field": [preload("res://assets/textures/field.png"), 0.72],
	"stone": [preload("res://assets/textures/masonry.png"), 0.86],
	"wood": [preload("res://assets/textures/timber.png"), 1.35],
	"roof": [preload("res://assets/textures/shingles.png"), 1.0],
}
var rng = RandomNumberGenerator.new()
var materials = {}
var pennant_mesh: PlaneMesh
var pennant_material: ShaderMaterial

func mat(tone, surface = ""):
	var key = tone + surface
	if not materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(tone)
		m.roughness = 1
		if SURFACES.has(surface):
			var pattern = SURFACES[surface]
			m.albedo_texture = pattern[0]
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if surface == "roof":
				m.uv1_scale = Vector3(2.0,1.3,1.0)
			else:
				m.uv1_triplanar = true
				m.uv1_world_triplanar = surface != "wood"
				m.uv1_triplanar_sharpness = 14.0
				m.uv1_scale = Vector3.ONE * pattern[1]
		materials[key] = m
	return materials[key]

func mesh_part(parent, shape, pos, tone, surface = ""):
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat(tone, surface)
	parent.add_child(node)
	node.position = pos
	return node

func box(parent, pos, size, tone, surface = ""):
	var shape = BoxMesh.new()
	shape.size = size
	return mesh_part(parent, shape, pos, tone, surface)

func cone(parent, pos, bottom, top, height, sides, tone, surface = ""):
	var shape = CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 0
	return mesh_part(parent, shape, pos, tone, surface)

func group(pos):
	var node = Node3D.new()
	add_child(node)
	node.position = pos
	return node

func light_world(evening: bool = false):
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9eb9a8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff3d8")
	env.environment.ambient_light_energy = 0.62
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-35,0)
	sun.light_energy = 0.98
	if evening:
		env.environment.background_color = Color("897e92")
		env.environment.ambient_light_color = Color("bac6e0")
		env.environment.ambient_light_energy = 0.53
		sun.rotation_degrees = Vector3(-24,-57,0)
		sun.light_color = Color("ffbb88")
		sun.light_energy = 0.82
	sun.shadow_enabled = true
	add_child(sun)

func tree(p,s):
	var n = group(p)
	n.scale = Vector3.ONE*s
	cone(n,Vector3.UP*0.25,0.11,0.09,0.5,5,WOOD,"wood")
	var leaf = ["405d30","526c32","637a38"][rng.randi_range(0,2)]
	cone(n,Vector3.UP*0.91,0.52,0,1.46,5,leaf,"needles")
	cone(n,Vector3.UP*1.42,0.36,0,1.08,5,leaf,"needles")

func turret(parent,p,s):
	var n = Node3D.new()
	parent.add_child(n)
	n.position = p
	n.scale = Vector3.ONE*s
	cone(n,Vector3.UP*0.68,0.43,0.35,1.36,8,STONE,"stone")
	box(n,Vector3(0,0.83,0.36),Vector3(0.10,0.28,0.035),"403c34")
	cone(n,Vector3.UP*1.39,0.51,0.49,0.17,8,WOOD,"wood")
	cone(n,Vector3.UP*1.8,0.55,0.03,0.70,8,SLATE,"roof")
	box(n,Vector3.UP*2.27,Vector3(0.04,0.42,0.04),WOOD,"wood")
	add_pennant(n)

func add_pennant(pole: Node3D):
	if pennant_mesh == null:
		pennant_mesh = PlaneMesh.new()
		pennant_mesh.orientation = PlaneMesh.FACE_Z
		pennant_mesh.size = Vector2(0.36, 0.16)
		pennant_mesh.subdivide_width = 7
		pennant_material = ShaderMaterial.new()
		pennant_material.shader = preload("res://shaders/pennant.gdshader")
	var flag = MeshInstance3D.new()
	flag.mesh = pennant_mesh
	flag.material_override = pennant_material
	pole.add_child(flag)
	flag.position = Vector3(0.18, 2.40, 0)
	var flutter = flag.create_tween().set_loops()
	flutter.tween_method(func(phase: float): flag.set_instance_shader_parameter("phase", phase),
		0.0, TAU, 1.25)

func village(sites = [Vector2(6.1,1.1),Vector2(7.6,2.4),Vector2(8.25,0.55)]):
	for site in sites:
		var cottage = group(Vector3(site.x,0,site.y))
		cottage.rotation.y = site.y * 0.24
		box(cottage,Vector3.UP*0.30,Vector3(0.92,0.60,0.71),"d3b280")
		var roof = cone(cottage,Vector3.UP*0.82,0.83,0,0.54,4,"815638","roof")
		roof.rotation.y = PI/4
		roof.scale = Vector3(1.04,1,0.84)
		box(cottage,Vector3(-0.18,0.20,0.36),Vector3(0.23,0.40,0.045),WOOD,"wood")
		box(cottage,Vector3(0.22,0.35,0.36),Vector3(0.17,0.17,0.04),"454538")
		box(cottage,Vector3(0.33,0.83,-0.1),Vector3(0.13,0.47,0.14),STONE,"stone")
		if site == Vector2(6.1,1.1):
			add_chimney_smoke(cottage)

func add_chimney_smoke(cottage: Node3D):
	var smoke = CPUParticles3D.new()
	smoke.amount = 6
	smoke.lifetime = 2.8
	smoke.preprocess = 2.8
	smoke.gravity = Vector3(0.12, 0.08, -0.03)
	smoke.direction = Vector3.UP
	smoke.spread = 12
	smoke.initial_velocity_min = 0.32
	smoke.initial_velocity_max = 0.42
	var size = Curve.new()
	size.add_point(Vector2(0, 0.2))
	size.add_point(Vector2(0.45, 1))
	size.add_point(Vector2(1, 0))
	smoke.scale_amount_curve = size
	var puff = SphereMesh.new()
	puff.radius = 0.105
	puff.height = 0.17
	puff.radial_segments = 5
	puff.rings = 2
	puff.material = mat("c5c5b7")
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cottage.add_child(smoke)
	smoke.position = Vector3(0.33,1.08,-0.1)

func castle(at: Vector3, factor: float):
	var n = group(at)
	n.scale = Vector3.ONE * factor
	box(n,Vector3(0,0.64,-0.40),Vector3(1.94,1.28,1.58),STONE,"stone")
	box(n,Vector3(-0.981,0.4,-0.08),Vector3(0.04,0.80,0.48),WOOD,"wood")
	for x in [-0.46, 0.0, 0.46]:
		box(n,Vector3(x,1.39,0.29),Vector3(0.23,0.24,0.22),STONE,"stone")
	# A crimson wall hanging with a gold diamond beneath the central merlon.
	box(n,Vector3(0,0.86,0.42),Vector3(0.38,0.60,0.04),"993f42")
	box(n,Vector3(0,0.86,0.45),Vector3(0.16,0.16,0.025),GOLD).rotation.z = PI/4
	box(n,Vector3(0,1.18,0.44),Vector3(0.51,0.055,0.07),WOOD,"wood")
	box(n,Vector3(0,1.55,-0.57),Vector3(0.90,1.20,0.85),"cfbc9d","stone")
	cone(n,Vector3(0,2.39,-0.57),0.86,0,0.88,4,SLATE,"roof").rotation.y = PI/4
	for x in [-0.94,0.94]:
		for z in [-1.18,0.40]:
			turret(n,Vector3(x,0,z),1.02)

func panel_color(bg, edge):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(bg)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style



func fit_interface(root: Control):
	if get_window().content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var resize = func():
		var area = get_viewport().get_visible_rect().size
		var factor = minf(area.x / 1280.0, area.y / 800.0)
		root.scale = Vector2.ONE * factor
		root.size = area / factor
	get_viewport().size_changed.connect(resize)
	resize.call()
