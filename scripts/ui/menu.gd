extends "res://scripts/world/scenery.gd"

const Campaign = preload("res://scripts/gameplay/campaign.gd")
const TRANSITION = preload("res://scripts/ui/transition.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var navigation = VBoxContainer.new()
var settings = SettingsPanel.new()
var levels = VBoxContainer.new()
var level_buttons: Array[Button] = []
var play_button: Button
var settings_button: Button
var starting = false

func _ready():
	settings.preview = $EffectsPreview
	build_landscape()
	var layer = CanvasLayer.new()
	add_child(layer)
	var root = Control.new()
	layer.add_child(root)
	fit_interface(root)
	var panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = 68
	panel.offset_right = 451
	panel.offset_top = -194
	panel.offset_bottom = 194
	var style = panel_color("20342ff5","b8a16a")
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 23
	style.content_margin_bottom = 23
	panel.add_theme_stylebox_override("panel",style)
	var stack = VBoxContainer.new()
	panel.add_child(stack)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation",22)
	var title = Label.new()
	title.text = "Стражи\nперевала"
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Georgia","Liberation Serif"])
	title.add_theme_font_override("font",font)
	title.add_theme_font_size_override("font_size",48)
	title.add_theme_color_override("font_color",Color("f6e5bd"))
	stack.add_child(title)
	for page in [navigation, settings, levels]:
		stack.add_child(page)
		page.add_theme_constant_override("separation",10)
	play_button = menu_button(navigation,"Начать игру",show_levels,true)
	var completed = Campaign.completed()
	var chapters = HBoxContainer.new()
	chapters.add_theme_constant_override("separation",10)
	levels.add_child(chapters)
	for chapter in 2:
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation",6)
		chapters.add_child(column)
		for row in 5:
			var i = chapter*5+row
			var button = menu_button(column,Campaign.level_title(i+1)+("  ✓" if i < completed else ""),begin.bind(i))
			style_level_button(button,chapter==1,i==completed)
			button.disabled = i > completed
			if button.disabled:
				button.tooltip_text = "Пройдите уровень «%s»" % Campaign.NAMES[i-1]
			level_buttons.append(button)
	menu_button(levels,"Назад",show_home)
	settings_button = menu_button(navigation,"Настройки",show_settings)
	menu_button(navigation,"Выход",get_tree().quit)
	decorate(settings.picker,false)
	menu_button(settings,"Назад",show_home)
	show_home()

func build_landscape():
	rng.seed = 142
	light_world()
	var cam = Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 13
	cam.position = Vector3(11,16,23)
	cam.look_at(Vector3(2,0,0))
	cam.current = true
	box(self,Vector3.DOWN*0.18,Vector3(100,0.36,100),MOSS,"grass")
	for col in range(-4,5):
		for row in range(-1,4):
			var p = Vector3(col*5,0.03,row*3.2+4.2)
			if col in [1,2] and row < 1:
				continue
			var tone = ["a3984d","819349","b49754","9a9d59"][rng.randi_range(0,3)]
			box(self,p,Vector3(4.74,0.06,2.97),tone,"field")
			var ridge = Color(tone).lightened(0.12).to_html(false)
			for furrow in 9:
				box(self,p+Vector3(furrow*0.49-1.96,0.045,0),Vector3(0.10,0.045,2.81),ridge,"field")
	box(self,Vector3(1,0.04,-1.2),Vector3(34,0.08,0.75),"bea574","earth")
	castle(Vector3(5,0,-3.6),2.0)
	village()
	for i in 108:
		var p = Vector3(rng.randf_range(-21,21),0,rng.randf_range(-16,-6))
		tree(p,rng.randf_range(0.7,1.6))

func decorate(button: Button, primary: bool):
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size",22)
	button.add_theme_stylebox_override("normal",panel_color("896534" if primary else "344a3f","be9f62" if primary else "607461"))
	button.add_theme_stylebox_override("hover",panel_color("796a42","dbc185"))
	button.add_theme_stylebox_override("pressed",panel_color("534a30","dbc185"))

func menu_button(parent,caption,callback,primary=false) -> Button:
	var button = Button.new()
	button.text = caption
	decorate(button,primary)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func style_level_button(button: Button,night: bool,current: bool):
	var base = Color("424054" if night else "394e3b")
	var trim = Color("a39ab7" if night else "a8a77a")
	button.custom_minimum_size = Vector2(242,38)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",17)
	for state in ["normal","hover","pressed","disabled"]:
		var stone = base
		var edge = trim
		match state:
			"hover": stone = base.lightened(0.14)
			"pressed": stone = base.darkened(0.16)
			"disabled":
				stone = base.darkened(0.27)
				edge = trim.darkened(0.43)
		var frame = panel_color(stone.to_html(),("e1bc75" if current else edge.to_html()))
		frame.border_width_left = 4
		frame.content_margin_top = 4
		frame.content_margin_bottom = 4
		frame.content_margin_left = 12
		frame.content_margin_right = 9
		button.add_theme_stylebox_override(state,frame)
	button.add_theme_color_override("font_disabled_color",Color("aaa4b6" if night else "a6afa1"))

func show_settings():
	navigation.hide()
	settings.show()
	settings.focus_settings()

func show_home():
	levels.hide()
	settings.hide()
	navigation.show()
	play_button.grab_focus()

func show_levels():
	navigation.hide()
	levels.show()
	level_buttons[mini(Campaign.completed(),level_buttons.size()-1)].grab_focus()

func begin(index: int):
	if starting or index < 0 or index >= Campaign.SCENES.size() or index > Campaign.completed():
		return
	starting = true
	create_tween().tween_property($MenuMusic, "volume_db", -60.0, 0.38)
	for button in level_buttons:
		button.disabled = true
	levels.get_child(-1).disabled = true
	var curtain = TRANSITION.new()
	get_tree().root.add_child(curtain)
	curtain.start(load(Campaign.SCENES[index]))

func _unhandled_key_input(event):
	if levels.visible and not starting and event.is_action_pressed("ui_cancel"):
		show_home()
		get_viewport().set_input_as_handled()
	if settings.visible and event.is_action_pressed("ui_cancel"):
		show_home()
		settings_button.grab_focus()
		get_viewport().set_input_as_handled()




