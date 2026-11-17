extends SceneTree

const Campaign = preload("res://scripts/gameplay/campaign.gd")
const Watch = preload("res://scripts/world/night_watchman.gd")
var failures = 0

func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func run():
	var display = root.get_node("DisplaySettings")
	var original = root.size
	root.size = Vector2i(1100,700)
	var menu = load("res://scenes/ui/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_settings()
	menu.show_home()
	menu.show_levels()
	check(root.size == Vector2i(1100,700),"Menu reset the window size")
	menu.queue_free()
	await process_frame
	for path in Campaign.SCENES:
		var game = load(path).instantiate()
		root.add_child(game)
		await process_frame
		check(root.size == Vector2i(1100,700),"Scene reset the window size: " + path)
		for kind in game.Tower.values():
			game.show_tower_details(kind)
			check(game.info_panel.visible,"Missing tower information")
			game.upgrade_kind = kind
			game.refresh_upgrade()
		var tile = game.find_child("ArcherTile",true,false)
		tile.mouse_entered.emit()
		check(game.info_panel.visible,"Hover did not immediately open info")
		tile.mouse_exited.emit()
		check(not game.info_panel.visible,"Hover exit did not close info")
		var cell: Vector2i = game.pads.keys()[0]
		var point = game.camera.unproject_position(game.ground(cell)+Vector3.UP*0.05)
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = point
		game._unhandled_input(click)
		check(game.towers.size() == 1,"Tower placement failed")
		var before: int = game.coins
		game.sell_tower(cell,point)
		check(game.towers.is_empty() and game.coins == before+15,"Wrong sale refund")
		check(game.rewards.get_child_count() > 0,"Missing sale coin animation")
		game.wave = 1
		game.remaining = 3
		game.spawn_enemy()
		check(game.enemies.size() == 1,"Enemy failed to spawn: " + path)
		game.queue_free()
		await process_frame
		print("PASS scene ",path)
	var watch = Watch.new()
	var points = [Vector2(Watch.WEST,Watch.SOUTH),Vector2(Watch.JUNCTION,Watch.NORTH)]
	points.append_array(Watch.EAST_PATH)
	for origin in points:
		for goal in points:
			var here: Vector2 = origin
			for step in 3000:
				if here.distance_to(goal) < 0.01:
					break
				var next = here.move_toward(watch.patrol_waypoint(here,goal),0.05)
				check(on_path(next),"Watchman left gravel path")
				here = next
			check(here.distance_to(goal)<0.01,"Watchman failed to reach destination")
	watch.free()
	root.size = original
	print("CHECKS COMPLETE failures=",failures)
	quit(1 if failures else 0)

func on_path(point: Vector2) -> bool:
	var paths = [[Vector2(Watch.WEST,Watch.SOUTH),Vector2(Watch.JUNCTION,Watch.SOUTH)], [Vector2(Watch.JUNCTION,Watch.NORTH),Vector2(Watch.JUNCTION,Watch.SOUTH)]]
	for i in Watch.EAST_PATH.size()-1:
		paths.append([Watch.EAST_PATH[i],Watch.EAST_PATH[i+1]])
	for edge in paths:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,edge[0],edge[1]))<0.015:
			return true
	return false
