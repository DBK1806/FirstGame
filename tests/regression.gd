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
		var haunting = game.find_child("CemeteryHaunting",true,false)
		check((haunting != null) == (game.level_number == 10),"Haunting must appear only on level 10")
		if haunting != null:
			check(haunting.web_count >= 8 and haunting.web_count <= 30 and haunting.spirits.size() == 3,"Wrong cemetery decoration density")
			var ground_spiders = 0
			var web_spiders = 0
			for spider in haunting.spiders:
				if spider.on_web:
					web_spiders += 1
				else:
					ground_spiders += 1
			check(ground_spiders > 0 and web_spiders > 0,"Missing spider route type")
			for animation_step in 600:
				haunting._process(0.1)
				for spider in haunting.spiders:
					var a: Vector3 = spider.points[spider.segment]
					var b: Vector3 = spider.points[(spider.segment+1)%spider.points.size()]
					var nearest = Geometry3D.get_closest_point_to_segment(spider.node.position,a,b)
					check(spider.node.position.distance_to(nearest) < 0.001,"Spider left its ground/silk route")
			for ghost in haunting.spirits:
				check(ghost.from != ghost.to and ghost.node.position.is_finite(),"Invalid ghost flight")
			var visited_graves = [{},{},{}]
			var previous_speed = Engine.time_scale
			for rate in [1.0,2.0,3.0]:
				Engine.time_scale = rate
				var ghost = haunting.spirits[0]
				ghost.progress = 0.3
				var previous_time: float = haunting.time
				haunting._process(0.1*rate)
				check(is_equal_approx(ghost.progress,0.3+0.1/ghost.duration),"Game speed changed ghost flight speed")
				check(is_equal_approx(haunting.time-previous_time,0.1),"Game speed changed ghost animation speed")
				check(is_equal_approx(ghost.material.get_shader_parameter("animation_time"),haunting.time),"Ghost cloth clock is out of sync")
			Engine.time_scale = previous_speed
			for flight_step in 3600:
				for ghost_index in haunting.spirits.size():
					var ghost = haunting.spirits[ghost_index]
					haunting.move_ghost(ghost,1.0)
					check(haunting.road_clear(ghost.node.position),"Ghost crossed the monster road")
					visited_graves[ghost_index][ghost.from] = true
			for visited in visited_graves:
				check(visited.size() >= 20,"Ghost keeps revisiting a small group of graves")
		var starting_gold = 80 if game.level_number == 5 else 60
		if game.cemetery_stage:
			starting_gold = 140 if game.cemetery_stage in [1,5] else 125
		check(game.coins == starting_gold,"Incorrect starting gold: " + path)
		for kind in game.Tower.values():
			game.show_tower_details(kind)
			check(game.info_panel.visible,"Missing tower information")
			game.upgrade_kind = kind
			game.refresh_upgrade()
		var tile = game.find_child("ArcherTile",true,false)
		check(game.tower_cost(game.Tower.ARCHER) == 30,"Base archer cost changed")
		check(game.SHELL_DAMAGE == 6 and game.HEAVY_SHELL_DAMAGE == 8,"Wrong mortar damage")
		check(game.tower_range(game.Tower.BALLISTA) == 6.5,"Wrong ballista range")
		check(is_equal_approx(game.Ballista.INTERVAL,1.85),"Wrong ballista interval")
		game.upgraded[game.Tower.BALLISTA] = true
		check(game.tower_range(game.Tower.BALLISTA) == 7.5,"Wrong upgraded ballista range")
		game.upgraded[game.Tower.BALLISTA] = false
		game.coins = 500
		for kind in game.Tower.values():
			game.upgrade_kind = kind
			game.upgrade_preview_level = 2
			var gold_before: int = game.coins
			game.buy_upgrade()
			var allowed: bool = (game.level_number >= 3 and kind == game.Tower.ARCHER) or (game.level_number >= 5 and kind == game.Tower.MORTAR) or (game.level_number >= 6 and kind == game.Tower.MILL) or (game.level_number >= 8 and kind == game.Tower.BALLISTA)
			check(game.upgraded[kind] == allowed,"Incorrect upgrade lock: " + path)
			check(game.coins == gold_before-(game.UPGRADE_COSTS[kind] if allowed else 0),"Incorrect upgrade charge")
		check(game.UPGRADE_COSTS[game.Tower.MILL] == 50,"Wrong mill upgrade price")
		check(game.tower_cost(game.Tower.MILL) == (50 if game.level_number >= 6 else 40),"Wrong mill build price")
		check(game.tower_cost(game.Tower.BALLISTA) == (85 if game.level_number >= 8 else 65),"Wrong ballista build price")
		game.upgrade_kind = game.Tower.BALLISTA
		game.refresh_upgrade()
		if game.level_number >= 8:
			check(game.upgrade_stats.text.contains("6 → 10") and game.upgrade_stats.text.contains("65 → 85"),"Missing ballista upgrade stats")
			check(game.upgrade_choices[0].icon == game.BALLISTA_VETERAN_ICON,"Wrong ballista upgrade preview icon")
			check(game.find_child("BallistaTile",true,false).icon == game.BALLISTA_VETERAN_ICON,"Ballista upgraded icon did not change")
		game.upgrade_kind = game.Tower.MILL
		game.refresh_upgrade()
		check(game.upgrade_choices[0].icon == game.MILL_VETERAN_ICON,"Wrong mill preview icon")
		if game.level_number >= 6:
			check(game.upgrade_stats.text.contains("25% → 40%"),"Missing mill stats")
			check(game.find_child("MillTile",true,false).icon == game.MILL_VETERAN_ICON,"Mill icon did not change")
			check(game.tower_range(game.Tower.MILL) == 3.5,"Wrong upgraded mill range")
		game.upgrade_choices[1].mouse_entered.emit()
		var mill_gold: int = game.coins
		game.buy_upgrade()
		check(game.upgrade_action.disabled and game.coins == mill_gold and game.upgrade_stats.text == "?\nУлучшение пока неизвестно","Mill III is not locked")
		game.upgrade_choices[0].mouse_entered.emit()
		game.upgrade_kind = game.Tower.MORTAR
		game.refresh_upgrade()
		check(game.upgrade_choices[0].icon == game.MORTAR_VETERAN_ICON,"Wrong mortar preview icon")
		if game.level_number >= 5:
			check(game.upgrade_stats.text.contains("Радиус взрыва"),"Missing mortar stats")
			check(game.find_child("MortarTile",true,false).icon == game.MORTAR_VETERAN_ICON,"Mortar icon did not change")
		game.upgrade_choices[1].mouse_entered.emit()
		check(game.upgrade_action.disabled and game.upgrade_stats.text == "?\nУлучшение пока неизвестно","Mortar III is not hidden")
		var mortar_gold: int = game.coins
		game.buy_upgrade()
		check(game.coins == mortar_gold,"Mortar III was purchased")
		game.upgrade_kind = game.Tower.ARCHER
		game.upgrade_choices[1].mouse_entered.emit()
		check(game.upgrade_action.disabled and not game.upgrade_stats.text.contains("Урон"),"Mystery upgrade exposed stats")
		var mystery_gold: int = game.coins
		game.buy_upgrade()
		check(game.coins == mystery_gold,"Mystery upgrade was purchased")
		game.upgrade_choices[0].mouse_entered.emit()
		check(game.upgrade_preview_level == 2,"Level II preview did not return")
		if game.level_number >= 3:
			check(tile.icon == game.ARCHER_VETERAN_ICON,"Upgrade icon did not change")
		for test_wave in range(1,game.wave_count+1):
			game.wave = test_wave
			var expected_bonus: int = (2 if game.level_number == 3 else (3 if game.level_number == 4 else 5))+test_wave-1 if game.level_number >= 3 else 0
			if game.level_number == 4:
				expected_bonus = [3,4,5,6,7,13,15,17,19,21,23,25][test_wave-1]
			if game.level_number == 5:
				expected_bonus = [3,5,7,9,11,13,15,17,19,21,23,25][test_wave-1]
			if game.level_number == 6:
				expected_bonus = [2,3,4,5,6,7,8,9,10,11,12,13][test_wave-1]
			if game.level_number == 7:
				expected_bonus = [8,10,12,14,16,18,20,22,24,26,28,30][test_wave-1]
			if game.level_number == 8:
				expected_bonus = [5,6,7,8,9,10,11,22,25,28,31,34][test_wave-1]
			if game.level_number == 9:
				expected_bonus = [0,1,2,3,4,5,11,13,15,17,19,21,23,25][test_wave-1]
			check(game.enemy_health_bonus() == expected_bonus,"Wrong health bonus: " + path)
		tile.mouse_entered.emit()
		check(game.info_panel.visible,"Hover did not immediately open info")
		tile.mouse_exited.emit()
		check(not game.info_panel.visible,"Hover exit did not close info")
		for entry in game.tower_tiles:
			if not entry.button.toggle_mode:
				game.upgrade_panel.hide()
				entry.button.mouse_entered.emit()
				check(game.upgrade_panel.visible == game.upgrade_available(entry.kind),"Incorrect upgrade hover availability")
				if game.upgrade_panel.visible:
					game.update_upgrade_hover(entry.button.get_global_rect().get_center())
					check(game.upgrade_panel.visible,"Upgrade closed over its tile")
					game.update_upgrade_hover(game.upgrade_panel.get_global_rect().get_center())
					check(game.upgrade_panel.visible,"Upgrade closed inside panel")
					game.update_upgrade_hover(Vector2(-1000,-1000))
					check(not game.upgrade_panel.visible,"Upgrade stayed open outside panel")
		var cell: Vector2i = game.pads.keys()[0]
		var point = game.camera.unproject_position(game.ground(cell)+Vector3.UP*0.05)
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = point
		var build_price = 45 if game.level_number >= 3 else 30
		var build_gold: int = game.coins
		game.coins = build_price-1
		game._unhandled_input(click)
		check(game.towers.is_empty() and game.coins == build_price-1,"Construction allowed without enough gold")
		game.coins = build_gold
		game._unhandled_input(click)
		check(game.towers.size() == 1,"Tower placement failed")
		game.info_panel.hide()
		game.update_range_preview(point,false)
		check(not game.info_panel.visible,"Map tower hover opened info")
		check(game.ring.visible,"Map tower lost range preview")
		check(game.coins == build_gold-build_price,"Incorrect archer construction price")
		var before: int = game.coins
		game.sell_tower(cell,point)
		check(game.towers.is_empty() and game.coins == before+int(build_price*0.5),"Wrong sale refund")
		check(game.rewards.get_child_count() > 0,"Missing sale coin animation")
		game.selected_tower = game.Tower.MORTAR
		var mortar_price = 75 if game.level_number >= 5 else 60
		var mortar_build_gold: int = game.coins
		game.coins = mortar_price-1
		game._unhandled_input(click)
		check(game.towers.is_empty() and game.coins == mortar_price-1,"Mortar built without enough gold")
		game.coins = mortar_build_gold
		game._unhandled_input(click)
		check(game.towers.size() == 1,"First mortar placement failed")
		check(game.coins == mortar_build_gold-mortar_price,"Incorrect mortar construction price")
		for dx in range(-2,3):
			for dy in range(-2,3):
				var target = cell + Vector2i(dx,dy)
				var adjacent = absi(dx) <= 1 and absi(dy) <= 1
				check(game.mortar_spacing_allowed(target,game.Tower.MORTAR) == not adjacent,"Wrong mortar spacing")
				for kind in [game.Tower.ARCHER,game.Tower.MILL,game.Tower.BALLISTA]:
					check(game.mortar_spacing_allowed(target,kind),"Mortar blocked another tower type")
				if adjacent and game.pads.has(target):
					click.position = game.camera.unproject_position(game.ground(target)+Vector3.UP*0.05)
					var gold_before: int = game.coins
					game._unhandled_input(click)
					check(game.towers.size() == 1 and game.coins == gold_before and game.pads.has(target),"Blocked mortar changed the board or gold")
		game.sell_tower(cell,point)
		check(game.mortar_spacing_allowed(cell+Vector2i.ONE,game.Tower.MORTAR),"Sold mortar still blocks placement")
		game.wave = 1
		game.remaining = 3
		if game.cemetery_stage:
			for boss_test_wave in [5,7,9,12]:
				game.wave = boss_test_wave
				game.remaining = 1
				var mob = game.Undead.spawn(game)
				var expected_boss = boss_test_wave in ([7,9,12] if game.level_number == 6 else [5,9,12])
				check((mob.kind == "gargoyle") == expected_boss,"Wrong gargoyle wave: " + path)
				if expected_boss:
					var boss_bonus = 50 if game.level_number == 6 else 100
					var expected_hp = game.Undead.base_gargoyle_hp(game)+boss_bonus
					if game.level_number == 7:
						expected_hp = {5:110,9:190,12:280}[boss_test_wave]
					if game.level_number == 8:
						expected_hp = {5:190,9:280,12:430}[boss_test_wave]
					if game.level_number == 9:
						expected_hp = {5:130,9:276,12:444}[boss_test_wave]
					if game.level_number == 10:
						expected_hp = {5:124,9:262,12:514}[boss_test_wave]
					check(mob.hp == expected_hp,"Wrong gargoyle health: " + path)
				elif game.level_number == 6:
					var weapon = (game.remaining+game.wave)%4
					var factor = 2.45 if mob.kind == "zombie" else game.Undead.WEAPON_HEALTH[weapon]
					check(mob.hp == maxi(1,roundi(game.health_table[game.wave-1]*factor))+2+(game.wave-1),"Wrong level 6 health bonus")
				mob.node.queue_free()
			if game.level_number == 9:
				game.wave = 14
				for remaining_count in [14,1]:
					game.remaining = remaining_count
					var final_mob = game.Undead.spawn(game)
					check(final_mob.kind == "gargoyle" and final_mob.hp == 606,"Wrong level 9 final gargoyle health")
					final_mob.node.queue_free()
			game.wave = 1
			game.remaining = 3
		game.spawn_enemy()
		check(game.enemies.size() == 1,"Enemy failed to spawn: " + path)
		if game.level_number == 10:
			game.wave = game.wave_count
			game.remaining = 1
			game.reaper_pending = true
			game.spawn_clock = 0
			game.step_wave(0)
			check(game.boss_warning.visible and game.boss_warning.text.contains("10 с") and game.boss_warning_sound.playing,"Missing boss countdown or warning sound")
			game.step_wave(9.99)
			check(game.reaper_pending,"Final boss spawned before ten seconds")
			game.step_wave(0.02)
			check(not game.reaper_pending and not game.boss_warning.visible,"Boss countdown did not finish")
			var reapers = 0
			for mob in game.enemies:
				if mob.kind == "death":
					reapers += 1
			check(reapers == 1,"Final boss did not spawn exactly once")
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
