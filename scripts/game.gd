extends Node3D
## 游戏主控：障碍/金币程序化生成与移动、碰撞结算、计分、加速、
## 游戏结束与最高分持久化、暂停/结束 UI 与 Android 返回键暂停
## （实现 R4, R5, R6, R7, R8）

enum State { RUNNING, PAUSED, GAME_OVER }

const BASE_SPEED: float = 8.0
const MAX_SPEED: float = 24.0
const SPEED_PER_SCORE: float = 0.12
const SPAWN_INTERVAL: float = 1.1
const SPAWN_Z: float = -90.0
const DESPAWN_Z: float = 14.0
const SAVE_PATH: String = "user://highscore.cfg"

const LANE_X := [-2.0, 0.0, 2.0]

var state: int = State.RUNNING
var score: int = 0
var high_score: int = 0
var speed: float = BASE_SPEED
var _entities: Array[Node3D] = []
var _spawn_timer: Timer

@onready var score_label: Label = %ScoreLabel
@onready var high_label: Label = %HighScoreLabel
@onready var game_over_panel: Control = %GameOverPanel
@onready var final_label: Label = %FinalScoreLabel
@onready var pause_menu: Control = %PauseMenu

func _ready() -> void:
	_load_high_score()
	_build_track()
	_setup_player()
	_setup_timer()
	_setup_ui()

func _build_track() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var box := BoxMesh.new()
	box.size = Vector3(14.0, 0.2, 400.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.3)
	box.material = mat
	ground.mesh = box
	ground.position = Vector3(0.0, -0.1, -160.0)
	add_child(ground)

func _setup_player() -> void:
	var player := $Player
	player.jumped.connect(_on_player_jumped)

func _setup_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_row)
	add_child(_spawn_timer)
	_spawn_timer.start()

func _setup_ui() -> void:
	score_label.text = "分数: 0"
	high_label.text = "最高分: %d" % high_score
	%PauseButton.pressed.connect(_toggle_pause)
	%ResumeButton.pressed.connect(_toggle_pause)
	%ToMenuButton.pressed.connect(_to_menu)
	%RetryButton.pressed.connect(_restart)
	%GameOverMenuButton.pressed.connect(_to_menu)

func _input(event: InputEvent) -> void:
	# Android 返回键 / Esc：暂停或恢复（实现 R8）
	if event.is_action_pressed("ui_cancel") and state != State.GAME_OVER:
		_toggle_pause()

func _process(delta: float) -> void:
	if state != State.RUNNING:
		return
	_move_entities(delta)

func _spawn_row() -> void:
	if state != State.RUNNING:
		return
	var blocked := randi() % LANE_X.size()
	var coin_lane := -1
	for i in LANE_X.size():
		if i == blocked:
			continue
		if coin_lane == -1 and randf() < 0.45:
			coin_lane = i
		else:
			_spawn_obstacle(i)
	if coin_lane >= 0:
		_spawn_coin(coin_lane)

func _spawn_obstacle(lane: int) -> void:
	var area := Area3D.new()
	area.add_to_group("obstacle")
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 1.4, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.3, 0.25)
	box.material = mat
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0.0, 0.7, 0.0)
	area.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.4, 0.8)
	shape.shape = box_shape
	shape.position = Vector3(0.0, 0.7, 0.0)
	area.add_child(shape)
	area.area_entered.connect(_on_entity_touched.bind(area))
	area.position = Vector3(LANE_X[lane], 0.0, SPAWN_Z)
	add_child(area)
	_entities.append(area)

func _spawn_coin(lane: int) -> void:
	var area := Area3D.new()
	area.add_to_group("coin")
	var mesh_instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.8, 0.2)
	mat.metallic = 0.6
	cyl.material = mat
	mesh_instance.mesh = cyl
	mesh_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mesh_instance.position = Vector3(0.0, 0.6, 0.0)
	area.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.6, 0.0)
	area.add_child(shape)
	area.area_entered.connect(_on_entity_touched.bind(area))
	area.position = Vector3(LANE_X[lane], 0.0, SPAWN_Z)
	add_child(area)
	_entities.append(area)

func _move_entities(delta: float) -> void:
	for entity in _entities.duplicate():
		entity.position.z += speed * delta
		if entity.position.z > DESPAWN_Z:
			_entities.erase(entity)
			entity.queue_free()

func _on_entity_touched(other: Area3D, entity: Area3D) -> void:
	if state != State.RUNNING or not other.is_in_group("player"):
		return
	if entity.is_in_group("coin"):
		score += 1
		speed = minf(MAX_SPEED, BASE_SPEED + score * SPEED_PER_SCORE)
		score_label.text = "分数: %d" % score
		Sfx.play("coin")
		_entities.erase(entity)
		entity.queue_free()
	elif entity.is_in_group("obstacle"):
		_game_over()

func _on_player_jumped() -> void:
	Sfx.play("jump")

func _game_over() -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	_spawn_timer.stop()
	$Player.alive = false
	Sfx.play("crash")
	if score > high_score:
		high_score = score
		_save_high_score()
	final_label.text = "本局分数: %d · 最高分: %d" % [score, high_score]
	game_over_panel.visible = true

func _toggle_pause() -> void:
	if state == State.GAME_OVER:
		return
	var pausing := state == State.RUNNING
	if pausing:
		state = State.PAUSED
	else:
		state = State.RUNNING
	get_tree().paused = pausing
	pause_menu.visible = pausing

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("score", "high", 0))
	high_label.text = "最高分: %d" % high_score

func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "high", high_score)
	cfg.save(SAVE_PATH)
