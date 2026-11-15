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
