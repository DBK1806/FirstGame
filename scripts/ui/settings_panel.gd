extends VBoxContainer

const SIZES = [Vector2i(800,600), Vector2i(1024,768), Vector2i(1280,720),
	Vector2i(1280,800), Vector2i(1366,768), Vector2i(1600,900),
	Vector2i(1920,1080), Vector2i(1980,1080), Vector2i(2560,1440)]

var picker = OptionButton.new()
var preview: AudioStreamPlayer

static func saved_size() -> Vector2i:
	var saved = DisplaySettings.config.get_value("display","size",Vector2i(1280,800))
	if saved in SIZES:
		return saved
	return Vector2i(1280,800)

func _ready():
	var caption = Label.new()
	caption.text = "Разрешение экрана"
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

static func apply_size(window: Window,resolution: Vector2i):
	# Keep the render target at the selected resolution even in an editor-owned window.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = resolution
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.size = resolution

func select_size(index):
	var resolution = SIZES[index]
	apply_size(get_window(),resolution)
	DisplaySettings.save_size(resolution)

