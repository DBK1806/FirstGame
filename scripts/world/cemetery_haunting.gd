extends Node3D

var spiders: Array[Dictionary] = []
var spirits: Array[Dictionary] = []
var destinations: Array[Vector3] = []
var time = 0.0
var web_count = 0
var silk: StandardMaterial3D
var layout_rng = RandomNumberGenerator.new()
var web_routes: Array[Dictionary] = []
var ghost_grid = AStarGrid2D.new()
var monster_road: Array[Vector2] = []
var ghost_rng = RandomNumberGenerator.new()

func build(scenery):
	name = "CemeteryHaunting"
	layout_rng.seed = 104729
	silk = StandardMaterial3D.new()
	silk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silk.albedo_color = Color("8797a3")
	silk.cull_mode = BaseMaterial3D.CULL_DISABLED
	for grave in scenery.haunted_graves:
		destinations.append(to_local(grave.global_position))
		if layout_rng.randf() > 0.34:
			continue
		var size = layout_rng.randf_range(0.3,0.74)
		var side = -1.0 if layout_rng.randf() < 0.5 else 1.0
		var placement = layout_rng.randi_range(0,3)
		var route: Dictionary
		if placement == 0:
			route = web(grave,Vector3(side*0.31,0.15,-0.06),Vector3(-side*size,0,0),Vector3(0,size*0.8,0.03),true)
		elif placement == 1:
			route = web(grave,Vector3(side*0.41,0.12,-0.35),Vector3(0,0,size),Vector3(-side*0.18,size*0.7,0),true)
		elif placement == 2:
			route = web(grave,Vector3(-size*0.5,0.17,0.04),Vector3(size,0.02,0),Vector3(0,-0.02,size*0.65),false)
		else:
			route = web(grave,Vector3(side*0.3,0.12,0.35),Vector3(-side*size,0,0),Vector3(0,size*0.6,-size*0.7),false)
		spider(scenery,grave,ground_route(0.55,0.65),Vector3.UP,false)
		if layout_rng.randf() < 0.65:
			spider(scenery,grave,route.points,route.normal,true)
	for statue in get_tree().get_nodes_in_group("cemetery_statues"):
		if not scenery.is_ancestor_of(statue):
			continue
		var route = web(statue,Vector3(-0.48,0.28,0.54),Vector3(0.68,0,0),Vector3(0,0.78,-0.18),true)
		spider(scenery,statue,route.points,route.normal,true)
	for building in scenery.haunted_buildings:
		var width = 0.72 if building.name == "Chapel" else 1.13
		var front = 0.78 if building.name == "Chapel" else 1.01
		var side = -1.0 if layout_rng.randf() < 0.5 else 1.0
		var size = layout_rng.randf_range(0.55,0.95)
		var route = web(building,Vector3(side*width,1.5,front),Vector3(-side*size,0,0),Vector3(0,-size,0),true)
		spider(scenery,building,route.points,route.normal,true)
	build_ghost_navigation(scenery)
	if destinations.size() >= 3:
		for i in 3:
			spirit(scenery,i)

# Each mesh has its own asymmetric outline, missing strands and off-center hub.
# Walking routes follow the same radial strands used to construct the mesh.
func web(parent: Node3D,origin: Vector3,u: Vector3,v: Vector3,fan: bool) -> Dictionary:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center = origin if fan else origin+u*layout_rng.randf_range(0.3,0.6)+v*layout_rng.randf_range(0.3,0.6)
	var rim: Array[Vector3] = []
	var spokes = layout_rng.randi_range(6,9)
	var rings = layout_rng.randi_range(2,4)
	var normal = u.cross(v).normalized()
	if normal.dot(Vector3(0,1,1)) < 0:
		normal = -normal
	for i in spokes:
		var angle = PI*0.5*i/(spokes-1.0) if fan else TAU*i/spokes
		angle += layout_rng.randf_range(-0.06,0.06)
		var reach = layout_rng.randf_range(0.73,1.0)
		var point = origin+(u*cos(angle)+v*sin(angle))*reach if fan else origin+u*(0.5+0.5*cos(angle)*reach)+v*(0.5+0.5*sin(angle)*reach)
		rim.append(point)
		thread(surface,center,rim[-1])
	for ring in range(1,rings+1):
		var fraction = (ring+layout_rng.randf_range(-0.15,0.15))/(rings+0.15)
		for i in (spokes-1 if fan else spokes):
			if layout_rng.randf() < 0.17:
				continue
			var a = center.lerp(rim[i],fraction)
			var b = center.lerp(rim[(i+1)%spokes],fraction)
			var sag = ((a+b)*0.5).lerp(center,layout_rng.randf_range(0.03,0.13))
			thread(surface,a,sag)
			thread(surface,sag,b)
	var mesh = MeshInstance3D.new()
	mesh.name = "Cobweb"
	mesh.mesh = surface.commit()
	mesh.material_override = silk
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	web_count += 1
	var points: Array[Vector3] = [center,rim[0],center,rim[spokes/2],center,rim[-1]]
	var route = {"points":points,"normal":normal,"parent":parent}
	web_routes.append(route)
	return route

