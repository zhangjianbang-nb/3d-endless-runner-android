extends Control
## 主菜单：开始/退出 + 最高分展示（实现 R7 持久化读取、R8 主菜单 UI）

const SAVE_PATH: String = "user://highscore.cfg"

func _ready() -> void:
	var cfg := ConfigFile.new()
	var best := 0
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("score", "high", 0))
	%HighScoreLabel.text = "最高分: %d" % best
	%StartButton.pressed.connect(_on_start)
	%QuitButton.pressed.connect(_on_quit)

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit() -> void:
	get_tree().quit()
