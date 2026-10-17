extends Node2D
## 模组「招笑版」：**掉在草坪上的路障** —— 路障僵尸变种走到第 4 列摔倒时掉下来的那个，
## **永久存在**（本关不清、不淡出，与本体那些「弹一下淡出」的掉落物正好相反），
## 后来走到它身上的僵尸会被**绊倒**（挂一个 `zhaoxiao_fall.gd` 摔倒状态）。
##
## ★ 三条口径：
##   1. **永久存在**：挂在僵尸行节点上（与本体掉落物同一个父节点，见
##      `ZombieDropBase.acitvate_it()`），跟着这一行活到关尾 —— 没有着地动画、
##      没有淡出，掉下来就躺在那儿。
##   2. **只绊本行的**：每物理帧扫一遍 `ZombieManager.all_zombies_2d[lane]`
##      （本体自己也在用的按行僵尸表），与路障的 |x 差| ≤ `CONE_TRIP_RANGE` 就绊。
##      朝左走来的 / 朝右走来的（魅惑僵尸）都绊；天上（气球）和地下（矿工）的碰不到它。
##   3. **每只僵尸只被同一根路障绊一次**：摔倒的那只记在 `_tripped` 里
##      （掉路障的那只自己也算 —— 它摔倒时人就压在路障上，起来走远就不再绊第二次）；
##      已经摔着的（身上有摔倒状态）不重复绊。
##
## ★ 贴图是**借本体的**：`zombie_cone.tscn` 里那套「路障掉地上」用的正是这一张
##   （`Node2D_Arm1_Drop` 子树里的 `Zombie_cone3.png`）—— 与模组其它「借原版素材」同一个口径。
##
## ⚠️ 本类是普通 `Node2D`（不是 `Character000Base` / `ComponentNormBase` 的子类），
##    `_ready()` 按 Godot 常态写即可 —— 硬约束 §1-3 只管那两类角色 / 组件。

const Settings := preload("zhaoxiao_settings.gd")
const FallStatus := preload("zhaoxiao_fall.gd")

## 场上所有掉落的路障共用一个组名（探针按它找）
const GROUP := &"zhaoxiao_cone_drop"
## 节点名（同一行可能掉好几根，引擎会自动加 `@N` 后缀，不靠名字找）
const NODE_NAME := &"ConeDrop"
## 贴图节点名
const SPRITE_NAME := &"ConeBody"

## 路障贴图：**借本体**路障僵尸「掉地上」那一张（`zombie_cone.tscn` 同款）
const CONE_TEXTURE := preload("res://pak/reanim/Zombie_cone3.png")

## 在哪一行（决定扫哪一行僵尸 / 画在哪一层）
var lane := -1
## 掉下这根路障的那只僵尸（它起来走远之前不算「后来的僵尸」，不再绊它）
var _ignore: Zombie000Base
## 已经被这根路障绊过的僵尸（每只只绊一次）
var _tripped: Array = []


#region 初始化
## 初始化（与本体掉落物一样：**加入场景树之前**调）
##
## [param p_lane]  哪一行
## [param p_ignore] 掉下这根路障的那只僵尸（不再绊它）
func setup(p_lane: int, p_ignore: Zombie000Base) -> void:
	lane = p_lane
	_ignore = p_ignore


func _ready() -> void:
	## 层级口径与本体掉落物一致：不设 z_index（0）⇒ 画在僵尸（z_index = 10）后面
	_build_sprite()
	add_to_group(GROUP)


## 自己造一个贴图节点（**不用场景**：本模组整目录拷到 `user://mods/` 也要能跑，
## 路径读不到的 `.tscn` 不如直接 `new()` 一个 `Sprite2D` 省事）
func _build_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.name = SPRITE_NAME
	sprite.texture = CONE_TEXTURE
	## 往上抬一点，看着是「掉在地上」而不是浮空
	sprite.position = Vector2(0.0, Settings.CONE_GROUND_OFFSET_Y)
	add_child(sprite)
#endregion


#region 每物理帧：扫本行僵尸，走到身上的绊倒
func _physics_process(_delta: float) -> void:
	var manager := _zombie_manager()
	if manager == null or lane < 0 or lane >= manager.all_zombies_2d.size():
		return
	_prune_tripped()
	var row_zombies: Array = manager.all_zombies_2d[lane]
	for i in range(row_zombies.size()):
		var zombie: Zombie000Base = row_zombies[i]
		if not is_instance_valid(zombie) or zombie == _ignore:
			continue
		if _tripped.has(zombie):
			continue
		if not _can_trip(zombie):
			continue
		if absf(zombie.global_position.x - global_position.x) > Settings.CONE_TRIP_RANGE:
			continue
		_tripped.append(zombie)
		_trip(zombie)


## 这只僵尸能被这根路障绊吗
func _can_trip(zombie: Zombie000Base) -> bool:
	if zombie.is_death:
		return false
	## 已经摔着的（被别的路障绊过 / 自己就是路障僵尸摔着了）不再重复绊
	if zombie.get_node_or_null(FallStatus.NODE_PATH) != null:
		return false
	## 天上（气球）和地下（矿工）的碰不到地上的路障
	var status: int = zombie.curr_be_attack_status
	if status == Zombie000Base.E_BeAttackStatusZombie.IsSky \
			or status == Zombie000Base.E_BeAttackStatusZombie.IsDownGround:
		return false
	return true


## 绊倒它：挂一个摔倒状态（趴 `FALL_TIME` 秒，然后自己站起来继续走）
func _trip(zombie: Zombie000Base) -> void:
	var fall := FallStatus.new()
	fall.name = FallStatus.NODE_NAME
	zombie.add_child(fall)


## 把已经没了的僵尸从「绊过」名单里剔掉（名单很小，每帧重扫一遍成本可忽略）
func _prune_tripped() -> void:
	if _tripped.is_empty():
		return
	var alive: Array = []
	for one in _tripped:
		if is_instance_valid(one):
			alive.append(one)
	_tripped = alive


func _zombie_manager() -> ZombieManager:
	var main_game: MainGameManager = GameContext.curr_main_game
	if main_game == null:
		return null
	return main_game.zombie_manager
#endregion
