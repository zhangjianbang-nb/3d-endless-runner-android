extends CharacterBody3D
## 玩家（实现 R1 三车道、R2 左右滑变道、R3 上滑跳跃；DC1 程序化几何）。
## 相对运动设计：玩家固定于原点附近，障碍/金币沿 +Z 移向玩家，
## 等价于角色沿 -Z 前进；碰撞体用 Area3D 检测（covers R1, R2, R3, DC1）

signal jumped
signal lane_changed(lane: int)

const LANE_X := [-2.0, 0.0, 2.0]
const JUMP_VELOCITY: float = 9.5
const GRAVITY: float = 24.0
const SWIPE_MIN_PIXELS: float = 60.0
const LANE_LERP_SPEED: float = 14.0

var lane: int = 1
var alive: bool = true
var _vy: float = 0.0
var _touch_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	_build_body()

func _build_body() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 0.95)
	box.material = mat
	body.mesh = box
	body.position = Vector3(0.0, 0.4, 0.0)
	add_child(body)

	var area := Area3D.new()
	area.name = "Hitbox"
	area.add_to_group("player")
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.8, 0.8, 0.8)
	shape.shape = box_shape
	shape.position = Vector3(0.0, 0.4, 0.0)
	area.add_child(shape)
	add_child(area)

func _input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			_handle_swipe(event.position - _touch_start)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)

func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_LEFT:
			move_lane(-1)
		KEY_RIGHT:
			move_lane(1)
		KEY_UP, KEY_SPACE:
			try_jump()

func _handle_swipe(delta: Vector2) -> void:
	if absf(delta.x) > absf(delta.y) and absf(delta.x) >= SWIPE_MIN_PIXELS:
		move_lane(1 if delta.x > 0.0 else -1)
	elif delta.y <= -SWIPE_MIN_PIXELS:
		try_jump()

func move_lane(dir: int) -> void:
	var next := clampi(lane + dir, 0, LANE_X.size() - 1)
	if next == lane:
		return
	lane = next
	lane_changed.emit(lane)

func try_jump() -> void:
	if position.y > 0.01:
		return
	_vy = JUMP_VELOCITY
	jumped.emit()

func _process(delta: float) -> void:
	if not alive:
		return
	var target_x: float = LANE_X[lane]
	position.x = lerpf(position.x, target_x, minf(1.0, LANE_LERP_SPEED * delta))
	if position.y > 0.0 or _vy > 0.0:
		_vy -= GRAVITY * delta
		position.y = maxf(0.0, position.y + _vy * delta)
		if position.y <= 0.0 and _vy < 0.0:
			_vy = 0.0
