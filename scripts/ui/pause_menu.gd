extends ColorRect

var resume_button = Button.new()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("14211edb")
	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack = VBoxContainer.new()
	stack.custom_minimum_size.x = 250
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)
	var title = Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("f6e5bd"))
	stack.add_child(title)
	resume_button.text = "Продолжить"
	stack.add_child(resume_button)
	resume_button.pressed.connect(set_paused.bind(false))
	var home = Button.new()
	home.text = "В главное меню"
	stack.add_child(home)
	for button in [resume_button, home]:
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 21)
	home.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
	)
	hide()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		set_paused(not visible)

func set_paused(value: bool):
	visible = value
	get_tree().paused = value
	if value:
		resume_button.grab_focus()
