extends Node2D
class_name PoolSparkly
## 泳池「波光」：原版 PARTICLE_POOL_SPARKLY（pak/particles/PoolSparkly.xml）的逐字段移植。
##
## TodLib 语义出处（本机只读参照 C++ 工程，只搬行为不搬素材）：
## - SpawnRate 单位是「个/逻辑帧」（UpdateSpawning 里 *0.01：150 → 1.5/帧）；
## - FIELD_VELOCITY 每帧 pos += 0.01 * field（TodParticle.cpp UpdateParticleField）；
## - FloatTrackEvaluate：单节点轨道 = 用粒子固定随机数在 [low, high] 内按分布采样；
##   多节点轨道（ParticleScale）先按随机数取各节点值，再按时间线性交叉淡变；
## - EmitterSkewX：粒子 x += 盒内 y * skew（平行四边形斜切 → 波光呈斜带）；
## - FastInOutWeak 分布 = InvQuadS（TodCommon.cpp TodCurveInvQuadS）；
## - 系统按 30fps 逻辑帧推进，这里用固定步长累加器逐帧复刻。

const TEXTURE_PATH: String = "res://pak/particles/PoolSparkly.png"
const LOGIC_FPS: float = 30.0
const ALPHA: float = 0.8

## 两条 Emitter，与 pak/particles/PoolSparkly.xml 逐字段对应
## （vel_* 是 XML 原值，单位 px/逻辑帧，*0.01 的 TodLib 系数在生成时乘；时长单位逻辑帧）
const EMITTERS: Array = [
	{
		spawn_rate = 1.5,                # SpawnRate 150
		box_x = Vector2(0.0, 290.0),     # EmitterBoxX [0 FastInOutWeak 290]
		box_x_weak = true,
		box_y = Vector2(0.0, 135.0),     # EmitterBoxY [0 135]
		skew_x = -0.3,                   # EmitterSkewX -.3
		vel_x = Vector2(0.0, -10.0),     # Field Velocity X [0 -10]
		vel_y = Vector2(-2.0, 2.0),      # Field Velocity Y [-2 2]
		duration = Vector2(20.0, 80.0),  # ParticleDuration [20 80]
	},
	{
		spawn_rate = 0.2,                # SpawnRate 20
		box_x = Vector2(-330.0, 260.0),  # EmitterBoxX [-330 260]
		box_x_weak = false,
		box_y = Vector2(0.0, 135.0),
		skew_x = 0.0,
		vel_x = Vector2(0.0, -5.0),
		vel_y = Vector2(-2.0, 2.0),
		duration = Vector2(20.0, 60.0),
	},
]

## ParticleScale 交叉淡变包络：节点 [时间, low, high]（XML 末节点时间省略 = 1.0）
const SCALE_TRACK: Array = [
	[0.0, 0.3, 0.6], [0.1, 0.4, 0.8], [0.5, 0.5, 1.0], [0.9, 0.4, 0.8], [1.0, 0.3, 0.6],
]

var _texture: Texture2D
## { pos, vel, age, duration, rand_value } —— rand_value 是该粒子固定随机数（采样 SCALE_TRACK 用）
var _sparkles: Array[Dictionary] = []
var _spawn_accums: Array[float] = [0.0, 0.0]
var _frame_acc := 0.0


func _ready() -> void:
	_texture = AssetRegistry.get_texture(TEXTURE_PATH)


func _process(delta: float) -> void:
	_frame_acc += delta * LOGIC_FPS
	while _frame_acc >= 1.0:
		_frame_acc -= 1.0
		_step_one_frame()
	queue_redraw()


func _step_one_frame() -> void:
	for i in EMITTERS.size():
		_spawn_accums[i] += EMITTERS[i].spawn_rate
		while _spawn_accums[i] >= 1.0:
			_spawn_accums[i] -= 1.0
			_spawn_sparkle(i)
	for i in range(_sparkles.size() - 1, -1, -1):
		var sparkle: Dictionary = _sparkles[i]
		sparkle.age += 1.0
		sparkle.pos += sparkle.vel
		if sparkle.age >= sparkle.duration:
			_sparkles.remove_at(i)


func _spawn_sparkle(index: int) -> void:
	var emitter: Dictionary = EMITTERS[index]
	var box_x: Vector2 = emitter.box_x
	var box_y: Vector2 = emitter.box_y
	var vel_x: Vector2 = emitter.vel_x
	var vel_y: Vector2 = emitter.vel_y
	var duration: Vector2 = emitter.duration
	var bx: float = _tod_curve(randf(), box_x.x, box_x.y, emitter.box_x_weak)
	var by: float = randf_range(box_y.x, box_y.y)
	_sparkles.append({
		pos = Vector2(bx + by * emitter.skew_x, by),
		vel = Vector2(
			randf_range(vel_x.x, vel_x.y) * 0.01,
			randf_range(vel_y.x, vel_y.y) * 0.01
		),
		age = 0.0,
		duration = randf_range(duration.x, duration.y),
		rand_value = randf(),
	})


func _draw() -> void:
	if _texture == null:
		return
	var tex_size := _texture.get_size()
	var color := Color(1.0, 1.0, 1.0, ALPHA)
	for sparkle in _sparkles:
		## 原版 mParticleTimeValue = age / (duration - 1)
		var time_value: float = sparkle.age / maxf(sparkle.duration - 1.0, 1.0)
		var particle_scale: float = _eval_scale_track(time_value, sparkle.rand_value)
		var size := tex_size * particle_scale
		draw_texture_rect(_texture, Rect2(sparkle.pos - size * 0.5, size), false, color)


## TodCurveEvaluate：FastInOutWeak = InvQuadS，其余（本文件只用到）Linear 即 lerp
func _tod_curve(time: float, low: float, high: float, fast_in_out_weak: bool) -> float:
	var warped := time
	if fast_in_out_weak:
		warped = _inv_quad_s(time)
	return lerpf(low, high, warped)


func _inv_quad_s(time: float) -> float:
	if time <= 0.5:
		return _inv_quad(time * 2.0) * 0.5
	return _quad((time - 0.5) * 2.0) * 0.5 + 0.5


func _inv_quad(time: float) -> float:
	return 2.0 * time - time * time


func _quad(time: float) -> float:
	return time * time


## ParticleScale 轨道求值：各节点先按粒子固定随机数采样，再按时间线性过渡
func _eval_scale_track(time_value: float, rand_value: float) -> float:
	var prev: Array = SCALE_TRACK[0]
	for i in range(1, SCALE_TRACK.size()):
		var node: Array = SCALE_TRACK[i]
		if time_value <= node[0]:
			var fraction: float = (time_value - prev[0]) / (node[0] - prev[0])
			return lerpf(_node_scale(prev, rand_value), _node_scale(node, rand_value), fraction)
		prev = node
	return _node_scale(SCALE_TRACK[-1], rand_value)


func _node_scale(node: Array, rand_value: float) -> float:
	return lerpf(node[1], node[2], rand_value)
