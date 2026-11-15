extends ColorRect

var resume_button = Button.new()
var settings_button = Button.new()
var navigation = VBoxContainer.new()
var settings = preload("res://scripts/ui/settings_panel.gd").new()
var title = Label.new()

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
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("f6e5bd"))
	stack.add_child(title)
	stack.add_child(navigation)
	navigation.add_theme_constant_override("separation",14)
	resume_button.text = "Продолжить"
	navigation.add_child(resume_button)
	resume_button.pressed.connect(set_paused.bind(false))
	var restart = Button.new()
	restart.text = "Начать уровень заново"
	navigation.add_child(restart)
	restart.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	settings_button.text = "Настройки"
	navigation.add_child(settings_button)
	settings_button.pressed.connect(show_settings.bind(true))
	var home = Button.new()
	home.text = "В главное меню"
	navigation.add_child(home)
	var preview = AudioStreamPlayer.new()
	preview.stream = preload("res://assets/audio/sfx/menu_click.wav")
	preview.bus = &"Effects"
	preview.volume_db = -9
	add_child(preview)
	settings.preview = preview
	stack.add_child(settings)
	settings.custom_minimum_size.x = 300
	settings.add_theme_constant_override("separation",10)
	settings.hide()
	var back = Button.new()
	back.text = "Назад"
	settings.add_child(back)
	back.pressed.connect(show_settings.bind(false))
	for button in [resume_button, restart, settings_button, home, back]:
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 21)
	home.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
	)
	hide()

func show_settings(open: bool):
	title.text = "Настройки" if open else "Пауза"
	settings.visible = open
	navigation.visible = not open
	if open:
		settings.picker.grab_focus()
	else:
		settings_button.grab_focus()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if visible and settings.visible:
			show_settings(false)
		else:
			set_paused(not visible)

func set_paused(value: bool):
	visible = value
	get_tree().paused = value
	if value:
		resume_button.grab_focus()
