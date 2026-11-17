extends VBoxContainer

const SIZES = [Vector2i(800,600), Vector2i(1024,768), Vector2i(1280,720),
	Vector2i(1280,800), Vector2i(1366,768), Vector2i(1600,900),
	Vector2i(1920,1080), Vector2i(1980,1080), Vector2i(2560,1440)]

var picker = OptionButton.new()
var preview: AudioStreamPlayer

static func saved_size() -> Vector2i:
	return DisplaySettings.saved_size()

func _ready():
	var mode_caption = Label.new()
	mode_caption.text = "Режим экрана"
	add_child(mode_caption)
	var mode_picker = OptionButton.new()
	mode_picker.add_item("Оконный")
	mode_picker.add_item("Полноэкранный")
	mode_picker.select(1 if DisplaySettings.is_fullscreen() else 0)
	mode_picker.custom_minimum_size.y = 40
	add_child(mode_picker)
	mode_picker.item_selected.connect(func(index): DisplaySettings.set_fullscreen(index == 1))
	var caption = Label.new()
	caption.text = "Размер окна (полный экран — размер монитора)"
	caption.add_theme_font_size_override("font_size",14)
	add_child(caption)
	add_child(picker)
	picker.custom_minimum_size.y = 48
	var current = saved_size()
	for resolution in SIZES:
		var caption_text = "%d × %d" % [resolution.x,resolution.y]
		if resolution == Vector2i(2560,1440):
			caption_text += " (2К / QHD)"
		picker.add_item(caption_text)
		if resolution == current:
			picker.select(picker.item_count-1)
	picker.item_selected.connect(select_size)
	add_display_slider("Яркость","brightness")
	add_display_slider("Гамма","gamma")
	add_volume_slider("Музыка", &"Music")
	add_volume_slider("Звуки игры", &"Effects")
	var general = VBoxContainer.new()
	general.name = "Общие"
	general.add_theme_constant_override("separation",10)
	for child in get_children():
		remove_child(child)
		general.add_child(child)
	var tabs = TabContainer.new()
	add_child(tabs)
	tabs.add_child(general)
	var controls = VBoxContainer.new()
	controls.name = "Управление"
	controls.add_theme_constant_override("separation",14)
	tabs.add_child(controls)
	for text in ["ЛКМ — построить выбранную башню", "ПКМ по башне — продать", "Колесо мыши — масштаб карты", "Зажать колесо и двигать мышь — перемещение карты", "Esc — пауза / назад"]:
		var help = Label.new()
		help.text = text
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.custom_minimum_size.x = 280
		controls.add_child(help)

func focus_settings():
	var tabs = picker.get_parent().get_parent() as TabContainer
	tabs.current_tab = 0
	picker.grab_focus()

func add_display_slider(caption: String,key: String):
	var row = HBoxContainer.new()
	add_child(row)
	var label = Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var readout = Label.new()
	row.add_child(readout)
	var slider = HSlider.new()
	slider.name = key.capitalize()
	var limits: Vector2 = DisplaySettings.LIMITS[key]
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = 0.05
	slider.value = DisplaySettings.value(key)
	add_child(slider)
	var update_text = func(amount: float):
		readout.text = ("%d%%" % roundi(amount*100)) if key == "brightness" else ("%.2f" % amount).replace(".",",")
	update_text.call(slider.value)
	slider.value_changed.connect(func(amount: float):
		DisplaySettings.set_value(key,amount)
		update_text.call(amount)
	)

func add_volume_slider(caption: String, bus: StringName):
	var row = HBoxContainer.new()
	add_child(row)
	var label = Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var percent = Label.new()
	row.add_child(percent)
	var slider = HSlider.new()
	slider.value = AudioSettings.volume(bus)
	percent.text = "%d%%" % int(slider.value)
	add_child(slider)
	slider.value_changed.connect(func(value):
		AudioSettings.set_volume(bus, int(value))
		percent.text = "%d%%" % int(value)
		if bus == &"Effects" and preview != null and not preview.playing:
			preview.play()
	)

func select_size(index):
	DisplaySettings.select_resolution(SIZES[index])
