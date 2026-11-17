extends CanvasLayer

const FILE = "user://display.cfg"
const LIMITS = {"brightness":Vector2(0.5,1.5),"gamma":Vector2(0.6,1.8)}
var config = ConfigFile.new()
var correction = ShaderMaterial.new()

func _ready():
	config.load(FILE)
	layer = -1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen = ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	correction.shader = preload("res://shaders/display_correction.gdshader")
	screen.material = correction
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_correction()
	apply_window_settings()

func value(key: String) -> float:
	var limits: Vector2 = LIMITS[key]
	return clampf(float(config.get_value("display",key,1.0)),limits.x,limits.y)

func set_value(key: String,amount: float):
	config.set_value("display",key,amount)
	apply_correction()
	config.save(FILE)

func apply_correction():
	for key in LIMITS:
		correction.set_shader_parameter(key,value(key))
	visible = not (is_equal_approx(value("brightness"),1.0) and is_equal_approx(value("gamma"),1.0))

func save_size(resolution: Vector2i):
	config.set_value("display","size",resolution)
	config.save(FILE)

func saved_size() -> Vector2i:
	var resolution = config.get_value("display","size",Vector2i(1280,800))
	if resolution is Vector2i and resolution.x >= 800 and resolution.y >= 600:
		return resolution
	return Vector2i(1280,800)

func is_fullscreen() -> bool:
	return bool(config.get_value("display","fullscreen",false))

func apply_window_settings():
	var window = get_window()
	# UI already scales with fit_interface; keep the viewport tied to the window.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_size = Vector2i.ZERO
	window.mode = Window.MODE_FULLSCREEN if is_fullscreen() else Window.MODE_WINDOWED
	if not is_fullscreen():
		fit_window(saved_size())

func set_fullscreen(enabled: bool):
	config.set_value("display","fullscreen",enabled)
	config.save(FILE)
	apply_window_settings()

func select_resolution(resolution: Vector2i):
	save_size(resolution)
	if not is_fullscreen():
		get_window().mode = Window.MODE_WINDOWED
		fit_window(resolution)

func fit_window(requested: Vector2i):
	var window = get_window()
	if DisplayServer.get_name() == "headless":
		window.size = requested
		return
	var usable = DisplayServer.screen_get_usable_rect(window.current_screen)
	# Leave room for the native title bar, borders and taskbar.
	var available = (usable.size-Vector2i(32,64)).max(Vector2i(320,240))
	window.size = requested.min(available)
	window.position = usable.position + (usable.size-window.size)/2
