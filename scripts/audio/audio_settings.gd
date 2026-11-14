extends Node

const FILE = "user://audio.cfg"
var config = ConfigFile.new()

func _ready():
	config.load(FILE)
	for bus in [&"Music", &"Effects"]:
		apply_volume(bus, volume(bus))

func volume(bus: StringName) -> int:
	return clampi(config.get_value("volume", bus, 100), 0, 100)

func set_volume(bus: StringName, percent: int):
	config.set_value("volume", bus, percent)
	apply_volume(bus, percent)
	config.save(FILE)

func apply_volume(bus: StringName, percent: int):
	var index = AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent / 100.0, 0.001)))
	AudioServer.set_bus_mute(index, percent == 0)