func thread(surface: SurfaceTool,a: Vector3,b: Vector3):
	var side = (b-a).cross(Vector3(0.3,0.8,1)).normalized()*0.004
	for point in [a-side,b-side,b+side,a-side,b+side,a+side]:
		surface.add_vertex(point)

func ground_route(width: float,depth: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var offset = layout_rng.randf_range(0.0,0.08)
	# The rectangular circuit stays outside the stone slab, including its corners.
	for point in [Vector3(-width,0.025,-depth),Vector3(width,0.025,-depth),Vector3(width+offset,0.025,0),Vector3(width,0.025,depth),Vector3(-width,0.025,depth),Vector3(-width-offset,0.025,0)]:
		points.append(point)
	if layout_rng.randf() < 0.5:
		points.reverse()
	return points

func spider(scenery,parent: Node3D,points: Array[Vector3],normal: Vector3,on_web: bool):
	var body = scenery.limb(parent,Vector3.ZERO)
	body.name = "LittleSpider"
	body.scale = Vector3.ONE*(layout_rng.randf_range(0.42,0.58) if on_web else layout_rng.randf_range(0.65,0.9))
	scenery.oval(body,Vector3(0,0.09,0.04),Vector3(0.17,0.14,0.23),"302834")
	scenery.oval(body,Vector3(0,0.08,-0.09),Vector3(0.12,0.11,0.12),"514054")
	var legs: Array[Node3D] = []
	for side in [-1,1]:
		for i in 3:
			var leg = scenery.limb(body,Vector3(side*0.055,0.08,(i-1.5)*0.043))
			var knee = Vector3(side*0.12,0.025,(i-1.5)*0.055)
			scenery.segment(leg,Vector3.ZERO,knee,0.012,0.009,"584457","")
			scenery.segment(leg,knee,Vector3(side*0.19,-0.065,(i-1.5)*0.085),0.009,0.005,"584457","")
			legs.append(leg)
	var start = layout_rng.randi_range(0,points.size()-1)
	body.position = points[start]
	spiders.append({"node":body,"legs":legs,"points":points,"normal":normal,"on_web":on_web,"segment":start,"distance":0.0,"pause":layout_rng.randf_range(0,2),"speed":layout_rng.randf_range(0.035,0.065) if on_web else layout_rng.randf_range(0.09,0.15),"gait":layout_rng.randf()*TAU})

func ghost_vertex(ring: int,sector: int) -> Vector3:
	var heights = [0.06,0.24,0.43,0.53,0.62,0.71,0.8,0.9,1.06,1.15]
	var radii = [0.34,0.3,0.255,0.25,0.25,0.245,0.24,0.235,0.165,0.025]
	var angle = TAU*sector/20.0
	var lower = 1.0-float(ring)/9.0
	var radius: float = radii[ring] * (1.0+0.13*cos(angle*10)*lower)
	var y: float = heights[ring]
	if ring == 0:
		y += 0.1*(0.5+0.5*cos(angle*10))
	# Rounded sleeves droop from the shoulders, with their tips below the elbows.
	var sleeve = pow(absf(cos(angle)),6.0)
	var sleeve_profile = [0.0,0.0,0.015,0.09,0.16,0.15,0.065,0.0,0.0,0.0]
	radius += sleeve_profile[ring]*sleeve
	var sleeve_drop = [0.0,0.0,0.07,0.16,0.19,0.13,0.04,0.0,0.0,0.0]
	y -= sleeve_drop[ring]*sleeve
	return Vector3(cos(angle)*radius,y,sin(angle)*radius*0.75)

func ghost_mesh() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 9:
		for sector in 20:
			var a = ghost_vertex(ring,sector)
			var b = ghost_vertex(ring+1,sector)
			var c = ghost_vertex(ring,(sector+1)%20)
			var d = ghost_vertex(ring+1,(sector+1)%20)
			for point in [a,c,b,c,d,b]:
				surface.add_vertex(point)
	for sector in 20:
		for point in [ghost_vertex(9,sector),ghost_vertex(9,(sector+1)%20),Vector3(0,1.155,0)]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

func spirit(scenery,index: int):
	var root = scenery.limb(self,Vector3.ZERO)
	root.name = "WanderingGhost"
	root.scale = Vector3.ONE*(0.92+index*0.045)
	var material = ShaderMaterial.new()
	material.shader = preload("res://shaders/ghost_cloth.gdshader")
	material.set_shader_parameter("phase",index*1.7)
	var cloth = MeshInstance3D.new()
	cloth.name = "GhostCloth"
	cloth.mesh = ghost_mesh()
	cloth.material_override = material
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloth)
	var start = 0
	if not spirits.is_empty():
		var furthest = -1.0
		for i in destinations.size():
			var spacing = INF
			for other in spirits:
				spacing = minf(spacing,destinations[i].distance_squared_to(destinations[other.from]))
			if spacing > furthest:
				furthest = spacing
				start = i
	var ghost = {"node":root,"material":material,"from":start,"to":start,"progress":0.0,"duration":30.0,"path":PackedVector3Array(),"length":0.0,"visited":[start],"phase":index*2.1}
	plan_ghost_flight(ghost)
	root.position = destinations[start]+Vector3.DOWN*0.3
	spirits.append(ghost)

