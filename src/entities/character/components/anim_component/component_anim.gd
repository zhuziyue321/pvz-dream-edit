@abstract
extends ComponentNormBase
class_name AnimComponentBase
## 动画组件基类
## 由于部分僵尸可能没有AnimationTree或者AnimationPlayer
## 使用该组件统一进行一些动画速度的控制
## 子类实现具体方法
##
## 已接入组件体系（`ComponentNormBase`），子类初始化写在 `component_ready()` 里。
##
## 本类的 `owner_update_speed()` 与组件基类同名 —— 那不是「漏了 extends」的痕迹，
## 而是组件体系本来就约定了这个速度钩子，接入后正好对上。
##
## 关于禁用机制：动画是攻击帧的驱动者（`_shoot_bullet()` 由动画轨调用），一旦被禁用
## 就表现为「全体不攻击」且不报错。但全仓无任何代码对 `anim_component` 调
## `disable_component()`，所以继承来的 `is_enabling` 恒为 true。
## （曾经接入后出现过该回归，但元凶是攻击组件改名漏了 `super()`，与本类无关 ——
##   回退本类后症状并未消失。见 2026-10-07 的工作记录。）

## 动画结束信号
signal signal_animation_finished(anim_name:StringName)

## 角色动画原始速度
var animation_origin_speed :float = -1


## 获取动画原始速度
func get_animation_origin_speed():
	if animation_origin_speed == -1:
		Log.error("动画速度为-1")
	return animation_origin_speed

## 设置初始化速度(伴舞使用)
func set_animation_origin_speed(value:float):
	animation_origin_speed = value

## 更新动画速度(根据速度倍率)
@abstract
func owner_update_speed(speed_factor_product:float)

## 更新动画速度(动画播放速度)
@abstract
func update_anim_speed_scale(speed_scale:float)

## 停止动画
func stop_anim():
	pass

## 动画结束时发射信号
func _on_animation_finished(anim_name:StringName):
	signal_animation_finished.emit(anim_name)
	#Log.debug("当前动画结束")

