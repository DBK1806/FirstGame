extends SceneTree
var failures = 0
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func settle():
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
func run():
	var display = root.get_node("DisplaySettings")
	var saved = display.config.encode_to_text()
	display.set_fullscreen(false)
	display.select_resolution(Vector2i(2560,1440))
	await settle()
	var usable = DisplayServer.screen_get_usable_rect(root.current_screen)
	check(usable.encloses(Rect2i(root.position,root.size)),"Window outside usable screen")
	display.select_resolution(Vector2i(1280,800))
	await settle()
	check(root.size == Vector2i(1280,800),"Window size selection failed")
	display.set_fullscreen(true)
	await settle()
	check(root.mode == Window.MODE_FULLSCREEN,"Fullscreen failed")
	display.set_fullscreen(false)
	await settle()
	check(root.size == Vector2i(1280,800),"Window restore failed")
	var game = load("res://scenes/levels/night_arcade.tscn").instantiate()
	root.add_child(game)
	await settle()
	root.get_texture().get_image().save_png("user://check-path.png")
	game.hud_root.hide()
	# Isolate models on a clean stage for front/side inspection.
	game.camera.position = Vector3(4,2,4)
	game.camera.look_at(Vector3(0,0.45,0))
	game.camera.size = 3.8
	var models = Node3D.new()
	root.add_child(models)
	for i in 2:
		var base = Node3D.new()
		models.add_child(base)
		base.position = Vector3((i-0.5)*1.6,4,0)
		var mob = game.Undead.build_model(game,base,"skeleton",i)
		mob.arms[0].rotation.x = -0.25
	game.camera.position += Vector3.UP*4
	game.camera.look_at(Vector3(0,4.45,0))
	await settle()
	root.get_texture().get_image().save_png("user://check-weapons.png")
	models.queue_free()
	game.queue_free()
	await process_frame
	display.config.clear()
	display.config.parse(saved)
	display.config.save(display.FILE)
	print("NATIVE CHECKS COMPLETE failures=",failures)
	quit(failures)