func road_clear(point: Vector3) -> bool:
	for cell in monster_road:
		if absf(point.x-cell.x) < 0.96 and absf(point.z-cell.y) < 0.96:
			return false
	return true

func safe_segment(a: Vector3,b: Vector3) -> bool:
	# Exact segment/rectangle clipping also catches tiny cuts across road corners.
	var start = Vector2(a.x,a.z)
	var direction = Vector2(b.x-a.x,b.z-a.z)
	for cell in monster_road:
		var enter = 0.0
		var leave = 1.0
		for axis in 2:
			var low = cell[axis]-0.96
			var high = cell[axis]+0.96
			if absf(direction[axis]) < 0.000001:
				if start[axis] < low or start[axis] > high:
					leave = -1.0
					break
			else:
				var first = (low-start[axis])/direction[axis]
				var last = (high-start[axis])/direction[axis]
				enter = maxf(enter,minf(first,last))
				leave = minf(leave,maxf(first,last))
		if enter <= leave:
			return false
	return true

func build_ghost_navigation(scenery):
	ghost_rng.seed = 91731
	for cell in scenery.get_parent().route:
		monster_road.append(Vector2(cell))
	ghost_grid.region = Rect2i(-38,-30,76,60)
	ghost_grid.cell_size = Vector2(0.5,0.5)
	ghost_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	ghost_grid.update()
	for y in range(-30,30):
		for x in range(-38,38):
			ghost_grid.set_point_solid(Vector2i(x,y),not road_clear(Vector3(x*0.5,0,y*0.5)))
	var safe_graves: Array[Vector3] = []
	for grave in destinations:
		var cell = Vector2i(roundi(grave.x*2),roundi(grave.z*2))
		if ghost_grid.is_in_boundsv(cell) and not ghost_grid.is_point_solid(cell) and safe_segment(grave,Vector3(cell.x*0.5,0,cell.y*0.5)):
			safe_graves.append(grave)
	destinations = safe_graves

