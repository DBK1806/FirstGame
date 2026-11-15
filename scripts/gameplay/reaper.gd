extends RefCounted

const SPIRIT_TIME = 2.5
const MORTAL_TIME = 16.0

static func spawn(map,hp: float):
	var root = map.group(map.ground(map.route.front()))
	root.name = "Death"
	var body = map.limb_joint(root,Vector3.ZERO)
	body.scale = Vector3.ONE*1.94
	var chest = map.limb_joint(body,Vector3.UP*0.53)
	var cloth = "34313e"
	map.cone(body,Vector3.UP*0.33,0.34,0.16,0.60,11,cloth)
	for i in 9:
		var angle = i*TAU/9
		var fold = map.cone(body,Vector3(0.235*sin(angle),0.24,0.235*cos(angle)),0.092,0.035,0.41,4,"403946")
		fold.rotation = Vector3(-0.23*cos(angle),angle,0.23*sin(angle))
	map.cone(chest,Vector3.UP*0.04,0.23,0.30,0.24,10,"494251")
	map.oval(chest,Vector3(0,0.33,-0.035),Vector3(0.49,0.52,0.44),cloth)
	var peak = map.cone(chest,Vector3(0,0.51,-0.10),0.186,0.028,0.23,7,cloth)
	peak.rotation.x = -0.45
	map.oval(chest,Vector3(0,0.31,0.13),Vector3(0.36,0.38,0.105),"191823")
	map.oval(chest,Vector3(0,0.33,0.176),Vector3(0.237,0.21,0.075),"b3afa3")
	map.box(chest,Vector3(0,0.23,0.176),Vector3(0.145,0.07,0.06),"9e9c93")
	var arms = []
	for side in [-1,1]:
		map.oval(chest,Vector3(side*0.057,0.34,0.212),Vector3(0.061,0.045,0.018),"302b37")
		var shoulder = map.limb_joint(chest,Vector3(side*0.24,0.10,0.02))
		arms.append(shoulder)
		var sleeve = map.cone(shoulder,Vector3(0,-0.12,0.04),0.105,0.08,0.29,7,cloth)
		sleeve.rotation.x = -0.30
		map.oval(shoulder,Vector3(0,-0.24,0.09),Vector3(0.096,0.095,0.09),"bcb9a9")
	var scythe = map.limb_joint(arms[0],Vector3(0,-0.22,0.10))
	scythe.rotation.z = 0.19
	map.cone(scythe,Vector3.UP*0.12,0.026,0.023,1.12,7,"827363","wood")
	var blade = SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine = [Vector2(0,0.64),Vector2(-0.18,0.73),Vector2(-0.39,0.71),Vector2(-0.58,0.60),Vector2(-0.70,0.42)]
	var edge = [Vector2(0,0.54),Vector2(-0.18,0.58),Vector2(-0.36,0.59),Vector2(-0.52,0.54),spine.back()]
	for i in spine.size()-1:
		var points = [spine[i],edge[i],spine[i+1]]
		if i < spine.size()-2:
			points.append_array([spine[i+1],edge[i],edge[i+1]])
		for j in range(0,points.size(),3):
			for k in [0,1,2,2,1,0]:
				var p: Vector2 = points[j+k]
				blade.add_vertex(Vector3(p.x,p.y,0.02))
	blade.generate_normals()
	map.mesh_part(scythe,blade.commit(),Vector3.ZERO,"c3ced2")
	var original = {}
	for piece in body.find_children("*","MeshInstance3D",true,false):
		original[piece] = piece.material_override
	var mist = StandardMaterial3D.new()
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.albedo_color = Color(0.54,0.79,0.89,0.30)
	return {"node":root,"body":body,"chest":chest,"arms":arms,"kind":"death","brute":true,"ogre":true,
		"hp":hp,"max_hp":hp,"speed":1.0,"progress":0.0,"flight":0.0,"in_spirit":false,
		"phase_time":MORTAL_TIME,"original":original,"mist":mist}

static func tick(mob,delta):
	mob.phase_time -= delta
	if mob.phase_time > 0:
		return
	mob.in_spirit = not mob.in_spirit
	mob.phase_time += SPIRIT_TIME if mob.in_spirit else MORTAL_TIME
	for piece in mob.original:
		piece.material_override = mob.mist if mob.in_spirit else mob.original[piece]
