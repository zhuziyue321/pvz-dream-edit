extends PlantSunProducerBase
## 产脑光墓碑（DLC 对战墓碑 VSGravestone，由模组「僵尸卡」提供）
##
## ★ 玩法一句话：**50 脑光**的僵尸方单位（只在「玩家对战」里发得出来），行为类似
##   向日葵 —— 放下去后周期性给僵尸方银行入账脑子（见 `component_create_brains.gd`：
##   节奏全复用本体的产阳光组件，只把出阳光换成脑子入账）。
##
## ★ 为什么继承 PlantSunProducerBase 还要在僵尸模式把产阳光重新打开：
##   基类 ready_norm() 在 `is_zombie_mode` 时禁用 CreateSunComponent —— 那是给
##   「我是僵尸」关里**纸板植物**用的口径（纸板植物不产阳光）。对战的空关卡现在
##   没设 is_zombie_mode，这道保险平时不生效；哪天对战把放置限制补上、关卡标了
##   is_zombie_mode，墓碑也不至于被这道闸误伤（僵尸方的产钱单位不该被它拦）。
##
## ★ 动画走 VSGravestone.reanim → Godot 动画（`animation/character/plant/VSGravestone/`），
##   两段装在同一个库 `AnimLib` 里：
##     · `VSGravestone_rise`（0.5 s）：出土
##     · `VSGravestone_idle`（0 长度静帧）：立定待机
##   转换产物只保留这两段（break / roof / night / water 各段本模组用不上）。
##
## ⚠️ 本文件可能跑在 `user://mods/zombie_card/` 下：不写 `class_name`
##    （同 `aloe_plant.gd` 口径，全局类型只引用本体的）。

## 动画播放器：动画场景里 root 下最后一个子节点（见同目录 `VSGravestone.tscn` 注释）；
## 动画整体套在出土裁剪板 `VSGravestoneMask` 里（见场景内注释）
@onready var _anim_player: AnimationPlayer = $Body/VSGravestoneMask/VSGravestoneAnim/AnimLib


#region 动画常量
const STATE_IDLE := &"VSGravestone_idle"
const STATE_RISE := &"VSGravestone_rise"
#endregion


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 关卡全场加速（「僵尸快跑」）要连动画一起加速；产阳光计时器基类已经连过
	signal_update_speed.connect(_on_update_speed_anim)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	if is_zombie_mode:
		## 基类按「纸板植物」口径在僵尸模式关了产阳光，这里重新打开（见文件头）
		create_sun_component.enable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
	_play(STATE_RISE)


## 初始化展示角色（图鉴 / 选卡界面里的形象）
func ready_show() -> void:
	super()
	_play(STATE_IDLE)


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play(STATE_IDLE)
#endregion


#region 动画回调
## 一段动画播完：出土播完回待机
func _on_animation_finished(anim_name: StringName) -> void:
	if is_death:
		return
	if anim_name == STATE_RISE:
		_play(STATE_IDLE)


## 播一段动画；待机是静帧，显式 seek 一次确保第 0 帧姿态被应用
func _play(anim: StringName) -> void:
	if _anim_player.current_animation == anim and _anim_player.is_playing():
		return
	_anim_player.play(anim)
	_anim_player.seek(0.0, true)


## 全场加速：动画跟着折算（产阳光计时器由基类接的 `owner_update_speed` 折算）
func _on_update_speed_anim(speed_product: float) -> void:
	_anim_player.speed_scale = speed_product
#endregion