func grave_path(start: int,finish: int) -> PackedVector3Array:
	var a = destinations[start]
	var b = destinations[finish]
	var grid_path = ghost_grid.get_point_path(Vector2i(roundi(a.x*2),roundi(a.z*2)),Vector2i(roundi(b.x*2),roundi(b.z*2)))
	if grid_path.is_empty():
		return PackedVector3Array()
	var points = PackedVector3Array([a])
	for point in grid_path:
		points.append(Vector3(point.x,0,point.y))
	points.append(b)
	# Skip grid corners only when the entire shortcut clears the road and body margin.
	var result = PackedVector3Array([a])
	var cursor = 0
	while cursor < points.size()-1:
		var next = points.size()-1
		while next > cursor+1 and not safe_segment(points[cursor],points[next]):
			next -= 1
		if result[-1].distance_to(points[next]) > 0.001:
			result.append(points[next])
		cursor = next
	return result

func plan_ghost_flight(ghost: Dictionary):
	if ghost.visited.size() >= destinations.size():
		ghost.visited = [ghost.from]
	var candidates: Array[int] = []
	for i in destinations.size():
		if i != ghost.from and not ghost.visited.has(i):
			candidates.append(i)
	while not candidates.is_empty():
		var slot = ghost_rng.randi_range(0,candidates.size()-1)
		var target = candidates[slot]
		candidates.remove_at(slot)
		var path = grave_path(ghost.from,target)
		if path.size() < 2:
			ghost.visited.append(target)
			continue
		ghost.to = target
		ghost.path = path
		ghost.length = 0.0
		for i in path.size()-1:
			ghost.length += path[i].distance_to(path[i+1])
		ghost.duration = 10.0+ghost.length/0.55
		return

func move_ghost(ghost: Dictionary,delta: float):
	ghost.progress += delta/ghost.duration
	if ghost.progress >= 1.0:
		ghost.progress = 0.0
		ghost.from = ghost.to
		ghost.visited.append(ghost.from)
		plan_ghost_flight(ghost)
	var t: float = ghost.progress
	var travel = smoothstep(0.08,0.92,t)*ghost.length
	var position: Vector3 = ghost.path[0]
	var direction = Vector3.FORWARD
	for i in ghost.path.size()-1:
		var a: Vector3 = ghost.path[i]
		var b: Vector3 = ghost.path[i+1]
		var length = a.distance_to(b)
		if travel <= length or i == ghost.path.size()-2:
			position = a.lerp(b,clampf(travel/maxf(length,0.001),0,1))
			direction = a.direction_to(b)
			break
		travel -= length
	var lift = smoothstep(0.0,0.12,t)*(1.0-smoothstep(0.88,1.0,t))
	ghost.node.position = position+Vector3.UP*(-0.3+lift*(1.1+sin(time*1.1+ghost.phase)*0.09))
	var heading = atan2(direction.x,direction.z)+sin(time*0.7+ghost.phase)*0.22
	ghost.node.rotation.y = lerp_angle(ghost.node.rotation.y,heading,1.0-exp(-delta*1.8))
	ghost.node.rotation.z = sin(time*0.9+ghost.phase)*0.035
	ghost.material.set_shader_parameter("visibility",lift)
	ghost.material.set_shader_parameter("animation_time",time)
	ghost.node.visible = lift > 0.03

func _process(delta: float):
	var ghost_delta = delta / maxf(Engine.time_scale,0.001)
	time += ghost_delta
	for actor in spiders:
		if actor.pause > 0:
			actor.pause = maxf(0,actor.pause-delta)
			continue
		var a: Vector3 = actor.points[actor.segment]
		var b: Vector3 = actor.points[(actor.segment+1)%actor.points.size()]
		var length = a.distance_to(b)
		actor.distance = minf(length,actor.distance+delta*actor.speed)
		actor.node.position = a.lerp(b,actor.distance/maxf(length,0.001))
		var forward = a.direction_to(b)
		var up: Vector3 = actor.normal
		var right = forward.cross(up).normalized()
		if right.length_squared() > 0.5:
			var scale_factor: Vector3 = actor.node.scale
			actor.node.basis = Basis(right,up,-forward).orthonormalized().scaled(scale_factor)
		actor.gait += delta*10
		for i in actor.legs.size():
			actor.legs[i].rotation.y = sin(actor.gait+i*PI*0.75)*0.24
		if actor.distance >= length:
			actor.segment = (actor.segment+1)%actor.points.size()
			actor.distance = 0.0
			actor.pause = layout_rng.randf_range(0.3,2.4)
	for ghost in spirits:
		move_ghost(ghost,ghost_delta)

