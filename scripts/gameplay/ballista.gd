extends RefCounted

const DAMAGE = [6,10]
const INTERVAL = 1.65
const BOLT_SPEED = 18.0

static func bow(map,swivel,height: float,span: float,steel: bool):
	for side in [-1,1]:
		var root = Vector3(0,height,0.29)
		var bend = Vector3(side*span*0.65,height,0.18)
		var tip = Vector3(side*span,height,-0.01)
		for pair in [[root,bend],[bend,tip],[tip,Vector3(0,height,-0.37)]]:
			var string = pair[0] == tip
			var width = 0.022 if string else 0.085
			var piece = map.box(swivel,(pair[0]+pair[1])*0.5,Vector3(width,width,pair[0].distance_to(pair[1])),
				"d8c49b" if string else ("81909c" if steel else "997750"))
			piece.look_at(swivel.to_global(pair[1]))

static func build(map,base):
	map.box(base,Vector3.UP*0.10,Vector3(0.82,0.20,0.83),"8d8781","stone")
	for side in [-1,1]:
		map.box(base,Vector3(side*0.24,0.32,0),Vector3(0.14,0.46,0.62),"71543e","wood")
	map.cone(base,Vector3.UP*0.53,0.34,0.31,0.14,10,"5c5d65")
	var swivel = map.limb_joint(base,Vector3.UP*0.66)
	map.box(swivel,Vector3.ZERO,Vector3(0.19,0.14,0.99),"855d41","wood")
	bow(map,swivel,0.08,0.57,false)
	map.box(swivel,Vector3(0,0.11,0.07),Vector3(0.052,0.045,0.87),"d6c49c")
	return swivel

static func reinforce(map,swivel):
	bow(map,swivel,-0.055,0.65,true)
	for side in [-1,1]:
		map.box(swivel,Vector3(side*0.115,0,-0.12),Vector3(0.055,0.20,0.56),"c79b54")

static func fire(map,tower,target,damage: int):
	var origin: Vector3 = tower.barrel.global_position
	var direction: Vector3 = target.node.global_position-origin
	direction.y = 0
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	direction = direction.normalized()
	tower.barrel.rotation.y = atan2(direction.x,direction.z)
	var bolt = map.group(origin)
	bolt.rotation.y = tower.barrel.rotation.y
	map.box(bolt,Vector3.ZERO,Vector3(0.049,0.049,0.54),"cba975")
	map.cone(bolt,Vector3(0,0,0.33),0.086,0,0.17,4,"c7cad1").rotation.x = PI/2
	map.get_node("BallistaRelease").play()
	var struck = {}
	var flight = bolt.create_tween()
	map.shells_in_flight += 1
	flight.tween_method(func(distance: float):
		var previous = bolt.position
		bolt.position = origin+direction*distance
		if previous.is_equal_approx(bolt.position) or map.finished:
			return
		for mob in map.enemies.duplicate():
			if mob.get("in_spirit",false):
				continue
			var id = mob.node.get_instance_id()
			if struck.has(id):
				continue
			var center: Vector3 = mob.node.position
			center.y = origin.y
			var closest = Geometry3D.get_closest_point_to_segment(center,previous,bolt.position)
			if center.distance_squared_to(closest) <= 0.28*0.28:
				struck[id] = true
				map.damage_enemy(mob,damage)
	,0.0,float(tower.range),tower.range/BOLT_SPEED)
	flight.tween_callback(func():
		map.shells_in_flight -= 1
		bolt.queue_free()
	)
