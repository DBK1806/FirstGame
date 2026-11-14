extends CanvasLayer

func start(level: PackedScene):
	layer = 100
	var veil = ColorRect.new()
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color("19261f")
	veil.modulate.a = 0.0
	var fade = create_tween().set_trans(Tween.TRANS_SINE)
	fade.tween_property(veil,"modulate:a",1.0,0.38)
	await fade.finished
	get_tree().change_scene_to_packed(level)
	await get_tree().scene_changed
	fade = create_tween().set_trans(Tween.TRANS_SINE)
	fade.tween_property(veil,"modulate:a",0.0,0.55)
	await fade.finished
	queue_free()
