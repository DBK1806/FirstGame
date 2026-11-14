extends RefCounted

const SCENES = ["res://scenes/levels/main.tscn","res://scenes/levels/mill_valley.tscn",
	"res://scenes/levels/three_fields.tscn","res://scenes/levels/amber_quarry.tscn","res://scenes/levels/dusk_ridge.tscn"]
const NAMES = ["Перевал","Мельничная долина","Три нивы","Янтарный карьер","Сумеречный кряж"]
const FILE = "user://campaign.cfg"

static func completed() -> int:
	var config = ConfigFile.new()
	if config.load(FILE) != OK:
		return 0
	return clampi(int(config.get_value("campaign","completed",0)),0,SCENES.size())

static func record_win(number: int):
	if number <= completed():
		return
	var config = ConfigFile.new()
	config.set_value("campaign","completed",number)
	if config.save(FILE) != OK:
		push_warning("Не удалось сохранить прохождение уровня.")
