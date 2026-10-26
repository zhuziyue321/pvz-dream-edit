extends Zombie000Base
## 靶子僵尸（DLC 的 `Zombie_target`，由模组「玩家对战」提供）
##
## ★ 它是什么：原版（PVZ1）里**没启用**的残留僵尸类型 —— `Zombie_target.reanim` 与三条文案
##   （「举着大靶心用于防御」「必须在已被突破的路线上使用标靶僵尸」「必须不惜一切代价保护标靶僵尸」）
##   都还在，但 C++ 那份参照实现里 `ZOMBIE_TARGET` 那段是整块注释掉的（见
##   `../re-plants-vs-zombies-main`），所以**没有原版行为可对齐**。
##   本模组按对战玩法接：**僵尸方每行摆一只当靶子，站着不动；植物方击破 3 只即算植物赢**
##   （摆位与胜负条件见 `levels/player_battle_day.gd`）。
##
## ★ 站着不动：`ready_norm()` 里给移动组件按上「禁用」因子（`E_MoveFactor.IsDisable`）。
##   它不是进攻单位 —— 不往前推、也不啃植物（红线把植物挡在左边，够不到）。
##
## ★ 素材只有 idle / hit / death（外加 death2 / superlongdeath 两个死亡变体）：
##   reanim 里没有 walk / eat 段 —— 走路与啃食本来都用不上，idle 循环就是它的常态。
##   掉血播 hit（0.83 s）、播完回 idle —— 接的是 `hp_component.signal_hp_loss`（子弹 / 爆炸都能触发）。
##   ⚠️ idle 段必须**循环**：转换器默认 `loop_mode = 0`，播一遍就停在最后一帧
##   （手改在 `animation/character/zombie/ZombieTarget/Zombie_target_idle.tres`，
##   重新转换时会被覆盖，记得补回 `loop_mode = 1`）。
##
## ★ 受创换外观：**换手里那块招牌的贴图**（DLC 的 TARGET_1/2/3），三档阈值与资源都在
##   `zombie_target.tscn` 的 `HpStageChangeComponent` 上（本体 `zombie_base.gd` 已经把
##   `hp_component.signal_hp_loss` 接到它的 `judge_body_change`，所以这里一行都不用写）。
##   换的是动画场景里 `Target` 底下的三张覆盖精灵（`TargetDamage1~3`），不是 `Target.texture`：
##   转换器把贴图写进了 idle 轨道，每轮重播都会把 `Target.texture` 写回完好那张。
##
## ★ 为什么不用本体的 AnimationTree 那套：DLC 动画是转换器逐帧烘焙出来的
##   「一堆 Sprite2D + 每段一个 AnimationPlayer」（与 DLC 植物同一套产物），不是
##   「骨架 + 状态机」。所以场景里把 `AnimComponent` 换成 `AnimComponentEmpty`，
##   由本脚本直接播动画场景里那个装好全部段的 `AnimLib`（具名库 `Zombie_target`）。
##
## ★ 死亡要自己收尾：本体僵尸的死亡动画自带 `_fade_and_remove` 方法轨，DLC 这段没有 ——
##   不自己补的话尸体会永远留在场上（`hp_component` 只把血扣到 0，不删节点）。
##   所以 `character_death()` 播 death，`animation_finished` 里淡出删除。
##
## ⚠️ 本文件跑在 `user://mods/player_battle/` 下时 `class_name` 不会注册成全局类，所以不写 class_name，
##    由同目录的 `zombie_target.tscn` 按路径引用。

## 动画名（带库名：动画场景里 `AnimationLibrary_targetlib` 挂在 `AnimLib` 上的键是 `Zombie_target`）
const ANIM_IDLE := &"Zombie_target/Zombie_target_idle"
const ANIM_HIT := &"Zombie_target/Zombie_target_hit"
const ANIM_DEATH := &"Zombie_target/Zombie_target_death"

## 播放器：动画场景里那个「一个播放器装全部段」的入口
@onready var _anim_player: AnimationPlayer = $Body/BodyCorrect/ZombieTargetAnim/AnimLib

## 正在死亡（播死亡动画到收尾这一段）：防重入 —— 同一帧可能被连打两下 / 被清场再打一次
var _is_dying := false


#region 生命周期
## 正常出战：**原地不动**（靶子是站位目标）+ idle 常播
func ready_norm() -> void:
	super()
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDisable)
	_play_idle()


## 展示态（图鉴 / 开局预览 / 卡面）：动画不进 AnimationTree，得自己把 idle 播起来
func ready_show() -> void:
	super()
	_play_idle()


func ready_norm_signal_connect() -> void:
	super()
	hp_component.signal_hp_loss.connect(_on_hp_loss)
	_anim_player.animation_finished.connect(_on_animation_finished)
#endregion


#region 免疫（与墓碑同一套待遇，2026-10-25）
## 免疫小推车**不在这里写**（2026-10-26 改）：小推车已经是一种**特殊伤害**
## （`E_DamageCause.Mower` + 秒杀，走 `DamageSystem`），免疫靠场景里那个
## `ImmuneMowerComponent`（`DamageModifierComponent` 子类）在修饰器链上整包取消 ——
## 见 `zombie_target.tscn`。角色脚本里不再需要「压不动」的特判。
##
## 靶子站第 10 列、站草坪外，推车被前面的僵尸触发后会一路开出去必然撞上它；
## 不挡的话，植物刚打掉半血的靶子会被「自己人」的车顺手推没，击破计数也跟着乱。

## 被魅惑僵尸无视：魅惑僵尸索敌时**不把靶子当目标**（DLC 原版里墓碑 / 靶子都不算敌对目标）。[br]
## 只挡「僵尸打僵尸」这一条通道 —— 植物照样能打它，否则击破 3 只判胜就无从谈起。
func is_targetable_by_hypno_zombie() -> bool:
	return false
#endregion


#region 死亡
## 角色死亡：先走本体那一套（禁攻击 / 受击框、发死亡信号给管理器），再播 DLC 的死亡段
func character_death() -> void:
	if _is_dying:
		return
	super()
	_is_dying = true
	_anim_player.play(ANIM_DEATH)


## 死亡动画播完：本体僵尸是靠动画方法轨 `_fade_and_remove` 收尾的，这里补上
##
## 关卡那边只听 `signal_character_death`（击破计数）—— 删节点是这一句的事
## 受击段播完回待机（0.83 s；不接这一下会停在受击最后一帧）
func _on_animation_finished(anim_name: StringName) -> void:
	if _is_dying:
		if anim_name == ANIM_DEATH:
			_fade_and_remove()
		return
	if anim_name == ANIM_HIT:
		_play_idle()


## 掉血就播一次受击段（DLC reanim 里的 hit，0.83 s）—— 打死的那一下不播，
## 交给死亡段（血量组件的死亡信号先于 signal_hp_loss 发出，所以这里判 is_death 就够）
func _on_hp_loss(_curr_hp: int, _is_drop: bool) -> void:
	if _is_dying or is_death:
		return
	_anim_player.play(ANIM_HIT)
#endregion


#region 动画
## 待机（同时也是它的「常态」）：已经在播就不打断，避免每帧重置
func _play_idle() -> void:
	if _is_dying or not is_instance_valid(_anim_player):
		return
	if _anim_player.current_animation == ANIM_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(ANIM_IDLE)
	## 立刻把第一帧写进各部件：图鉴 / 开局预览是在 `ready_show()` 之后**同一帧**把 `Body` 摘走的，
	## 不推这一下的话摘到的是一堆还停在 (0,0) 的散件
	_anim_player.seek(0.0, true)
#endregion
