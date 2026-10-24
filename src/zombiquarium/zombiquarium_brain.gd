extends Sprite2D
class_name ZombiquariumBrain
## 僵尸水族馆里喂僵尸的「脑子」
##
## 原版口径（A 级参照工程 `../PvZ-Portable-main/src/Lawn/`）：
##   · 投放：点击点 - (15, 15)（Challenge.cpp:3355-3356），贴图左上角就在这个点上
##   · 判定中心：mPos + (15, 15)（原版贴图 30x30，中心在 +15,+15）
##   · 下沉：每 tick +0.15（Challenge.cpp:3436 `mPosY += 0.15f`）
##   · 沉到 mPosY >= 500 就死（Challenge.cpp:3437），这一份 5 阳光就白花了
##   · 落地 15 tick 之后才吃得掉（Zombie.cpp:3090 `mGridItemCounter >= 15`）
##
## 本节点的 `position` 就是原版的 `mPos`（贴图 `centered = false`，左上角对齐原点）。
## 贴图: res://pak/images/brain.png

## 脑子没了（沉到缸底 / 被吃掉），管理器据此把僵尸的目标清掉
signal signal_brain_gone(brain: ZombiquariumBrain)

## 是否已经被吃掉（被吃掉时管理器补一次消失表现）
var is_eaten := false
## 原版 mGridItemCounter：脑子存在了多少 tick（落地 15 tick 之后才吃得掉）
var _alive_tick := 0
var _tick_accumulator := 0.0


func _ready() -> void:
	## 原版 `DrawImageF(IMAGE_BRAIN, mPosX, mPosY)`：贴图左上角在 mPos，判定中心在 mPos + (15,15)
	centered = false


func _process(delta: float) -> void:
	_tick_accumulator += delta
	## 一帧最多补 15 tick：防止卡顿后一次性狂跑
	_tick_accumulator = minf(_tick_accumulator, ConstZombiquarium.TICK_SECONDS * 15.0)
	while _tick_accumulator >= ConstZombiquarium.TICK_SECONDS:
		_tick_accumulator -= ConstZombiquarium.TICK_SECONDS
		_tick()


## 一个 tick：原版 Challenge.cpp:3429-3440 对每个脑子做的事
func _tick() -> void:
	_alive_tick += 1
	## 原版 Challenge.cpp:3436：慢慢往下沉
	position.y += ConstZombiquarium.BRAIN_SINK_PER_TICK
	## 原版 Challenge.cpp:3437：沉到缸底就死（这份阳光白花了）
	if position.y < ConstZombiquarium.BRAIN_DEATH_Y:
		return
	set_process(false)
	signal_brain_gone.emit(self)
	queue_free()


## 判定中心（原版 mPos + (15, 15)）
func get_center() -> Vector2:
	return position + ConstZombiquarium.BRAIN_OFFSET


## 已经存在了多少 tick（原版 mGridItemCounter）
func get_alive_tick() -> int:
	return _alive_tick


## 被僵尸吃掉：发信号后直接消失（咬的那口由僵尸的动画表现）
func be_eaten() -> void:
	if is_eaten:
		return
	is_eaten = true
	set_process(false)
	signal_brain_gone.emit(self)
	queue_free()
