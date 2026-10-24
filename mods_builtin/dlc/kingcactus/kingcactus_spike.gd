extends BulletLinear000Base
## 国王仙人掌的尖刺（模组「DLC植物」自己的子弹，不走本体 `BulletRegistry` 的静态表）
##
## ★ 轨迹：**径向匀加速 + 恒定角速度转向**
##   · 速度大小：沿当前运动方向每帧加 `radial_acceleration`，越飞越快；
##   · 速度方向：每帧按 `angular_speed`（弧度 / 秒）旋转，方向由 `axial_sign` 决定
##     逆时针 / 顺时针 —— 角速度恒定，所以是「圆弧 + 越来越大的半径（v/ω）」。
##   · 发射方每次齐射翻转 `axial_sign`，相邻两轮 8 根刺的弯法镜像。
##
## ★ 为什么自己算移动、不用 `MovementComponent`：
##   `BulletMovementLinear` 只有「每帧 `position += direction * speed * delta`」这一句匀速直线，
##   而 `Bullet000NormBase.speed` 又是场景里的定值 —— 想加速 / 转向只能自己维护速度向量。
##   （仍然继承 `BulletLinear000Base`：撞击 / 斜坡 / 伤害判定这些一行都不用重写。）
##
## ★ 走模组自带的场景（`kingcactus_spike.tscn` 继承本体 `bullet_cactus.tscn`），
##   不改本体的 `bullet_cactus.tscn`：关掉模组 = 回到原版那颗匀速直线刺。

## 径向加速度（像素 / 秒²）：沿**当前运动方向**加速
@export var radial_acceleration := 160.0
## 转向的角速度（弧度 / 秒）：恒定，不随速度变化；约 0.9 rad/s ≈ 51°/秒
@export var angular_speed := 0.9
## 转向方向：+1 / -1（发射方每次齐射翻转）
## 用 1.0 / -1.0 而不是 bool，方便直接乘进弧度增量
var axial_sign := 1.0

## 当前速度向量（不是 `speed * direction`：本类会一直改它）
var _velocity := Vector2.ZERO
## 已飞行时间（秒）：给探针核对「转过的角度 = 角速度 × 时间」
var _elapsed := 0.0


func _ready() -> void:
	super()
	## `init_bullet()` 在入树前就写好了 `direction` / `speed`
	_velocity = direction.normalized() * speed


func _physics_process(delta: float) -> void:
	_elapsed += delta
	## 先按恒定角速度转向，再沿新方向加速（次序差别只有一阶小量）
	_velocity = _velocity.rotated(angular_speed * axial_sign * delta)
	_velocity += _velocity.normalized() * radial_acceleration * delta
	position += _velocity * delta

	## 刺一直朝速度方向（贴着圆弧轨迹转）
	body.rotation = _velocity.angle()

	if global_position.distance_to(start_pos) > max_distance:
		queue_free()
