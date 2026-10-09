extends RefCounted
class_name GameRng
## 全局可播种随机源：给「两处必须抽到同一个结果」的场合用（联机 / 回放 / 自动回归）
##
## 为什么要有它：仓库里原本只有 Godot 全局 `randi()` / `randf()` —— 进程启动时自动随机播种，
## 于是同一关在两台机器上会抽出**不同的怪种、不同的出怪行**。
## 单机无所谓，但联机时一端有僵尸、另一端没有，局面立刻岔开且无法收敛。
## 本类把随机收成一个可播种的开关：
##   · 不调 `set_seed()` → 与原来完全一致（同样的 PCG 算法，每次运行同样不同）；
##   · 调了 `set_seed(n)` → 同一颗种子在两端抽出同一串数。
##
## 用法（联机）：开局时主机定一个种子随「开局命令」下发，两端都 `GameRng.set_seed(种子)`，
## 之后出怪相关的一切随机都走本类。
##
## ★ 替换是渐进的，只有**影响判定**的随机才必须走这里：
##   出怪类型（`RandomPicker`）、出怪行（`ZmZombieChooseRowSystem`）、波次时长、阳光落点。
##   纯表现随机（眨眼、断肢弹道、音效、花园）不同步也不影响胜负，留在全局随机即可。
##   已替换清单与后续待替换项见 [联机模组](../../docs/参考存档/联机模组.md)。
##
## 关联：[联机模组](../../docs/参考存档/联机模组.md) ｜ 抽怪入口 [RandomPicker](../core/autoload/random_picker.gd)

## 播种状态：false = 未播种（每次运行不同，等于原来的全局随机）
static var _rng: RandomNumberGenerator = null
static var _seed_value: int = 0
static var _is_seeded: bool = false


## 取随机发生器（第一次调用时才建，建好即 randomize，等价于原来的全局随机）
static func _ensure() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


#region 种子
## 播种：之后所有 `GameRng.*` 都是可复现的
## [param seed_value] 种子（联机时由主机统一下发）
static func set_seed(seed_value: int) -> void:
	_seed_value = seed_value
	_is_seeded = true
	_ensure().seed = seed_value
	Log.info("GameRng: 已播种 seed=%d，之后的随机可复现" % seed_value)


## 撤销播种：回到「每次运行不同」的默认行为（单机 / 退出联机时调）
static func clear_seed() -> void:
	_seed_value = 0
	_is_seeded = false
	_ensure().randomize()


## 当前是否处于播种状态
static func is_seeded() -> bool:
	return _is_seeded


## 当前种子（未播种时返回 0）
static func get_seed() -> int:
	return _seed_value


## 存 / 取发生器内部状态（做快照回滚时用，比记种子更细）
static func get_state() -> int:
	return _ensure().state


static func set_state(state: int) -> void:
	_ensure().state = state
#endregion


#region 取值（与 Godot 全局同名函数一一对应，替换时只换前缀）
static func randi() -> int:
	return _ensure().randi()


static func randf() -> float:
	return _ensure().randf()


static func randf_range(from: float, to: float) -> float:
	return _ensure().randf_range(from, to)


static func randi_range(from: int, to: int) -> int:
	return _ensure().randi_range(from, to)


## 从数组里等概率取一个（空数组返回 null）
static func pick_random(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[_ensure().randi() % array.size()]


## 原地洗牌（`Array.shuffle()` 用的是全局随机，走不了种子，所以这里自己洗）
static func shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _ensure().randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
#endregion
